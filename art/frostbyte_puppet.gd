class_name FrostbytePuppet
extends RefCounted
const Eyes = preload("res://art/boss_eyes.gd")
enum Action { WALK, ATTACK, POWER, IDLE }
const ATLAS_PATH := "res://assets/art/enemies_atlas.png"
const PARTS_PATH := "res://assets/art/frostbyte_original_parts.json"
const WALK_DURATION := 1.4
const ATTACK_DURATION := 1.9
const POWER_DURATION := 3.2
const IMPACT_TIME := .9
static var _parts: Dictionary = {}
static func parts() -> Dictionary:
	if _parts.is_empty():
		_parts = JSON.parse_string(FileAccess.get_file_as_string(PARTS_PATH))
	return _parts
static func polygon(key: String) -> PackedVector2Array:
	var def: Dictionary = parts()[key]
	var out := PackedVector2Array()
	for xy in def.points:
		out.append((Vector2(xy[0], xy[1]) - Vector2(def.pivot[0], def.pivot[1])) * float(def.fit))
	return out
static func uvs(key: String, normalized: bool = true) -> PackedVector2Array:
	var out := PackedVector2Array()
	for xy in parts()[key].points:
		out.append(Vector2(xy[0], xy[1]) / (1254.0 if normalized else 1.0))
	return out
static func curve(t: float, keys: Array) -> float:
	for i in range(1, keys.size()):
		var a: Vector2 = keys[i - 1]
		var b: Vector2 = keys[i]
		if t <= b.x:
			return lerpf(a.y, b.y, smoothstep(0, 1, (t - a.x) / (b.x - a.x)))
	return keys.back().y
static func compute_pose(action: Action, playhead: float) -> Dictionary:
	var p := {"body_offset": Vector2.ZERO, "body_tilt": 0.0, "jaw": 0.0, "chin": 0.0,
		"foot_l_offset": Vector2.ZERO, "foot_r_offset": Vector2.ZERO, "foot_l_rot": 0.0, "foot_r_rot": 0.0,
		"vent": 0.0, "blast": 0.0, "impact": 0.0, "time": playhead, "action": action}
	match action:
		Action.WALK:
			var phase := fposmod(playhead, WALK_DURATION) / WALK_DURATION
			var s := sin(phase * TAU)
			p.body_offset = Vector2(s * 1.5, -s * s * 2)
			p.body_tilt = s * .009
			p.foot_l_offset = _step(phase)
			p.foot_r_offset = _step(fposmod(phase + .5, 1))
			p.foot_l_rot = -.08 * pow(maxf(0, s), 2)
			p.foot_r_rot = .08 * pow(maxf(0, -s), 2)
			p.jaw = -2 * s * s
		Action.ATTACK:
			var t := fposmod(playhead, ATTACK_DURATION)
			p.jaw = curve(t, [Vector2(0, 0), Vector2(.65, -15), Vector2(.74, -15), Vector2(.9, 24), Vector2(1.04, 21), Vector2(1.3, -7), Vector2(1.9, 0)])
			p.chin = curve(t, [Vector2(0, 0), Vector2(.65, 5), Vector2(.74, 5), Vector2(.9, -4), Vector2(1.04, -3), Vector2(1.9, 0)])
			p.body_offset.y = curve(t, [Vector2(0, 0), Vector2(.65, -5), Vector2(.74, -5), Vector2(.9, 9), Vector2(1.3, -3), Vector2(1.9, 0)])
			p.impact = clampf((t - IMPACT_TIME) / .55, 0, 1)
		Action.POWER:
			var t := fposmod(playhead, POWER_DURATION)
			p.jaw = curve(t, [Vector2(0, 0), Vector2(.82, -20), Vector2(2.72, -20), Vector2(3.2, 0)])
			p.chin = curve(t, [Vector2(0, 0), Vector2(.82, 0), Vector2(2.72, 0), Vector2(3.2, 0)])
			p.vent = curve(t, [Vector2(0, 0), Vector2(.22, 0), Vector2(.82, 1), Vector2(2.82, 1), Vector2(3.2, 0)])
			p.blast = curve(t, [Vector2(0, 0), Vector2(.94, 0), Vector2(1.22, 1), Vector2(2.30, 1), Vector2(2.7, 0), Vector2(3.2, 0)])
			p.body_offset.y = -6 * float(p.blast)
			p.body_tilt = sin(t * 16) * .004 * float(p.blast)
		Action.IDLE:
			p.jaw = -1.5 * (1 - cos(playhead * 2))
	Eyes.animate(p, playhead, [WALK_DURATION, ATTACK_DURATION, POWER_DURATION, 3.6][action], IMPACT_TIME)
	return p
static func _step(phase: float) -> Vector2:
	if phase < .5:
		var t := phase * 2
		return Vector2(lerpf(-3, 3, smoothstep(0, 1, t)), -3 * pow(sin(t * PI), 2))
	return Vector2(lerpf(3, -3, smoothstep(0, 1, (phase - .5) * 2)), 0)
