extends Node2D
## Visualizador interativo de animação da Mini-Prensa 500 (Boss do Setor 1).
## Motor completo de interpolação física: Squash & Stretch volumétrico,
## transição suave (cross-fade) entre sub-frames, antecipação e impacto,
## além de interpolação harmônica entre estados e partículas procedurais.

enum Mode { WALK, ATTACK, POWER, GRID }
var mode: Mode = Mode.WALK

var _timer: float = 0.0
var _shake: float = 0.0
var auto_loop: bool = true
var _state_timer: float = 0.0
const STATE_DURATION := 3.4

# Variáveis contínuas de interpolação da pose atual:
var _pose_offset: Vector2 = Vector2.ZERO
var _pose_rotation: float = 0.0
var _pose_scale: Vector2 = Vector2.ONE
var _frame_a: Rect2
var _frame_b: Rect2
var _frame_blend: float = 0.0

# Interpolação de transição suave entre modos (state blending):
var _prev_pose_offset: Vector2 = Vector2.ZERO
var _prev_pose_rotation: float = 0.0
var _prev_pose_scale: Vector2 = Vector2.ONE
var _prev_frame: Rect2
var _trans_t: float = 1.0 # 1.0 = transição concluída

# Partículas procedurais determinísticas:
var _dust_puffs: Array[Dictionary] = []
var _shockwaves: Array[Dictionary] = []
var _steam_puffs: Array[Dictionary] = []
var _last_footstep := -1

const FRAMES_WALK := [
	Rect2(21, 27, 306, 314),
	Rect2(370, 26, 312, 291),
	Rect2(682, 36, 307, 286),
]
const FRAMES_ATTACK := [
	Rect2(41, 341, 292, 331),
	Rect2(356, 353, 307, 314),
	Rect2(683, 393, 334, 282),
]
const FRAMES_POWER := [
	Rect2(39, 705, 302, 315),
	Rect2(341, 682, 341, 338),
	Rect2(682, 696, 318, 324),
]

var _tex: Texture2D


func _ready() -> void:
	_tex = load("res://assets/art/mini_prensa_animated.png")
	_frame_a = FRAMES_WALK[0]
	_frame_b = FRAMES_WALK[1]


func _change_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	_prev_pose_offset = _pose_offset
	_prev_pose_rotation = _pose_rotation
	_prev_pose_scale = _pose_scale
	_prev_frame = _frame_b if _frame_blend > 0.5 else _frame_a
	_trans_t = 0.0
	mode = new_mode
	_timer = 0.0
	_state_timer = 0.0


func _process(delta: float) -> void:
	_timer += delta
	_shake = maxf(0.0, _shake - delta * 4.0)

	if _trans_t < 1.0:
		_trans_t = minf(1.0, _trans_t + delta / 0.35)

	_update_particles(delta)

	if auto_loop and mode != Mode.GRID:
		_state_timer += delta
		if _state_timer >= STATE_DURATION:
			match mode:
				Mode.WALK:
					_change_mode(Mode.ATTACK)
				Mode.ATTACK:
					_change_mode(Mode.POWER)
				Mode.POWER:
					_change_mode(Mode.WALK)

	match mode:
		Mode.WALK:
			_compute_walk_interpolation()
		Mode.ATTACK:
			_compute_attack_interpolation()
		Mode.POWER:
			_compute_power_interpolation()
		Mode.GRID:
			_pose_offset = Vector2.ZERO
			_pose_rotation = 0.0
			_pose_scale = Vector2.ONE
			_frame_a = FRAMES_WALK[0]
			_frame_b = FRAMES_WALK[0]
			_frame_blend = 0.0

	queue_redraw()


