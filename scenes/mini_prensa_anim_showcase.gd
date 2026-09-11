extends Node2D
## Visualizador interativo de animação modular da Mini-Prensa 500 (Boss do Setor 1).
## Implementa o padrão de animação modular rígida em 10 passos:
## - Peças rígidas 2D separadas sem deformação elástica de metal sólido
## - Linha do tempo absoluta contínua (playhead)
## - Transformadas rígidas com Transform2D em torno de pivôs físicos (dobradiça traseira)
## - Cinemática telescópica dos pistões hidráulicos
## - Núcleo de fornalha e engrenagem interna revelados na abertura da mandíbula
## - Sem cross-fades borrados de transparência

const MiniPrensaPuppet = preload("res://art/mini_prensa_puppet.gd")

enum Mode { WALK, ATTACK, POWER, GRID }
var mode: Mode = Mode.WALK

var _playhead: float = 0.0
var _shake: float = 0.0
var auto_loop: bool = true
var _state_timer: float = 0.0
const STATE_DURATION := 3.5

# Transição suave entre poses ao trocar de modo:
var _current_pose: Dictionary = {}
var _prev_pose: Dictionary = {}
var _transition_t: float = 1.0 # 1.0 = transição completa

# Partículas procedurais determinísticas:
var _dust_puffs: Array[Dictionary] = []
var _shockwaves: Array[Dictionary] = []
var _steam_puffs: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []

var _last_footstep: int = -1
var _last_impact_cycle: int = -1

var _tex: Texture2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_tex = load(MiniPrensaPuppet.ATLAS_PATH)
	_current_pose = MiniPrensaPuppet.compute_pose(MiniPrensaPuppet.Action.WALK, 0.0)
	_prev_pose = _current_pose.duplicate()


func _change_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	_prev_pose = _current_pose.duplicate()
	_transition_t = 0.0
	mode = new_mode
	_playhead = 0.0
	_state_timer = 0.0
	_last_footstep = -1
	_last_impact_cycle = -1


func _process(delta: float) -> void:
	_playhead += delta
	_shake = maxf(0.0, _shake - delta * 5.0)

	if _transition_t < 1.0:
		_transition_t = minf(1.0, _transition_t + delta / 0.25)

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

	# Calcula pose alvo para o modo ativo:
	var target_pose: Dictionary
	match mode:
		Mode.WALK:
			target_pose = MiniPrensaPuppet.compute_pose(MiniPrensaPuppet.Action.WALK, _playhead)
			var step: int = int(target_pose.get("footstep", -1))
			if step != -1 and step != _last_footstep:
				_last_footstep = step
				Sfx.play("dash", -14.0)
				var foot_x := -115.0 if step == 0 else 115.0
				_spawn_dust(Vector2(foot_x, 185.0))

		Mode.ATTACK:
			target_pose = MiniPrensaPuppet.compute_pose(MiniPrensaPuppet.Action.ATTACK, _playhead)
			var cycle_idx := int(_playhead / MiniPrensaPuppet.ATTACK_DURATION)
			if bool(target_pose.get("impact_event", false)) and cycle_idx != _last_impact_cycle:
				_last_impact_cycle = cycle_idx
				_shake = float(target_pose.get("shake_request", 18.0))
				Sfx.play("fire_heavy", 3.0)
				_spawn_impact_fx(Vector2(0, 185.0))

		Mode.POWER:
			target_pose = MiniPrensaPuppet.compute_pose(MiniPrensaPuppet.Action.POWER, _playhead)
			var steam_int: float = float(target_pose.get("steam_intensity", 0.0))
			if steam_int > 0.1 and fmod(_playhead, 0.08) < 0.03:
				_spawn_steam(steam_int)
				if fmod(_playhead, 0.4) < 0.05:
					Sfx.play("dash", -18.0)

		Mode.GRID:
			target_pose = MiniPrensaPuppet.compute_pose(MiniPrensaPuppet.Action.IDLE, 0.0)

	# Interpolação suave entre poses se estiver em transição de modo:
	if _transition_t < 1.0:
		var ease_t := smoothstep(0.0, 1.0, _transition_t)
		_current_pose = _lerp_pose(_prev_pose, target_pose, ease_t)
	else:
		_current_pose = target_pose

	queue_redraw()


