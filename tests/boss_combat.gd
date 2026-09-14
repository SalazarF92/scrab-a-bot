extends Node
## Contratos dos chefes adaptados ao poco: dano direcional, aviso antes do
## ataque, mira fixa/esquiva, fases, projeteis hostis e reset do pool.

const TEST_SAVE := "user://boss_combat_test_save.json"
var _failures: Array[String] = []
var _enemy: Enemy
var _target: BossTarget
var _projectiles: ProjectilePool


class BossTarget extends Node2D:
	var pool: ProjectilePool
	var damage_received := 0.0
	var last_source := ""
	var breaches := 0

	func take_damage(amount: float, _from: Vector2 = Vector2.ZERO, _bounce: int = 0,
			source: String = "", breach: bool = false) -> void:
		damage_received += amount
		last_source = source
		breaches += 1 if breach else 0

	func body_center() -> Vector2:
		return global_position

	var pushed := Vector2.ZERO
	func apply_push(v: Vector2) -> void:
		pushed += v


## Ouve as chamadas de call_group que os chefes fazem ao diretor de ondas.
class DirectorSpy extends Node:
	var minions: Array = []
	var obstacles: Array = []
	func _ready() -> void:
		add_to_group(&"wave_director")
	func spawn_minions(key: String, at: Vector2, count: int) -> void:
		minions.append({"key": key, "at": at, "count": count})
	func spawn_obstacle(at: Vector2, size: Vector2, restitution: float, label: String) -> void:
		obstacles.append({"at": at, "size": size, "restitution": restitution, "label": label})


func _ready() -> void:
	MetaManager.save_path = TEST_SAVE
	MetaManager.reset_save()
	GameRng.reseed(20260910)
	_projectiles = ProjectilePool.new()
	add_child(_projectiles)
	_projectiles.set_physics_process(false)
	_target = BossTarget.new()
	_target.pool = _projectiles
	_target.position = Vector2(500.0, ArenaGenerator.BASELINE_Y)
	add_child(_target)
	_enemy = Enemy.new()
	add_child(_enemy)
	print("=== SCRAP-A-BOT :: contratos dos chefes ===")
	_test_armor()
	_test_telegraph_and_dodge()
	_test_phases_and_reset()
	_test_shards()
	_test_hold_and_spawn()
	_test_profiles_cover_every_boss()
	_test_sugao()
	_test_formulario()
	_test_elite_and_phase_hitstop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	if _failures.is_empty():
		print("=== TUDO OK ===")
	else:
		for message in _failures:
			push_error(message)
	Sfx.shutdown()
	for i in 30:
		await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _activate(key: String) -> void:
	_enemy.activate(EnemyLibrary.spec(key, 1), 0, Vector2(500.0, Enemy.BOSS_HOLD_Y))
	_enemy.set_physics_process(false)
	_enemy.set("_player", _target)
	_target.position.x = 500.0
	_target.damage_received = 0.0
	_target.breaches = 0
	_projectiles.clear()


func _test_armor() -> void:
	_activate("mini_prensa")
	var initial := _enemy.hp
	_enemy.take_damage(100.0, _enemy.global_position + Vector2.DOWN * 60.0, 0)
	_check(is_equal_approx(initial - _enemy.hp, 30.0), "Prensa deve reduzir dano frontal em 70%")
	initial = _enemy.hp
	_enemy.take_damage(50.0, _enemy.global_position + Vector2.UP * 60.0, 2)
	_check(is_equal_approx(initial - _enemy.hp, 100.0), "Costas da Prensa devem receber dano dobrado")
	initial = _enemy.hp
	_enemy.take_damage(10.0, _enemy.global_position, 0)
	_check(is_equal_approx(initial - _enemy.hp, 10.0), "Dano em area no centro nao deve virar impacto frontal")
	print("  blindagem frontal, costas e dano em area verificados")


func _test_telegraph_and_dodge() -> void:
	_activate("mini_prensa")
	_enemy.call("_begin_boss_attack")
	_check(_enemy.boss_state == Enemy.BossState.TELEGRAPH, "Ataque deve comecar com telegrafia")
	_enemy.call("_update_boss", 1.19)
	_check(is_zero_approx(_target.damage_received), "Telegrafia nao pode causar dano")
	# A mira precisa ficar na posicao anterior enquanto o alvo caminha.
	_target.position.x = 800.0
	_enemy.call("_update_boss", 0.02)
	_check(is_zero_approx(_target.damage_received), "Esquivar da faixa deve evitar o golpe")
	_enemy.call("_update_boss", 0.31)
	_check(_enemy.boss_exposed, "Golpe deve abrir janela de vulnerabilidade")
	_enemy.call("_begin_boss_attack")
	_enemy.call("_update_boss", 1.21)
	_check(_target.damage_received > 0.0, "Ficar na faixa avisada deve causar dano")
	_check(_target.last_source.contains("Mini-Prensa"), "Dano do golpe deve preservar autor para legenda")
	_check(_target.breaches == 0, "Ataque telegrafado nao deve contar como invasao da base")
	print("  aviso sem dano, esquiva e autoria do ataque verificados")


