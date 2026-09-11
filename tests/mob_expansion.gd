extends Node
const TEST_SAVE := "user://mob_expansion_save.json"
var failures: Array[String] = []
var robot: Robot
var pool: ProjectilePool
var enemies: EnemyPool
var director: WaveDirector

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func mob(key: String, at := Vector2(500, 300)) -> Enemy:
	var e := enemies.acquire(EnemyLibrary.spec(key), at)
	e._player = robot
	e.set_physics_process(false)
	return e

func _ready() -> void:
	MetaManager.save_path = TEST_SAVE
	MetaManager.reset_save()
	MetaManager.start_new_run(0, false, 20260910)
	GameRng.reseed(20260910)
	pool = ProjectilePool.new()
	add_child(pool)
	pool.set_physics_process(false)
	robot = Robot.new()
	robot.pool = pool
	add_child(robot)
	robot.position = Vector2(500, 960)
	robot.set_physics_process(false)
	robot.equip(PartLibrary.head_parts()[0].clone())
	enemies = EnemyPool.new()
	add_child(enemies)
	director = WaveDirector.new()
	director.player = robot
	director.enemy_pool = enemies
	add_child(director)
	director.set_process(false)
	director.set_physics_process(false)
	director.active = true
	print("=== SCRAP-A-BOT :: expansao de monstros ===")
	for sector in range(1, 6):
		for key in EnemyLibrary.EXPANSION_KEYS:
			check(WaveDirector.available_mobs(sector).has(key) == (sector >= EnemyLibrary.INTRO_SECTOR[key]), "Introducao: " + key)
	_test_keyboard()
	_test_popup()
	_test_lock()
	_test_wind()
	_test_specials()
	await _test_laser_cover()
	enemies.release_all()
	director.stop()
	pool.clear()
	Sfx.shutdown()
	for i in 30:
		OS.delay_msec(10)
		await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	for message in failures: push_error(message)
	if failures.is_empty(): print("=== TUDO OK ===")
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_keyboard() -> void:
	var e := mob("qwertypede")
	e._mob.target = robot.body_center()
	e._mob._execute(e, robot)
	check(pool.alive_count() == 5, "QWERTYpede dispara cinco teclas")
	for i in 7: e.take_damage(10000)
	check(e.active and e.hp == 1, "QWERTYpede resiste aos sete primeiros impactos")
	director._telegraphs.clear()
	e.take_damage(10000)
	check(not e.active and director._telegraphs.size() == 3, "Oitavo impacto libera tres Parafusetas")
	pool.clear()
	director._telegraphs.clear()

func _test_popup() -> void:
	var e := mob("popup_vivo")
	for generation in 4:
		e.split_generation = generation
		director._telegraphs.clear()
		director.spawn_popup_children(e)
		check(director._telegraphs.size() == (2 if generation < 3 else 0), "Limite de geracoes do Pop-Up")
		if generation < 3:
			var spec: Dictionary = director._telegraphs[0].spec
			check(spec.max_hp == e.max_hp * 0.5 and spec.split_generation == generation + 1, "Filhotes herdam HP reduzido e geracao")
	enemies.release(e)
	director._telegraphs.clear()

func _test_lock() -> void:
	var e := mob("cadeado_chorao")
	e._mob._execute(e, robot)
	check(robot.slot_jam_remaining(PartData.Slot.HEAD) == 8.0, "Cadeado bloqueia peca equipada")
	robot.jam_slot(PartData.Slot.HEAD, 123, 2.0)
	enemies.release(e)
	check(robot.slot_jam_remaining(PartData.Slot.HEAD) == 2.0, "Morte libera apenas seu proprio bloqueio")
	robot.release_jam(123)
	check(robot.slot_jam_remaining(PartData.Slot.HEAD) == 0.0, "Bloqueios liberados")
	robot.jam_slot(PartData.Slot.HEAD, 123, 1.0)
	robot._tick_timers(1.1)
	check(robot.slot_jam_remaining(PartData.Slot.HEAD) == 0.0, "Bloqueio expira pelo tempo")
	robot._iframes = 0.0
	check(robot.take_damage(0) == 0 and robot._iframes == 0, "Contato sem dano nao concede invulnerabilidade")

