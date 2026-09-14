extends Node
## Capturas com renderer real das telas de titulo, opcoes e pausa. Nunca usa o
## save nem as opcoes do jogador. Executar com janela:
##   Godot --path . res://tools/capture_front_end.tscn
## Gera docs/visual/titulo.png, opcoes.png e pausa.png.

const TEST_SAVE := "user://front_end_capture_save.json"
const TEST_SETTINGS := "user://front_end_capture_settings.cfg"
var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		push_error("Captura visual exige renderer com janela.")
		get_tree().quit(1)
		return
	MetaManager.save_path = TEST_SAVE
	MetaManager.reset_save()
	Settings.path = TEST_SETTINGS
	var proto: Node2D = load("res://scenes/prototype.tscn").instantiate()
	add_child(proto)
	await _capture("titulo")
	proto.title.activate("options")
	await _capture("opcoes")
	proto.options.closed.emit()
	proto._begin_run(false, 20260914)
	for i in 90:
		await get_tree().process_frame
	proto._open_pause()
	await _capture("pausa")
	get_tree().paused = false
	Sfx.shutdown()
	MetaManager.clear_run_state()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
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
