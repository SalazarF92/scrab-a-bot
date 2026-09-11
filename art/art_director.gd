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
const PART_CELLS := {
	&"arm_l_mousetrap": 0, &"arm_l_drill": 1, &"arm_l_stapler": 2,
	&"arm_r_psu": 3, &"arm_r_pipe_bazooka": 4, &"arm_r_hdd": 5,
	&"head_toaster": 6, &"head_toaster_tesla": 7,
	&"chassis_springs": 8, &"chassis_treads": 9, &"chassis_casters": 10,
	&"chassis_mannequin": 11, &"chassis_safe": 12, &"car_battery": 13,
}
const BIOMES := ["DEPÓSITO DE SUCATA", "ESGOTO ELETRÔNICO", "CÂMARA FRIA", "ESCRITÓRIO MORTO", "A FORNALHA"]
const BIOME_COLORS := [Color("#C5A77A"), Color("#91B795"), Color("#97BEC9"), Color("#B6A2C4"), Color("#D79676")]
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
	var expanded := EXPANSION_CELLS.has(enemy.visual_id) and texture(EXPANSION_PATH) != null
	cell(canvas, EXPANSION_PATH if expanded else ENEMIES_PATH,
		EXPANSION_CELLS[enemy.visual_id] if expanded else enemy_cell(enemy.enemy_name), 3,
		Rect2(-extent * 0.5, -extent * 0.6 + bob, extent, extent), tint)
	if EXPANSION_CELLS.has(enemy.visual_id) and not expanded:
		canvas.draw_string(ThemeDB.fallback_font, Vector2(-90, -extent * 0.6 - 5),
			enemy.enemy_name, HORIZONTAL_ALIGNMENT_CENTER, 180, 14, enemy.color)


static func draw_arena(canvas: Node2D, sector: int) -> void:
	var tint: Color = BIOME_COLORS[clampi(sector - 1, 0, 4)]
	canvas.draw_rect(Rect2(-900, -400, 2800, 1900), Color("#191719"))
	var tex := texture(BACKGROUND_PATH)
	if tex:
		# Camada distante acompanha só uma fração do deslocamento da câmera.
		var camera := canvas.get_viewport().get_camera_2d()
		var parallax := Vector2.ZERO
		if camera: parallax = (camera.global_position - Vector2(500, 540)) * 0.22
		canvas.draw_texture_rect(tex, Rect2(Vector2(-460, 0) + parallax, Vector2(1920, 1080)), false, tint)
		canvas.draw_texture_rect_region(tex, Rect2(0, 0, 1000, 1080),
			Rect2(tex.get_width() * 0.29, 0, tex.get_width() * 0.42, tex.get_height()), tint)
	canvas.draw_rect(Rect2(0, 0, 1000, 1080), Color(0.055, 0.045, 0.06, 0.48))
	# Nervuras fixas e face frontal produzem profundidade sem deslocar a colisão.
	for x in [-15.0, 1000.0]:
		canvas.draw_rect(Rect2(x, 0, 15, 1080), Color("#4C4245"))
		canvas.draw_line(Vector2(x + 4, 0), Vector2(x + 4, 1080), tint.darkened(0.25), 3.0)
		for y in range(35, 1080, 90):
			canvas.draw_circle(Vector2(x + 8, y), 4, INK)
			canvas.draw_circle(Vector2(x + 7, y - 1), 2, tint)
	for y in range(100, 920, 100):
		canvas.draw_line(Vector2(12, y), Vector2(988, y + 9), Color(0.8, 0.75, 0.8, 0.045), 2.0)
	canvas.draw_rect(Rect2(0, 982, 1000, 98), Color("#1A141D", 0.7))
	canvas.draw_line(Vector2(0, 960), Vector2(1000, 960), Color("#FF2D95", 0.55), 2.0)
	for x in range(0, 1000, 36):
		canvas.draw_line(Vector2(x, 985), Vector2(x + 16, 996), Color("#C5A77A", 0.65), 7.0)


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
	for side in [-1.0, 1.0]:
		canvas.draw_circle(Vector2(side * (size.x * 0.5 - 7), -size.y * 0.5 + 7), 2, BONE)
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
