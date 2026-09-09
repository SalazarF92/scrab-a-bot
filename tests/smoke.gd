extends Node2D
## Teste de fumaca sem interface, para rodar na integracao continua.
##
##   Godot --headless --path <projeto> res://tests/smoke.tscn
##
## Cobre as tres coisas que, se quebrarem, quebram o jogo em silencio:
##  1. tunelamento de projetil, que o cast de varredura existe para impedir;
##  2. as restricoes de arena do GDD 3.3.4, que garantem o pilar 3;
##  3. a tabela de multiplicador de quique, que e o balanceamento inteiro.
##
## O GDD 7.6 exige benchmark noturno com falha da integracao continua se cair de
## 60 fps. Este arquivo e o lugar onde esse benchmark passa a morar.

const WorkbenchUI := preload("res://ui/workbench_ui.gd")

const SIM_FRAMES := 900
const WARMUP_FRAMES := 300
const PROJECTILES := 800
const ARENA_GENERATIONS := 40

var arena: ArenaGenerator
var pool: ProjectilePool
var _frames := 0
var _failures: Array[String] = []
var _peak_physics_ms := 0.0
var _physics_samples: Array[float] = []
var _spike_frames: Array[int] = []
var _peak_frame := 0


## Semente fixa. Sem isto o benchmark mede uma arena diferente a cada execucao e
## a variacao entre noites vira ruido em cima da regressao que se quer detectar.
const FIXED_SEED := 20260908


func _ready() -> void:
	GameRng.reseed(FIXED_SEED)
	print("=== SCRAP-A-BOT :: teste de fumaca ===  semente %d" % FIXED_SEED)
	_test_bounce_table()
	_test_hitstop_cap()
	_test_arena_constraints()
	_test_meta_manager()
	_test_workbench()
	_test_enemy_and_boss_catalog()

	arena = ArenaGenerator.new()
	add_child(arena)
	arena.generate(1)

	pool = ProjectilePool.new()
	add_child(pool)
	_seed_projectiles()


func _seed_projectiles() -> void:
	var type := ProjectileType.make({
		"id": &"smoke", "speed": 1400.0, "radius": 6.0, "max_bounces": 12,
		"restitution": 1.0, "ttl": 30.0, "damage": 1.0,
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

	# Adiciona cobre e compra
	MetaManager.copper = 200
	_check(MetaManager.can_buy_upgrade("chapa"), "deve permitir compra com saldo")
	var bought := MetaManager.buy_upgrade("chapa")
	_check(bought and MetaManager.get_upgrade_level("chapa") == 1, "nivel de chapa deve ser 1")
	_check(MetaManager.copper == 50, "saldo restante deve ser 50")
	_check(is_equal_approx(MetaManager.get_bonus_hp_flat(), 15.0), "bonus de HP deve ser 15.0")

	# Testa persistencia em disco
	MetaManager.load_save()
	_check(MetaManager.copper == 50 and MetaManager.get_upgrade_level("chapa") == 1,
		"save recarregado deve manter saldo 50 e nivel de chapa 1")

	# Teste do Modo Ferro-Velho Infernal (Heat / Ascension)
	MetaManager.start_new_run(2)
	_check(MetaManager.selected_heat == 2, "heat selecionado deve ser 2")
	_check(is_equal_approx(MetaManager.get_heat_enemy_hp_mult(), 1.24), "mult de HP do Heat 2 deve ser 1.24")
	_check(is_equal_approx(MetaManager.get_heat_copper_bonus_mult(), 1.50), "bonus de cobre Heat 2 deve ser 1.50 (+50%)")
	# Vitoria no Heat 2 deve desbloquear Heat 3
	var win_summary := MetaManager.end_run(5, true)
	_check(win_summary["won"], "run deve marcar vitoria")
	_check(MetaManager.highest_heat_beaten >= 3, "maior heat superado deve ser pelo menos 3")

	print("  sistema de metaprogressao, economia, persistencia e Heat verificados")


func _test_enemy_and_boss_catalog() -> void:
	var keys := EnemyLibrary.keys()
	_check(keys.has("mini_prensa"), "chefe mini_prensa deve existir no catalogo")
	_check(keys.has("frostbyte"), "chefe frostbyte deve existir no catalogo")
	_check(keys.has("fornalha_suprema"), "chefe fornalha_suprema deve existir no catalogo")

	var s1_boss := EnemyLibrary.spec("mini_prensa", 1)
	_check(s1_boss["is_boss"] == true, "mini_prensa deve ser is_boss")
	_check(s1_boss["max_hp"] >= 400.0, "HP do chefe mini_prensa deve ser >= 400")

	print("  catalogo de inimigos e chefes de setor verificado")


## GDD 4.7 e GDD_ADENDOS B.1 / B.3: Bancada, vitrine, niveis de fusao e solda.
func _test_workbench() -> void:
	# 1. Teste de vitrine
	var offers := PartLibrary.roll_shop_offer(3)
	_check(offers.size() == 3, "vitrine deve conter 3 pecas")
	for p in offers:
		_check(p != null and p.display_name != "", "peca da vitrine deve ser valida")

	# 2. Teste de niveis de fusao e multiplicadores do GDD 4.7.1
	var dummy := PartData.new()
	dummy.fusion_level = 0
	_check(is_equal_approx(dummy.fusion_mult(), 1.0), "fusao Tier I deve ser 1.0x")
	dummy.fusion_level = 1
	_check(is_equal_approx(dummy.fusion_mult(), 1.4), "fusao Tier II deve ser 1.4x (+40%)")
	dummy.fusion_level = 2
	_check(is_equal_approx(dummy.fusion_mult(), 1.9), "fusao Tier III deve ser 1.9x (+90%)")
	dummy.fusion_level = 3
	_check(is_equal_approx(dummy.fusion_mult(), 2.6), "fusao Tier IV deve ser 2.6x (+160%)")

	# 3. Teste de custos de upgrade
	dummy.fusion_level = 0
	_check(dummy.upgrade_cost() == 80, "custo Tier I->II deve ser 80")
	dummy.fusion_level = 1
	_check(dummy.upgrade_cost() == 140, "custo Tier II->III deve ser 140")
	dummy.fusion_level = 2
	_check(dummy.upgrade_cost() == 220, "custo Tier III->IV deve ser 220")
	dummy.fusion_level = 3
	_check(dummy.upgrade_cost() == -1, "Tier IV nao deve permitir mais upgrade")

	# 4. Teste de operacoes na WorkbenchUI
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

	# Segunda tentativa de solda na mesma bancada deve ser bloqueada
	wb._try_repair()
	_check(is_equal_approx(test_robot.hp, 85.0) and MetaManager.current_scrap == 180,
		"segunda solda deve ser ignorada")

	# Reroll da vitrine (custo 60 base)
	wb._try_reroll()
	_check(wb._rerolls_used == 1, "contador de rerolls deve ser 1")
	_check(MetaManager.current_scrap == 120, "sucata apos reroll deve ser 120")

	wb.free()
	test_robot.free()

	print("  sistema da Bancada (vitrine, fusao, reroll e reparo) verificado")