func _test_phases_and_reset() -> void:
	for key in ["mini_prensa", "frostbyte", "fornalha_suprema"]:
		_activate(key)
		_enemy.call("_begin_boss_attack")
		_enemy.hp = _enemy.max_hp * 0.65
		_enemy.call("_update_boss", 0.01)
		_check(_enemy.boss_phase == 2 and _enemy.boss_exposed, key + ": faltou fase 2 e nucleo exposto")
		_check(_enemy.boss_lanes.is_empty(), key + ": transicao deve cancelar ataque anterior")
		_enemy.hp = _enemy.max_hp * 0.32
		_enemy.call("_update_boss", 0.01)
		_check(_enemy.boss_phase == 3, key + ": faltou fase 3")
		if key == "frostbyte":
			_check(is_equal_approx(_enemy.damage_multiplier_from(_enemy.global_position), 2.5),
				"Pote de maionese deve ser o ponto fraco da fase final")
		_enemy.call("_begin_boss_attack")
		# Mesmo na fase final, a linha de defesa deve ter uma posicao caminhavel
		# fora das faixas; largura do robo faz parte dessa verificacao.
		var has_safe_position := false
		for x in range(60, 941, 10):
			var safe := true
			for lane in _enemy.boss_lanes:
				if absf(float(x) - lane) <= _enemy.boss_lane_half_width + Robot.COLLISION_RADIUS:
					safe = false
			has_safe_position = has_safe_position or safe
		_check(has_safe_position, key + ": fase 3 deve deixar corredor seguro")
	_enemy.deactivate()
	_activate("parafuseta")
	_check(_enemy.boss_kind == &"" and _enemy.boss_phase == 1 and not _enemy.boss_exposed,
		"Reuso do pool deve apagar estado do chefe")
	_check(_enemy.boss_lanes.is_empty() and is_equal_approx(_enemy.front_damage_mult, 1.0),
		"Inimigo comum reutilizado nao pode herdar faixas ou blindagem")
	print("  tres fases, cancelamento, corredores e reset do pool verificados")


func _test_shards() -> void:
	for key in ["frostbyte", "fornalha_suprema"]:
		_activate(key)
		_enemy.call("_begin_boss_attack")
		_enemy.call("_begin_boss_attack")
		_check(_projectiles.alive_count() == 0, key + ": nao pode disparar durante aviso")
		_enemy.call("_update_boss", 1.36)
		_check(_projectiles.alive_count() == 3, key + ": rajada da fase 1 deve criar tres projeteis")
		var factions: PackedByteArray = _projectiles.get("_faction")
		for i in ProjectilePool.MAX_PROJECTILES:
			if _projectiles.is_alive(i):
				_check(factions[i] == ProjectilePool.FACTION_ENEMY, key + ": estilhaco deve usar faccao hostil")
				_check(_projectiles.get_velocity_of(i).y > 0.0, key + ": estilhaco deve descer para a linha de defesa")
	print("  rajadas hostis telegrafadas dos chefes 3 e 5 verificadas")


func _test_hold_and_spawn() -> void:
	_activate("mini_prensa")
	_enemy.call("_think")
	var desired: Vector2 = _enemy.get("_desired_velocity")
	_check(is_zero_approx(desired.y), "Chefe deve segurar posicao acima da base e exigir abate")
	_enemy.set("_player", null)
	_enemy.call("_think")
	desired = _enemy.get("_desired_velocity")
	_check(desired.y > 0.0, "Sem jogador o anti-travamento deve continuar funcionando")
	var director := WaveDirector.new()
	add_child(director)
	director.set_process(false)
	director.wave_index = 2
	director.sector = 1
	director.call("_spawn_wave")
	var telegraphs: Array[Dictionary] = director.get("_telegraphs")
	var found_boss := false
	for tg in telegraphs:
		if tg["key"] == "mini_prensa":
			found_boss = true
			_check(float(tg["time"]) >= 1.2, "Entrada do chefe deve ter aviso maior que inimigo comum")
	_check(found_boss, "Ultima onda do setor deve continuar despachando o chefe vigente")
	print("  posicao no poco e entrada da onda de chefe verificadas")


