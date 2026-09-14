class_name MiniPrensaPuppet
extends RefCounted
## Independent rigid pieces. Animation changes only translation and rotation.
const Eyes = preload("res://art/boss_eyes.gd")
const PressureFlame = preload("res://art/press_flame.gd")
enum Action { WALK, ATTACK, POWER, IDLE }
const ATLAS_PATH := "res://assets/art/mini_prensa_rigid_atlas.png"
const WALK_DURATION := 1.2
const ATTACK_DURATION := 1.7
const POWER_DURATION := 2.6
const IMPACT_TIME := .88
const PARTS_PATH := "res://assets/art/mini_prensa_rigid_parts.json"
static var _parts: Dictionary = {}
static func parts() -> Dictionary:
	if _parts.is_empty():
		_parts = JSON.parse_string(FileAccess.get_file_as_string(PARTS_PATH))
	return _parts

static func polygon(key: String) -> PackedVector2Array:
	var def: Dictionary = parts()[key]
	var pivot := Vector2(def.pivot[0], def.pivot[1])
	var out := PackedVector2Array()
	for xy in def.points:
		out.append((Vector2(xy[0], xy[1]) - pivot) * float(def.fit))
	return out

static func uvs(key: String, normalized: bool = true) -> PackedVector2Array:
	var out := PackedVector2Array()
	for xy in parts()[key].points:
		out.append(Vector2(xy[0], xy[1]) / (1254.0 if normalized else 1.0))
	return out

static func _curve(t: float, keys: Array) -> float:
	for i in range(1, keys.size()):
		if t <= keys[i].x:
			var a: Vector2 = keys[i - 1]
			var b: Vector2 = keys[i]
			return lerpf(a.y, b.y, smoothstep(0, 1, (t - a.x) / (b.x - a.x)))
	return keys.back().y

static func compute_pose(action: Action, playhead: float) -> Dictionary:
	var p := {"body_offset": Vector2.ZERO, "body_tilt": 0.0, "jaw": 0.0,
		"foot_l_offset": Vector2.ZERO, "foot_r_offset": Vector2.ZERO, "foot_l_rot": 0.0, "foot_r_rot": 0.0,
		"core_glow": 0.0, "blast": 0.0, "hatch_open": 0.0, "impact": 0.0, "time": playhead, "action": action}
	match action:
		Action.WALK:
			var phase := fposmod(playhead, WALK_DURATION) / WALK_DURATION
			var s := sin(phase * TAU)
			p.body_offset = Vector2(s * 3, -s * s * 5)
			p.body_tilt = s * .018
			p.jaw = -2.0 * (1.0 - cos(phase * TAU * 2))
			p.foot_l_offset = _step(phase)
			p.foot_r_offset = _step(fposmod(phase + .5, 1))
			p.foot_l_rot = -.07 * pow(maxf(0, sin(phase * TAU)), 2)
			p.foot_r_rot = .07 * pow(maxf(0, -sin(phase * TAU)), 2)
		Action.ATTACK:
			var t := fposmod(playhead, ATTACK_DURATION)
			p.jaw = _curve(t, [Vector2(0, 0), Vector2(.70, -36), Vector2(.76, -36), Vector2(.88, 56), Vector2(.98, 46), Vector2(1.22, -6), Vector2(1.7, 0)])
			p.body_offset.y = _curve(t, [Vector2(0, 0), Vector2(.70, 7), Vector2(.76, 7), Vector2(.88, 16), Vector2(.98, 12), Vector2(1.22, -3), Vector2(1.7, 0)])
			p.body_tilt = _curve(t, [Vector2(0, 0), Vector2(.7, -.025), Vector2(.88, .025), Vector2(1.22, -.008), Vector2(1.7, 0)])
			p.core_glow = _curve(t, [Vector2(0, 0), Vector2(.7, .6), Vector2(.88, 1), Vector2(1.2, 0), Vector2(1.7, 0)])
			p.impact = clampf((t - IMPACT_TIME) / .48, 0, 1)
		Action.POWER:
			var t := fposmod(playhead, POWER_DURATION)
			p.jaw = _curve(t, [Vector2(0, 0), Vector2(.72, -28), Vector2(1.05, -32), Vector2(1.85, -32), Vector2(2.6, 0)])
			p.core_glow = _curve(t, [Vector2(0, 0), Vector2(.7, 1), Vector2(1, 1.5), Vector2(1.8, 1.2), Vector2(2.6, 0)])
			p.hatch_open = _curve(t, [Vector2(0, 0), Vector2(.22, 0), Vector2(.74, 1), Vector2(2.24, 1), Vector2(2.6, 0)])
			p.blast = _curve(t, [Vector2(0, 0), Vector2(.82, 0), Vector2(1.06, 1), Vector2(1.72, 1), Vector2(2.18, 0), Vector2(2.6, 0)])
			p.body_offset.y = _curve(t, [Vector2(0, 0), Vector2(.8, -4), Vector2(1.08, -15), Vector2(1.8, -10), Vector2(2.6, 0)])
			p.body_tilt = sin(t * 22) * .006 * p.blast
		Action.IDLE:
			p.jaw = -1.5 * (1 - cos(playhead * 2.5))
	Eyes.animate(p, playhead, [WALK_DURATION, ATTACK_DURATION, POWER_DURATION, 3.6][action], IMPACT_TIME)
	return p