func _compute_walk_interpolation() -> void:
	var cycle_len := 0.70
	var phase := fmod(_timer, cycle_len) / cycle_len

	var step_pulse := sin(phase * TAU * 2.0)
	var vert_bob := -step_pulse * 14.0
	var sway := sin(phase * TAU) * 14.0
	var tilt := -sin(phase * TAU) * 0.05

	var squash_y := 1.0 + step_pulse * 0.08
	var squash_x := 2.0 - squash_y

	_pose_offset = Vector2(sway, vert_bob)
	_pose_rotation = tilt
	_pose_scale = Vector2(squash_x, squash_y)

	var p3 := phase * 3.0
	var seg := int(p3)
	var local_t := p3 - float(seg)
	local_t = smoothstep(0.12, 0.88, local_t)

	match seg:
		0:
			_frame_a = FRAMES_WALK[0]
			_frame_b = FRAMES_WALK[1]
			_frame_blend = local_t
		1:
			_frame_a = FRAMES_WALK[1]
			_frame_b = FRAMES_WALK[2]
			_frame_blend = local_t
		_:
			_frame_a = FRAMES_WALK[2]
			_frame_b = FRAMES_WALK[0]
			_frame_blend = local_t

	var current_step := 0 if phase < 0.5 else 1
	if current_step != _last_footstep:
		_last_footstep = current_step
		Sfx.play("dash", -16.0)
		var foot_x := -90.0 if current_step == 0 else 90.0
		_spawn_dust(Vector2(foot_x, 175.0))


func _compute_attack_interpolation() -> void:
	var cycle_len := 1.70
	var cycle := fmod(_timer, cycle_len)

	if cycle < 0.65:
		var p := cycle / 0.65
		var ease_p := smoothstep(0.0, 1.0, p)
		var lift := -45.0 * ease_p
		var tilt_back := -0.10 * ease_p
		var s_y := 1.0 + 0.18 * ease_p
		var s_x := 1.0 - 0.10 * ease_p
		var jitter := sin(_timer * 55.0) * 1.8 * ease_p
		_pose_offset = Vector2(jitter, lift)
		_pose_rotation = tilt_back
		_pose_scale = Vector2(s_x, s_y)

		_frame_a = FRAMES_ATTACK[0]
		_frame_b = FRAMES_ATTACK[1]
		_frame_blend = ease_p

	elif cycle < 0.85:
		var p := (cycle - 0.65) / 0.20
		var cubic_p := p * p * p
		var drop := -45.0 + 95.0 * cubic_p
		var tilt := lerpf(-0.10, 0.04, p)
		var s_y := lerpf(1.18, 0.70, p)
		var s_x := lerpf(0.90, 1.30, p)
		_pose_offset = Vector2(0.0, drop)
		_pose_rotation = tilt
		_pose_scale = Vector2(s_x, s_y)

		_frame_a = FRAMES_ATTACK[1]
		_frame_b = FRAMES_ATTACK[2]
		_frame_blend = p

		if p >= 0.85 and _shake < 5.0:
			_shake = 16.0
			Sfx.play("fire_heavy", 2.0)
			_spawn_shockwave(Vector2(0, 175.0))

	elif cycle < 1.30:
		var p := (cycle - 0.85) / 0.45
		var spring := exp(-6.0 * p) * cos(16.0 * p)
		var s_y := 1.0 - 0.35 * spring
		var s_x := 1.0 + 0.35 * spring
		var drop := 50.0 * exp(-7.0 * p) * cos(12.0 * p)

		_pose_offset = Vector2(0.0, drop)
		_pose_rotation = 0.02 * spring
		_pose_scale = Vector2(s_x, s_y)

		_frame_a = FRAMES_ATTACK[2]
		_frame_b = FRAMES_ATTACK[2]
		_frame_blend = 0.0

	else:
		var p := (cycle - 1.30) / 0.40
		var ease_p := smoothstep(0.0, 1.0, p)
		_pose_offset = Vector2.ZERO
		_pose_rotation = 0.0
		_pose_scale = Vector2.ONE
		_frame_a = FRAMES_ATTACK[2]
		_frame_b = FRAMES_ATTACK[0]
		_frame_blend = ease_p


