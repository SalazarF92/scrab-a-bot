class_name BalanceSim
extends Node
## Simulador de balanceamento headless. GDD 7.6: "simulador headless que roda
## runs com builds aleatorias e reporta taxa de vitoria por peca".
##
## Um piloto automatico joga a run sem abate assistido: mira no inimigo mais
## baixo (por ricochete na parede quando o alvo so morre por quique), segura o
## braco esquerdo, pulsa o direito e a cabeca, purga com calor alto, corre para
## rebater o proprio projetil que cai e sai das faixas avisadas dos chefes. Na
## Bancada solda com HP baixo, funde duplicatas e evolui pecas. CPU e pecas sao
## sorteadas pela semente de cada run, sem upgrades da Garagem e com risco zero.
##
## O piloto e simples de proposito: mede o jogo com uma habilidade fixa, nao a
## de uma pessoa. Serve para comparar pecas e versoes entre si, nao para cravar
## a dificuldade real.
##
## Uso:
##   Godot --headless --path . --fixed-fps 120 res://tools/balance_sim.tscn ++ --runs=20 --seed=1000 --max-sector=5
## Relatorio em user://balance_sim/report.json; um log por run em user://balance_sim/runs/.

signal finished(report: Dictionary)

const TEST_SAVE := "user://balance_sim_save.json"
## 25 minutos de jogo; uma run normal leva de 10 a 15.
const RUN_TIME_LIMIT := 1500.0
## So persegue projetil que ja esta perto da base.
const PADDLE_WATCH_Y := 600.0
const PADDLE_HORIZON := 0.9
const ACTIONS := ["aim_left", "aim_right", "aim_up", "aim_down", "move_left", "move_right",
	"fire_left", "fire_right", "head_ability", "heat_purge", "dash"]
const GROUPS := ["cpu", "arm_left", "arm_right", "head", "chassis"]

@export var runs := 8
@export var base_seed := 1000
@export var max_sector := 5
@export var report_dir := "user://balance_sim"
@export var quit_when_done := true
@export var parse_args := true

var results: Array[Dictionary] = []
var proto: Node

var _run_index := -1
var _run_time := 0.0
var _frame := 0
var _loadout: Dictionary = {}
var _bench_done_sector := -1
var _pending_result := ""
var _limit_cleared := 0
var _done := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if parse_args:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--runs="):
				runs = maxi(1, arg.get_slice("=", 1).to_int())
			elif arg.begins_with("--seed="):
				base_seed = arg.get_slice("=", 1).to_int()
			elif arg.begins_with("--max-sector="):
				max_sector = clampi(arg.get_slice("=", 1).to_int(), 1, 5)
	MetaManager.save_path = TEST_SAVE
	MetaManager.reset_save()
	MetaManager.clear_run_state()
	MetaManager.run_log_dir = report_dir + "/runs"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MetaManager.run_log_dir))
	print("=== SCRAP-A-BOT :: simulador de balanceamento (%d runs, semente %d, ate o setor %d) ===" % [runs, base_seed, max_sector])
	_start_next_run()


func run_seed(index: int) -> int:
	return base_seed + index * 7919


func _start_next_run() -> void:
	_run_index += 1
	if _run_index >= runs:
		_finish()
		return
	var seed_value := run_seed(_run_index)
	_rng.seed = hash("balance|%d" % seed_value)
	if proto == null:
		proto = load("res://scenes/prototype.tscn").instantiate()
		proto.start_seed = seed_value
		add_child(proto)
	else:
		proto._begin_run(false, seed_value)
	_apply_random_loadout()
	_run_time = 0.0
	_frame = 0
	_bench_done_sector = -1
	_pending_result = ""


func _apply_random_loadout() -> void:
	var robot: Robot = proto.robot
	var cpus := PartLibrary.cpus()
	var cpu: CpuData = cpus[_rng.randi_range(0, cpus.size() - 1)]
	robot.set_cpu(cpu)
	_loadout = {"cpu": String(cpu.id)}
	var catalog := [
		["arm_left", PartLibrary.arm_left_parts()],
		["arm_right", PartLibrary.arm_right_parts()],
		["head", PartLibrary.head_parts()],
		["chassis", PartLibrary.chassis_parts()],
	]
	for entry in catalog:
		var candidates: Array = []
		for part in entry[1]:
			if not part.recipe_only:
				candidates.append(part)
		var pick: PartData = candidates[_rng.randi_range(0, candidates.size() - 1)]
		robot.equip(pick.clone())
		_loadout[entry[0]] = String(pick.id)
	robot.reset_for_run()


func _physics_process(delta: float) -> void:
	if _done or proto == null or _run_index >= runs:
		return
	if proto.garage.visible:
		_release_inputs()
		var result := _pending_result
		if result == "":
			result = "won" if bool(MetaManager.last_run_summary.get("won", false)) else "died"
		_record_run(result)
		_start_next_run()
		return
	if proto.workbench.visible:
		_release_inputs()
		_shop()
		return
	if get_tree().paused or proto._run_over:
		_release_inputs()
		return
	_run_time += delta
	_frame += 1
	if _run_time > RUN_TIME_LIMIT:
		_release_inputs()
		_pending_result = "timeout"
		proto._finish_run(false)
		return
	_pilot()