func _lerp_pose(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var res := b.duplicate()
	res["body_offset"] = (a.get("body_offset", Vector2.ZERO) as Vector2).lerp(b.get("body_offset", Vector2.ZERO) as Vector2, t)
	res["body_tilt"] = lerp_angle(float(a.get("body_tilt", 0.0)), float(b.get("body_tilt", 0.0)), t)
	res["head_angle"] = lerp_angle(float(a.get("head_angle", 0.0)), float(b.get("head_angle", 0.0)), t)
	res["head_extra_offset"] = (a.get("head_extra_offset", Vector2.ZERO) as Vector2).lerp(b.get("head_extra_offset", Vector2.ZERO) as Vector2, t)
	res["foot_l_offset"] = (a.get("foot_l_offset", Vector2.ZERO) as Vector2).lerp(b.get("foot_l_offset", Vector2.ZERO) as Vector2, t)
	res["foot_r_offset"] = (a.get("foot_r_offset", Vector2.ZERO) as Vector2).lerp(b.get("foot_r_offset", Vector2.ZERO) as Vector2, t)
	res["foot_l_rot"] = lerp_angle(float(a.get("foot_l_rot", 0.0)), float(b.get("foot_l_rot", 0.0)), t)
	res["foot_r_rot"] = lerp_angle(float(a.get("foot_r_rot", 0.0)), float(b.get("foot_r_rot", 0.0)), t)
	res["core_glow"] = lerpf(float(a.get("core_glow", 0.0)), float(b.get("core_glow", 0.0)), t)
	res["gear_rot"] = lerpf(float(a.get("gear_rot", 0.0)), float(b.get("gear_rot", 0.0)), t)
	res["chimney_offset"] = (a.get("chimney_offset", Vector2.ZERO) as Vector2).lerp(b.get("chimney_offset", Vector2.ZERO) as Vector2, t)
	return res


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
		sw["radius"] = float(sw["radius"]) + delta * 320.0
		if float(sw["life"]) <= 0.0:
			_shockwaves.remove_at(k)
		else:
			k += 1

	k = 0
	while k < _steam_puffs.size():
		var st: Dictionary = _steam_puffs[k]
		st["life"] = float(st["life"]) - delta
		st["pos"] = (st["pos"] as Vector2) + (st["vel"] as Vector2) * delta
		st["size"] = float(st["size"]) + delta * 55.0
		if float(st["life"]) <= 0.0:
			_steam_puffs.remove_at(k)
		else:
			k += 1

	k = 0
	while k < _sparks.size():
		var sp: Dictionary = _sparks[k]
		sp["life"] = float(sp["life"]) - delta
		sp["pos"] = (sp["pos"] as Vector2) + (sp["vel"] as Vector2) * delta
		sp["vel"] = (sp["vel"] as Vector2) + Vector2(0, 480.0) * delta # Gravidade
		if float(sp["life"]) <= 0.0:
			_sparks.remove_at(k)
		else:
			k += 1


func _spawn_dust(pos: Vector2) -> void:
	for i in 5:
		var sign_dir := -1.0 if pos.x < 0 else 1.0
		var vel := Vector2(sign_dir * (40.0 + float(i) * 25.0), -15.0 - float(i) * 8.0)
		_dust_puffs.append({"pos": pos, "vel": vel, "life": 0.45, "max_life": 0.45, "size": 14.0 + float(i) * 6.0})


func _spawn_impact_fx(pos: Vector2) -> void:
	_shockwaves.append({"pos": pos, "radius": 25.0, "life": 0.45, "max_life": 0.45})
	_shockwaves.append({"pos": pos, "radius": 8.0, "life": 0.35, "max_life": 0.35})
	for i in 8:
		var angle := float(i) * (TAU / 8.0)
		var vel := Vector2(cos(angle) * 140.0, sin(angle) * 35.0 - 15.0)
		_dust_puffs.append({"pos": pos, "vel": vel, "life": 0.50, "max_life": 0.50, "size": 18.0})
	# Faíscas metálicas de estilhaçamento:
	for i in 12:
		var angle := _rng.randf_range(-PI * 0.9, -PI * 0.1)
		var spd := _rng.randf_range(160.0, 320.0)
		_sparks.append({"pos": pos + Vector2(_rng.randf_range(-60, 60), -20), "vel": Vector2(cos(angle) * spd, sin(angle) * spd), "life": 0.35, "max_life": 0.35})


func _spawn_steam(intensity: float) -> void:
	# Válvulas laterais e chaminé superior:
	var emitters: Array[Vector2] = [
		Vector2(-130, -50), Vector2(120, -50), # Bicos laterais da fornalha
		Vector2(-140, 40), Vector2(130, 40),   # Respiros inferiores dos pistões
		Vector2(0, -180),                       # Chaminé superior
	]
	for e in emitters:
		var dir := (e - Vector2(0, -20)).normalized()
		if e.y < -150: dir = Vector2(_rng.randf_range(-0.3, 0.3), -1.0).normalized()
		var vel: Vector2 = dir * (120.0 * intensity + _rng.randf_range(20.0, 60.0))
		_steam_puffs.append({"pos": e, "vel": vel, "life": 0.45, "max_life": 0.45, "size": 15.0 * intensity})


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := get_viewport_rect().size

	# Fundo industrial escuro com grelha metálica:
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#120F16"))
	for y in range(40, int(vp.y), 60):
		draw_line(Vector2(0, y), Vector2(vp.x, y), Color("#261E2C", 0.35), 1.0)
	for x in range(40, int(vp.x), 80):
		draw_line(Vector2(x, 0), Vector2(x, vp.y), Color("#261E2C", 0.35), 1.0)

	draw_string(font, Vector2(0, 45), "SCRAP-A-BOT :: RIG MECÂNICO ARTICULADO (MINI-PRENSA 500)",
		HORIZONTAL_ALIGNMENT_CENTER, vp.x, 23, Color("#FFD400"))
	var help := "[1] ANDAR    [2] ATAQUE (PRENSAGEM)    [3] PODER (SUPER-VAPOR)    [4] ATLAS DAS PEÇAS & RIG    [ESPAÇO] PAUSAR LOOP    [ESC] SAIR"
	draw_string(font, Vector2(0, 75), help, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 14, Color("#8CFF1A"))

	if _tex == null:
		draw_string(font, Vector2(0, 300), "ERRO: Atlas de peças 'mini_prensa_pieces.png' não encontrado", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 20, Color.RED)
		return

	if mode == Mode.GRID:
		_draw_grid(font, vp)
		return

	var shake_offset := Vector2(sin(_playhead * 45.0) * _shake, cos(_playhead * 50.0) * _shake)
	var center := vp * 0.5 + Vector2(0, 20) + shake_offset

	# Sombra adaptativa projetada no chão sob a prensa:
	var shadow_y := 185.0
	var body_offset_y: float = (_current_pose.get("body_offset", Vector2.ZERO) as Vector2).y
	var shadow_elev := -body_offset_y
	var shadow_scale := clampf(1.0 - shadow_elev / 250.0, 0.4, 1.3)
	_draw_ellipse(center + Vector2(0, shadow_y), Vector2(175 * shadow_scale, 28 * shadow_scale), Color(0, 0, 0, 0.45 * shadow_scale))

	# Partículas de chão (poeira dos passos e shockwaves de impacto):
	_draw_floor_particles(center)

	# Renderização do Puppet mecânico modular com peças rígidas:
	MiniPrensaPuppet.draw_puppet(self, _tex, center, 1.25, _current_pose)

	# Partículas sobrepostas (jatos de vapor das válvulas e chaminé, faíscas):
	_draw_steam_particles(center + (_current_pose.get("body_offset", Vector2.ZERO) as Vector2))
	_draw_sparks(center)

	# Painel HUD de Telemetria Mecânica:
	_draw_hud(font, vp)


func _draw_ellipse(pos: Vector2, radii: Vector2, color: Color) -> void:
	if radii.x <= 0.0 or radii.y <= 0.0:
		return
	draw_set_transform(pos, 0.0, Vector2(1.0, radii.y / radii.x))
	draw_circle(Vector2.ZERO, radii.x, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_floor_particles(center: Vector2) -> void:
	for p in _dust_puffs:
		var alpha: float = float(p["life"]) / float(p["max_life"])
		var col := Color(0.72, 0.65, 0.58, alpha * 0.5)
		draw_circle(center + (p["pos"] as Vector2), float(p["size"]) * (2.0 - alpha), col)

	for sw in _shockwaves:
		var alpha: float = float(sw["life"]) / float(sw["max_life"])
		var col := Color(1.0, 0.7, 0.2, alpha * 0.75)
		var rad: float = float(sw["radius"])
		draw_set_transform(center + (sw["pos"] as Vector2), 0.0, Vector2(1.0, 0.35))
		draw_arc(Vector2.ZERO, rad, 0.0, TAU, 32, col, 4.0 * alpha)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_steam_particles(center: Vector2) -> void:
	for st in _steam_puffs:
		var alpha: float = float(st["life"]) / float(st["max_life"])
		var col := Color(1.0, 0.92, 0.85, alpha * 0.45)
		draw_circle(center + (st["pos"] as Vector2), float(st["size"]), col)


func _draw_sparks(center: Vector2) -> void:
	for sp in _sparks:
		var alpha: float = float(sp["life"]) / float(sp["max_life"])
		var col := Color(1.0, 0.9, 0.3, alpha)
		var p: Vector2 = center + (sp["pos"] as Vector2)
		var v: Vector2 = (sp["vel"] as Vector2).normalized() * 6.0
		draw_line(p, p + v, col, 2.0)


func _draw_hud(font: Font, vp: Vector2) -> void:
	var mode_label := ""
	var mode_desc := ""
	var badge_color := Color("#FFD400")

	var jaw_angle_deg := rad_to_deg(float(_current_pose.get("head_angle", 0.0)))
	var body_off: Vector2 = _current_pose.get("body_offset", Vector2.ZERO)
	var gear_rpm := int(float(_current_pose.get("gear_rot", 0.0)) * 9.55)
	var core_glow := float(_current_pose.get("core_glow", 0.0))

	match mode:
		Mode.WALK:
			mode_label = "MODO 1: ANDAR (Cinemática de Passadas Rígidas & Balanço de Carga)"
			mode_desc = "Mandíbula: %.1f° | Offset Chassi: (%.1f, %.1f) px | Passada Alternada: %.2fs" % [jaw_angle_deg, body_off.x, body_off.y, MiniPrensaPuppet.WALK_DURATION]
			badge_color = Color("#8CFF1A")
		Mode.ATTACK:
			mode_label = "MODO 2: ATAQUE (Carimbo Hidráulico com Golpe Violento & Rebote Elástico)"
			mode_desc = "Abertura: %.1f° | Tremor: %.1f | Dentes Superiores e Pistões Rígidos em Ação" % [jaw_angle_deg, _shake]
			badge_color = Color("#FF2D95")
		Mode.POWER:
			mode_label = "MODO 3: PODER (Superaquecimento da Fornalha & Erupção Contínua de Vapor)"
			mode_desc = "Caldeira: %d RPM | Brilho do Núcleo: %.0f%% | Jatos de Vapor Ativos" % [gear_rpm, core_glow * 100.0]
			badge_color = Color("#FF6B1A")

	draw_string(font, Vector2(0, vp.y - 120), mode_label, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 19, badge_color)
	draw_string(font, Vector2(0, vp.y - 92), mode_desc, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 14, Color("#F5F0E1"))

	# Barra de progresso do loop automático:
	if auto_loop:
		var bar_w := 440.0
		var bar_h := 8.0
		var bar_x := (vp.x - bar_w) * 0.5
		var bar_y := vp.y - 52.0
		var next_label := "Próximo: ATAQUE" if mode == Mode.WALK else ("Próximo: PODER" if mode == Mode.ATTACK else "Próximo: ANDAR")
		var progress := clampf(_state_timer / STATE_DURATION, 0.0, 1.0)
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color("#1C1622"))
		draw_rect(Rect2(bar_x, bar_y, bar_w * progress, bar_h), badge_color)
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(1, 1, 1, 0.3), false, 1.0)
		draw_string(font, Vector2(0, bar_y - 8), "LOOP ATIVO — " + next_label, HORIZONTAL_ALIGNMENT_CENTER, vp.x, 12, Color(1, 1, 1, 0.7))
	else:
		draw_string(font, Vector2(0, vp.y - 48), "[LOOP PAUSADO - MODO TRAVADO - PRESSIONE ESPAÇO PARA REATIVAR]", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 13, Color("#FFD400"))