func _compute_power_interpolation() -> void:
	if _timer < 0.60:
		var p := _timer / 0.60
		var ease_p := smoothstep(0.0, 1.0, p)
		var swell := 1.0 + 0.09 * ease_p
		var shudder := sin(_timer * 45.0) * 2.2 * ease_p
		_pose_offset = Vector2(shudder, -12.0 * ease_p)
		_pose_rotation = sin(_timer * 35.0) * 0.02 * ease_p
		_pose_scale = Vector2(swell, swell)

		_frame_a = FRAMES_POWER[0]
		_frame_b = FRAMES_POWER[1]
		_frame_blend = ease_p

	elif _timer < 2.50:
		var t_active := _timer - 0.60
		var pulse := sin(t_active * 8.0) * 0.06
		var float_bob := -14.0 + cos(t_active * 6.0) * 5.0
		_pose_offset = Vector2(sin(t_active * 25.0) * 1.2, float_bob)
		_pose_rotation = sin(t_active * 4.0) * 0.025
		_pose_scale = Vector2(1.09 + pulse, 1.09 - pulse)

		_frame_a = FRAMES_POWER[1]
		_frame_b = FRAMES_POWER[1]
		_frame_blend = 0.0

		if fmod(t_active, 0.12) < 0.025:
			_spawn_steam()

	else:
		var p := (_timer - 2.50) / 0.90
		var ease_p := smoothstep(0.0, 1.0, p)
		var swell := lerpf(1.09, 1.0, ease_p)
		var lift := lerpf(-14.0, 0.0, ease_p)
		_pose_offset = Vector2(0.0, lift)
		_pose_rotation = 0.0
		_pose_scale = Vector2(swell, swell)

		_frame_a = FRAMES_POWER[1]
		_frame_b = FRAMES_POWER[2]
		_frame_blend = ease_p


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_1:
			_change_mode(Mode.WALK)
			auto_loop = false
		KEY_2:
			_change_mode(Mode.ATTACK)
			auto_loop = false
		KEY_3:
			_change_mode(Mode.POWER)
			auto_loop = false
		KEY_4:
			mode = Mode.GRID
			auto_loop = false
		KEY_SPACE:
			auto_loop = not auto_loop
			_state_timer = 0.0
		KEY_ESCAPE:
			get_tree().quit(0)


func _update_particles(delta: float) -> void:
	var k := 0
	while k < _dust_puffs.size():
		var p: Dictionary = _dust_puffs[k]
		p["life"] = float(p["life"]) - delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		if float(p["life"]) <= 0.0:
			_dust_puffs.remove_at(k)
		else:
			k += 1

	k = 0
	while k < _shockwaves.size():
		var sw: Dictionary = _shockwaves[k]
		sw["life"] = float(sw["life"]) - delta
		sw["radius"] = float(sw["radius"]) + delta * 240.0
		if float(sw["life"]) <= 0.0:
			_shockwaves.remove_at(k)
		else:
			k += 1

	k = 0
	while k < _steam_puffs.size():
		var st: Dictionary = _steam_puffs[k]
		st["life"] = float(st["life"]) - delta
		st["pos"] = (st["pos"] as Vector2) + (st["vel"] as Vector2) * delta
		st["size"] = float(st["size"]) + delta * 45.0
		if float(st["life"]) <= 0.0:
			_steam_puffs.remove_at(k)
		else:
			k += 1


func _spawn_dust(pos: Vector2) -> void:
	for i in 4:
		var sign_dir := -1.0 if pos.x < 0 else 1.0
		var vel := Vector2(sign_dir * (35.0 + float(i) * 22.0), -12.0 - float(i) * 6.0)
		_dust_puffs.append({"pos": pos, "vel": vel, "life": 0.40, "max_life": 0.40, "size": 12.0 + float(i) * 5.0})


func _spawn_shockwave(pos: Vector2) -> void:
	_shockwaves.append({"pos": pos, "radius": 20.0, "life": 0.45, "max_life": 0.45})
	_shockwaves.append({"pos": pos, "radius": 5.0, "life": 0.35, "max_life": 0.35})


