extends Node
## Teste de gameplay de ponta a ponta. Sobe a cena principal de verdade, com os
## autoloads, e dirige o jogo por input simulado.
##
##   Godot --headless --path <projeto> --fixed-fps 120 res://tests/gameplay.tscn
##
## --fixed-fps e obrigatorio na pratica: desacopla o tempo de jogo do relogio e
## alguns minutos de partida rodam em segundos.
##
## Pega o que o teste de fumaca nao pega:
##  - inimigo preso em cima de obstaculo, que faz a sala nunca terminar;
##  - menu que nao recebe teclado por falta de foco;
##  - robo atirando atras do menu por falta de pausa;
##  - rebatedor, chao do poco e parede de vapor;
##  - onda de bumpers e filhotes;
##  - legenda de morte e desafio diario pela tela da Garagem.

const PrototypeScene := preload("res://scenes/prototype.tscn")
const FIXED_SEED := 20260910
const TEST_SAVE := "user://gameplay_test_save.json"
## Tempo de jogo maximo por estagio. Estourar aqui e o sintoma de soft-lock.
const STAGE_TIMEOUT := 180.0

enum Stage { SOFTLOCK, BOOT, PADDLE, COMBAT, WORKBENCH, BUMPERS, DEATH, DAILY, DONE }

var _stage: int = Stage.SOFTLOCK
var _stage_time := 0.0
var _stage_frames := 0
var _failures: Array[String] = []
var _proto: Node
var _scratch: Array[Node] = []

var _small: Enemy
var _wide: Enemy
var _small_passed := false
var _wide_passed := false

var _paddle_probe := -1
var _paddle_before := 0
var _floor_before := 0

var _fired_at_pause := 0
var _space_sent := false


func _ready() -> void:
	# O teste precisa continuar rodando com a arvore pausada pelos menus.
	process_mode = Node.PROCESS_MODE_ALWAYS
	MetaManager.save_path = TEST_SAVE
	MetaManager.reset_save()
	print("=== SCRAP-A-BOT :: teste de gameplay ===  semente %d" % FIXED_SEED)
	_setup_softlock()


func _physics_process(delta: float) -> void:
	_stage_time += delta
	_stage_frames += 1
	match _stage:
		Stage.SOFTLOCK:
			_run_softlock()
		Stage.BOOT:
			_run_boot()
		Stage.PADDLE:
			_run_paddle()
		Stage.COMBAT:
			_run_combat()
		Stage.WORKBENCH:
			_run_workbench()
		Stage.BUMPERS:
			_run_bumpers()
		Stage.DEATH:
			_run_death()
		Stage.DAILY:
			_run_daily()

	if _stage != Stage.DONE and _stage_time > STAGE_TIMEOUT:
		_check(false, "estagio %s passou de %.0f s de jogo (soft-lock?)" % [Stage.keys()[_stage], STAGE_TIMEOUT])
		_finish()


func _next(stage: int) -> void:
	_stage = stage
	_stage_time = 0.0
	_stage_frames = 0


func _check(condition: bool, failure_message: String) -> void:
	if not condition:
		_failures.append(failure_message)


func _robot() -> Robot:
	return _proto.get("robot")


func _director() -> WaveDirector:
	return _proto.get("director")


func _send_key(keycode: Key) -> void:
	# push_input entrega pelo mesmo caminho do teclado de verdade, incluindo o
	# roteamento por foco. Chamar _gui_input direto esconderia o bug de foco.
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		get_viewport().push_input(ev)


# --- estagios -----------------------------------------------------------------

