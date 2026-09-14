extends Node
## Titulo, pausa, opcoes, remapeamento, atalhos de desenvolvimento e save de
## estado de run (GDD_ADENDOS B.7 e C.3). Usa save e opcoes isolados.

const TEST_SAVE := "user://front_end_save.json"
const SETTINGS_PATH := "user://front_end_settings.cfg"
const PrototypeScene := preload("res://scenes/prototype.tscn")

var failures: Array[String] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MetaManager.save_path = TEST_SAVE
	MetaManager.reset_save()
	MetaManager.clear_run_state()
	Settings.path = SETTINGS_PATH
	print("=== SCRAP-A-BOT :: titulo, pausa, opcoes e save de run ===")
	_test_settings_round_trip()
	_test_rebinding()
	await _test_title_and_dev_shortcuts()
	await _test_pause_and_abandon()
	await _test_shelf_cpu_used()
	await _test_run_state_resume()
	Settings.reset_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	MetaManager.clear_run_state()
	get_tree().paused = false
	Sfx.shutdown()
	for i in 30:
		await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	for message in failures:
		push_error(message)
	if failures.is_empty():
		print("=== TUDO OK ===")
	get_tree().quit(0 if failures.is_empty() else 1)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _send_key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		get_viewport().push_input(ev)


func _test_settings_round_trip() -> void:
	Settings.reset_defaults()
	Settings.shake = 0.0
	Settings.hitstop = 0.5
	Settings.reduced_flashes = true
	Settings.colorblind_shapes = false
	Settings.master_volume = 0.5
	Settings.apply()
	check(is_zero_approx(CombatFeel.shake_scale) and is_equal_approx(CombatFeel.hitstop_scale, 0.5), "Opcoes de tremor e hitstop nao chegaram ao CombatFeel")
	check(Vfx.reduced_flashes and not Vfx.colorblind_shapes, "Opcoes de acessibilidade nao chegaram ao Vfx")
	check(is_equal_approx(Sfx.master_volume_db, Settings.BASE_VOLUME_DB + linear_to_db(0.5)), "Volume nao chegou ao Sfx")
	CombatFeel.reset()
	CombatFeel.request_hitstop(100.0)
	check(is_equal_approx(float(CombatFeel.get("_freeze_remaining")), 0.05), "Hitstop em 50% deveria congelar 50 ms")
	CombatFeel.reset()
	Settings.save_settings()
	Settings.reset_defaults()
	check(is_equal_approx(CombatFeel.shake_scale, 1.0) and Vfx.colorblind_shapes, "Restaurar padrao devolve tremor e formas")
	Settings.load_settings()
	Settings.apply()
	check(is_zero_approx(Settings.shake) and Settings.reduced_flashes and is_equal_approx(Settings.master_volume, 0.5), "Opcoes nao sobreviveram ao save")
	Settings.reset_defaults()
	print("  opcoes aplicadas, salvas, lidas e restauradas: OK")


func _test_rebinding() -> void:
	Settings.reset_defaults()
	Settings.rebind("dash", KEY_F)
	var has_f := false
	var has_space := false
	var has_pad := false
	for ev in InputMap.action_get_events("dash"):
		if ev is InputEventKey:
			has_f = has_f or ev.physical_keycode == KEY_F
			has_space = has_space or ev.physical_keycode == KEY_SPACE
		if ev is InputEventJoypadButton:
			has_pad = true
	check(has_f and not has_space and has_pad, "Dash remapeado para F deveria trocar o teclado e manter o controle")
	check(GameInput.key_label("dash") == "F", "Rotulo do dash remapeado: " + GameInput.key_label("dash"))
	Settings.reset_defaults()
	check(GameInput.key_label("dash") == "ESPAÇO", "Padrao devolve o dash ao espaco: " + GameInput.key_label("dash"))

	var ui := OptionsUI.new()
	add_child(ui)
	var purge_row := -1
	for i in ui._rows.size():
		if ui._rows[i].key == "heat_purge":
			purge_row = i
	ui.activate(purge_row)
	check(ui.waiting_for_key(), "ENTER numa linha de tecla deveria esperar a proxima tecla")
	var ev := InputEventKey.new()
	ev.keycode = KEY_R
	ev.physical_keycode = KEY_R
	ev.pressed = true
	ui._gui_input(ev)
	check(not ui.waiting_for_key() and GameInput.key_label("heat_purge") == "R", "Tela de opcoes nao remapeou a purga")
	check(FileAccess.file_exists(SETTINGS_PATH), "Remapear pela tela deveria salvar as opcoes")
	ui.adjust(0, -1)
	check(is_equal_approx(Settings.shake, 0.9), "Seta para a esquerda deveria tirar 10%% do tremor (%.2f)" % Settings.shake)
	ui.queue_free()
	Settings.reset_defaults()
	print("  remapeamento pelo Settings e pela tela de opcoes: OK")