func _spawn_steam() -> void:
	var nozzles: Array[Vector2] = [Vector2(-125, -55), Vector2(125, -55), Vector2(-135, 45), Vector2(135, 45)]
	for n: Vector2 in nozzles:
		var vel: Vector2 = n.normalized() * 110.0 + Vector2(0, -45.0)
		_steam_puffs.append({"pos": n, "vel": vel, "life": 0.50, "max_life": 0.50, "size": 16.0})


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := get_viewport_rect().size

	draw_rect(Rect2(Vector2.ZERO, vp), Color("#131015"))
	for y in range(40, int(vp.y), 60):
		draw_line(Vector2(0, y), Vector2(vp.x, y), Color("#241D26", 0.35), 1.0)
	for x in range(40, int(vp.x), 80):
		draw_line(Vector2(x, 0), Vector2(x, vp.y), Color("#241D26", 0.35), 1.0)

	draw_string(font, Vector2(0, 48), "SCRAP-A-BOT :: SHOWCASE DE ANIMAÇÃO INTERPOLADA (MINI-PRENSA 500)",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 23, Color("#FFD400"))
	var help := "[1] ANDAR    [2] ATAQUE    [3] PODER    [4] GRADE COMPLETA    [ESPAÇO] PAUSAR LOOP    [ESC] SAIR"
	draw_string(font, Vector2(0, 80), help, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 14, Color("#8CFF1A"))

	if _tex == null:
		draw_string(font, Vector2(0, 300), "ERRO: Textura não carregada", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 20, Color.RED)
		return

	if mode == Mode.GRID:
		_draw_grid(font, vp)
		return

	var final_offset := _pose_offset
	var final_rot := _pose_rotation
	var final_scale := _pose_scale

	if _trans_t < 1.0:
		var ease_t := smoothstep(0.0, 1.0, _trans_t)
		final_offset = _prev_pose_offset.lerp(_pose_offset, ease_t)
		final_rot = lerp_angle(_prev_pose_rotation, _pose_rotation, ease_t)
		final_scale = _prev_pose_scale.lerp(_pose_scale, ease_t)

	var shake_offset := Vector2(sin(_timer * 40.0) * _shake, cos(_timer * 47.0) * _shake)
	var center := vp * 0.5 + Vector2(0, 25) + shake_offset

	# Sombra adaptativa projetada no chão:
	var shadow_y := 175.0
	var shadow_elev := -final_offset.y
	var shadow_scale := clampf(1.0 - shadow_elev / 240.0, 0.4, 1.3) * final_scale.x
	_draw_ellipse(center + Vector2(final_offset.x * 0.4, shadow_y), Vector2(170 * shadow_scale, 28 * shadow_scale), Color(0, 0, 0, 0.45 * shadow_scale))

	# Partículas de poeira e shockwaves sob o personagem:
	_draw_floor_particles(center)

	# Transformação 2D com interpolação contínua (sub-pixel, rotação e escala elástica):
	var xform := Transform2D(final_rot, final_scale, 0.0, center + final_offset)
	draw_set_transform_matrix(xform)

	var sprite_rect := Rect2(-180, -180, 360, 360)
	var tint := Color.WHITE

	if _trans_t < 1.0:
		var ease_t := smoothstep(0.0, 1.0, _trans_t)
		var col_prev := Color(1, 1, 1, 1.0 - ease_t)
		var col_curr := Color(1, 1, 1, ease_t)
		draw_texture_rect_region(_tex, sprite_rect, _prev_frame, col_prev)
		draw_texture_rect_region(_tex, sprite_rect, _frame_a, col_curr)
	else:
		if _frame_blend <= 0.01:
			draw_texture_rect_region(_tex, sprite_rect, _frame_a, tint)
		elif _frame_blend >= 0.99:
			draw_texture_rect_region(_tex, sprite_rect, _frame_b, tint)
		else:
			var col_a := Color(1, 1, 1, 1.0 - _frame_blend)
			var col_b := Color(1, 1, 1, _frame_blend)
			draw_texture_rect_region(_tex, sprite_rect, _frame_a, col_a)
			draw_texture_rect_region(_tex, sprite_rect, _frame_b, col_b)

	draw_set_transform_matrix(Transform2D.IDENTITY)

	# Partículas sobrepostas (jatos de vapor das válvulas):
	_draw_steam_particles(center + final_offset)

	# Textos informativos de modo e física:
	var mode_label := ""
	var mode_desc := ""
	var badge_color := Color("#FFD400")
	match mode:
		Mode.WALK:
			mode_label = "ESTADO 1: ANDAR (Interpolação de Passada & Balanço Lateral)"
			mode_desc = "Offset: (%.1f, %.1f) | Ângulo: %.2f rad | Escala: (%.2f, %.2f) — Squash elétrico no passo" % [_pose_offset.x, _pose_offset.y, _pose_rotation, _pose_scale.x, _pose_scale.y]
			badge_color = Color("#8CFF1A")
		Mode.ATTACK:
			mode_label = "ESTADO 2: ATAQUE (Antecipação, Descarga Acelerada & Impacto com Mola)"
			mode_desc = "Offset: (%.1f, %.1f) | Ângulo: %.2f rad | Escala: (%.2f, %.2f) — Rebote harmônico amortecido" % [_pose_offset.x, _pose_offset.y, _pose_rotation, _pose_scale.x, _pose_scale.y]
			badge_color = Color("#FF2D95")
		Mode.POWER:
			mode_label = "ESTADO 3: PODER (Superaquecimento, Jatos de Vapor & Pulso Térmico)"
			mode_desc = "Offset: (%.1f, %.1f) | Pulsação: %.2f — Válvulas laterais e fornalha interna em fusão" % [_pose_offset.x, _pose_offset.y, _pose_scale.x]
			badge_color = Color("#FF6B1A")

	draw_string(font, Vector2(0, vp.y - 125), mode_label, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 19, badge_color)
	draw_string(font, Vector2(0, vp.y - 95), mode_desc, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 14, Color("#F5F0E1"))

	# Barra de progresso do loop automático:
	if auto_loop:
		var bar_w := 420.0
		var bar_h := 8.0
		var bar_x := (vp.x - bar_w) * 0.5
		var bar_y := vp.y - 55.0
		var next_label := "Próximo: ATAQUE" if mode == Mode.WALK else ("Próximo: PODER" if mode == Mode.ATTACK else "Próximo: ANDAR")
		var progress := clampf(_state_timer / STATE_DURATION, 0.0, 1.0)
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color("#1C1622"))
		draw_rect(Rect2(bar_x, bar_y, bar_w * progress, bar_h), badge_color)
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(1, 1, 1, 0.3), false, 1.0)
		draw_string(font, Vector2(0, bar_y - 8), "LOOP ATIVO — " + next_label, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 12, Color(1, 1, 1, 0.65))
	else:
		draw_string(font, Vector2(0, vp.y - 50), "[LOOP PAUSADO - MODO TRAVADO - PRESSIONE ESPAÇO PARA REATIVAR]", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 13, Color("#FFD400"))