# --- piloto --------------------------------------------------------------------

func _pilot() -> void:
	var robot: Robot = proto.robot
	var center := robot.body_center()
	var target := _pick_target()

	var aim := Vector2.UP
	if target != Vector2.INF:
		aim = (target - center).normalized()
	_press("aim_right", maxf(aim.x, 0.0))
	_press("aim_left", maxf(-aim.x, 0.0))
	_press("aim_up", maxf(-aim.y, 0.3))
	_press("aim_down", 0.0)

	var desired_x := _paddle_x(robot)
	if is_nan(desired_x):
		desired_x = clampf(target.x, 60.0, 940.0) if target != Vector2.INF else 500.0
	desired_x = _avoid_boss_lanes(desired_x, robot)
	var dx := desired_x - robot.global_position.x
	_press("move_right", 1.0 if dx > 14.0 else 0.0)
	_press("move_left", 1.0 if dx < -14.0 else 0.0)

	_press("fire_left", 1.0)
	_press("fire_right", 1.0 if _frame % 16 < 8 else 0.0)
	_press("head_ability", 1.0 if _frame % 90 == 0 else 0.0)
	_press("heat_purge", 1.0 if robot.heat_ratio() > 0.75 and robot.purge_ready() and _frame % 2 == 0 else 0.0)
	_press("dash", 1.0 if _in_boss_lane(robot) and _frame % 20 == 0 else 0.0)


## Inimigo mais proximo da base. Alvo que so morre por quique (Fantasma de
## Disquete) e mirado pelo reflexo na parede lateral mais proxima.
func _pick_target() -> Vector2:
	var best := Vector2.INF
	var best_y := -INF
	var needs_bounce := false
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e == null or not e.active:
			continue
		if e.global_position.y > best_y:
			best_y = e.global_position.y
			best = e.global_position
			needs_bounce = e.min_bounces_to_damage > 0
	if best != Vector2.INF and needs_bounce:
		best.x = -best.x if best.x < ArenaGenerator.ARENA_SIZE.x * 0.5 else 2.0 * ArenaGenerator.ARENA_SIZE.x - best.x
	return best


## Ponto onde o proprio projetil que esta caindo vai cruzar a linha do corpo.
func _paddle_x(robot: Robot) -> float:
	var pool: ProjectilePool = robot.pool
	var baseline := robot.body_center().y
	var best_t := INF
	var best_x := NAN
	for i in ProjectilePool.MAX_PROJECTILES:
		if pool._alive[i] == 0 or pool._faction[i] != ProjectilePool.FACTION_PLAYER:
			continue
		var v: Vector2 = pool._vel[i]
		var p: Vector2 = pool._pos[i]
		if v.y <= 60.0 or p.y < PADDLE_WATCH_Y:
			continue
		var t := (baseline - p.y) / v.y
		if t < 0.0 or t > PADDLE_HORIZON:
			continue
		var x := p.x + v.x * t
		if x < 40.0 or x > ArenaGenerator.ARENA_SIZE.x - 40.0:
			continue
		if t < best_t:
			best_t = t
			best_x = x
	return best_x


func _boss_lanes() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e == null or not e.active or e.boss_kind == &"" or e._boss_shards:
			continue
		if e.boss_state != Enemy.BossState.TELEGRAPH and e.boss_state != Enemy.BossState.STRIKE:
			continue
		for x in e.boss_lanes:
			out.append([x, e.boss_lane_half_width + Robot.COLLISION_RADIUS + 12.0])
	return out


func _avoid_boss_lanes(desired_x: float, robot: Robot) -> float:
	var lanes := _boss_lanes()
	if lanes.is_empty():
		return desired_x
	var best := desired_x
	var best_cost := INF
	for candidate in range(60, 941, 20):
		var safe := true
		for lane in lanes:
			if absf(float(candidate) - float(lane[0])) <= float(lane[1]):
				safe = false
		if not safe:
			continue
		var cost := absf(float(candidate) - robot.global_position.x) * 2.0 + absf(float(candidate) - desired_x)
		if cost < best_cost:
			best_cost = cost
			best = float(candidate)
	return best


func _in_boss_lane(robot: Robot) -> bool:
	for lane in _boss_lanes():
		if absf(robot.global_position.x - float(lane[0])) <= float(lane[1]):
			return true
	return false


