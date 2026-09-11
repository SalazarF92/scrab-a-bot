class_name DebugOverlay
extends Control
## Painel de desenvolvimento. GDD 7.2 e 7.7.
##
## Existe desde o primeiro dia por decisao explicita do GDD 7.6: "Benchmark
## automatizado noturno com falha da integracao continua se cair de 60 fps.
## Nunca otimizamos depois." O painel e a versao manual desse benchmark, e o
## orcamento por quadro da tabela do GDD 7.2 esta impresso nele para comparacao.
##
## Os limites da arena sao lidos das constantes do ArenaGenerator. Antes o painel
## imprimia os numeros da arena de 2400 por 1350 do GDD enquanto o gerador usava
## os do poco, e o painel mentia para quem desenvolvia.

var pool: ProjectilePool
var arena: ArenaGenerator
var robot: Robot
var enemy_pool: EnemyPool

var visible_panel: bool = false

var _font: Font
var _frame_samples: Array[float] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_frame_samples.append(delta)
	if _frame_samples.size() > 600:
		_frame_samples.pop_front()
	queue_redraw()


## Percentil 1 de quadros por segundo. GDD 7.7 pede exatamente esta metrica,
## e nao a media, porque e a travada que o jogador sente.
func _worst_percentile_fps() -> float:
	if _frame_samples.size() < 30:
		return 0.0
	var sorted := _frame_samples.duplicate()
	sorted.sort()
	var idx: int = int(float(sorted.size()) * 0.99)
	var worst: float = sorted[mini(idx, sorted.size() - 1)]
	return 1.0 / maxf(worst, 0.0001)


func _draw() -> void:
	if not visible_panel:
		draw_string(_font, Vector2(16, 24), "F1 painel", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.35))
		return

	var lines: Array[String] = []
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)

	lines.append("SCRAP-A-BOT  prototipo")
	lines.append("")
	lines.append("fps %d   p1 %.0f   alvo 60 travados" % [Engine.get_frames_per_second(), _worst_percentile_fps()])
	lines.append("fisica %.2f ms   processo %.2f ms   orcamento total 16,6 ms" % [physics_ms, process_ms])
	lines.append("draw calls %d" % draw_calls)
	lines.append("")

	if pool != null:
		lines.append("projeteis vivos %d / %d   (alvo de estresse 800)" % [pool.alive_count(), ProjectilePool.MAX_PROJECTILES])
	if enemy_pool != null:
		lines.append("inimigos %d   pool %d   cresceu %d" % [enemy_pool.active_count(), enemy_pool.capacity(), enemy_pool.grown])
	lines.append("")

	if robot != null and is_instance_valid(robot):
		lines.append("hp %.0f/%.0f   calor %.0f%%   watts %d/%d%s   rebatedor x%.2f" % [
			robot.hp, robot.max_hp, robot.heat_ratio() * 100.0,
			robot.watts_used, robot.total_tdp(),
			"  SUBVOLTAGEM" if robot.is_undervolt() else "",
			robot.paddle_restitution,
		])
		lines.append("cpu: %s" % (robot.cpu.display_name if robot.cpu else "-"))
		for slot in [PartData.Slot.ARM_LEFT, PartData.Slot.ARM_RIGHT, PartData.Slot.HEAD, PartData.Slot.CHASSIS]:
			var p: PartData = robot.equipped.get(slot)
			if p != null:
				lines.append("  %s  (tier %s)" % [p.display_name, p.fusion_roman()])
		lines.append("")

	lines.append("METAPROGRESSÃO: %d Cobre  |  Sucata atual: %d  |  Melhor Setor: %d  |  Abates totais: %d" % [
		MetaManager.copper, MetaManager.current_scrap, MetaManager.best_sector, MetaManager.total_kills
	])
	lines.append("  Upgrades: Chapa %d/5  Polvora %d/5  Mola %d/5  Cobre %d/5  Sorte %d/5" % [
		MetaManager.get_upgrade_level("chapa"), MetaManager.get_upgrade_level("polvora"),
		MetaManager.get_upgrade_level("mola"), MetaManager.get_upgrade_level("cobre"),
		MetaManager.get_upgrade_level("sorte")
	])
	lines.append("  semente %s%s" % [GameRng.seed_label(GameRng.run_seed), "  (desafio de hoje)" if MetaManager.run_is_daily else ""])
	lines.append("")

	lines.append("TELEMETRIA (GDD 7.7)")
	lines.append("  " + Telemetry.summary())
	var med := Telemetry.median_bounce_multiplier()
	lines.append("  contrato do pilar 3: mediana >= 1,25  ->  %s" % ("OK" if med >= 1.25 else "FALHOU"))
	lines.append("  distribuicao de quiques por acerto:")
	lines.append("  " + _histogram())
	lines.append("")

	if arena != null and not arena.last_report.is_empty():
		var r := arena.last_report
		lines.append("ARENA (GDD 3.3.4, limites do poco)")
		lines.append("  obstaculos %d (%d a %d)   cobertura %.0f%% (%.0f a %.0f%%) %s" % [
			r["obstacles"], ArenaGenerator.MIN_OBSTACLES, ArenaGenerator.MAX_OBSTACLES,
			r["coverage"] * 100.0, ArenaGenerator.MIN_COVERAGE * 100.0, ArenaGenerator.MAX_COVERAGE * 100.0,
			"ok" if r["coverage_ok"] else "FORA",
		])
		lines.append("  corredores >= %.0f px: %s   alcancavel: %s" % [
			ArenaGenerator.MIN_CORRIDOR,
			"ok" if r["corridors_ok"] else "FALHOU", "ok" if r["reachable_ok"] else "FALHOU",
		])
		lines.append("  ponto mais distante de superficie: %.0f px (teto %.0f) %s" % [
			r["max_surface_dist"], ArenaGenerator.MAX_DIST_TO_SURFACE, "ok" if r["surface_dist_ok"] else "FALHOU",
		])
		lines.append("")

	lines.append("B Bancada   G Garagem   F1 painel   F2 nova arena   F3 estresse 800")
	lines.append("F4 formas daltonismo   F5 trocar CPU   1/2/3 trocar pecas   F6 tremor 0%")
	lines.append("A/D mover   mouse mirar   clique E/D atirar   espaco dash   E purga + parede de vapor")

	var y := 24.0
	var pad := Rect2(10, 10, 760, lines.size() * 19.0 + 14.0)
	draw_rect(pad, Color(0, 0, 0, 0.55))
	for l in lines:
		var col := Color(1, 1, 1, 0.85)
		if l.find("FALHOU") >= 0 or l.find("FORA") >= 0 or l.find("SUBVOLTAGEM") >= 0:
			col = Color("#FF2D95")
		elif l.ends_with("OK") or l.find("ok") >= 0:
			col = Color("#8CFF1A")
		draw_string(_font, Vector2(20, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		y += 19.0


func _histogram() -> String:
	var out := ""
	var total: int = maxi(Telemetry.total_hits, 1)
	for b in 7:
		var pct: float = float(Telemetry.hits_by_bounce[b]) / float(total) * 100.0
		out += "%d:%02.0f%%  " % [b, pct]
	return out
