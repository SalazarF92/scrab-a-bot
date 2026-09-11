extends Node2D
## Teste de fumaca sem interface, para rodar na integracao continua.
##
##   powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
##   Godot --headless --path <projeto> res://tests/smoke.tscn
##
## Sem --fixed-fps: o benchmark precisa de ritmo de tempo real. Com a flag, o laco
## principal atropela a thread de audio e a fisica mostra picos falsos.
##
## Cobre as coisas que, se quebrarem, quebram o jogo em silencio:
##  1. tunelamento de projetil, que o cast de varredura existe para impedir;
##  2. as restricoes de arena do GDD 3.3.4, que garantem o pilar 3;
##  3. a tabela de multiplicador de quique, que e o balanceamento inteiro;
##  4. economia, desafio diario e Bancada;
##  5. pool de inimigos, invasao da base e filhotes da onda de bumpers;
##  6. determinismo: isolamento de fluxos e ausencia de RNG global no gameplay.
##
## Compilacao de todos os scripts fica em tests/compile_check.gd, e o jogo de
## ponta a ponta fica em tests/gameplay.gd.
##
## O GDD 7.6 exige benchmark noturno com falha da integracao continua se cair de
## 60 fps. Este arquivo e o lugar onde esse benchmark passa a morar.

const SIM_FRAMES := 900
const WARMUP_FRAMES := 300
const PROJECTILES := 800
const ARENA_GENERATIONS := 40

## Semente fixa. Sem isto o benchmark mede uma arena diferente a cada execucao e
## a variacao entre noites vira ruido em cima da regressao que se quer detectar.
const FIXED_SEED := 20260908

## Nunca tocar no save do jogador. A versao anterior deste teste chamava
## reset_save direto no user://save.json.
const TEST_SAVE := "user://smoke_test_save.json"

## Pastas de gameplay onde RNG global e proibido. Sintese de audio e efeito
## puramente visual ficam de fora: nao mudam o resultado da run.
const DETERMINISM_DIRS := ["res://actors", "res://combat", "res://data", "res://generation", "res://scenes"]

var arena: ArenaGenerator
var pool: ProjectilePool
var _frames := 0
var _failures: Array[String] = []
var _peak_physics_ms := 0.0
var _physics_samples: Array[float] = []
var _spike_frames: Array[int] = []
var _peak_frame := 0


func _ready() -> void:
	MetaManager.save_path = TEST_SAVE
	GameRng.reseed(FIXED_SEED)
	print("=== SCRAP-A-BOT :: teste de fumaca ===  semente %d" % FIXED_SEED)
	_test_bounce_table()
	_test_hitstop_cap()
	_test_arena_constraints()
	_test_stream_isolation()
	_test_meta_manager()
	_test_daily_challenge()
	_test_workbench()
	_test_shop_rarity()
	_test_enemy_and_boss_catalog()
	_test_enemy_pool_recycling()
	_test_bumper_and_breach()
	_test_run_caption()
	_test_determinism_lint()

	GameRng.reseed(FIXED_SEED)
	arena = ArenaGenerator.new()
	add_child(arena)
	arena.generate(1)

	pool = ProjectilePool.new()
	add_child(pool)
	_seed_projectiles()


func _seed_projectiles() -> void:
	# ignore_floor: o benchmark mede o cast de varredura, nao a regra do chao.
	var type := ProjectileType.make({
		"id": &"smoke", "speed": 1400.0, "radius": 6.0, "max_bounces": 12,
		"restitution": 1.0, "ttl": 30.0, "damage": 1.0, "ignore_floor": true,
	})
	var rng := GameRng.stream(GameRng.Stream.COMBAT)
	for i in PROJECTILES:
		var p := Vector2(
			rng.randf_range(100.0, ArenaGenerator.ARENA_SIZE.x - 100.0),
			rng.randf_range(100.0, ArenaGenerator.ARENA_SIZE.y - 100.0))
		pool.spawn(p, Vector2.from_angle(rng.randf_range(0.0, TAU)), type)
	print("  %d projeteis a 1400 px/s, o pior caso de tunelamento" % PROJECTILES)