func _test_title_and_dev_shortcuts() -> void:
	Settings.dev_shortcuts = false
	Settings.apply()
	get_tree().paused = false
	var proto := PrototypeScene.instantiate()
	add_child(proto)
	await _frames(3)
	check(proto.title.visible and get_tree().paused, "Sem semente de teste o jogo deveria abrir no titulo, pausado")
	check(not proto.title.actions().has("continue"), "Sem estado de run o titulo nao deveria oferecer Continuar")
	check(proto.title.has_focus(), "Titulo sem foco de teclado")
	_send_key(KEY_G)
	await _frames(2)
	check(not proto.garage.visible, "G com atalhos de desenvolvimento desligados nao deveria abrir a Garagem")
	_send_key(KEY_ENTER)
	await _frames(2)
	check(proto.garage.visible and not proto.title.visible and get_tree().paused, "ENTER em JOGAR deveria abrir a Garagem")
	var shows_debug := false
	for line in proto.hud.manual_lines():
		shows_debug = shows_debug or line.contains("F1")
	check(not shows_debug, "Manual da HUD nao deveria listar atalhos de depuracao desligados")
	proto.queue_free()
	await _frames(2)
	Settings.dev_shortcuts = true
	Settings.apply()
	print("  titulo na abertura, JOGAR e atalhos de desenvolvimento desligados: OK")


func _test_pause_and_abandon() -> void:
	get_tree().paused = false
	var proto := PrototypeScene.instantiate()
	proto.set("start_seed", 20260914)
	add_child(proto)
	await _frames(3)
	check(not proto.title.visible and not get_tree().paused, "Com semente a cena deveria comecar direto na run")
	_send_key(KEY_ESCAPE)
	await _frames(2)
	check(proto.pause_menu.visible and get_tree().paused and proto.pause_menu.has_focus(), "ESC deveria pausar o combate com foco no menu")
	var fired := Telemetry.projectiles_fired
	Input.action_press("fire_left")
	await _frames(10)
	Input.action_release("fire_left")
	check(Telemetry.projectiles_fired == fired, "O robo atirou com o jogo pausado")
	_send_key(KEY_ESCAPE)
	await _frames(2)
	check(not proto.pause_menu.visible and not get_tree().paused, "ESC de novo deveria voltar ao combate")

	proto._open_pause()
	proto.pause_menu.activate("options")
	check(proto.options.visible and not proto.pause_menu.visible and get_tree().paused, "OPCOES na pausa deveria abrir as opcoes pausado")
	proto.options.closed.emit()
	check(proto.pause_menu.visible and not proto.options.visible, "Fechar as opcoes deveria voltar para a pausa")

	var runs := MetaManager.total_runs
	proto.pause_menu.activate("abandon")
	check(proto.pause_menu.visible and MetaManager.total_runs == runs, "O primeiro toque em DESISTIR so deveria armar")
	proto.pause_menu.activate("abandon")
	await get_tree().create_timer(1.5).timeout
	check(proto.garage.visible and MetaManager.total_runs == runs + 1, "Desistir deveria encerrar a run e abrir a Garagem")
	check(str(MetaManager.last_run_summary.get("caption", "")).contains("largar"), "Legenda da desistencia: " + str(MetaManager.last_run_summary.get("caption", "")))
	proto.queue_free()
	await _frames(2)
	print("  pausa, opcoes a partir da pausa e desistencia com confirmacao: OK")


