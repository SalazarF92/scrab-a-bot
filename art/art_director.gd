class_name ArtDirector
extends RefCounted
## Raster original + composição modular. A animação visual usa poses a 12 Hz;
## não consome RNG nem altera colisões, mira ou o pool de projéteis.

const INK := Color("#1A0F14")
const BONE := Color("#F5F0E1")
const PARTS_PATH := "res://assets/art/parts_atlas.png"
const ENEMIES_PATH := "res://assets/art/enemies_atlas.png"
const EXPANSION_PATH := "res://assets/art/expansion_atlas_alpha.png"
const EXPANSION_CELLS := {&"qwertypede": 0, &"popup_vivo": 1, &"cadeado_chorao": 2, &"olhudo": 3,
	&"bipador": 4, &"ze_ventoinha": 5, &"cabo_cobra": 6, &"fabricadora": 7}
const PROP_CELLS := {"Barril Toxico": 8, "TV Quebrada": 9, "Bobina de Cobre": 10, "Tubulacao": 11}
const BACKGROUND_PATH := "res://assets/art/junkyard.png"
const FrostbytePuppet = preload("res://art/frostbyte_puppet.gd")
const MiniPrensaPuppet = preload("res://art/mini_prensa_puppet.gd")
const PART_CELLS := {
	&"arm_l_mousetrap": 0, &"arm_l_drill": 1, &"arm_l_stapler": 2, &"arm_l_drill_super": 1,
	&"arm_r_psu": 3, &"arm_r_pipe_bazooka": 4, &"arm_r_hdd": 5, &"arm_r_pipe_napalm": 4,
	&"head_toaster": 6, &"head_toaster_tesla": 7,
	&"chassis_springs": 8, &"chassis_treads": 9, &"chassis_casters": 10,
	&"chassis_mannequin": 11, &"chassis_safe": 12, &"car_battery": 13,
	&"diamond_drillbit": 1, &"propane_tank": 4,
}
const BIOMES := ["DEPÓSITO DE SUCATA", "ESGOTO ELETRÔNICO", "CÂMARA FRIA", "ESCRITÓRIO MORTO", "A FORNALHA"]
const BIOME_COLORS := [Color("#C5A77A"), Color("#68BA80"), Color("#70BCD4"), Color("#BD8EFF"), Color("#FF5722")]
const BIOME_WALL_COLORS := [Color("#3E332B"), Color("#183024"), Color("#1C2C3D"), Color("#2A1B36"), Color("#331208")]
const BIOME_CONDUIT_COLORS := [Color("#B87333"), Color("#39FF14"), Color("#5CE1E6"), Color("#E056FD"), Color("#FF3D00")]
const BIOME_HAZARD_A := [Color("#FFCC00"), Color("#39FF14"), Color("#5CE1E6"), Color("#FF2D95"), Color("#FF4500")]
const BIOME_HAZARD_B := [Color("#1C1510"), Color("#0A1C12"), Color("#0A1826"), Color("#180B22"), Color("#200802")]
const BIOME_HAZARD_WIRE := [Color("#FF8C00", 0.70), Color("#39FF14", 0.75), Color("#74E5FF", 0.85), Color("#FF2D95", 0.80), Color("#FFAA00", 0.90)]
const BIOME_WASH := [
	Color(0.20, 0.14, 0.08, 0.38),
	Color(0.04, 0.18, 0.08, 0.42),
	Color(0.05, 0.15, 0.25, 0.40),
	Color(0.14, 0.06, 0.20, 0.42),
	Color(0.25, 0.07, 0.01, 0.44),
]
static var _textures: Dictionary = {}
static var _layout: Dictionary = {}


static func layout() -> Dictionary:
	if _layout.is_empty():
		_layout = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/atlas_layout.json"))
	return _layout


static func assembly_rect(key: String) -> Rect2:
	var values: Array = layout()["assembly"][key]
	return Rect2(values[0], values[1], values[2], values[3])


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path] as Texture2D


