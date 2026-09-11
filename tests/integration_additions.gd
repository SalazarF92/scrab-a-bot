extends Node
## Regressões das novas transações e da defesa, usando save isolado.
const TEST_SAVE := "user://integration_additions_save.json"
var failures: Array[String] = []
var robot: Robot
var bench: WorkbenchUI
var pool: ProjectilePool


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
	robot.set_physics_process(false)
	robot.set_cpu(PartLibrary.cpus()[0])
	robot.equip(PartLibrary.chassis_parts()[0].clone())
	robot.equip(PartLibrary.head_parts()[0].clone())
	bench = WorkbenchUI.new()
	bench.robot = robot
	add_child(bench)
	bench.visible = false
	print("=== SCRAP-A-BOT :: fusao, economia, defesa e assets ===")
	_test_fusion()
	_test_defense()
	_test_damage_reporting()
	_test_assets()
	pool.clear()
	Sfx.shutdown()
	for i in 30:
		await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	for message in failures:
		push_error(message)
	if failures.is_empty(): print("=== TUDO OK ===")
	get_tree().quit(0 if failures.is_empty() else 1)


func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)


func _test_fusion() -> void:
	MetaManager.current_scrap = 0
	bench._try_buy_module(&"car_battery")
	bench._try_fuse_recipe(0)
	check(bench.inventory.size() == 0 and MetaManager.current_scrap == 0, "Falha de compra/fusao deve preservar saldo e mochila")
	MetaManager.current_scrap = 1000
	var head: PartData = robot.equipped[PartData.Slot.HEAD]
	head.fusion_level = 2
	bench._try_buy_module(&"car_battery")
	check(MetaManager.current_scrap == 910 and bench.inventory.size() == 1, "Bateria custa 90 e ocupa uma vaga")
	bench._try_fuse_recipe(0)
	var fused: PartData = robot.equipped[PartData.Slot.HEAD]
	check(fused.id == &"head_toaster_tesla" and fused.fusion_level == 2, "Receita deve equipar Tesla preservando tier")
	check(bench.inventory.size() == 0 and MetaManager.current_scrap == 910, "Receita consome bateria sem taxa extra")
	check(head.id == &"head_toaster" and PartLibrary.head_parts()[1].fusion_level == 0, "Receita nao pode alterar fonte/catalogo")
	bench._try_buy_module(&"car_battery")
	bench._try_fuse_recipe(0)
	check(bench.inventory.size() == 1 and MetaManager.current_scrap == 820, "Receita incompativel nao consome ingrediente")
	bench._try_sell_module(&"car_battery")
	check(MetaManager.current_scrap == 865 and bench.inventory.size() == 0, "Revenda de modulo restitui apenas metade")
	for i in 4: bench._try_buy_module(&"car_battery")
	var before := MetaManager.current_scrap
	bench._try_buy_module(&"car_battery")
	check(bench.inventory.size() == 4 and MetaManager.current_scrap == before, "Mochila cheia nao gasta Sucata")
	bench.reset_for_run()
	check(bench.inventory.size() == 0 and bench._reroll_cost() == 60, "Nova run limpa mochila e rerolls")
	MetaManager.current_scrap = 1000
	bench._try_reroll()
	check(bench._reroll_cost() == 100 and MetaManager.current_scrap == 940, "Reroll deve subir de 60 para 100")
	bench._try_reroll()
	check(bench._reroll_cost() == 140 and MetaManager.current_scrap == 840, "Segundo reroll custa 100 e proximo custa 140")
	var part := PartLibrary.arm_left_parts()[0].clone()
	part.fusion_level = 3
	check(part.sell_value() == 265, "Revenda tier IV deve incluir custos de evolucao")
	print("  receita, mochila cheia, transacoes atomicas, tier, reroll e revenda: OK")


