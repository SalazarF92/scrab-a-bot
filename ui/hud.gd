class_name Hud
extends Control
## HUD do prototipo. Layout proposto em GDD_ADENDOS B.4, porque o GDD nao
## especifica HUD nenhum apesar de o jogo ter seis leituras simultaneas.
##
## Principio: o que muda depressa fica NO robo (o anel de calor e o arco do
## rebatedor, desenhados pelo proprio Robot), o que muda devagar fica nas bordas.
## E o que mantem os olhos no centro da tela, onde a acao acontece.
##
## GDD 1.4: elementos criticos da interface ficam nos 60% centrais horizontais,
## para o corte vertical de 9 por 16 continuar jogavel.

const PLATE_HP := 25.0
## Um chassi de Cofre fundido ate o tier IV passa de 800 HP. Acima deste numero
## de chapas, cada chapa passa a valer mais que 25 para a fileira caber na tela.
const MAX_PLATES := 12

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

	_draw_shell(vp)
	_draw_hp_and_dash(vp)
	_draw_parts(vp)
	_draw_header(vp)
	_draw_wave_banner(vp)
	_draw_reticle()
	_draw_vignette(vp)


## Vida em chapas de metal soldadas, uma por 25 de HP. Contar chapas e mais
## rapido que ler uma barra continua, e a chapa que racha e legivel de canto
## de olho.
func _draw_hp_and_dash(vp: Vector2) -> void:
	var scrap_str := "%d SUCATA" % MetaManager.current_scrap
	if MetaManager.airbag_available:
		scrap_str += "  [AIRBAG PRONTO]"
	draw_string(_font, Vector2(50.0, vp.y - 82.0), scrap_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#FFD400"))

	var plate_hp := maxf(PLATE_HP, robot.max_hp / float(MAX_PLATES))
	var plates := int(ceil(robot.max_hp / plate_hp))
	var x := 50.0
	var y := vp.y - 66.0
	for i in plates:
		var filled: float = clampf((robot.hp - float(i) * plate_hp) / plate_hp, 0.0, 1.0)
		var r := Rect2(x + (i % 12) * 26.0, y - (i / 12) * 34.0, 22.0, 30.0)
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


func _draw_shell(vp: Vector2) -> void:
	var left := 28.0
	ArtDirector.panel(self, Rect2(left, 26, 350, 177))
	draw_string(_font, Vector2(left + 22, 87), "SCRAP-A-BOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color("#FFD400"))
	draw_string(_font, Vector2(left + 23, 119), "SUCATA SEM LICENÇA", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#D6C9A8"))
	draw_line(Vector2(left + 23, 136), Vector2(left + 325, 136), Color("#78665D"), 2)
	draw_string(_font, Vector2(left + 23, 171), "MONTE. RICOCHETEIE. EXPLODA.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#C5B8AB"))
	ArtDirector.panel(self, Rect2(left, 228, 350, 242))
	draw_string(_font, Vector2(left + 22, 266), "MANUAL DA GAMBIARRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#FFD400"))
	var lines := ["A / D   Mover e rebater", "MOUSE   Mirar para cima", "CLIQUE E / D   Disparar braços", "Q   Disparar cabeça", "ESPAÇO   Dash     E   Purga", "G   Garagem     F1   Diagnóstico"]
	for i in lines.size():
		draw_string(_font, Vector2(left + 22, 305 + i * 26), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#D6C9A8"))
	ArtDirector.panel(self, Rect2(left, vp.y - 237, 350, 221), Color("#8CFF1A"))
	draw_string(_font, Vector2(left + 22, vp.y - 198), "INTEGRIDADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#D6C9A8"))
	draw_string(_font, Vector2(left + 22, vp.y - 158), "%d / %d" % [robot.hp, robot.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#8CFF1A"))


func _draw_parts(vp: Vector2) -> void:
	var x := vp.x - 378.0
	ArtDirector.panel(self, Rect2(x, 26, 350, 132), Color("#22E0FF"))
	draw_string(_font, Vector2(x + 22, 65), "SUA GAMBIARRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#22E0FF"))
	var cpu_name: String = robot.cpu.display_name if robot.cpu else "CPU"
	draw_string(_font, Vector2(x + 22, 98), cpu_name, HORIZONTAL_ALIGNMENT_LEFT, 304, 16, Color("#F5F0E1"))
	draw_string(_font, Vector2(x + 22, 131), "%d / %d W%s" % [robot.watts_used, robot.total_tdp(), "  SUBVOLTAGEM" if robot.is_undervolt() else "  ESTÁVEL"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#FF2D95") if robot.is_undervolt() else Color("#8CFF1A"))
	var slots := [PartData.Slot.ARM_LEFT, PartData.Slot.ARM_RIGHT, PartData.Slot.HEAD, PartData.Slot.CHASSIS]
	var labels := ["BRAÇO E  /  CLIQUE E", "BRAÇO D  /  CLIQUE D", "CABEÇA  /  Q", "CHASSI  /  REBATEDOR"]
	for i in slots.size():
		var part: PartData = robot.equipped.get(slots[i])
		var r := Rect2(x, 180 + i * 110, 350, 98)
		ArtDirector.panel(self, r)
		if part == null: continue
		ArtDirector.part_icon(self, part, Rect2(r.position + Vector2(10, 9), Vector2(85, 80)))
		draw_string(_font, r.position + Vector2(107, 28), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#B6A299"))
		var name_text := part.display_name.split('"')[0].strip_edges()
		if name_text.length() > 24: name_text = name_text.left(22) + "…"
		draw_string(_font, r.position + Vector2(107, 52), name_text, HORIZONTAL_ALIGNMENT_LEFT, 228, 17, Color("#F5F0E1"))
		draw_string(_font, r.position + Vector2(107, 78), "TIER %s   %d W" % [part.fusion_roman(), part.watts], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, part.rarity_color())
		var jammed := robot.slot_jam_remaining(slots[i])
		if jammed > 0.0:
			draw_rect(Rect2(r.position + Vector2(100, 58), Vector2(235, 29)), Color("#382138"))
			draw_string(_font, r.position + Vector2(107, 78), "BLOQUEADO %.1f s" % jammed, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#FF2D95"))
	ArtDirector.panel(self, Rect2(x, vp.y - 170, 350, 152), Color("#FF6B1A"))
	var ratio := robot.heat_ratio()
	draw_string(_font, Vector2(x + 22, vp.y - 132), "CALOR   %.0f%%" % (ratio * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#FFD400"))
	draw_rect(Rect2(x + 22, vp.y - 113, 306, 12), Color("#130F16"))
	draw_rect(Rect2(x + 22, vp.y - 113, 306 * ratio, 12), Color("#FF2D95") if robot.overheated else Color("#FF6B1A"))
	draw_string(_font, Vector2(x + 22, vp.y - 70), "E  PURGA + PAREDE" if robot.purge_ready() else "E  RECARREGANDO %.1fs" % robot.purge_seconds_left(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#22E0FF"))
	draw_string(_font, Vector2(x + 22, vp.y - 40), "O que cai, você rebate.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#B6A299"))

func _draw_header(vp: Vector2) -> void:
	if director == null:
		return
	var left := vp.x * 0.5 - 260.0
	var text := "SETOR %d   ONDA %d/%d" % [director.sector, director.wave_index, WaveDirector.WAVES_PER_ROOM]
	draw_string(_font, Vector2(left, 42.0), text, HORIZONTAL_ALIGNMENT_CENTER, 520.0, 20, Color(1, 1, 1, 0.75))

	draw_string(_font, Vector2(left, 68.0),
		"%d DESMONTADOS   /   %d REBATIDAS" % [Telemetry.enemies_killed, Telemetry.paddle_catches],
		HORIZONTAL_ALIGNMENT_CENTER, 520.0, 15, Color("#8CFF1A"))

	var seed_text := "semente %s" % GameRng.seed_label(GameRng.run_seed)
	if MetaManager.run_is_daily:
		seed_text = "DESAFIO DE HOJE   " + seed_text
	draw_string(_font, Vector2(left, 90.0), seed_text, HORIZONTAL_ALIGNMENT_CENTER, 520.0, 12, Color(1, 1, 1, 0.4))


## Letreiro de onda especial. A onda de bumpers inverte o reflexo do genero, e
## sem um aviso o jogador so descobre a regra quando o enxame ja nasceu.
func _draw_wave_banner(vp: Vector2) -> void:
	if director == null or director.wave_banner_time <= 0.0:
		return
	var title := ""
	var sub := ""
	match director.wave_kind:
		&"bumpers":
			title = "ONDA DE BUMPERS"
			sub = "geladeira viva acelera seu tiro. geladeira morta vira enxame."
		&"boss":
			title = "CHEFE NO POÇO"
		_:
			return
	var a := clampf(director.wave_banner_time / 0.5, 0.0, 1.0)
	var y := vp.y * 0.30
	draw_string(_font, Vector2(3.0, y + 3.0), title, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 40, Color(0, 0, 0, 0.7 * a))
	draw_string(_font, Vector2(0.0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 40, Color("#FF2D95", a))
	if sub != "":
		draw_string(_font, Vector2(0.0, y + 34.0), sub, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 18, Color("#FFD400", a))


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
		# Tremor puramente visual: pode usar o fluxo de VFX sem afetar a run.
		jitter = Vector2(GameRng.randf_range_in(GameRng.Stream.VFX, -3.0, 3.0), GameRng.randf_range_in(GameRng.Stream.VFX, -3.0, 3.0))
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