static func cell(canvas: CanvasItem, path: String, index: int, rows: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
	var tex := texture(path)
	if tex == null:
		return
	var group := "expansion" if path == EXPANSION_PATH else ("parts" if rows == 4 else "enemies")
	var values: Array = layout()[group][index]
	var source := Rect2(values[0], values[1], values[2], values[3])
	# Recortar regiões preserva a imagem/alpha original; não gera arquivos derivados.
	var aspect := source.size.x / source.size.y
	var fitted := Vector2(minf(rect.size.x, rect.size.y * aspect), minf(rect.size.y, rect.size.x / aspect))
	rect = Rect2(rect.get_center() - fitted * 0.5, fitted)
	canvas.draw_texture_rect_region(tex, rect, source, tint)


static func part_icon(canvas: CanvasItem, part: PartData, rect: Rect2) -> void:
	if part != null:
		cell(canvas, PARTS_PATH, PART_CELLS.get(part.id, 13), 4, rect)


static func shadow(canvas: CanvasItem, at: Vector2, radius: Vector2, alpha: float = 0.34) -> void:
	var points := PackedVector2Array()
	for i in 24:
		points.append(at + Vector2(cos(i * TAU / 24.0), sin(i * TAU / 24.0)) * radius)
	canvas.draw_colored_polygon(points, Color(0.06, 0.025, 0.05, alpha))


static func draw_robot(canvas: Node2D, robot: Node2D) -> void:
	var t := floorf(Time.get_ticks_msec() * 0.012) / 12.0
	var stride: float = clampf(absf(robot.velocity.x) / 240.0, 0.0, 1.0)
	var bob := sin(t * 12.0) * (1.0 + stride * 2.0)
	var pose: Vector2 = robot.deform * Vector2(1.0 + sin(t * 5.0) * 0.015, 1.0 - sin(t * 5.0) * 0.015)
	shadow(canvas, Vector2(2, 2), Vector2(40, 10))
	var tint := Color(1.4, 1.4, 1.4) if robot._hit_flash > 0.0 else Color.WHITE
	if robot._iframes > 0.0 and fmod(robot._iframes * 12.0, 1.0) < 0.5:
		tint.a = 0.5
	canvas.draw_set_transform(Vector2.ZERO, 0.0, pose)
	var chassis: PartData = robot.equipped.get(PartData.Slot.CHASSIS)
	var chassis_rect := assembly_rect("chassis")
	chassis_rect.position.y += bob
	cell(canvas, PARTS_PATH, PART_CELLS.get(chassis.id, 8) if chassis else 8, 4, chassis_rect, tint)
	var head: PartData = robot.equipped.get(PartData.Slot.HEAD)
	var tilt: float = clampf(robot.aim_direction.x * 0.18, -0.18, 0.18)
	canvas.draw_set_transform(Vector2(0, -77 + bob) * pose, tilt, pose)
	cell(canvas, PARTS_PATH, PART_CELLS.get(head.id, 6) if head else 6, 4, assembly_rect("head"), tint)
	for slot in [PartData.Slot.ARM_LEFT, PartData.Slot.ARM_RIGHT]:
		var arm: PartData = robot.equipped.get(slot)
		var side := -1.0 if slot == PartData.Slot.ARM_LEFT else 1.0
		var shoulder := Vector2(side * 23.0, -43 + bob)
		canvas.draw_set_transform(shoulder * pose, robot.aim_direction.angle(), pose)
		cell(canvas, PARTS_PATH, PART_CELLS.get(arm.id, 0) if arm else 0, 4, assembly_rect("arm"), tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if chassis and chassis.id == &"chassis_safe":
		canvas.draw_arc(robot.BODY_CENTER, 35, robot.aim_direction.angle() - PI * 0.48,
			robot.aim_direction.angle() + PI * 0.48, 24, Color("#22E0FF", 0.6), 3.0, true)


static func enemy_cell(enemy_name: String) -> int:
	if "Prensa" in enemy_name: return 6
	if "FROSTBYTE" in enemy_name: return 7
	if "Fornalha" in enemy_name: return 8
	if "Lotada" in enemy_name: return 5
	if "Geladeira" in enemy_name: return 2
	if "Disquete" in enemy_name: return 3
	if "Rato" in enemy_name: return 1
	if "Jato" in enemy_name: return 4
	return 0


static func draw_enemy(canvas: Node2D, enemy: Node2D) -> void:
	var radius: float = enemy.body_radius
	var t: float = floorf(Time.get_ticks_msec() * 0.012) / 12.0 + enemy._phase
	var bob := sin(t * 7.0) * 1.6
	# O volume continua próximo da colisão; chefes ganham silhueta, não hitbox invisível.
	var extent := radius * 3.0 + 18.0
	shadow(canvas, Vector2(3, radius * 0.7), Vector2(radius * 1.2, radius * 0.35))
	var tint := Color(1.3, 1.3, 1.3) if enemy._flash > 0.0 else Color.WHITE

	# Mini-Prensa: malha da arte original com relogio continuo.
	if enemy.get("boss_kind") == &"mini_prensa" and texture(MiniPrensaPuppet.ATLAS_PATH) != null:
		var tex := texture(MiniPrensaPuppet.ATLAS_PATH)
		var state_val = enemy.get("boss_state") # 0 = APPROACH, 1 = RECOVERY, 2 = TELEGRAPH, 3 = STRIKE
		var timer: float = float(enemy.get("_boss_timer"))
		var act := MiniPrensaPuppet.Action.WALK
		var puppet_t: float = Time.get_ticks_msec() * 0.001 + enemy._phase
		if state_val == 0:
			act = MiniPrensaPuppet.Action.WALK
			puppet_t *= 1.0
		elif state_val == 2:
			act = MiniPrensaPuppet.Action.ATTACK
			var dur: float = maxf(0.001, float(enemy.get("_boss_telegraph_duration")))
			var prog := clampf(1.0 - (timer / dur), 0.0, 1.0)
			puppet_t = prog * 0.70 # Antecipação e abertura ampla da mandíbula
		elif state_val == 3:
			act = MiniPrensaPuppet.Action.ATTACK
			var dur := 0.4
			var p := clampf(1.0 - (timer / dur), 0.0, 1.0)
			puppet_t = 0.70 + p * 0.55 # Golpe veloz e impacto amortecido
		elif state_val == 1:
			act = MiniPrensaPuppet.Action.POWER
			puppet_t = minf(2.599, maxf(0.0, (3.8 - 0.6 * float(enemy.boss_phase - 1)) - timer)) # Exposicao do nucleo durante recuperacao

		var pose := MiniPrensaPuppet.compute_pose(act, puppet_t)
		# Recovery exposes the core without advertising a damaging plasma attack.
		if state_val == 1:
			pose.blast = 0.0
		var now := Time.get_ticks_msec() * 0.001
		if int(enemy.get_meta("press_state", -1)) != int(state_val):
			enemy.set_meta("press_from", enemy.get_meta("press_pose", pose))
			enemy.set_meta("press_changed", now)
			enemy.set_meta("press_state", int(state_val))
		var weight := smoothstep(0.0, 1.0, (now - float(enemy.get_meta("press_changed", now))) / .18)
		pose = MiniPrensaPuppet.blend_pose(enemy.get_meta("press_from", pose), pose, weight)
		enemy.set_meta("press_pose", pose)
		var puppet_scale := (extent * 1.15) / 418.0
		MiniPrensaPuppet.draw_puppet(canvas, tex, Vector2(0.0, -12.0), puppet_scale, pose, tint)
		return

	# Frostbyte uses continuous rigid articulation; combat timing remains authoritative.
	if enemy.get("boss_kind") == &"frostbyte" and texture(FrostbytePuppet.ATLAS_PATH) != null:
		var tex := texture(FrostbytePuppet.ATLAS_PATH)
		var state: int = int(enemy.boss_state)
		var timer: float = float(enemy._boss_timer)
		var shards: bool = bool(enemy._boss_shards)
		var act := FrostbytePuppet.Action.WALK
		var now := Time.get_ticks_msec() * .001
		var playhead: float = now + float(enemy._phase)
		if state == 2:
			act = FrostbytePuppet.Action.ATTACK if shards else FrostbytePuppet.Action.POWER
			var progress := clampf(1 - timer / maxf(.001, float(enemy._boss_telegraph_duration)), 0, 1)
			playhead = progress * (.74 if shards else .94)
		elif state == 3:
			act = FrostbytePuppet.Action.ATTACK if shards else FrostbytePuppet.Action.POWER
			var progress := clampf(1 - timer / (.3 if shards else .9), 0, 1)
			playhead = .74 + progress * .6 if shards else .94 + progress * 1.76
		elif state == 1:
			act = FrostbytePuppet.Action.POWER
			playhead = 1.9
		var pose := FrostbytePuppet.compute_pose(act, playhead)
		if state == 1:
			pose.blast = 0.0
		if int(enemy.get_meta("frost_state", -1)) != state:
			enemy.set_meta("frost_from", enemy.get_meta("frost_pose", pose))
			enemy.set_meta("frost_changed", now)
			enemy.set_meta("frost_state", state)
		var weight := smoothstep(0, 1, (now - float(enemy.get_meta("frost_changed", now))) / .16)
		pose = FrostbytePuppet.blend_pose(enemy.get_meta("frost_from", pose), pose, weight)
		enemy.set_meta("frost_pose", pose)
		FrostbytePuppet.draw_puppet(canvas, tex, Vector2(0, -12), extent * 1.15 / 460.0, pose, tint)
		return

	var expanded := EXPANSION_CELLS.has(enemy.visual_id) and texture(EXPANSION_PATH) != null
	cell(canvas, EXPANSION_PATH if expanded else ENEMIES_PATH,
		EXPANSION_CELLS[enemy.visual_id] if expanded else enemy_cell(enemy.enemy_name), 3,
		Rect2(-extent * 0.5, -extent * 0.6 + bob, extent, extent), tint)
	if EXPANSION_CELLS.has(enemy.visual_id) and not expanded:
		canvas.draw_string(ThemeDB.fallback_font, Vector2(-90, -extent * 0.6 - 5),
			enemy.enemy_name, HORIZONTAL_ALIGNMENT_CENTER, 180, 14, enemy.color)


static func draw_arena(canvas: Node2D, sector: int) -> void:
	var s_idx: int = clampi(sector - 1, 0, 4)
	var tint: Color = BIOME_COLORS[s_idx]
	var wall_col: Color = BIOME_WALL_COLORS[s_idx]
	var conduit_col: Color = BIOME_CONDUIT_COLORS[s_idx]
	var hz_a: Color = BIOME_HAZARD_A[s_idx]
	var hz_b: Color = BIOME_HAZARD_B[s_idx]
	var hz_wire: Color = BIOME_HAZARD_WIRE[s_idx]
	var wash: Color = BIOME_WASH[s_idx]

	canvas.draw_rect(Rect2(-900, -400, 2800, 1900), Color("#121013"))
	var tex := texture(BACKGROUND_PATH)
	if tex:
		# Camada distante acompanha só uma fração do deslocamento da câmera.
		var camera := canvas.get_viewport().get_camera_2d()
		var parallax := Vector2.ZERO
		if camera: parallax = (camera.global_position - Vector2(500, 540)) * 0.22
		canvas.draw_texture_rect(tex, Rect2(Vector2(-460, 0) + parallax, Vector2(1920, 1080)), false, tint)
		canvas.draw_texture_rect_region(tex, Rect2(0, 0, 1000, 1080),
			Rect2(tex.get_width() * 0.29, 0, tex.get_width() * 0.42, tex.get_height()), tint)

	# Atmosfera específica do bioma sobreposta ao poço:
	canvas.draw_rect(Rect2(0, 0, 1000, 1080), wash)

	# Identificação stencil do setor no topo do poço:
	canvas.draw_string(ThemeDB.fallback_font, Vector2(0, 28), "/// SETOR %d : %s ///" % [s_idx + 1, BIOMES[s_idx]],
		HORIZONTAL_ALIGNMENT_CENTER, 1000.0, 13, Color(tint, 0.32))

	# Nervuras fixas e face frontal produzem profundidade sem deslocar a colisão:
	for x in [-15.0, 1000.0]:
		canvas.draw_rect(Rect2(x, 0, 15, 1080), wall_col)
		canvas.draw_line(Vector2(x + 4, 0), Vector2(x + 4, 1080), conduit_col, 2.5)
		# Detalhes específicos de bioma nos pilares laterais:
		for y in range(35, 1080, 90):
			canvas.draw_circle(Vector2(x + 8, y), 4, INK)
			canvas.draw_circle(Vector2(x + 7, y - 1), 2, tint)
			match s_idx:
				1: # Esgoto Eletrônico: trilhas e vias de circuito impresso
					canvas.draw_line(Vector2(x + 4, y), Vector2(x + 13, y), conduit_col, 1.5)
					canvas.draw_circle(Vector2(x + 13, y), 1.5, Color("#B2FF59"))
				2: # Câmara Fria: cristais de gelo e pontas de estalactite
					canvas.draw_line(Vector2(x + 4, y), Vector2(x + 11, y + 7), Color("#DDF7FF", 0.7), 2.0)
				3: # Escritório Morto: LEDs de status em barramentos de servidores
					var led_col := Color("#FFBE53") if (y / 90) % 2 == 0 else Color("#E056FD")
					canvas.draw_circle(Vector2(x + 11, y), 2.0, led_col)
				4: # A Fornalha: fissuras incandescentes de magma
					canvas.draw_circle(Vector2(x + 4, y), 3.0, Color("#FFAA00", 0.8))
					canvas.draw_line(Vector2(x + 4, y), Vector2(x + 10, y + 5), Color("#FF3D00", 0.6), 2.0)

	# Vigas estruturais horizontais de fundo:
	for y in range(110, 920, 100):
		canvas.draw_line(Vector2(12, y), Vector2(988, y + 6), Color(tint, 0.08), 2.0)
		if s_idx == 4:
			canvas.draw_line(Vector2(20, y + 1), Vector2(980, y + 7), Color(1.0, 0.4, 0.1, 0.06), 4.0)
		elif s_idx == 1:
			canvas.draw_line(Vector2(180 + (y * 3) % 640, y + 6), Vector2(180 + (y * 3) % 640, y + 26), Color(conduit_col, 0.12), 1.5)

	# Piso e Linha de Base:
	canvas.draw_rect(Rect2(0, 982, 1000, 98), Color("#141017", 0.82))
	canvas.draw_line(Vector2(0, 960), Vector2(1000, 960), hz_wire, 2.5)
	# Listras diagonais de perigo industriais:
	for x in range(0, 1000, 36):
		canvas.draw_line(Vector2(x, 985), Vector2(x + 18, 1000), hz_a, 7.0)
		canvas.draw_line(Vector2(x + 18, 985), Vector2(x + 36, 1000), hz_b, 7.0)


static func draw_obstacle(canvas: Node2D, obstacle: Node2D) -> void:
	var size: Vector2 = obstacle.size
	if obstacle.label == "Parede":
		return
	var r := Rect2(-size * 0.5, size)
	shadow(canvas, Vector2(5, size.y * 0.4), Vector2(size.x * 0.54, size.y * 0.3))
	# A borda é a superfície física exata; sprite recortado é decoração de volume.
	canvas.draw_rect(Rect2(r.position + Vector2(0, 9), r.size), Color("#1A141B"))
	canvas.draw_rect(r, Color("#352B28"))
	canvas.draw_rect(r, Color("#88756A"), false, 2.0)
	canvas.draw_line(r.position, r.position + Vector2(size.x, 0), Color("#B6A299"), 3.0)
	var s_idx: int = 0
	if obstacle.get_parent() != null and obstacle.get_parent().get("visual_sector") != null:
		s_idx = clampi(int(obstacle.get_parent().visual_sector) - 1, 0, 4)
	var rivet_color: Color = BIOME_COLORS[s_idx].lightened(0.2)
	for side in [-1.0, 1.0]:
		canvas.draw_circle(Vector2(side * (size.x * 0.5 - 7), -size.y * 0.5 + 7), 2, rivet_color)
	var tint := Color(1.25, 1.25, 1.25) if obstacle._flash > 0.0 else Color(0.85, 0.85, 0.85)
	if PROP_CELLS.has(obstacle.label) and texture(EXPANSION_PATH) != null:
		cell(canvas, EXPANSION_PATH, PROP_CELLS[obstacle.label], 3, r.grow(8), tint)
	elif "Pneus" in obstacle.label:
		cell(canvas, PARTS_PATH, 14, 4, r.grow(8), tint)
	elif "Fusca" in obstacle.label:
		cell(canvas, PARTS_PATH, 15, 4, r.grow(8), tint)
	elif "Colchao" in obstacle.label:
		cell(canvas, ENEMIES_PATH, 11, 3, r.grow(8), tint)
	else:
		cell(canvas, ENEMIES_PATH, 6, 3, r.grow(8), tint)


static func panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


static func panel(canvas: CanvasItem, rect: Rect2, accent: Color = Color("#78665D")) -> void:
	canvas.draw_style_box(panel_style(Color("#211C24", 0.94), accent.darkened(0.25)), rect)
	for p in [rect.position + Vector2(9, 9), rect.position + Vector2(rect.size.x - 9, 9), rect.end - Vector2(9, 9), rect.position + Vector2(9, rect.size.y - 9)]:
		canvas.draw_circle(p, 3, accent)
		canvas.draw_line(p - Vector2(1, 1), p + Vector2(1, 1), INK, 1.5)
