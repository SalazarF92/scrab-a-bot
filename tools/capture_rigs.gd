extends Node
## Capturas com renderer real dos rigs articulados dentro do combate. Nunca usa
## o save do jogador. Executar com janela:
##   Godot --path . res://tools/capture_rigs.tscn
## Gera docs/visual/rigs-no-jogo.png (tela de jogo) e rigs-no-jogo-zoom.png.

const TEST_SAVE := "user://rig_capture_save.json"
var prototype: Node2D
var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		push_error("Captura visual exige renderer com janela.")
		get_tree().quit(1)
		return
	MetaManager.save_path = TEST_SAVE
	MetaManager.reset_save()
	prototype = load("res://scenes/prototype.tscn").instantiate()
	prototype.start_seed = 20260914
	add_child(prototype)
	prototype.director.stop()
	prototype.enemy_pool.release_all()
	prototype.robot.set_physics_process(false)
	prototype.robot.global_position = Vector2(620, 960)
	prototype.robot.aim_direction = Vector2(-0.2, -1).normalized()
	prototype.pool.set_physics_process(false)
	prototype.camera.set_process(false)
	prototype.camera.snap_to(Vector2(500, 540))

	var robot: Robot = prototype.robot
	# Parafusetas e Ratos em fileiras, alternando andar, golpe e flash de dano.
	for i in 12:
		var key := "rato_morto" if i % 3 == 2 else "parafuseta"
		var e: Enemy = prototype.enemy_pool.acquire(EnemyLibrary.spec(key), Vector2(150 + (i % 6) * 140, 330 + (i / 6) * 150))
		e.set_physics_process(false)
		e._player = robot
		e._phase = float(i) * 0.37
		if i % 4 == 1:
			e.anim_since_contact = 0.12
		e.rig_view.sync(e, 0.3)
		e.queue_redraw()
	# Um Olhudo carregando o aviso e outro no pico da emissao.
	var charging: Enemy = prototype.enemy_pool.acquire(EnemyLibrary.spec("olhudo"), Vector2(180, 150))
	var firing: Enemy = prototype.enemy_pool.acquire(EnemyLibrary.spec("olhudo"), Vector2(820, 150))
	for eye in [charging, firing]:
		eye.set_physics_process(false)
		eye._player = robot
		eye._mob.target = robot.body_center()
	await get_tree().process_frame
	# Um quadro de vigilancia primeiro: o Olhudo vira para o robo antes de travar
	# a mira, como acontece no jogo nos 2 s que antecedem o primeiro aviso.
	for eye in [charging, firing]:
		eye.rig_view.sync(eye, 0.3)
	charging._mob.warning = 0.25
	firing._mob.since_execute = 0.2
	for eye in [charging, firing]:
		eye.rig_view.sync(eye, 0.3)
		eye.queue_redraw()
	await _capture("rigs-no-jogo")

	prototype.hud.visible = false
	prototype.camera.zoom = Vector2(2.6, 2.6)
	prototype.camera.global_position = Vector2(360, 410)
	await _capture("rigs-no-jogo-zoom")

	Sfx.shutdown()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("=== CAPTURAS OK ===" if failures == 0 else "CAPTURA FALHOU")
	get_tree().quit(failures)


func _capture(label: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var bitmap := get_viewport().get_texture().get_image()
	var path := "res://docs/visual/" + label + ".png"
	var error := bitmap.save_png(path)
	if error != OK:
		failures += 1
	print("captura: ", path, " (", error, ")")