func _physics_process(_delta: float) -> void:
	_frames += 1
	# Os primeiros quadros incluem a liberacao das salas do teste de arena e a
	# construcao do pool. Medir isso como custo de combate seria mentira.
	if _frames > WARMUP_FRAMES:
		var ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		_physics_samples.append(ms)
		if ms > _peak_physics_ms:
			_peak_physics_ms = ms
			_peak_frame = _frames
		if ms > 8.0:
			_spike_frames.append(_frames)

	if _frames == SIM_FRAMES:
		_finish()


func _percentile(values: Array[float], p: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[clampi(int(float(sorted.size()) * p), 0, sorted.size() - 1)]


func _finish() -> void:
	var bounds := Rect2(Vector2(-40, -40), ArenaGenerator.ARENA_SIZE + Vector2(80, 80))
	var escaped := pool.count_outside(bounds)
	var bounces := pool.total_bounces()

	_check(escaped == 0, "tunelamento: %d projeteis escaparam da arena" % escaped)

	# Projeteis morrendo e o comportamento CORRETO: com teto de 12 quiques, um
	# projetil a 1400 px/s esgota o contador em poucos segundos. O que precisa
	# ser verdade e que eles morreram quicando, e nao sumindo. Com 800 projeteis
	# e teto de 12, o total de eventos de quique tem que se aproximar de 10.400.
	_check(pool.debug_bounce_events > PROJECTILES * 8,
		"quiques: apenas %d eventos, esperado mais de %d" % [pool.debug_bounce_events, PROJECTILES * 8])
	print("  quiques por projetil: %.1f (teto do tipo: 12)" % (float(pool.debug_bounce_events) / float(PROJECTILES)))

	print("  projeteis vivos %d, quiques acumulados %d" % [pool.alive_count(), bounces])
	print("  diagnostico: casts %d, bloqueados %d, eventos de quique %d, contatos vazios %d" % [
		pool.debug_casts, pool.debug_blocked_casts, pool.debug_bounce_events, pool.debug_empty_contacts])

	# GDD 7.2, orcamento de 2,4 ms por quadro para a simulacao de projeteis.
	# O numero abaixo e de um binario de editor com depuracao ligada, que e
	# varias vezes mais lento que o template de exportacao; serve como alarme de
	# regressao, nao como o numero do Steam Deck.
	var med := _percentile(_physics_samples, 0.5)
	var p99 := _percentile(_physics_samples, 0.99)
	print("  fisica por quadro: mediana %.2f ms, p99 %.2f ms, pico %.2f ms no quadro %d (build de editor)" % [
		med, p99, _peak_physics_ms, _peak_frame])
	print("  quadros acima de 8 ms: %d  %s" % [_spike_frames.size(), str(_spike_frames.slice(0, 12))])

	# Contato vazio e o caminho em que o projetil atravessa a superficie sem
	# quicar. Uma ocorrencia rara e tolerada; uma taxa alta significa que o
	# cast de varredura nao esta resolvendo e o pilar 3 vaza.
	var empty_rate: float = float(pool.debug_empty_contacts) / maxf(float(pool.debug_blocked_casts), 1.0)
	_check(empty_rate < 0.01, "taxa de contato vazio de %.2f%%, teto de 1%%" % (empty_rate * 100.0))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))

	print("")
	if _failures.is_empty():
		print("=== TUDO OK ===")
		quit_with(0)
	else:
		print("=== %d FALHAS ===" % _failures.size())
		for f in _failures:
			print("  - " + f)
		quit_with(1)


func quit_with(code: int) -> void:
	# Fecha a entrada: projeteis vivos ainda geram quiques durante esta espera.
	# Parar so as vozes atuais permitiria criar playbacks ate o ultimo quadro.
	Sfx.shutdown()
	for k in 30:
		OS.delay_msec(10)
		await get_tree().process_frame
	get_tree().quit(code)


func _check(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)


# --- verificacoes puras -------------------------------------------------------

