class_name Hud
extends Control
## HUD do prototipo. Layout proposto em GDD_ADENDOS B.4, porque o GDD nao
## especifica HUD nenhum apesar de o jogo ter seis leituras simultaneas.
##
## Principio: o que muda depressa fica NO robo (o anel de calor, desenhado pelo
## proprio Robot), o que muda devagar fica nas bordas. E o que mantem os olhos
## no centro da tela, onde a acao acontece.
##
## GDD 1.4: elementos criticos da interface ficam nos 60% centrais horizontais,
## para o corte vertical de 9 por 16 continuar jogavel.

const PLATE_HP := 25.0

var robot: Robot
var director: WaveDirector

var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if robot == null or not is_instance_valid(robot):
		return
	var vp := get_viewport_rect().size

	_draw_hp_and_dash(vp)
	_draw_parts(vp)
	_draw_header(vp)
	_draw_reticle()
	_draw_vignette(vp)


## Vida em chapas de metal soldadas, uma por 25 de HP. Contar chapas e mais
## rapido que ler uma barra continua, e a chapa que racha e legivel de canto
## de olho.
func _draw_hp_and_dash(vp: Vector2) -> void:
	# Contador de sucata da run atual
	var scrap_str := "🔩 %d SUCATA" % MetaManager.current_scrap
	if MetaManager.airbag_available:
		scrap_str += "  [AIRBAG PRONTO]"
	draw_string(_font, Vector2(30.0, vp.y - 82.0), scrap_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#FFD400"))

	var plates := int(ceil(robot.max_hp / PLATE_HP))
	var x := 30.0
	var y := vp.y - 66.0
	for i in plates:
		var filled: float = clampf((robot.hp - float(i) * PLATE_HP) / PLATE_HP, 0.0, 1.0)
		var r := Rect2(x + i * 26.0, y, 22.0, 30.0)
		draw_rect(r, Color(0, 0, 0, 0.45))
		if filled > 0.0:
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y * (1.0 - filled), r.size.x, r.size.y * filled),
				Color("#8CFF1A") if filled > 0.34 else Color("#FF2D95"))
		draw_rect(r, Color("#1A0F14"), false, 2.0)

	# Cargas de dash como parafusos: cheio e uma carga pronta.
	var dy := vp.y - 28.0
	for i in robot.dash_charges_max():
		var at := Vector2(x + 11.0 + i * 26.0, dy)
		var ready: bool = robot.dash_charges() > i
		draw_circle(at, 8.0, Color("#F5F0E1") if ready else Color(1, 1, 1, 0.18))
		draw_arc(at, 8.0, 0.0, TAU, 12, Color("#1A0F14"), 2.0)
		if ready:
			draw_line(at + Vector2(-4, -4), at + Vector2(4, 4), Color("#1A0F14"), 2.0)