## Dois obstaculos sem jogador na cena, entao nada puxa o inimigo para o lado.
## A Parafuseta tem que contornar o estreito; o chefe nao cabe em lado nenhum do
## largo e tem que se espremer.
func _setup_softlock() -> void:
	var narrow := Obstacle.new()
	narrow.size = Vector2(300, 60)
	narrow.position = Vector2(500, 560)
	add_child(narrow)

	var wide := Obstacle.new()
	wide.size = Vector2(900, 60)
	wide.position = Vector2(500, 300)
	add_child(wide)

	_small = Enemy.new()
	_small.activate(EnemyLibrary.spec("parafuseta", 1), 0, Vector2(500, 500))
	add_child(_small)

	_wide = Enemy.new()
	_wide.activate(EnemyLibrary.spec("fornalha_suprema", 1), 1, Vector2(500, 160))
	add_child(_wide)

	_scratch.append_array([narrow, wide, _small, _wide])


func _run_softlock() -> void:
	if is_instance_valid(_small) and _small.global_position.y > 640.0:
		_small_passed = true
	if is_instance_valid(_wide) and _wide.global_position.y > 420.0:
		_wide_passed = true
	if not (_small_passed and _wide_passed):
		return

	print("  anti-travamento: contornou o obstaculo estreito e se espremeu no largo em %.1f s" % _stage_time)
	for n in _scratch:
		if is_instance_valid(n):
			n.queue_free()
	_scratch.clear()

	_proto = PrototypeScene.instantiate()
	_proto.set("start_seed", FIXED_SEED)
	add_child(_proto)
	_next(Stage.BOOT)


func _run_boot() -> void:
	if _stage_frames < 3:
		return
	var robot := _robot()
	var pool: ProjectilePool = _proto.get("pool")
	var probe := ProjectileType.make({"speed": 700.0, "radius": 7.0, "max_bounces": 4, "damage": 1.0, "ttl": 5.0})

	_paddle_before = Telemetry.paddle_catches
	_floor_before = Telemetry.projectiles_lost_floor
	# Nasce abaixo da zona de obstaculos (y <= 820) e cai reto no corpo.
	_paddle_probe = pool.spawn(robot.body_center() + Vector2(0, -90), Vector2.DOWN, probe)
	var side_x := robot.global_position.x + (300.0 if robot.global_position.x < 500.0 else -300.0)
	pool.spawn(Vector2(side_x, 940.0), Vector2.DOWN, probe)
	_next(Stage.PADDLE)


func _run_paddle() -> void:
	if _stage_time < 0.35:
		return
	var robot := _robot()
	var pool: ProjectilePool = _proto.get("pool")
	_check(Telemetry.paddle_catches > _paddle_before, "rebatedor: projetil caindo sobre o robo nao foi rebatido")
	_check(pool.is_alive(_paddle_probe) and pool.get_bounces_of(_paddle_probe) >= 1,
		"rebatedor: projetil rebatido deveria continuar vivo e com um quique")
	_check(Telemetry.projectiles_lost_floor > _floor_before, "chao do poco: projetil que passou do robo nao morreu")

	robot.call("_heat_purge")
	var wall_up := false
	for w in robot.steam_walls:
		wall_up = wall_up or w.is_active()
	_check(wall_up, "Purga de Calor nao ergueu a parede de vapor")
	print("  rebatedor, chao do poco e parede de vapor verificados")
	_next(Stage.COMBAT)


## Joga o setor 1 inteiro atirando sem parar. O robo fica invulneravel: este
## estagio mede se a sala termina, nao se o robo sobrevive.
func _run_combat() -> void:
	var robot := _robot()
	robot.set("_iframes", 1.0)
	Input.action_press("fire_left")
	if _stage_frames % 30 == 0:
		Input.action_press("fire_right")
	elif _stage_frames % 30 == 1:
		Input.action_release("fire_right")

	var wb: Control = _proto.get("workbench")
	if wb.visible:
		print("  setor 1 limpo em %.1f s de jogo (%s)" % [_stage_time, Telemetry.summary()])
		_next(Stage.WORKBENCH)