## GDD 3.3.2, a tabela que define o jogo inteiro.
func _test_bounce_table() -> void:
	var expected := {0: 1.0, 1: 1.25, 2: 1.5625, 3: 1.953125, 4: 4.0}
	for b in expected:
		_check(is_equal_approx(ProjectilePool.bounce_multiplier(b), expected[b]),
			"multiplicador do quique %d: %f, esperado %f" % [b, ProjectilePool.bounce_multiplier(b), expected[b]])
	# GDD_ADENDOS A.2: acima do 4o quique soma +0,12 por quique, ate 4,96 no 12o.
	_check(is_equal_approx(ProjectilePool.bounce_multiplier(12), 4.96),
		"multiplicador do quique 12: %f, esperado 4,96" % ProjectilePool.bounce_multiplier(12))
	# O teto rigido nao pode ser furado por um numero de quiques acima do limite.
	_check(is_equal_approx(ProjectilePool.bounce_multiplier(40), 4.96),
		"teto rigido furado acima de 12 quiques")
	print("  tabela de multiplicador de quique verificada")


## GDD 3.4.1: hitstop nao soma, vale o maior valor pendente, e nenhum quadro
## passa de 130 ms. Este e um bug classico do genero e precisa de teste.
func _test_hitstop_cap() -> void:
	CombatFeel.reset()
	for i in 50:
		CombatFeel.request_hitstop(40.0)
	CombatFeel._physics_process(0.0)
	_check(CombatFeel.frozen, "hitstop nao ativou")
	CombatFeel.request_hitstop(9000.0)
	CombatFeel._physics_process(0.0)
	# Passa de 130 ms so em evento roteirizado; 9 s virou 130 ms.
	CombatFeel._physics_process(0.131)
	_check(not CombatFeel.frozen, "hitstop passou do teto de 130 ms sem ser roteirizado")
	CombatFeel.reset()
	print("  regra de acumulo e teto de hitstop verificados")


## GDD 3.3.4. Gera muitas salas e exige que TODAS passem em TODAS as restricoes.
## Uma restricao que falha em uma sala em cada trinta e uma run arruinada por
## sessao, o que e inaceitavel num jogo de 12 minutos por run.
func _test_arena_constraints() -> void:
	var gen := ArenaGenerator.new()
	add_child(gen)
	var bad := 0
	for i in ARENA_GENERATIONS:
		gen.generate(1)
		var r := gen.last_report
		if not (r["coverage_ok"] and r["corridors_ok"] and r["reachable_ok"] and r["surface_dist_ok"]):
			bad += 1
			if bad <= 3:
				print("    sala reprovada: %s" % str(r))
	_check(bad == 0, "%d de %d salas geradas violaram as restricoes do GDD 3.3.4" % [bad, ARENA_GENERATIONS])
	gen.queue_free()
	print("  %d salas geradas, %d reprovadas" % [ARENA_GENERATIONS, bad])


## GDD 7.3: fluxos separados por sistema. A arena de uma semente tem que ser a
## mesma, nao importa quanto os fluxos de ondas, vitrine e drops foram consumidos.
func _test_stream_isolation() -> void:
	var gen := ArenaGenerator.new()
	add_child(gen)
	GameRng.reseed(FIXED_SEED)
	gen.generate(2)
	var first: Array = gen._obstacle_rects.duplicate()

	GameRng.reseed(FIXED_SEED)
	var waves := GameRng.stream(GameRng.Stream.WAVES)
	var shop := GameRng.stream(GameRng.Stream.SHOP)
	var drops := GameRng.stream(GameRng.Stream.DROPS)
	var combat := GameRng.stream(GameRng.Stream.COMBAT)
	for k in 500:
		waves.randf()
		shop.randf()
		drops.randf()
		combat.randf()
	gen.generate(2)
	_check(gen._obstacle_rects == first, "a arena mudou quando outros fluxos foram consumidos: fluxos nao estao isolados")
	gen.queue_free()
	print("  isolamento dos fluxos de RNG verificado")


