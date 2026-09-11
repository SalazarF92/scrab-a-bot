extends Node2D
## Cena do marco Prototipo. GDD 7.5.
##
## "Um retangulo cinza atirando bolas que quicam. A meta e unica: o ricochete
## precisa ser divertido sem arte nenhuma. Se nao for, o projeto e cancelado
## aqui, e isso e barato."
##
## Tudo e montado em codigo, sem .tscn autorado, por dois motivos: a cena de
## producao vai ser outra, e um arquivo de cena grande e ilegivel em diff, o que
## atrapalha justamente na fase em que todo numero muda todo dia.
##
## Pausa. Esta cena roda sempre; o que pausa e o no World, que contem tudo que e
## simulacao. Menus e atalhos ficam fora dele. Antes nao havia pausa nenhuma:
## clicar num botao da Garagem disparava o braco esquerdo atras do menu, com
## calor, som e tremor.

const STEAM_WALL_COUNT := 2

## Semente fixa para testes automatizados. Zero sorteia uma semente nova por run.
@export var start_seed: int = 0

var world: Node2D
var arena: ArenaGenerator
var pool: ProjectilePool
var enemy_pool: EnemyPool
var director: WaveDirector
var robot: Robot
var camera: ArenaCamera
var hud: Hud
var overlay: DebugOverlay
var garage: GarageUI
var workbench: WorkbenchUI

var _cpu_index := 0
var _part_index := {PartData.Slot.ARM_LEFT: 0, PartData.Slot.ARM_RIGHT: 0, PartData.Slot.HEAD: 0}
var _cpus: Array[CpuData]
var _catalog: Dictionary
var _run_over := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_catalog = {
		PartData.Slot.ARM_LEFT: PartLibrary.arm_left_parts(),
		PartData.Slot.ARM_RIGHT: PartLibrary.arm_right_parts(),
		PartData.Slot.HEAD: PartLibrary.head_parts(),
		PartData.Slot.CHASSIS: PartLibrary.chassis_parts(),
	}
	_cpus = PartLibrary.cpus()

	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)

	arena = ArenaGenerator.new()
	world.add_child(arena)

	pool = ProjectilePool.new()
	world.add_child(pool)

	enemy_pool = EnemyPool.new()
	world.add_child(enemy_pool)

	director = WaveDirector.new()
	director.enemy_pool = enemy_pool
	world.add_child(director)

	robot = Robot.new()
	robot.pool = pool
	world.add_child(robot)

	for i in STEAM_WALL_COUNT:
		var wall := SteamWall.new()
		world.add_child(wall)
		robot.steam_walls.append(wall)

	camera = ArenaCamera.new()
	camera.target = robot
	world.add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.robot = robot
	hud.director = director
	layer.add_child(hud)
	overlay = DebugOverlay.new()
	overlay.pool = pool
	overlay.arena = arena
	overlay.robot = robot
	overlay.enemy_pool = enemy_pool
	layer.add_child(overlay)

	garage = GarageUI.new()
	garage.start_run_requested.connect(_on_garage_start_run)
	garage.visible = false
	layer.add_child(garage)

	workbench = WorkbenchUI.new()
	workbench.proceed_requested.connect(_on_workbench_proceed)
	workbench.visible = false
	layer.add_child(workbench)

	robot.died.connect(_on_player_died)
	director.room_cleared.connect(_on_room_cleared)

	_begin_run(false, start_seed)

	# Permite disparar o teste de estresse sem teclado, para gravacao de video e
	# para a integracao continua:
	#   Godot --path <projeto> --write-movie f.png --quit-after 300 ++ --stress
	if OS.get_cmdline_user_args().has("--stress"):
		_stress_test.call_deferred()


## Comeca uma run. O desafio diario usa a semente do dia e o loadout inicial
## fixo; a run comum sorteia uma semente, ou usa a da cena quando ha uma.
func _begin_run(daily: bool, seed_override: int = 0) -> void:
	var seed_value := seed_override
	if daily:
		seed_value = GameRng.daily_seed()
		_cpu_index = 0
		for slot in _part_index:
			_part_index[slot] = 0
	elif seed_value == 0:
		seed_value = GameRng.fresh_seed()

	# A ordem importa: todo sorteio da run, inclusive a primeira arena, precisa
	# acontecer depois do reseed.
	GameRng.reseed(seed_value)
	pool.reseed_rng()
	Telemetry.reset()
	MetaManager.start_new_run(-1, daily, seed_value)
	workbench.reset_for_run()
	_run_over = false

	garage.visible = false
	workbench.visible = false
	hud.visible = true
	_new_room(1)
	_refresh_pause()