func _draw_parts(vp: Vector2) -> void:
	var slots := [
		[PartData.Slot.ARM_LEFT, "L2"],
		[PartData.Slot.ARM_RIGHT, "R2"],
		[PartData.Slot.HEAD, "R1"],
	]
	var x := vp.x - 40.0
	for entry in slots:
		var part: PartData = robot.equipped.get(entry[0])
		var at := Vector2(x, vp.y - 52.0)
		draw_rect(Rect2(at - Vector2(26, 26), Vector2(52, 52)), Color(0, 0, 0, 0.45))
		if part != null:
			draw_rect(Rect2(at - Vector2(20, 20), Vector2(40, 40)), part.color)
			# Sombra de recarga radial: gira e some conforme a peca fica pronta.
			# Armas automaticas de cadencia alta nao mostram, senao pisca sem parar.
			var ratio := robot.cooldown_ratio(entry[0])
			if ratio > 0.0 and part.fire_rate < 4.0:
				draw_arc(at, 24.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, Color(0, 0, 0, 0.7), 10.0)
		draw_rect(Rect2(at - Vector2(26, 26), Vector2(52, 52)), Color("#1A0F14"), false, 2.0)
		draw_string(_font, at + Vector2(-24, 40), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
		x -= 62.0

	# Orcamento de energia. Em subvoltagem o texto pisca, porque a penalidade e
	# severa e o jogador precisa saber que ela e escolha dele. GDD 4.1.1.
	var tdp: int = robot.cpu.tdp if robot.cpu else 0
	var over := robot.is_undervolt()
	var col := Color("#FF2D95") if over else Color("#8CFF1A")
	if over and fmod(Time.get_ticks_msec() / 220.0, 2.0) < 1.0:
		col = Color("#FFD400")
	var text := "%d / %d W%s" % [robot.watts_used, tdp, "  SUBVOLTAGEM" if over else ""]
	draw_string(_font, Vector2(vp.x - 300.0, vp.y - 96.0), text, HORIZONTAL_ALIGNMENT_RIGHT, 270.0, 18, col)

	# Purga de calor.
	var purge_col := Color("#22E0FF") if robot.purge_ready() else Color(1, 1, 1, 0.25)
	draw_string(_font, Vector2(vp.x - 300.0, vp.y - 118.0),
		"E  PURGA" if robot.purge_ready() else "E  %.1fs" % robot.purge_seconds_left(),
		HORIZONTAL_ALIGNMENT_RIGHT, 270.0, 16, purge_col)


func _draw_header(vp: Vector2) -> void:
	if director == null:
		return
	var text := "SETOR %d   ONDA %d/%d" % [director.sector, director.wave_index, WaveDirector.WAVES_PER_ROOM]
	draw_string(_font, Vector2(vp.x * 0.5 - 200.0, 42.0), text, HORIZONTAL_ALIGNMENT_CENTER, 400.0, 20, Color(1, 1, 1, 0.75))

	# A metrica que decide o pilar 3, visivel durante o desenvolvimento.
	# GDD 7.7: se a mediana ficar abaixo de 1,25, o pilar 3 falhou.
	var med := Telemetry.median_bounce_multiplier()
	var ok := med >= 1.25
	draw_string(_font, Vector2(vp.x * 0.5 - 200.0, 68.0),
		"quique mediano x%.2f   ricochete %.0f%% do dano" % [med, Telemetry.ricochet_damage_share() * 100.0],
		HORIZONTAL_ALIGNMENT_CENTER, 400.0, 15,
		Color("#8CFF1A") if ok else Color("#FF2D95"))


## GDD 3.2: "O reticulo e um alvo desenhado a mao que se deforma. Ele fica
## vermelho e treme quando o calor esta acima de 80%."
func _draw_reticle() -> void:
	# A HUD vive numa CanvasLayer sem transformada, entao suas coordenadas ja
	# sao as da tela e o mouse nao precisa de conversao pela camera.
	var at := get_global_mouse_position()
	var heat := robot.heat_ratio()
	var color := Color("#F5F0E1")
	var jitter := Vector2.ZERO
	if heat > 0.8:
		color = Color("#FF2D95")
		jitter = Vector2(randf_range(-3, 3), randf_range(-3, 3))
	var r := 16.0 + robot.velocity.length() * 0.02
	for i in 4:
		var a := PI * 0.25 + TAU * i / 4.0
		var d := Vector2.from_angle(a)
		draw_line(at + jitter + d * (r - 7.0), at + jitter + d * r, color, 3.0)
	draw_arc(at + jitter, r, 0.0, TAU, 20, Color(color, 0.35), 2.0)


## GDD 3.4.2: com o slider de tremor em 0%, o tremor e substituido por um pulso
## de vinheta na borda da tela, para nao perder a informacao.
func _draw_vignette(vp: Vector2) -> void:
	var pulse := CombatFeel.vignette_pulse()
	if pulse <= 0.01:
		return
	var thickness := 30.0 * pulse
	var col := Color("#FF2D95")
	col.a = pulse * 0.5
	draw_rect(Rect2(0, 0, vp.x, thickness), col)
	draw_rect(Rect2(0, vp.y - thickness, vp.x, thickness), col)
	draw_rect(Rect2(0, 0, thickness, vp.y), col)
	draw_rect(Rect2(vp.x - thickness, 0, thickness, vp.y), col)
