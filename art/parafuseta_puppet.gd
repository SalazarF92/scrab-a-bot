class_name ParafusetaPuppet
extends RefCounted
const Eyes = preload("res://art/boss_eyes.gd")
const Mouth = preload("res://art/creature_mouth.gd")
const Energy = preload("res://art/creature_energy.gd")
enum Action { WALK, ATTACK, POWER, IDLE }
const ATLAS_PATH := "res://assets/art/enemies_atlas.png"
const PARTS_PATH := "res://assets/art/parafuseta_mouth_parts.json"
const WALK_DURATION := 1.4
const ATTACK_DURATION := 1.9
const POWER_DURATION := 3.2
const IMPACT_TIME := .9
## Olho e boca montados na cabeca; lidos tambem pelo desenho do combate.
const EYE_PUPIL := Vector2(247,175)
const EYE_RADIUS := 8.0
const MOUTH_SPECIES := 0
static func eye_frame(p: Dictionary) -> Transform2D:
	return Transform2D(p.body_tilt,p.body_offset)*joint(p.head,Vector2(159,177))*Transform2D(0,-Vector2(155,200))
static var _parts: Dictionary = {}
static func parts() -> Dictionary:
	if _parts.is_empty():
		_parts = JSON.parse_string(FileAccess.get_file_as_string(PARTS_PATH))
	return _parts
## Geometria estatica: construida uma vez por peca. Antes era refeita do JSON a
## cada quadro, o que dominava o custo de desenho do rig.
static var _poly_cache: Dictionary = {}
static var _uv_cache: Dictionary = {}
static func polygon(key: String) -> PackedVector2Array:
	if _poly_cache.has(key):
		return _poly_cache[key]
	var def: Dictionary = parts()[key]
	var out := PackedVector2Array()
	for xy in def.points:
		out.append((Vector2(xy[0], xy[1]) - Vector2(def.pivot[0], def.pivot[1])) * float(def.fit))
	_poly_cache[key] = out
	return out
static func uvs(key: String, normalized: bool = true) -> PackedVector2Array:
	var cache_key := key if normalized else key + "#px"
	if _uv_cache.has(cache_key):
		return _uv_cache[cache_key]
	var out := PackedVector2Array()
	for xy in parts()[key].points:
		out.append(Vector2(xy[0], xy[1]) / (1254.0 if normalized else 1.0))
	_uv_cache[cache_key] = out
	return out
static func curve(t: float, keys: Array) -> float:
	for i in range(1, keys.size()):
		var a: Vector2 = keys[i - 1]
		var b: Vector2 = keys[i]
		if t <= b.x:
			return lerpf(a.y, b.y, smoothstep(0, 1, (t - a.x) / (b.x - a.x)))
	return keys.back().y
static func compute_pose(action: Action, playhead: float) -> Dictionary:
	var duration: float = [WALK_DURATION,ATTACK_DURATION,POWER_DURATION,3.6][action]
	var t := fposmod(playhead,duration)
	var wave := sin(t/duration*TAU)
	var p := {"time":playhead,"action":action,"body_offset":Vector2.ZERO,"body_tilt":0.0,"head":0.0,"jaw":0.0,"left":0.0,"right":0.0,"knee_l":0.0,"knee_r":0.0,"foot":0.0,"blast":0.0,"vent":1.0}
	match action:
		Action.WALK:
			p.left = wave*.13
			p.right = -wave*.13
			p.knee_l = -wave*.19
			p.knee_r = wave*.19
			p.foot = wave*.08
			p.body_offset = Vector2(wave*2,-pow(wave,2)*3)
			p.head = -wave*.025
		Action.ATTACK:
			var recoil := curve(t,[Vector2(0,0),Vector2(.6,-1),Vector2(.72,-1),Vector2(.9,1),Vector2(1.05,.75),Vector2(1.9,0)])
			p.body_tilt = recoil*.09
			p.body_offset = Vector2(recoil*13,recoil*5)
			p.head = recoil*.13
			p.jaw = curve(t,[Vector2(0,0),Vector2(.6,.18),Vector2(.9,-.08),Vector2(1.05,-.06),Vector2(1.9,0)])
			p.left = -recoil*.08
			p.right = recoil*.08
		Action.POWER:
			p.blast = curve(t,[Vector2(0,0),Vector2(.65,0),Vector2(.95,1),Vector2(2.3,1),Vector2(2.8,0),Vector2(3.2,0)])
			var brace := curve(t,[Vector2(0,0),Vector2(.6,1),Vector2(2.8,1),Vector2(3.2,0)])
			p.left = brace*.1
			p.right = -brace*.1
			p.knee_l = -brace*.14
			p.knee_r = brace*.14
			p.head = -brace*.03
			p.jaw = brace*.06
			p.body_offset = Vector2(sin(t*28)*p.blast*.6,-brace*3)
		Action.IDLE:
			p.head = wave*.012
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
	var pivot := at-Vector2(155,200)
	return Transform2D(angle,pivot-pivot.rotated(angle))
## Transformacao de cada grupo de pecas. "__body" vale para as pecas sem junta
## propria. CreatureRigView desenha pecas consecutivas do mesmo grupo como uma malha.
static func group_transforms(p: Dictionary) -> Dictionary:
	var body := Transform2D(p.body_tilt,p.body_offset)
	var left := body*joint(p.left,Vector2(100,237))
	var right := body*joint(p.right,Vector2(184,276))
	return {"__body":body,"head":body*joint(p.head,Vector2(159,177)),"jaw":body*joint(p.jaw,Vector2(148,235)),"arm_l":left,"leg_l":left*joint(p.knee_l,Vector2(78,293)),"arm_r":right,"leg_r":right*joint(p.knee_r,Vector2(247,285)),"foot":body*joint(p.foot,Vector2(113,318))}
static func frames(p: Dictionary,exploded: float = 0) -> Array[Dictionary]:
	var transforms := group_transforms(p)
	var body: Transform2D = transforms["__body"]
	var out: Array[Dictionary] = []
	for key in parts():
		var xf: Transform2D = transforms.get(parts()[key].get("group",key),body)
		if exploded > 0:
			var mid := Vector2.ZERO
			for v in polygon(key):
				mid += v
			xf.origin += mid/float(polygon(key).size())*.65*exploded
		out.append({"name":key,"part":key,"transform":xf})
	return out
static func draw_puppet(canvas: CanvasItem,tex: Texture2D,center: Vector2,scale_factor: float,p: Dictionary,tint: Color = Color.WHITE,exploded: float = 0) -> void:
	Energy.hide_all(canvas,0)
	var root := Transform2D(0,Vector2.ONE*scale_factor,0,center)
	for item in frames(p,exploded):
		canvas.draw_set_transform_matrix(root*item.transform)
		canvas.draw_polygon(polygon(item.part),PackedColorArray([tint]),uvs(item.part),tex)
	if exploded < .01:
		draw_details(canvas,p,tex,tint,root)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
static func draw_details(canvas: CanvasItem,p: Dictionary,tex: Texture2D,tint: Color = Color.WHITE,root: Transform2D = Transform2D.IDENTITY) -> void:
	var body := Transform2D(p.body_tilt,p.body_offset)
	canvas.draw_set_transform_matrix(root*eye_frame(p))
	Eyes._eye(canvas,EYE_PUPIL,EYE_RADIUS,p.gaze,tint,tex)
	Mouth.draw(canvas,0,p,root,tint)
	Energy.sync(canvas,0,p,root*body*Transform2D(.55,Vector2(29,48)))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
