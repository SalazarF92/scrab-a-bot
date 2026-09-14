extends Node2D
const Rig = preload("res://art/rato_morto_puppet.gd")
var _tex: Texture2D
var _time := 0.0
var _mode := 3
var _paused := false
var _slow := false
var _exploded := false
var _capture := false
var _frames := 0
var _pose: Dictionary = {}
var _previous: Dictionary = {}
var _blend := 1.0
const LABELS := ["01  /  MOVIMENTO", "02  /  MORDIDA EM AVANÇO", "03  /  CURTO NO CABO"]
const NOTES := ["Patas alternadas • cabo e olhar", "Recuo • salto • mordida", "Cabo erguido • descarga elétrica"]
const ACCENTS := [Color("#7DE8EE"), Color("#B2D9FF"), Color("#66C9FF")]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_tex = load(Rig.ATLAS_PATH)
	_capture = "--capture-rato_morto" in OS.get_cmdline_user_args()
	_exploded = "--explode-rato_morto" in OS.get_cmdline_user_args()
	_pose = Rig.compute_pose(Rig.Action.WALK, 0)

func _process(delta: float) -> void:
	if not _paused:
		_time += delta * (.25 if _slow else 1.0)
		_blend = minf(1, _blend + delta / .25)
	if _mode != 3:
		var target := Rig.compute_pose(_mode as Rig.Action, _time)
		_pose = Rig.blend_pose(_previous, target, smoothstep(0, 1, _blend)) if _blend < 1 else target
	queue_redraw()
	if _capture:
		_frames += 1
		if _frames in [2, 4, 6]:
			await RenderingServer.frame_post_draw
			var path := "res://docs/visual/rato_morto_%d.png" % (_frames / 2)
			get_viewport().get_texture().get_image().save_png(path)
		if _frames >= 7:
			get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			_previous = _pose.duplicate()
			_mode = event.keycode - KEY_1
			_time = 0
			_blend = 0
		KEY_SPACE:
			_paused = not _paused
		KEY_S:
			_slow = not _slow
		KEY_E:
			_exploded = not _exploded
		KEY_R:
			_time = 0
		KEY_ESCAPE:
			get_tree().quit()

func _draw() -> void:
	var vp := get_viewport_rect().size
	var unit := minf(vp.x / 1280, vp.y / 720)
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#10171C"))
	for x in range(0, int(vp.x), int(40 * unit)):
		draw_line(Vector2(x, 110 * unit), Vector2(x, vp.y - 70 * unit), Color("#1A252C"))
	draw_string(font, Vector2(40, 40) * unit, "SCRAP-A-BOT   /   ESTÚDIO DE ANIMAÇÃO", HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * unit), Color("#8FA3AC"))
	draw_string(font, Vector2(40, 78) * unit, "RATO MORTO", HORIZONTAL_ALIGNMENT_LEFT, -1, int(32 * unit), Color("#E3F6FF"))
	draw_string(font, Vector2(vp.x - 370 * unit, 70 * unit), "PEÇAS RÍGIDAS • ESCALA FIXA", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * unit), Color("#7DE8EE"))
	if _mode == 3:
		for i in 3:
			var rect := Rect2(24 * unit + i * (vp.x - 48 * unit) / 3, 112 * unit, (vp.x - 48 * unit) / 3 - 12 * unit, vp.y - 200 * unit)
			var t := _time
			if _capture:
				t = [.25, .9, 1.65][mini(2, maxi(0, (_frames - 1) / 2))]
			_draw_card(rect, i, Rig.compute_pose(i as Rig.Action, t), unit)
	else:
		var rect := Rect2(24 * unit, 112 * unit, vp.x - 48 * unit, vp.y - 200 * unit)
		_draw_card(rect, _mode, _pose, unit)
	draw_string(font, Vector2(32 * unit, vp.y - 46 * unit), "[1] Movimento    [2] Golpe    [3] Poder    [4] Todos    [ESPAÇO] Pausar    [S] Câmera lenta    [E] Desmontar", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * unit), Color("#AFBEC4"))
	var status := "PAUSADO" if _paused else ("VELOCIDADE 25%" if _slow else "REPRODUZINDO")
	draw_string(font, Vector2(32 * unit, vp.y - 22 * unit), status, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * unit), Color("#7DE8EE"))

func _draw_card(rect: Rect2, action: int, pose: Dictionary, unit: float) -> void:
	var font := ThemeDB.fallback_font
	draw_style_box(_panel(), rect)
	draw_line(rect.position + Vector2(18, 0) * unit, rect.position + Vector2(90, 0) * unit, ACCENTS[action], 3 * unit)
	draw_string(font, rect.position + Vector2(20, 32) * unit, LABELS[action], HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * unit), ACCENTS[action])
	draw_string(font, rect.position + Vector2(20, 55) * unit, NOTES[action], HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * unit), Color("#9CAFB7"))
	var center := Vector2(rect.get_center().x, rect.position.y + 270 * unit)
	var sf := (.41 if _exploded else 1.0) * unit
	var floor_y := center.y + 170 * sf
	draw_set_transform(Vector2(center.x, floor_y), 0, Vector2(1, .17))
	draw_circle(Vector2.ZERO, 125 * sf, Color(0, 0, 0, .45))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_line(Vector2(rect.position.x + 22 * unit, floor_y + 3), Vector2(rect.end.x - 22 * unit, floor_y + 3), Color("#34424A"), 1)
	Rig.draw_puppet(self, _tex, center, sf, pose, Color.WHITE, 1.0 if _exploded else 0.0)
	var duration: float = [Rig.WALK_DURATION, Rig.ATTACK_DURATION, Rig.POWER_DURATION][action]
	var progress := fposmod(float(pose.time), duration) / duration
	draw_rect(Rect2(rect.position.x + 20 * unit, rect.end.y - 14 * unit, rect.size.x - 40 * unit, 2 * unit), Color("#34424A"))
	draw_rect(Rect2(rect.position.x + 20 * unit, rect.end.y - 14 * unit, (rect.size.x - 40 * unit) * progress, 2 * unit), ACCENTS[action])

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#182229")
	style.border_color = Color("#2B3A42")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