func _press(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	else:
		Input.action_release(action)


func _release_inputs() -> void:
	for action in ACTIONS:
		Input.action_release(action)


# --- Bancada -------------------------------------------------------------------

func _shop() -> void:
	var wb: WorkbenchUI = proto.workbench
	if _bench_done_sector == wb.sector:
		return
	_bench_done_sector = wb.sector
	if wb.sector >= max_sector:
		_pending_result = "limit"
		_limit_cleared = wb.sector
		proto._finish_run(false)
		return
	var robot: Robot = proto.robot
	if robot.hp < robot.max_hp * 0.6:
		wb._try_repair()
	for i in range(wb._offers.size() - 1, -1, -1):
		var offer: PartData = wb._offers[i]
		if wb.offer_mode(offer) == &"fuse" and MetaManager.current_scrap >= offer.base_price():
			wb._try_buy_offer(i)
	var guard := 0
	var bought := true
	while bought and guard < 12:
		guard += 1
		bought = false
		for slot in [PartData.Slot.ARM_RIGHT, PartData.Slot.ARM_LEFT, PartData.Slot.HEAD, PartData.Slot.CHASSIS]:
			var part: PartData = robot.equipped.get(slot)
			if part != null and part.fusion_level < 3 and part.upgrade_cost() > 0 and MetaManager.current_scrap >= part.upgrade_cost():
				wb._try_upgrade_slot(slot)
				bought = true
	wb._proceed()


# --- relatorio -----------------------------------------------------------------

func _record_run(result: String) -> void:
	var s: Dictionary = MetaManager.last_run_summary
	var entry := {
		"seed": run_seed(_run_index), "result": result,
		"sector_reached": int(s.get("sector_reached", 1)), "sectors_cleared": int(s.get("sectors_cleared", 0)),
		"game_time": snappedf(_run_time, 0.1), "kills": int(s.get("kills", 0)),
		"median_bounce": snappedf(Telemetry.median_bounce_multiplier(), 0.01),
		"ricochet_share": snappedf(Telemetry.ricochet_damage_share(), 0.01),
		"dps": snappedf(Telemetry.dps(), 0.1),
		"paddle_catches": Telemetry.paddle_catches, "lost_floor": Telemetry.projectiles_lost_floor,
		"breaches": Telemetry.enemies_breached, "killer": proto.robot.last_damage_source,
	}
	entry.merge(_loadout)
	if result == "limit":
		# Parar na Bancada conta os setores ja limpos, nao uma derrota no setor.
		entry.sectors_cleared = _limit_cleared
	results.append(entry)
	print("  run %d/%d  %-7s setor %d  %6.1f s  abates %4d  quique x%.2f  rebatidas %d / chao %d  %s" % [
		_run_index + 1, runs, result, entry.sector_reached, entry.game_time, entry.kills, entry.median_bounce,
		entry.paddle_catches, entry.lost_floor, "%s | %s | %s | %s | %s" % [_loadout.cpu, _loadout.arm_left, _loadout.arm_right, _loadout.head, _loadout.chassis]])


static func build_report(rows: Array) -> Dictionary:
	var report := {"runs": rows.size(), "wins": 0, "mean_sectors_cleared": 0.0, "by": {}, "rows": rows}
	for group in GROUPS:
		report.by[group] = {}
	var cleared := 0.0
	for row in rows:
		var won: bool = row.result == "won"
		if won:
			report.wins += 1
		cleared += float(row.sectors_cleared)
		for group in GROUPS:
			var key := str(row.get(group, "?"))
			var bucket: Dictionary = report.by[group].get(key, {"runs": 0, "wins": 0, "cleared": 0.0, "paddle": 0, "floor": 0})
			bucket.runs += 1
			if won:
				bucket.wins += 1
			bucket.cleared += float(row.sectors_cleared)
			bucket.paddle += int(row.paddle_catches)
			bucket.floor += int(row.lost_floor)
			report.by[group][key] = bucket
	report.mean_sectors_cleared = cleared / maxf(1.0, float(rows.size()))
	for group in GROUPS:
		for key in report.by[group]:
			var b: Dictionary = report.by[group][key]
			b["win_rate"] = float(b.wins) / float(b.runs)
			b["mean_sectors_cleared"] = float(b.cleared) / float(b.runs)
			b["paddle_per_floor"] = float(b.paddle) / maxf(1.0, float(b.floor))
			# GDD 7.6: taxa de vitoria fora de 35 a 65% entra em revisao. Com menos
			# de 10 runs a amostra nao sustenta a conclusao.
			b["review"] = int(b.runs) >= 10 and (float(b.win_rate) < 0.35 or float(b.win_rate) > 0.65)
	return report


func _print_report(report: Dictionary) -> void:
	print("--- %d runs, %d vitorias, media de %.2f setores limpos ---" % [report.runs, report.wins, report.mean_sectors_cleared])
	for group in GROUPS:
		print("  [%s]" % group)
		for key in report.by[group]:
			var b: Dictionary = report.by[group][key]
			print("    %-24s runs %2d  vitorias %2d  setores %.2f  rebatidas/chao %.2f%s" % [
				key, b.runs, b.wins, b.mean_sectors_cleared, b.paddle_per_floor, "  REVISAR" if b.review else ""])


func _finish() -> void:
	_done = true
	_release_inputs()
	var report := build_report(results)
	var path := report_dir + "/report.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	_print_report(report)
	print("relatorio: ", ProjectSettings.globalize_path(path))
	finished.emit(report)
	if not quit_when_done:
		return
	if proto != null:
		proto.queue_free()
	Sfx.shutdown()
	for i in 30:
		OS.delay_msec(10)
		await get_tree().process_frame
	MetaManager.clear_run_state()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("=== SIMULACAO CONCLUIDA ===")
	get_tree().quit(0)