## GDD 6.1 a 6.3: persistencia, conversao de sucata em cobre e aplicacao de upgrades.
func _test_meta_manager() -> void:
	MetaManager.reset_save()
	_check(MetaManager.copper == 0, "cobre inicial deve ser 0")

	# Simula run: 80 sucata coletada no setor 2 -> 10 cobre (sucata/8) + 40 (setor 2 - 1 * 40) = 50 cobre
	MetaManager.start_new_run()
	MetaManager.add_scrap(80)
	var summary := MetaManager.end_run(2, false)
	_check(summary["copper_earned"] == 50, "ganho de cobre esperado 50, obtido %d" % summary["copper_earned"])
	_check(MetaManager.copper == 50, "total de cobre esperado 50, obtido %d" % MetaManager.copper)

	# Compra de upgrade sem saldo suficiente deve falhar (Solda Reforcada custa 150)
	_check(not MetaManager.can_buy_upgrade("chapa"), "nao deve permitir compra sem saldo")

	MetaManager.copper = 200
	_check(MetaManager.can_buy_upgrade("chapa"), "deve permitir compra com saldo")
	var bought := MetaManager.buy_upgrade("chapa")
	_check(bought and MetaManager.get_upgrade_level("chapa") == 1, "nivel de chapa deve ser 1")
	_check(MetaManager.copper == 50, "saldo restante deve ser 50")
	_check(is_equal_approx(MetaManager.get_bonus_hp_flat(), 15.0), "bonus de HP deve ser 15.0")

	MetaManager.load_save()
	_check(MetaManager.copper == 50 and MetaManager.get_upgrade_level("chapa") == 1,
		"save recarregado deve manter saldo 50 e nivel de chapa 1")

	# Gasto e reembolso de Sucata. Reembolso nao passa pelo Ima de Sucata.
	MetaManager.current_scrap = 100
	_check(not MetaManager.spend_scrap(101) and MetaManager.current_scrap == 100, "gasto acima do saldo deve falhar sem alterar nada")
	_check(MetaManager.spend_scrap(40) and MetaManager.current_scrap == 60, "gasto de 40 deve deixar 60")
	MetaManager.refund_scrap(45)
	_check(MetaManager.current_scrap == 105, "reembolso de 45 deve deixar 105")

	# Modo Ferro-Velho Infernal (Heat / Ascension)
	MetaManager.start_new_run(2)
	_check(MetaManager.selected_heat == 2, "heat selecionado deve ser 2")
	_check(is_equal_approx(MetaManager.get_heat_enemy_hp_mult(), 1.24), "mult de HP do Heat 2 deve ser 1.24")
	_check(is_equal_approx(MetaManager.get_heat_copper_bonus_mult(), 1.50), "bonus de cobre Heat 2 deve ser 1.50 (+50%)")
	var win_summary := MetaManager.end_run(5, true)
	_check(win_summary["won"], "run deve marcar vitoria")
	_check(MetaManager.highest_heat_beaten >= 3, "maior heat superado deve ser pelo menos 3")

	print("  sistema de metaprogressao, economia, persistencia e Heat verificados")


## GDD 6.2 e 6.3.5: recompensa de 150 uma vez por dia, risco zero no diario, e a
## vitoria no diario nao desbloqueia nivel de risco.
func _test_daily_challenge() -> void:
	MetaManager.reset_save()
	MetaManager.selected_heat = 2
	MetaManager.start_new_run(-1, true, GameRng.daily_seed())
	_check(MetaManager.active_heat() == 0, "desafio diario deve ignorar a Calibragem de Risco")
	var first := MetaManager.end_run(1 + MetaManager.DAILY_GOAL_SECTORS, false)
	_check(int(first["daily_reward"]) == MetaManager.DAILY_REWARD,
		"cumprir a meta do dia deve pagar %d, pagou %d" % [MetaManager.DAILY_REWARD, int(first["daily_reward"])])
	_check(MetaManager.daily_rewarded, "meta do dia deve ficar marcada")

	MetaManager.start_new_run(-1, true, GameRng.daily_seed())
	var second := MetaManager.end_run(5, true)
	_check(int(second["daily_reward"]) == 0, "recompensa do desafio diario so pode sair uma vez por dia")
	_check(MetaManager.daily_best_sectors == 5, "melhor do dia deve ser 5 setores, e %d" % MetaManager.daily_best_sectors)
	_check(MetaManager.highest_heat_beaten == 0, "vitoria no desafio diario nao pode desbloquear nivel de risco")

	MetaManager.load_save()
	_check(MetaManager.daily_rewarded and MetaManager.daily_best_sectors == 5, "progresso do dia deve persistir no save")
	MetaManager.selected_heat = 0
	MetaManager.start_new_run(0)
	print("  desafio diario verificado (semente %s)" % GameRng.seed_label(GameRng.daily_seed()))