func _test_defense() -> void:
	robot.equip(PartLibrary.chassis_parts()[4].clone())
	robot.reset_for_run()
	robot.position = Vector2(500, 960)
	robot.aim_direction = Vector2.UP
	var center := robot.body_center()
	check(is_equal_approx(robot.take_damage(100, center + Vector2(0, -80)), 30.0), "Cofre deve bloquear 70% pela frente")
	robot._iframes = 0
	check(is_equal_approx(robot.take_damage(100, center + Vector2(0, 80)), 100.0), "Cofre nao protege costas")
	robot._iframes = 0
	check(is_equal_approx(robot.take_damage(10, center + Vector2(0, -80), 0, "invasao", true), 10.0), "Invasao nao usa blindagem do robo")
	robot.reset_for_run()
	var shot := ProjectileType.make({"damage": 20.0, "speed": 400.0})
	var i := pool.spawn(center + Vector2(0, -35), Vector2.DOWN, shot, ProjectilePool.FACTION_ENEMY)
	var hp_before := robot.hp
	pool._resolve_bounce(i, Vector2.UP, robot.get_instance_id())
	var factions: PackedByteArray = pool.get("_faction")
	var damage: PackedFloat32Array = pool.get("_damage")
	check(factions[i] == ProjectilePool.FACTION_PLAYER and is_equal_approx(damage[i], 40.0), "Defesa reflete no mesmo slot com faccao do jogador e dano dobrado")
	check(pool.get_velocity_of(i).y < 0 and robot.hp == hp_before and pool.alive_count() == 1, "Reflexao sobe sem duplicar projetil nem ferir jogador")
	pool.clear()
	print("  Cofre frontal, costas, invasao e reflexao de projetil: OK")


func _test_damage_reporting() -> void:
	var enemy := Enemy.new()
	add_child(enemy)
	enemy.activate(EnemyLibrary.spec("mini_prensa"), 0, Vector2(500, 300))
	enemy.set_physics_process(false)
	Telemetry.reset()
	var shot := ProjectileType.make({"damage": 100.0})
	var i := pool.spawn(Vector2(500, 360), Vector2.UP, shot)
	pool._resolve_bounce(i, Vector2.DOWN, enemy.get_instance_id())
	check(is_equal_approx(Telemetry.total_damage, 30.0), "Telemetria precisa refletir dano mitigado")
	enemy.activate(EnemyLibrary.spec("fantasma_disquete"), 0, Vector2(500, 300))
	enemy.set_physics_process(false)
	pool.clear()
	Telemetry.reset()
	i = pool.spawn(Vector2(500, 340), Vector2.UP, shot)
	pool._resolve_bounce(i, Vector2.DOWN, enemy.get_instance_id())
	check(Telemetry.total_hits == 0 and Telemetry.total_damage == 0, "Fantasma imune nao deve inflar telemetria")
	enemy.queue_free()
	pool.clear()
	print("  dano mitigado e imunidade na telemetria: OK")


func _test_assets() -> void:
	for path in [ArtDirector.PARTS_PATH, ArtDirector.ENEMIES_PATH, ArtDirector.BACKGROUND_PATH]:
		var tex := ArtDirector.texture(path)
		check(tex != null, "Textura ausente: " + path)
		if tex != null:
			check(tex.get_width() > 1000, "Arte deve ter resolucao suficiente: " + path)
	for path in [ArtDirector.PARTS_PATH, ArtDirector.ENEMIES_PATH]:
		var bitmap := (load(path) as Texture2D).get_image()
		check(bitmap != null and bitmap.detect_alpha() != Image.ALPHA_NONE, "Atlas precisa preservar transparencia real: " + path)
	for part in PartLibrary.arm_left_parts() + PartLibrary.arm_right_parts() + PartLibrary.head_parts() + PartLibrary.chassis_parts():
		check(ArtDirector.PART_CELLS.has(part.id), "Peca sem sprite: " + str(part.id))
	print("  assets locais, resolucao, alpha e cobertura das pecas: OK")
