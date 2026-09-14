extends Node
## O simulador de balanceamento completa uma run curta de ponta a ponta: piloto
## sem abate assistido, Bancada, relatorio agregado e log de telemetria por run.
## Nao mede balanceamento; garante que a ferramenta continua funcionando.

const REPORT_DIR := "user://balance_sim_smoke"

var failures: Array[String] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("=== SCRAP-A-BOT :: simulador de balanceamento, run curta ===")
	var sim := BalanceSim.new()
	sim.runs = 1
	sim.base_seed = 4242
	sim.max_sector = 1
	sim.report_dir = REPORT_DIR
	sim.quit_when_done = false
	sim.parse_args = false
	add_child(sim)
	var report: Dictionary = await sim.finished
	check(int(report.get("runs", 0)) == 1, "Relatorio deveria ter uma run")
	var rows: Array = report.get("rows", [])
	if rows.size() == 1:
		var row: Dictionary = rows[0]
		check(row.result == "limit" or row.result == "died", "Resultado inesperado da run curta: " + str(row.result))
		check(int(row.kills) > 0, "O piloto nao abateu nenhum inimigo")
		check(float(row.game_time) > 5.0, "A run curta terminou cedo demais (%.1f s)" % float(row.game_time))
		if row.result == "limit":
			check(int(row.sectors_cleared) == 1, "Parar na Bancada do setor 1 deveria contar 1 setor limpo")
		for group in BalanceSim.GROUPS:
			check(row.has(group) and report.by[group].has(str(row[group])), "Relatorio sem o grupo " + group)
		print("  piloto: %s no setor %d em %.1f s de jogo, %d abates" % [row.result, row.sector_reached, row.game_time, row.kills])
	check(FileAccess.file_exists(REPORT_DIR + "/report.json"), "Relatorio JSON nao foi gravado")
	var logs := DirAccess.get_files_at(ProjectSettings.globalize_path(REPORT_DIR + "/runs"))
	check(logs.size() == 1, "Deveria haver um log de telemetria por run, ha %d" % logs.size())
	if logs.size() == 1:
		var data = JSON.parse_string(FileAccess.get_file_as_string(REPORT_DIR + "/runs/" + logs[0]))
		check(typeof(data) == TYPE_DICTIONARY and data.has("telemetry") and data.has("loadout"), "Log da run sem telemetria ou loadout")

	sim.proto.queue_free()
	Sfx.shutdown()
	for i in 30:
		OS.delay_msec(10)
		await get_tree().process_frame
	for file_name in logs:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_DIR + "/runs/" + file_name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_DIR + "/runs"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_DIR + "/report.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT_DIR))
	MetaManager.clear_run_state()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BalanceSim.TEST_SAVE))
	for message in failures:
		push_error(message)
	if failures.is_empty():
		print("=== TUDO OK ===")
	get_tree().quit(0 if failures.is_empty() else 1)