func _test_profiles_cover_every_boss() -> void:
	for sector in range(1, 6):
		_check(WaveDirector.BOSS_BY_SECTOR.has(sector), "Setor %d sem chefe" % sector)
		var key: String = WaveDirector.BOSS_BY_SECTOR.get(sector, "")
		var spec := EnemyLibrary.spec(key, sector)
		_check(spec.get("is_boss", false) and EnemyLibrary.BOSS_PROFILES.has(spec["boss_kind"]),
			key + ": chefe sem perfil em BOSS_PROFILES")
		_check(WaveDirector.THREAT_COST.has(key), key + ": sem custo de ameaca")
	for kind in EnemyLibrary.BOSS_PROFILES:
		var attacks: Array = EnemyLibrary.BOSS_PROFILES[kind]["attacks"]
		_check(attacks.size() >= 1, str(kind) + ": perfil sem ataques")
		for a in attacks:
			_check(a.has("kind") and a.has("name") and a.has("strike"), str(kind) + ": ataque incompleto")
	print("  cinco setores com chefe, todos com perfil de dados")


func _test_sugao() -> void:
	var spy := DirectorSpy.new()
	add_child(spy)
	_activate("sugao_3000")
	# Ciclo 1: Sugadao. Aviso sem dano, depois puxa o alvo para o eixo do chefe.
	_target.position.x = 200.0
	_enemy.call("_begin_boss_attack")
	_check(_enemy.boss_attack_name == "SUGADAO" and _enemy.boss_lanes.is_empty(), "Sugao deve abrir com o Sugadao, sem faixas")
	_enemy.call("_update_boss", 1.21)
	_check(_enemy.boss_state == Enemy.BossState.STRIKE, "Sugadao deve entrar em golpe apos o aviso")
	_target.pushed = Vector2.ZERO
	_enemy.call("_update_boss", 0.1)
	_check(_target.pushed.x > 0.0, "Succao deve puxar o alvo para a direita, na direcao do chefe")
	_check(is_zero_approx(_target.damage_received), "Succao nao causa dano direto")
	# Projetil do jogador subindo dentro do cone e puxado para cima (para o chefe).
	var shot := ProjectileType.make({"damage": 5.0, "speed": 100.0})
	var i := _projectiles.spawn(Vector2(500.0, 900.0), Vector2.UP, shot)
	var v_before := _projectiles.get_velocity_of(i)
	_enemy.call("_update_boss", 0.1)
	_check(_projectiles.get_velocity_of(i).y < v_before.y, "Succao deve acelerar o projetil do jogador em direcao ao chefe")
	_projectiles.clear()
	_enemy.call("_update_boss", 2.5)
	_check(_enemy.boss_exposed and _enemy.boss_attack_name == "FILTRO HEPA EXPOSTO", "Depois do Sugadao o filtro HEPA fica exposto")
	_check(is_equal_approx(_enemy.damage_multiplier_from(_enemy.global_position), 2.5), "Filtro HEPA recebe 2,5x")
	# Ciclo 2: bolas de pelo com 4 quiques.
	_enemy.call("_begin_boss_attack")
	_check(_enemy.boss_attack_name == "BOLA DE PELO", "Segundo ciclo do Sugao deve ser a cusparada")
	_enemy.call("_update_boss", 1.21)
	var bounces: PackedInt32Array = _projectiles.get("_max_bounces")
	var alive := 0
	for k in ProjectilePool.MAX_PROJECTILES:
		if _projectiles.is_alive(k):
			alive += 1
			_check(bounces[k] == 4, "Bola de pelo deve quicar 4 vezes")
	_check(alive == 3, "Cusparada da fase 1 deve criar tres bolas")
	_projectiles.clear()
	# Fase 3: engole a arena. Restituicao 1,4 e tres bolotas.
	_enemy.hp = _enemy.max_hp * 0.3
	_enemy.call("_update_boss", 0.01)
	_check(_enemy.boss_phase == 3 and is_equal_approx(_enemy.restitution, 1.4), "Fase 3 do Sugao vira superficie 1,4")
	_check(spy.minions.size() == 1 and spy.minions[0]["key"] == "bolota_de_cabelo" and spy.minions[0]["count"] == 3, "Fase 3 deve pedir tres bolotas ao diretor")
	_enemy.deactivate()
	_activate("parafuseta")
	_check(is_equal_approx(_enemy.restitution, 0.85), "Restituicao de fase final nao pode vazar pelo pool")
	spy.queue_free()
	print("  Sugao: succao, filtro HEPA, bolas de pelo e fase 3 verificados")