func _run_workbench() -> void:
	var wb: Control = _proto.get("workbench")
	if _stage_frames == 1:
		_fired_at_pause = Telemetry.projectiles_fired
		return
	if not _space_sent:
		Input.action_press("fire_left")
		if _stage_time < 0.3:
			return
		Input.action_release("fire_left")
		Input.action_release("fire_right")
		_check(get_tree().paused, "Bancada aberta sem pausar o jogo")
		_check(Telemetry.projectiles_fired == _fired_at_pause, "robo atirou atras da Bancada")
		_check(wb.has_focus(), "Bancada aberta sem foco de teclado")
		_send_key(KEY_SPACE)
		_space_sent = true
		return
	if _stage_time < 0.5:
		return
	_check(not wb.visible, "ESPACO na Bancada nao prosseguiu")
	_check(not get_tree().paused, "o jogo continuou pausado depois da Bancada")
	_check(_director().sector == 2, "a Bancada deveria levar ao setor 2")
	print("  pausa e foco da Bancada verificados")
	_next(Stage.BUMPERS)


func _run_bumpers() -> void:
	var robot := _robot()
	robot.set("_iframes", 1.0)
	Input.action_press("fire_left")

	var director := _director()
	if director.wave_kind != &"bumpers":
		return
	var fridge: Enemy = null
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e != null and e.is_bumper:
			fridge = e
			break
	if fridge == null:
		return

	var before := director.pending_spawns()
	fridge.take_damage(1.0e9, fridge.global_position, 4)
	_check(director.pending_spawns() >= before + fridge.spawn_on_death_count,
		"geladeira lotada morreu sem liberar o enxame")
	print("  onda de bumpers do setor 2 verificada")
	Input.action_release("fire_left")
	_next(Stage.DEATH)


func _run_death() -> void:
	var garage: Control = _proto.get("garage")
	if _stage_frames == 1:
		var robot := _robot()
		robot.set("_iframes", 0.0)
		robot.hp = 1.0
		robot.take_damage(50.0, robot.global_position, 0, RunCaption.by_whom("uma", "Parafuseta de Teste"))
		return
	if not garage.visible:
		return

	var s: Dictionary = MetaManager.last_run_summary
	var caption := str(s.get("caption", ""))
	_check(caption.contains("Parafuseta de Teste"), "legenda de morte sem o autor: '%s'" % caption)
	_check(int(s.get("seed", 0)) == FIXED_SEED, "resumo da run sem a semente")
	_check(get_tree().paused, "Garagem aberta sem pausar o jogo")
	_check(garage.has_focus(), "Garagem aberta sem foco de teclado")
	print("  legenda: " + caption)
	_send_key(KEY_H)
	_next(Stage.DAILY)


func _run_daily() -> void:
	if _stage_time < 0.1:
		return
	var garage: Control = _proto.get("garage")
	_check(not garage.visible, "[H] na Garagem nao iniciou o desafio de hoje")
	_check(MetaManager.run_is_daily, "a run iniciada por [H] nao esta marcada como diaria")
	_check(GameRng.run_seed == GameRng.daily_seed(), "o desafio de hoje nao usa a semente do dia")
	_check(not get_tree().paused, "o desafio de hoje comecou pausado")
	print("  desafio de hoje iniciado pela Garagem (semente %s)" % GameRng.seed_label(GameRng.run_seed))
	_finish()


func _finish() -> void:
	_next(Stage.DONE)
	for action in ["fire_left", "fire_right"]:
		Input.action_release(action)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("")
	if _failures.is_empty():
		print("=== TUDO OK ===")
		_quit(0)
	else:
		print("=== %d FALHAS ===" % _failures.size())
		for f in _failures:
			print("  - " + f)
		_quit(1)


## Para o audio e da um instante para o servidor liberar os playbacks antes do
## quit, senao a saida acusa vazamento e esconde vazamentos de verdade.
func _quit(code: int) -> void:
	Sfx.shutdown()
	for k in 30:
		OS.delay_msec(10)
		await get_tree().process_frame
	get_tree().quit(code)