static func blend_pose(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	var result := b.duplicate()
	for key in b:
		if a.has(key):
			if b[key] is Vector2:
				result[key] = (a[key] as Vector2).lerp(b[key], weight)
			elif b[key] is float:
				result[key] = lerpf(a[key], b[key], weight)
	return result
static func frames(p: Dictionary, exploded: float = 0.0) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var body := Transform2D(float(p.body_tilt), p.body_offset)
	for key in parts():
		if key.begins_with("cabinet_"):
			_add(out, key, key, body, Vector2.ZERO, exploded)
	_add(out, "LeftIceBase", "foot_l", body, Vector2(-45, 80), exploded)
	_add(out, "RightIceBase", "foot_r", body, Vector2(45, 80), exploded)
	_add(out, "LowerJaw", "jaw", body * Transform2D(0, Vector2(0, float(p.chin))), Vector2(0, 70), exploded)
	_add(out, "UpperJaw", "head", body * Transform2D(0, Vector2(0, float(p.jaw))), Vector2(0, -90), exploded)
	return out

static func _add(out: Array[Dictionary], name: String, part: String, xf: Transform2D, offset: Vector2, exploded: float) -> void:
	xf.origin += offset * exploded
	out.append({"name": name, "part": part, "transform": xf})
static func draw_puppet(canvas: CanvasItem, tex: Texture2D, center: Vector2, scale_factor: float, pose: Dictionary, tint: Color = Color.WHITE, exploded: float = 0.0) -> void:
	if tex == null or pose.is_empty():
		return
	var root := Transform2D(0, Vector2.ONE * scale_factor, 0, center)
	for item in frames(pose, exploded):
		canvas.draw_set_transform_matrix(root * (item.transform as Transform2D))
		if parts()[item.part].has("color"):
			canvas.draw_colored_polygon(polygon(item.part), Color(parts()[item.part].color) * tint)
		else:
			canvas.draw_polygon(polygon(item.part), PackedColorArray([tint]), uvs(item.part), tex)
	if exploded < .01:
		Eyes.draw_frost(canvas, pose, root, tint)
		draw_effects(canvas, pose, tex, tint, root)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
static func draw_effects(canvas: CanvasItem, p: Dictionary, tex: Texture2D, tint: Color = Color.WHITE, root: Transform2D = Transform2D.IDENTITY) -> void:
	canvas.draw_set_transform_matrix(root)
	var time: float = p.time
	var body := Transform2D(float(p.body_tilt), p.body_offset)
	var origin := body * Vector2(69.5, 4.5)
	var blast: float = float(p.blast) * float(p.vent)
	if blast > .001:
		for ring in range(6, 0, -1):
			canvas.draw_circle(origin, ring * 5.5, Color(.2, .8, 1, blast * .065) * tint)
		# Cold jet emerges from the original open mouth.
		for layer in range(3):
			var points := PackedVector2Array()
			for side in [-1.0, 1.0]:
				for j in range(37):
					var u := float(j if side < 0 else 36 - j) / 36
					var spread := (19 + u * 75) * sin((.16 + .84 * u) * PI) * blast * (1 - layer * .24)
					var flow := sin(u * 22 - time * 15) * u * 12 * blast
					points.append(origin + Vector2(flow + side * spread, u * (350 - layer * 22) * blast))
			var color: Color = [Color(.08, .48, .9, .30), Color(.3, .85, 1, .38), Color(.85, .98, 1, .56)][layer]
			canvas.draw_colored_polygon(points, color * tint)
		for i in range(26):
			var age := fposmod(time * 1.25 + float(i) * .137, 1)
			var side := sin(i * 4.7)
			var at := origin + Vector2(side * (12 + age * 95), age * 340) * blast
			canvas.draw_circle(at, (4 + age * 19) * blast, Color(.7, .92, 1, sin(age * PI) * blast * .14) * tint)
		for i in range(42):
			var age := fposmod(time * 1.9 + float(i) * .173, 1)
			var at := origin + Vector2(sin(i * 7.1) * (14 + age * 120), age * 363) * blast
			canvas.draw_line(at, at + Vector2(sin(i) * 3, 7), Color(.85, .98, 1, sin(age * PI) * blast) * tint, 1.5, true)
		# Each ice shard has constant geometry and travels ballistically.
		for i in range(8):
			var age := fposmod(time * .95 + float(i) * .127, 1)
			var side := sin(float(i) * 5.3)
			var at := origin + Vector2(side * age * 110, age * 330)
			canvas.draw_set_transform_matrix(root * Transform2D(PI + side * .35 + age * side, at))
			canvas.draw_polygon(polygon("shard"), PackedColorArray([Color(1, 1, 1, blast * sin(age * PI)) * tint]), uvs("shard"), tex)
		canvas.draw_set_transform_matrix(root)
	var impact: float = p.impact
	if impact > 0 and impact < 1:
		for i in range(9):
			var side := (float(i) - 4) / 4
			var at := Vector2(side * impact * 170, 202 - sin(impact * PI) * (35 + (1 - absf(side)) * 25))
			canvas.draw_set_transform_matrix(root * Transform2D(side * impact * 5, at))
			canvas.draw_polygon(polygon("shard"), PackedColorArray([Color(1, 1, 1, 1 - impact) * tint]), uvs("shard"), tex)
		canvas.draw_set_transform_matrix(root)
