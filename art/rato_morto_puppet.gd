class_name RatoMortoPuppet
extends RefCounted
const Eyes = preload("res://art/boss_eyes.gd")
const Mouth = preload("res://art/creature_mouth.gd")
const Energy = preload("res://art/creature_energy.gd")
enum Action { WALK, ATTACK, POWER, IDLE }
const ATLAS_PATH := "res://assets/art/enemies_atlas.png"
const PARTS_PATH := "res://assets/art/rato_morto_mouth_parts.json"
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
static func compute_pose(action: Action,playhead: float) -> Dictionary:
	var duration: float = [WALK_DURATION,ATTACK_DURATION,POWER_DURATION,3.6][action]
	var t := fposmod(playhead,duration)
	var wave := sin(t/duration*TAU)
	var p := {"time":playhead,"action":action,"body_offset":Vector2.ZERO,"body_tilt":0.0,"jaw":0.0,"front":0.0,"back":0.0,"right":0.0,"tail":0.0,"blast":0.0,"vent":1.0}
	match action:
		Action.WALK:
			p.front = wave*.15
			p.back = -wave*.12
			p.right = -wave*.13
			p.tail = sin(t/duration*TAU+.5)*.035 - sin(.5)*.035
			p.body_offset = Vector2(wave*4,-wave*wave*3)
			p.body_tilt = wave*.014
		Action.ATTACK:
			var drive := curve(t,[Vector2(0,0),Vector2(.6,-1),Vector2(.72,-1),Vector2(.9,1),Vector2(1.05,.8),Vector2(1.9,0)])
			p.body_offset = Vector2(-drive*19,-maxf(0,drive)*6)
			p.body_tilt = -drive*.06
			p.jaw = curve(t,[Vector2(0,0),Vector2(.65,-.12),Vector2(.9,.07),Vector2(1.1,.04),Vector2(1.9,0)])
			p.front = drive*.12
			p.right = -drive*.08
			p.tail = -drive*.055
		Action.POWER:
			var brace := curve(t,[Vector2(0,0),Vector2(.6,1),Vector2(2.8,1),Vector2(3.2,0)])
			p.blast = curve(t,[Vector2(0,0),Vector2(.8,0),Vector2(1.05,1),Vector2(2.25,1),Vector2(2.7,0),Vector2(3.2,0)])
			p.tail = brace*.10
			p.front = brace*.07
			p.right = -brace*.06
			p.jaw = -brace*.045
			p.body_offset = Vector2(sin(t*24)*p.blast*.5,brace*2)
		Action.IDLE:
			p.tail = wave*.018
	p.jaw = 0.0
	p["mouth_open"] = Mouth.opening(action,playhead,duration)
	Eyes.animate(p,playhead,duration,IMPACT_TIME)
	return p
static func blend_pose(a: Dictionary,b: Dictionary,weight: float) -> Dictionary:
	var p := b.duplicate()
	for key in b:
		if a.has(key):
			if b[key] is Vector2:
				p[key] = (a[key] as Vector2).lerp(b[key],weight)
			elif b[key] is float:
				p[key] = lerpf(a[key],b[key],weight)
	return p
static func joint(angle: float,at: Vector2) -> Transform2D:
	var pivot := at-Vector2(484,220)
	return Transform2D(angle,pivot-pivot.rotated(angle))
static func frames(p: Dictionary,exploded: float = 0) -> Array[Dictionary]:
	var body := Transform2D(p.body_tilt,p.body_offset)
	var transforms := {"tail":body*joint(p.tail,Vector2(593,248)),"jaw":body*joint(p.jaw,Vector2(475,311)),"paw_front":body*joint(p.front,Vector2(373,342)),"paw_back":body*joint(p.back,Vector2(355,308)),"paw_right":body*joint(p.right,Vector2(570,316))}
	var out: Array[Dictionary] = []
	for key in parts():
		var xf: Transform2D = transforms.get(parts()[key].get("group",key),body)
		if exploded > 0:
			var mid := Vector2.ZERO
			for v in polygon(key):
				mid += v
			xf.origin += mid/float(polygon(key).size())*.7*exploded
		out.append({"name":key,"part":key,"transform":xf})
	return out
static func draw_puppet(canvas: CanvasItem,tex: Texture2D,center: Vector2,scale_factor: float,p: Dictionary,tint: Color = Color.WHITE,exploded: float = 0) -> void:
	Energy.hide_all(canvas,1)
	var root := Transform2D(0,Vector2.ONE*scale_factor,0,center)
	for item in frames(p,exploded):
		canvas.draw_set_transform_matrix(root*item.transform)
		canvas.draw_polygon(polygon(item.part),PackedColorArray([tint]),uvs(item.part),tex)
	if exploded < .01:
		draw_details(canvas,p,tex,tint,root)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
static func draw_details(canvas: CanvasItem,p: Dictionary,tex: Texture2D,tint: Color = Color.WHITE,root: Transform2D = Transform2D.IDENTITY) -> void:
	var body := Transform2D(p.body_tilt,p.body_offset)
	canvas.draw_set_transform_matrix(root*body*Transform2D(0,-Vector2(484,220)))
	Eyes._eye(canvas,Vector2(478,257),7,p.gaze,tint,tex)
	Mouth.draw(canvas,1,p,root,tint)
	var cable := body*joint(p.tail,Vector2(593,248))
	Energy.sync(canvas,1,p,root*cable*Transform2D(PI+.2,Vector2(612,120)-Vector2(484,220)))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)