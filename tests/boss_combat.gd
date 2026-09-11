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
