class_name BossEyes
extends RefCounted
static var _press_texture: Texture2D
static var _frost_texture: Texture2D
## Original iris pixels translate smoothly at a fixed size.
static func animate(p: Dictionary, t: float, duration: float, _impact_time: float) -> void:
	var phase := fposmod(t, duration) / duration
	var target := Vector2(.85 * sin(phase * TAU), .15 + .22 * sin(phase * TAU * 2))
	if int(p.action) != 0 and int(p.action) != 3:
		target = target.lerp(Vector2(0, .80), sin(phase * PI) * .85)
	p["gaze"] = target

## Small feathered patch covers only the old pupil, preserving the original veins.
static func eye_patch(canvas: CanvasItem, pupil: Vector2, radius: float, tint: Color) -> void:
	for i in range(4):
		canvas.draw_circle(pupil, radius + 2.2 - i * .45, Color(1.0, .94, .86, .35 + i * .18) * tint)

## Centro da iris deslocada pelo olhar. A iris mantem o tamanho.
static func iris_center(pupil: Vector2, radius: float, gaze: Vector2) -> Vector2:
	return pupil + gaze * Vector2(radius * .78, radius * .46)

## Iris centrada na origem, com UVs dos pixels originais da pupila.
static func iris_geometry(pupil: Vector2, radius: float) -> Array:
	var iris := PackedVector2Array()
	var uv := PackedVector2Array()
	for i in range(40):
		var offset := Vector2.from_angle(float(i) * TAU / 40.0) * radius
		iris.append(offset)
		uv.append((pupil + offset) / 1254.0)
	return [iris, uv]

static func _eye(canvas: CanvasItem, pupil: Vector2, radius: float, gaze: Vector2, tint: Color, texture: Texture2D) -> void:
	eye_patch(canvas, pupil, radius, tint)
	var at := iris_center(pupil, radius, gaze)
	var geometry := iris_geometry(pupil, radius)
	var iris := PackedVector2Array()
	for offset in geometry[0]:
		iris.append(at + offset)
	canvas.draw_polygon(iris, PackedColorArray([tint]), geometry[1], texture)
static func draw_press(canvas: CanvasItem, p: Dictionary, root: Transform2D, tint: Color) -> void:
	if _press_texture == null:
		_press_texture = load("res://assets/art/mini_prensa_rigid_atlas.png")
	var head := Transform2D(float(p.body_tilt), p.body_offset) * Transform2D(0, Vector2(0, -115 + float(p.jaw)))
	var source := Transform2D(0, Vector2.ONE * .6, 0, Vector2(-250, -245) * .6)
	canvas.draw_set_transform_matrix(root * head * source)
	_eye(canvas, Vector2(243,187), 8.0, p.gaze, tint, _press_texture)
	_eye(canvas, Vector2(365,204), 7.2, p.gaze, tint, _press_texture)
	canvas.draw_set_transform_matrix(root)

static func draw_frost(canvas: CanvasItem, p: Dictionary, root: Transform2D, tint: Color) -> void:
	if _frost_texture == null:
		_frost_texture = load("res://assets/art/enemies_atlas.png")
	var head := Transform2D(float(p.body_tilt), p.body_offset) * Transform2D(0, Vector2(0, float(p.jaw)))
	canvas.draw_set_transform_matrix(root * head * Transform2D(0, -Vector2(1103.5,603.5)))
	_eye(canvas, Vector2(1115,504), 5.0, p.gaze, tint, _frost_texture)
	_eye(canvas, Vector2(1185,522), 3.5, p.gaze, tint, _frost_texture)
	canvas.draw_set_transform_matrix(root)