func _test_run_state_resume() -> void:
	get_tree().paused = false
	MetaManager.clear_run_state()
	var proto := PrototypeScene.instantiate()
	proto.set("start_seed", 20260915)
	add_child(proto)
	await _frames(3)
	var robot: Robot = proto.robot
	robot.set_cpu(PartLibrary.cpu_by_id(&"cpu_ryzin"))
	var arm: PartData = robot.equipped[PartData.Slot.ARM_LEFT]
	arm.fusion_level = 2
	arm.grafts.append(&"quartz_crystal")
	proto.workbench.inventory.add(&"car_battery")
	MetaManager.current_scrap = 321
	robot.hp = robot.max_hp * 0.5
	var hp_ratio := robot.hp / robot.max_hp
	proto.enemy_pool.release_all()
	proto.director.stop()
	proto._show_workbench()
	check(MetaManager.has_run_state(), "Abrir a Bancada deveria gravar o estado de run")
	var offers_before := []
	for p in proto.workbench._offers:
		offers_before.append(String(p.id))
	var state := MetaManager.load_run_state()
	check(str(state.get("resume", "")) == "workbench" and int(state.get("sector", 0)) == 1 and str(state.get("cpu", "")) == "cpu_ryzin",
		"Estado salvo incompleto: %s" % str(state.keys()))
	proto.queue_free()
	await _frames(2)

	get_tree().paused = false
	var again := PrototypeScene.instantiate()
	add_child(again)
	await _frames(3)
	check(again.title.visible and again.title.actions().size() > 0 and again.title.actions()[0] == "continue", "Com estado salvo o titulo deveria abrir em Continuar")
	again.title.activate("continue")
	await _frames(2)
	check(again.workbench.visible and again.director.sector == 1 and not again.title.visible, "Continuar deveria reabrir a Bancada do setor salvo")
	var r2: Robot = again.robot
	var arm2: PartData = r2.equipped[PartData.Slot.ARM_LEFT]
	check(r2.cpu.id == &"cpu_ryzin" and arm2.fusion_level == 2 and arm2.grafts.has(&"quartz_crystal"), "O robo deveria voltar com CPU, tier e enxerto")
	check(MetaManager.current_scrap == 321 and again.workbench.inventory.count(&"car_battery") == 1, "Sucata e mochila deveriam voltar")
	check(absf(r2.hp / r2.max_hp - hp_ratio) < 0.01, "HP deveria voltar (%.2f)" % (r2.hp / r2.max_hp))
	var offers_after := []
	for p in again.workbench._offers:
		offers_after.append(String(p.id))
	check(offers_after == offers_before, "Vitrine deveria ser identica apos retomar: %s x %s" % [str(offers_before), str(offers_after)])

	again.workbench._proceed()
	await _frames(2)
	var room_state := MetaManager.load_run_state()
	check(str(room_state.get("resume", "")) == "room" and int(room_state.get("sector", 0)) == 2 and again.director.sector == 2,
		"Prosseguir deveria gravar o inicio do setor 2")

	r2._iframes = 0.0
	r2.hp = 1.0
	r2.take_damage(999.0, r2.global_position, 0, "por um teste")
	await _frames(2)
	check(not MetaManager.has_run_state(), "O golpe fatal deveria apagar o estado de run")
	await get_tree().create_timer(1.5).timeout
	again.queue_free()
	await _frames(2)
	print("  save de run na Bancada e no setor, Continuar identico e morte apagando o save: OK")


func _test_shelf_cpu_used() -> void:
	get_tree().paused = false
	MetaManager.selected_cpu_id = &"cpu_ryzin"
	var proto := PrototypeScene.instantiate()
	proto.set("start_seed", 20260916)
	add_child(proto)
	await _frames(3)
	check(proto.robot.cpu.id == &"cpu_ryzin", "A run deveria usar a CPU escolhida na prateleira, usou " + str(proto.robot.cpu.id))
	proto._begin_run(true)
	await _frames(2)
	check(proto.robot.cpu.id == &"cpu_pentiun", "O desafio de hoje deveria fixar a CPU inicial, usou " + str(proto.robot.cpu.id))
	MetaManager.selected_cpu_id = &"cpu_xeon"
	proto._begin_run(false, 20260917)
	await _frames(2)
	check(proto.robot.cpu.id == &"cpu_pentiun", "CPU bloqueada no save nao pode entrar na run, usou " + str(proto.robot.cpu.id))
	MetaManager.selected_cpu_id = &"cpu_pentiun"
	proto.queue_free()
	await _frames(2)
	print("  CPU da prateleira usada na run, ignorada no desafio de hoje e bloqueada respeitada: OK")