func _test_wind() -> void:
	var fan := mob("ze_ventoinha")
	var type := ProjectileType.make({"speed": 200.0})
	var affected := pool.spawn(fan.position + Vector2(40, 100), Vector2.UP, type)
	var outside := pool.spawn(fan.position + Vector2(300, 100), Vector2.UP, type)
	var hostile := pool.spawn(fan.position + Vector2(40, 100), Vector2.UP, type, ProjectilePool.FACTION_ENEMY)
	fan._mob.tick(fan, 0.1)
	check(pool._vel[affected].x > 0 and pool._vel[affected].y > -200, "Ventoinha desvia tiros dentro do cone")
	check(pool._vel[outside] == Vector2(0, -200) and pool._vel[hostile] == Vector2(0, -200), "Vento respeita alcance e faccao")
	pool.clear()
	enemies.release(fan)

func _test_laser_cover() -> void:
	enemies.release_all()
	robot.position = Vector2(500, 960)
	robot._iframes = 0
	var laser := mob("olhudo")
	var before := robot.hp
	laser._mob.target = robot.body_center()
	laser._mob._execute(laser, robot)
	check(robot.hp < before and robot.last_damage_source == laser.source_text(), "Laser acerta e registra autoria")
	var wall := Obstacle.new()
	wall.position = Vector2(500, 650)
	wall.size = Vector2(160, 60)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	before = robot.hp
	robot._iframes = 0
	laser._mob.target = robot.body_center()
	laser._mob._execute(laser, robot)
	check(robot.hp == before and laser._mob.target.y < 650, "Obstaculo intercepta laser e encurta feixe")
	wall.queue_free()
	enemies.release(laser)

func _test_specials() -> void:
	var laser := mob("olhudo")
	var before := robot.hp
	laser._mob.timer = 0
	laser._mob.tick(laser, 0.01)
	check(robot.hp == before and laser._mob.warning > 0, "Laser avisa antes do dano")
	robot.position.x += 300
	laser._mob.tick(laser, 0.81)
	check(robot.hp == before, "Deslocamento evita laser de mira travada")
	enemies.release(laser)
	var bomber := mob("bipador", robot.body_center() - Vector2(0, 150))
	bomber._mob.timer = 0
	bomber._mob.tick(bomber, 0.01)
	bomber._think()
	check(bomber._desired_velocity == Vector2.ZERO and bomber._mob.warning > 0, "Bipador para durante aviso")
	robot.position.x -= 300
	var kills := Telemetry.enemies_killed
	bomber._mob.tick(bomber, 1.01)
	check(not bomber.active and robot.hp == before and Telemetry.enemies_killed == kills, "Esquiva da explosao; sem recompensa por autodetonacao")
	var a := mob("cabo_cobra")
	var b := mob("cabo_cobra", Vector2(520, 300))
	if a.get_instance_id() > b.get_instance_id():
		var swap := a
		a = b
		b = swap
	var total := a.hp + b.hp
	a._mob._try_merge(a)
	check(a.active and not b.active and a.hp == total, "Cabos fundem conservando vida")
	var c := mob("cabo_cobra", a.position)
	a._mob._try_merge(a)
	check(c.active, "Fusao limitada a um par")
	enemies.release_all()
	var printer := mob("fabricadora")
	director._telegraphs.clear()
	for i in 8:
		printer._mob.tick(printer, 4.0)
		printer._mob.tick(printer, 0.8)
	check(printer._mob.spawned == 4 and director._telegraphs.size() == 4, "Fabricadora limitada a quatro minions")
	enemies.release(printer)
	var recycled := mob("parafuseta")
	check(recycled.mob_kind == &"" and recycled._mob.spawned == 0 and not recycled._mob.merged, "Pool limpa habilidades da vida anterior")