func _new_room(sector: int) -> void:
	enemy_pool.release_all()
	director.stop()
	pool.clear()
	for wall in robot.steam_walls:
		wall.retract()
	Vfx.clear_all()
	CombatFeel.reset()

	arena.generate(sector)
	overlay.arena = arena

	robot.global_position = arena.baseline_spawn()
	robot.velocity = Vector2.ZERO
	camera.snap_to(arena.center())

	# Apenas na primeira sala da run equipa o loadout inicial;
	# nas salas seguintes preserva as compras e evolucoes feitas na Bancada.
	if sector == 1:
		robot.set_cpu(_cpus[_cpu_index])
		robot.equip(_catalog[PartData.Slot.CHASSIS][0].clone())
		for slot in _part_index:
			robot.equip(_catalog[slot][_part_index[slot]].clone())
		robot.reset_for_run()

	director.arena = arena
	director.player = robot
	director.start_room(sector)


func _refresh_pause() -> void:
	get_tree().paused = garage.visible or workbench.visible


func _on_room_cleared() -> void:
	if _run_over:
		return
	if director.sector >= 5:
		_finish_run(true)
		return
	await get_tree().create_timer(0.8).timeout
	if _run_over:
		return
	_show_workbench()


func _on_player_died() -> void:
	_finish_run(false)


func _finish_run(won: bool) -> void:
	if _run_over:
		return
	_run_over = true
	director.stop()
	var sector := director.sector
	var caption := RunCaption.build(robot, won, sector, GameRng.run_seed)
	var summary := MetaManager.end_run(5 if won else sector, won, {"caption": caption})
	print("--- %s --- %s" % ["VITORIA DA RUN" if won else "morreu", Telemetry.summary()])
	print("--- legenda --- ", caption)
	print("--- resumo --- ", summary)
	await get_tree().create_timer(1.2).timeout
	_show_garage()


func _show_workbench() -> void:
	workbench.robot = robot
	workbench.open_workbench(director.sector)
	hud.visible = false
	_refresh_pause()


func _on_workbench_proceed() -> void:
	workbench.visible = false
	hud.visible = true
	_new_room(director.sector + 1)
	_refresh_pause()


func _show_garage() -> void:
	garage.visible = true
	workbench.visible = false
	hud.visible = false
	garage.queue_redraw()
	_refresh_pause()


func _on_garage_start_run(daily: bool) -> void:
	_begin_run(daily)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_B:
			if workbench.visible:
				_on_workbench_proceed()
			else:
				_show_workbench()
		KEY_G:
			if garage.visible:
				_begin_run(false)
			else:
				_show_garage()
		KEY_F1:
			overlay.visible_panel = not overlay.visible_panel
		KEY_F2:
			arena.generate(director.sector)
			robot.global_position = arena.baseline_spawn()
		KEY_F3:
			_stress_test()
		KEY_F4:
			Vfx.colorblind_shapes = not Vfx.colorblind_shapes
		KEY_F5:
			_cpu_index = (_cpu_index + 1) % _cpus.size()
			robot.set_cpu(_cpus[_cpu_index])
		KEY_F6:
			CombatFeel.shake_scale = 0.0 if CombatFeel.shake_scale > 0.0 else 1.0
		KEY_1:
			_cycle_part(PartData.Slot.ARM_LEFT)
		KEY_2:
			_cycle_part(PartData.Slot.ARM_RIGHT)
		KEY_3:
			_cycle_part(PartData.Slot.HEAD)
		KEY_R:
			Telemetry.reset()


## Troca de peca de desenvolvimento. Equipa uma copia: equipar o objeto do
## catalogo fazia a Bancada alterar o tier da peca-modelo de todas as runs.
func _cycle_part(slot: int) -> void:
	var list: Array = _catalog[slot]
	_part_index[slot] = (_part_index[slot] + 1) % list.size()
	robot.equip((list[_part_index[slot]] as PartData).clone())


## O benchmark do GDD 7.2: 800 projeteis vivos, 60 fps travados no Steam Deck.
## Aqui ele e manual e imediato, e o painel mostra o custo em milissegundos.
func _stress_test() -> void:
	var type := ProjectileType.make({
		"id": &"stress", "speed": 780.0, "radius": 7.0, "max_bounces": 12,
		"restitution": 1.0, "ttl": 20.0, "damage": 1.0, "ignore_floor": true,
		"base_color": Color("#8CFF1A"),
	})
	var rng := GameRng.stream(GameRng.Stream.VFX)
	for i in 800:
		var p := Vector2(rng.randf_range(100.0, ArenaGenerator.ARENA_SIZE.x - 100.0),
			rng.randf_range(100.0, ArenaGenerator.ARENA_SIZE.y - 100.0))
		pool.spawn(p, Vector2.from_angle(rng.randf_range(0.0, TAU)), type)
	print("estresse: 800 projeteis lancados")