func _test_enemy_and_boss_catalog() -> void:
	var keys := EnemyLibrary.keys()
	_check(keys.has("mini_prensa"), "chefe mini_prensa deve existir no catalogo")
	_check(keys.has("frostbyte"), "chefe frostbyte deve existir no catalogo")
	_check(keys.has("fornalha_suprema"), "chefe fornalha_suprema deve existir no catalogo")
	_check(keys.has("geladeira_bumper"), "geladeira da onda de bumpers deve existir no catalogo")

	var s1_boss := EnemyLibrary.spec("mini_prensa", 1)
	_check(s1_boss["is_boss"] == true, "mini_prensa deve ser is_boss")
	_check(s1_boss["max_hp"] >= 400.0, "HP do chefe mini_prensa deve ser >= 400")
	for k in keys:
		_check(EnemyLibrary.SPECS[k].has("article"), "inimigo %s sem artigo para a legenda" % k)

	print("  catalogo de inimigos e chefes de setor verificado")


## GDD 7.2, otimizacao 1. O objeto reciclado nao pode herdar nada do tipo anterior.
func _test_enemy_pool_recycling() -> void:
	var ep := EnemyPool.new()
	add_child(ep)
	var capacity := ep.capacity()

	var rat := ep.acquire(EnemyLibrary.spec("rato_morto", 1), Vector2(500, 300))
	_check(rat.is_in_group(&"enemies") and rat.zigzag_amplitude > 0.0, "Rato Morto do pool deve estar ativo e com ziguezague")
	ep.release(rat)
	_check(not rat.is_in_group(&"enemies") and not rat.is_in_group(&"damageable"), "inimigo liberado continua nos grupos")
	_check(rat.collision_layer == 0, "inimigo liberado continua sendo superficie de quique")

	var screw_spec := EnemyLibrary.spec("parafuseta", 1)
	var screw := ep.acquire(screw_spec, Vector2(500, 300))
	_check(screw == rat, "o pool deveria reciclar o mesmo objeto")
	_check(is_zero_approx(screw.zigzag_amplitude), "Parafuseta reciclada herdou o ziguezague do Rato Morto")
	_check(is_equal_approx(screw.hp, screw_spec["max_hp"]), "Parafuseta reciclada com HP errado")
	_check(ep.capacity() == capacity and ep.grown == 0, "o pool alocou em vez de reciclar")

	ep.release_all()
	_check(ep.active_count() == 0, "release_all deixou inimigos ativos")
	ep.queue_free()
	print("  pool de inimigos verificado (%d pre-alocados)" % capacity)


## Onda de bumpers: matar a geladeira libera o enxame. E invasao da base nao paga.
func _test_bumper_and_breach() -> void:
	var ep := EnemyPool.new()
	add_child(ep)
	var dir := WaveDirector.new()
	dir.enemy_pool = ep
	add_child(dir)
	dir.active = true

	var fridge := ep.acquire(EnemyLibrary.spec("geladeira_bumper", 2), Vector2(500, 300))
	_check(fridge.is_bumper and fridge.restitution > 1.0, "geladeira da onda de bumpers deve ser superficie que acelera")
	var before := dir.pending_spawns()
	fridge.take_damage(1.0e9, fridge.global_position, 4)
	_check(not fridge.active, "geladeira deveria ter morrido")
	_check(dir.pending_spawns() == before + fridge.spawn_on_death_count,
		"geladeira morta deveria telegrafar %d filhotes, telegrafou %d" % [fridge.spawn_on_death_count, dir.pending_spawns() - before])

	var screw := ep.acquire(EnemyLibrary.spec("parafuseta", 1), Vector2(500, ArenaGenerator.BASELINE_Y))
	var kills := Telemetry.enemies_killed
	var scrap := MetaManager.current_scrap
	var breaches := Telemetry.enemies_breached
	screw._check_contact()
	_check(not screw.active, "inimigo na baseline deveria invadir e sumir")
	_check(Telemetry.enemies_killed == kills and MetaManager.current_scrap == scrap,
		"invasao da base contou abate ou pagou Sucata")
	_check(Telemetry.enemies_breached == breaches + 1, "invasao da base nao foi registrada")

	dir.stop()
	ep.release_all()
	dir.queue_free()
	ep.queue_free()
	print("  onda de bumpers e invasao da base verificadas")