func _draw_ellipse(pos: Vector2, radii: Vector2, color: Color) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0:
		return
	draw_set_transform(pos, 0.0, Vector2(1.0, radii.y / radii.x))
	draw_circle(Vector2.ZERO, radii.x, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_floor_particles(center: Vector2) -> void:
	for p in _dust_puffs:
		var alpha: float = float(p["life"]) / float(p["max_life"])
		var col := Color(0.7, 0.65, 0.6, alpha * 0.45)
		draw_circle(center + (p["pos"] as Vector2), float(p["size"]) * (2.0 - alpha), col)

	for sw in _shockwaves:
		var alpha: float = float(sw["life"]) / float(sw["max_life"])
		var col := Color(1.0, 0.65, 0.2, alpha * 0.7)
		var rad: float = float(sw["radius"])
		draw_set_transform(center + (sw["pos"] as Vector2), 0.0, Vector2(1.0, 0.35))
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 32, col, 4.0 * alpha)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_steam_particles(center: Vector2) -> void:
	for st in _steam_puffs:
		var alpha: float = float(st["life"]) / float(st["max_life"])
		var col := Color(1.0, 0.9, 0.8, alpha * 0.4)
		draw_circle(center + (st["pos"] as Vector2), float(st["size"]), col)


func _draw_grid(font: Font, vp: Vector2) -> void:
	var rows := [
		{"name": "ANDAR", "frames": FRAMES_WALK, "color": Color("#8CFF1A")},
		{"name": "ATAQUE", "frames": FRAMES_ATTACK, "color": Color("#FF2D95")},
		{"name": "PODER", "frames": FRAMES_POWER, "color": Color("#FF6B1A")},
	]
	var cell_size := Vector2(240, 240)
	var start_y := 120.0
	for r in 3:
		var row_info: Dictionary = rows[r]
		var y: float = start_y + float(r) * 280.0
		draw_string(font, Vector2(80, y + 120), row_info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, row_info["color"])
		for c in 3:
			var x := 260.0 + float(c) * 380.0
			var rect := Rect2(Vector2(x, y), cell_size)
			draw_rect(rect.grow(4), Color("#2A2230"), false, 2.0)
			draw_texture_rect_region(_tex, rect, row_info["frames"][c])
			draw_string(font, Vector2(x, y + 255), "Frame %d" % [c + 1], HORIZONTAL_ALIGNMENT_CENTER, cell_size.x, 13, Color(1, 1, 1, 0.6))