func _test_formulario() -> void:
	var spy := DirectorSpy.new()
	add_child(spy)
	_activate("formulario_27b")
	# Ciclo 1: cabecote corre o trilho do lado oposto ao jogador.
	_target.position.x = 200.0
	_enemy.call("_begin_boss_attack")
	_check(_enemy.boss_attack_name == "CABECOTE CORRENDO" and _enemy.boss_lanes.size() == 1, "Formulario abre com o cabecote")
	_check(_enemy.boss_lanes[0] > 800.0, "Cabecote deve partir do lado oposto ao jogador")
	_enemy.call("_update_boss", 1.11)
	var x0: float = _enemy.boss_lanes[0]
	_enemy.call("_update_boss", 0.8)
	_check(_enemy.boss_lanes[0] < x0 - 300.0, "Cabecote deve atravessar o trilho durante o golpe")
	_check(is_zero_approx(_target.damage_received), "Cabecote longe do alvo nao causa dano")
	_enemy.call("_update_boss", 0.7)
	_check(_target.damage_received > 0.0, "Cabecote passando pelo alvo causa dano")
	_check(_target.last_source.contains("FORMUL"), "Dano do cabecote preserva autor")
	_enemy.call("_update_boss", 0.2)
	_check(_enemy.boss_exposed and _enemy.boss_attack_name == "PC LOAD LETTER", "Tampa abre depois do cabecote")
	# Ciclo 2: esteira empurra para a parede mais proxima.
	_target.position.x = 200.0
	_target.damage_received = 0.0
	_enemy.call("_begin_boss_attack")
	_check(_enemy.boss_attack_name == "FORMULARIO CONTINUO", "Segundo ciclo e a esteira")
	_enemy.call("_update_boss", 1.11)
	_target.pushed = Vector2.ZERO
	_enemy.call("_update_boss", 0.1)
	_check(_target.pushed.x < 0.0, "Esteira empurra o alvo que esta a esquerda para a parede esquerda")
	_check(is_zero_approx(_target.damage_received), "Esteira nao causa dano")
	_enemy.call("_update_boss", 2.5)
	# Fase 3, ciclo par: bola de papel vira obstaculo.
	_enemy.hp = _enemy.max_hp * 0.3
	_enemy.call("_update_boss", 0.01)
	_check(_enemy.boss_phase == 3, "Formulario deve entrar na fase 3")
	_enemy.call("_update_boss", 2.5)
	# A recuperacao da fase 3 ja abriu o ciclo 3 (fita de tinta) sozinha;
	# 1,1 s de aviso + 0,3 s de golpe terminam em recuperacao sem abrir o ciclo 4.
	_check(_enemy.boss_attack_name == "FITA DE TINTA", "Ciclo 3 deveria ser a fita de tinta, recebeu " + _enemy.boss_attack_name)
	_enemy.call("_update_boss", 1.5)
	_projectiles.clear()
	_enemy.call("_begin_boss_attack")  # ciclo 4: PAPER JAM
	_check(_enemy.boss_attack_name == "PAPER JAM", "Ciclo par da fase 3 deve ser o PAPER JAM, recebeu " + _enemy.boss_attack_name)
	_enemy.call("_update_boss", 1.11)
	_check(spy.obstacles.size() == _enemy.boss_lanes.size() and spy.obstacles.size() >= 1, "Cada faixa do PAPER JAM pede um obstaculo")
	for o in spy.obstacles:
		_check(is_equal_approx(o["restitution"], 1.5) and o["label"] == "Bola de Papel", "Bola de papel deve ter restituicao 1,5")
	spy.queue_free()
	print("  Formulario: cabecote, esteira, tampa e PAPER JAM verificados")


func _test_elite_and_phase_hitstop() -> void:
	var base := EnemyLibrary.spec("rato_morto", 3)
	var elite := EnemyLibrary.elite_spec("rato_morto", 3)
	_check(is_equal_approx(elite["max_hp"], base["max_hp"] * 6.0), "Elite deve ter 6x o HP do comum do setor")
	_check(elite["is_elite"] and is_equal_approx(elite["restitution"], 1.0), "Elite tem aura e restituicao 1,00")
	_check(elite["zigzag_amplitude"] == base["zigzag_amplitude"], "Elite preserva o comportamento do comum")
	# Mudanca de fase e evento roteirizado: passa do teto de 130 ms.
	_activate("mini_prensa")
	CombatFeel.reset()
	_enemy.hp = _enemy.max_hp * 0.5
	_enemy.call("_update_boss", 0.01)
	_check(CombatFeel.frozen and CombatFeel.get("_freeze_remaining") > 0.2, "Troca de fase deve pedir hitstop roteirizado de 350 ms")
	CombatFeel.reset()
	print("  promocao de elite e hitstop roteirizado verificados")