## GDD 4.7 e GDD_ADENDOS B.1 / B.3: Bancada, vitrine, niveis de fusao e solda.
func _test_workbench() -> void:
	var offers := PartLibrary.roll_shop_offer(3)
	_check(offers.size() == 3, "vitrine deve conter 3 pecas")
	for p in offers:
		_check(p != null and p.display_name != "", "peca da vitrine deve ser valida")

	# Niveis de fusao e multiplicadores do GDD 4.7.1
	var dummy := PartData.new()
	dummy.fusion_level = 0
	_check(is_equal_approx(dummy.fusion_mult(), 1.0), "fusao Tier I deve ser 1.0x")
	dummy.fusion_level = 1
	_check(is_equal_approx(dummy.fusion_mult(), 1.4), "fusao Tier II deve ser 1.4x (+40%)")
	dummy.fusion_level = 2
	_check(is_equal_approx(dummy.fusion_mult(), 1.9), "fusao Tier III deve ser 1.9x (+90%)")
	dummy.fusion_level = 3
	_check(is_equal_approx(dummy.fusion_mult(), 2.6), "fusao Tier IV deve ser 2.6x (+160%)")

	dummy.fusion_level = 0
	_check(dummy.upgrade_cost() == 80, "custo Tier I->II deve ser 80")
	dummy.fusion_level = 1
	_check(dummy.upgrade_cost() == 140, "custo Tier II->III deve ser 140")
	dummy.fusion_level = 2
	_check(dummy.upgrade_cost() == 220, "custo Tier III->IV deve ser 220")
	dummy.fusion_level = 3
	_check(dummy.upgrade_cost() == -1, "Tier IV nao deve permitir mais upgrade")

	var test_robot := Robot.new()
	add_child(test_robot)
	test_robot.max_hp = 100.0
	test_robot.hp = 50.0

	var wb := WorkbenchUI.new()
	wb.robot = test_robot
	add_child(wb)
	wb.open_workbench(1)

	# Solda de reparo (+35% de 100 = +35 HP, 50 -> 85, custo 120 sucata)
	MetaManager.current_scrap = 300
	wb._try_repair()
	_check(is_equal_approx(test_robot.hp, 85.0), "HP apos solda deve ser 85, obtido %f" % test_robot.hp)
	_check(MetaManager.current_scrap == 180, "sucata apos solda deve ser 180")
	_check(wb._repair_used, "solda deve marcar como utilizada")

	wb._try_repair()
	_check(is_equal_approx(test_robot.hp, 85.0) and MetaManager.current_scrap == 180,
		"segunda solda deve ser ignorada")

	wb._try_reroll()
	_check(wb._rerolls_used == 1, "contador de rerolls deve ser 1")
	_check(MetaManager.current_scrap == 120, "sucata apos reroll deve ser 120")

	# Fusao de duplicata (GDD 4.7.1): comprar a peca equipada sobe o tier.
	var left := PartLibrary.arm_left_parts()
	test_robot.equip(left[0].clone())
	MetaManager.current_scrap = 1000
	var duplicate_offer := left[0].clone()
	wb._offers.clear()
	wb._offers.append(duplicate_offer)
	_check(wb.offer_mode(duplicate_offer) == &"fuse", "oferta igual a peca equipada deveria ser fusao")
	wb._try_buy_offer(0)
	var fused: PartData = test_robot.equipped[PartData.Slot.ARM_LEFT]
	_check(fused.id == duplicate_offer.id and fused.fusion_level == 1, "fusao de duplicata deveria levar ao Tier II")
	_check(MetaManager.current_scrap == 1000 - duplicate_offer.base_price(), "fusao cobrou o preco errado")

	# Troca (GDD_ADENDOS B.3): peca diferente devolve metade do preco da que sai.
	var drill := left[1].clone()
	wb._offers.append(drill)
	var scrap_before := MetaManager.current_scrap
	var refund := fused.sell_value()
	wb._try_buy_offer(0)
	_check(test_robot.equipped[PartData.Slot.ARM_LEFT].id == drill.id, "troca deveria equipar a furadeira")
	_check(MetaManager.current_scrap == scrap_before - drill.base_price() + refund,
		"troca deveria custar %d e devolver %d" % [drill.base_price(), refund])

	wb.free()
	test_robot.free()

	print("  sistema da Bancada (vitrine, fusao, troca, reroll e reparo) verificado")