static func _step(phase: float) -> Vector2:
	if phase < .5:
		var t := phase * 2
		return Vector2(lerpf(-7, 7, smoothstep(0, 1, t)), -11 * pow(sin(t * PI), 2))
	return Vector2(lerpf(7, -7, smoothstep(0, 1, (phase - .5) * 2)), 0)

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
	var head := body * Transform2D(0, Vector2(0, -115 + float(p.jaw)))
	var left := Transform2D(float(p.foot_l_rot), Vector2(-100, 142) + (p.foot_l_offset as Vector2))
	var right := Transform2D(float(p.foot_r_rot), Vector2(100, 155) + (p.foot_r_offset as Vector2))
	_add(out, "Backplate", "back", body * Transform2D(0, Vector2(-2, -10)), Vector2(0, 0), exploded)
	var hatch_angle := -2.6 * float(p.hatch_open)
	var hatch_hinge := Vector2(31, -9.25)
	_add(out, "CoreHatch", "hatch", body * Transform2D(hatch_angle, hatch_hinge), Vector2(115, -15), exploded)
	_add(out, "LeftFoot", "foot_l", left, Vector2(-120, 130), exploded)
	_add(out, "RightFoot", "foot_r", right, Vector2(120, 130), exploded)
	_add(out, "LeftAnkle", "hinge", body * Transform2D(0, Vector2(-100, 143)), Vector2(-120, 75), exploded)
	_add(out, "RightAnkle", "hinge", body * Transform2D(0, Vector2(100, 151)), Vector2(120, 75), exploded)
	# Rods translate with the head. Sleeves rotate at their base; artwork is never stretched.
	for side in [-1.0, 1.0]:
		var base := body * Vector2(side * 126, 139)
		var tip := head * Vector2(side * 126, 10)
		var angle := (base - tip).angle() - PI * .5
		var label := "Left" if side < 0 else "Right"
		_add(out, label + "Rod", "rod", Transform2D(angle, tip), Vector2(side * 160, -50), exploded)
		_add(out, label + "Sleeve", "sleeve", Transform2D(angle, base), Vector2(side * 210, 60), exploded)
	_add(out, "LowerJaw", "chassis", body * Transform2D(0, Vector2(0, 112)), Vector2(0, 145), exploded)
	_add(out, "UpperJaw", "head", head, Vector2(0, -125), exploded)
	_add(out, "PressureCap", "cap", head * Transform2D(0, Vector2(-10, -102)), Vector2(0, -190), exploded)
	return out

static func _add(out: Array[Dictionary], name: String, part: String, xf: Transform2D, offset: Vector2, exploded: float) -> void:
	xf.origin += offset * exploded
	out.append({"name": name, "part": part, "transform": xf})

static func draw_puppet(canvas: CanvasItem, tex: Texture2D, center: Vector2, scale_factor: float, pose: Dictionary, tint: Color = Color.WHITE, exploded: float = 0.0) -> void:
	if tex == null or pose.is_empty():
		return
	PressureFlame.hide_all(canvas)
	var root := Transform2D(0, Vector2.ONE * scale_factor, 0, center)
	for item in frames(pose, exploded):
		if item.name == "CoreHatch" and exploded < .01:
			canvas.draw_set_transform_matrix(root)
			draw_core_port(canvas, pose, tint)
		canvas.draw_set_transform_matrix(root * (item.transform as Transform2D))
		canvas.draw_polygon(polygon(item.part), PackedColorArray([tint]), uvs(item.part), tex)
	canvas.draw_set_transform_matrix(root)
	if exploded < .01:
		Eyes.draw_press(canvas, pose, root, tint)
		_draw_energy(canvas, pose, tint, root)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var impact: float = pose.impact
	if impact > 0 and impact < 1 and exploded < .01:
		canvas.draw_set_transform(center + Vector2(0, 223) * scale_factor, 0, Vector2(scale_factor, scale_factor * .23))
		canvas.draw_arc(Vector2.ZERO, 40 + impact * 230, 0, TAU, 80, Color(1, .68, .2, (1 - impact) * .8) * tint, 5 * (1 - impact), true)
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func core_origin(pose: Dictionary) -> Vector2:
	return Transform2D(float(pose.body_tilt), pose.body_offset) * Vector2(-6.5, -9.25)

static func draw_core_port(canvas: CanvasItem, pose: Dictionary, tint: Color = Color.WHITE) -> void:
	var origin := core_origin(pose)
	var heat := float(pose.core_glow) * float(pose.hatch_open)
	canvas.draw_circle(origin, 38.5, Color("#211811") * tint)
	canvas.draw_circle(origin, 35.0, Color("#080607") * tint)
	canvas.draw_arc(origin, 35.0, 0, TAU, 64, Color(.8, .25, .04, heat * .55) * tint, 3.0, true)
	for ring in range(5, 0, -1):
		canvas.draw_circle(origin, ring * 5.7, Color(1, .2 + ring * .035, .015, heat * .09) * tint)

static func _draw_energy(canvas: CanvasItem, pose: Dictionary, tint: Color, root: Transform2D = Transform2D.IDENTITY) -> void:
	PressureFlame.hide_all(canvas)
	var blast: float = float(pose.blast) * float(pose.hatch_open)
	if blast <= .001:
		return
	var origin := core_origin(pose)
	PressureFlame.sync(canvas, pose, origin, root)
	# Fewer embers, emitted from the recessed throat and carried by the flow.
	for i in range(24):
		var age := fposmod(float(pose.time) * 1.3 + float(i) * .173, 1)
		var side := sin(float(i) * 5.1)
		var at := origin + Vector2(side * age * age * 74, 10 + age * 320)
		canvas.draw_line(at, at + Vector2(side * 2, 4 + age * 7), Color(1, .62 + age*.3, .16, sin(age * PI) * blast * .65) * tint, 1.2, true)