func _draw_grid(font: Font, vp: Vector2) -> void:
	draw_string(font, Vector2(0, 120), "PEÇAS MODULARES RÍGIDAS & HIERARQUIA DO RIG (MINI-PRENSA 500)", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 20, Color("#FFD400"))
	draw_string(font, Vector2(0, 145), "Cada elemento é transformado rigidamente em torno do seu pivô físico, sem deformação de chapas sólidas", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 14, Color("#C4B8A5"))

	var pieces := [
		{"name": "1. Mandíbula Superior (Cabeça)", "rect": MiniPrensaPuppet.RECT_HEAD, "pivot": "Pivô: Dobradiça Traseira", "x": 60, "y": 180, "w": 260, "h": 195},
		{"name": "2. Chassi & Mandíbula Inferior", "rect": MiniPrensaPuppet.RECT_CHASSIS, "pivot": "Base de Apoio e Trough", "x": 360, "y": 180, "w": 260, "h": 195},
		{"name": "3. Núcleo da Fornalha", "rect": MiniPrensaPuppet.RECT_CORE, "pivot": "Fogo / Interior da Boca", "x": 660, "y": 180, "w": 220, "h": 195},
		{"name": "4. Engrenagem Giratória", "rect": MiniPrensaPuppet.RECT_GEAR, "pivot": "Pivô Central 360°", "x": 920, "y": 180, "w": 180, "h": 195},
		{"name": "5. Pé Esquerdo", "rect": MiniPrensaPuppet.RECT_FOOT_L, "pivot": "Esteira / Passada", "x": 60, "y": 420, "w": 220, "h": 160},
		{"name": "6. Pé Direito", "rect": MiniPrensaPuppet.RECT_FOOT_R, "pivot": "Esteira / Passada", "x": 320, "y": 420, "w": 220, "h": 160},
		{"name": "7. Tampa da Chaminé", "rect": MiniPrensaPuppet.RECT_CHIMNEY, "pivot": "Válvula de Pressão", "x": 580, "y": 420, "w": 220, "h": 160},
		{"name": "8. Cilindro e Haste", "rect": MiniPrensaPuppet.RECT_PISTON_SLEEVE, "pivot": "Pistão Hidráulico", "x": 840, "y": 420, "w": 260, "h": 160},
	]

	for p in pieces:
		var frame_rect := Rect2(p["x"], p["y"], p["w"], p["h"])
		draw_rect(frame_rect, Color("#1A1420"))
		draw_rect(frame_rect, Color("#4A3B54"), false, 1.5)
		var img_rect := Rect2(frame_rect.position + Vector2(20, 30), Vector2(frame_rect.size.x - 40, frame_rect.size.y - 70))
		draw_texture_rect_region(_tex, img_rect, p["rect"])
		draw_string(font, Vector2(p["x"], p["y"] + 20), p["name"], HORIZONTAL_ALIGNMENT_CENTER, p["w"], 13, Color("#FFD400"))
		draw_string(font, Vector2(p["x"], p["y"] + p["h"] - 10), p["pivot"], HORIZONTAL_ALIGNMENT_CENTER, p["w"], 12, Color("#8CFF1A"))