## GDD 3.1, tabela de ritmo: a vitrine segue a raridade do setor.
func _test_shop_rarity() -> void:
	GameRng.reseed(FIXED_SEED)
	var early_violations := 0
	var recipe_leaks := 0
	for p in PartLibrary.roll_shop_offer(200, 1):
		if p.rarity > PartData.Rarity.UNCOMMON:
			early_violations += 1
		if p.recipe_only:
			recipe_leaks += 1
	_check(early_violations == 0, "setor 1 ofertou %d pecas acima de Incomum" % early_violations)
	_check(recipe_leaks == 0, "a vitrine ofertou %d resultados de receita de fusao" % recipe_leaks)

	var late_commons := 0
	for p in PartLibrary.roll_shop_offer(200, 5):
		if p.rarity == PartData.Rarity.COMMON:
			late_commons += 1
	_check(late_commons == 0, "setor 5 ofertou %d pecas Comuns" % late_commons)

	var w := PartLibrary.rarity_weights(1, 0.15)
	_check(is_equal_approx(w[PartData.Rarity.COMMON], 65.0) and is_equal_approx(w[PartData.Rarity.RARE], 15.0),
		"Olho Clinico deveria mover 15 pontos de Comum para Rara no setor 1: %s" % str(w))

	GameRng.reseed(FIXED_SEED)
	var a := _ids(PartLibrary.roll_shop_offer(4, 3))
	GameRng.reseed(FIXED_SEED)
	var b := _ids(PartLibrary.roll_shop_offer(4, 3))
	_check(a == b, "a mesma semente gerou vitrines diferentes")
	print("  raridade da vitrine por setor verificada")


func _ids(parts: Array[PartData]) -> Array:
	var out: Array = []
	for p in parts:
		out.append("%s:%d" % [p.id, p.rarity])
	return out


## GDD 1.4, item 3.
func _test_run_caption() -> void:
	var r := Robot.new()
	add_child(r)
	r.set_cpu(PartLibrary.cpus()[0])
	r.equip(PartLibrary.head_parts()[0].clone())
	r.equip(PartLibrary.chassis_parts()[0].clone())
	r.equip(PartLibrary.arm_right_parts()[0].clone())
	r.last_damage_source = RunCaption.by_whom("a", "Mini-Prensa 500")

	var text := RunCaption.build(r, false, 3, FIXED_SEED)
	_check(text.contains("pela Mini-Prensa 500"), "legenda sem o autor da morte: " + text)
	_check(text.contains("torradeira") and text.contains("molas de sofá"), "legenda sem as pecas: " + text)
	_check(text.contains("setor 3"), "legenda sem o setor: " + text)
	_check(RunCaption.build(r, false, 3, FIXED_SEED) == text, "a mesma semente deveria gerar a mesma legenda")
	_check(RunCaption.by_whom("uma", "Parafuseta") == "por uma Parafuseta", "contracao por + uma")
	_check(RunCaption.by_whom("o", "FROSTBYTE 500") == "pelo FROSTBYTE 500", "contracao por + o")
	print("  legenda: " + text)
	r.free()


## GDD 7.3: toda aleatoriedade da run passa pelo GameRng. Chamar o RNG global em
## codigo de gameplay quebra o desafio diario e a reproducao de bug em silencio,
## entao isto e verificado no fonte.
func _test_determinism_lint() -> void:
	var re := RegEx.new()
	re.compile("(?<![\\w.])(randf|randi|randf_range|randi_range|randfn|randomize)\\s*\\(")
	var offenders: Array[String] = []
	for dir_path in DETERMINISM_DIRS:
		var files: Array[String] = []
		_collect_gd(dir_path, files)
		for f in files:
			var line_no := 0
			for line in FileAccess.get_file_as_string(f).split("\n"):
				line_no += 1
				var code: String = line.split("#")[0]
				if re.search(code) != null:
					offenders.append("%s:%d" % [f, line_no])
	_check(offenders.is_empty(), "RNG global em codigo de gameplay: " + ", ".join(offenders))
	print("  nenhum RNG global no gameplay")


func _collect_gd(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_gd(dir_path.path_join(entry), out)
		elif entry.ends_with(".gd"):
			out.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
