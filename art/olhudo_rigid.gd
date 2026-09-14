extends Node2D
enum Action { WATCH, ATTACK, POWER }
const ATLAS := "res://assets/art/olhudo_components.png"
const CONTOURS_PATH := "res://assets/art/olhudo_contours.json"
const DURATION := 3.6
const BASE_JOINT := Vector2(50,100)
const LOWER_END := Vector2(177,-175)*.24
const UPPER_END := Vector2(-275,0)*.20
## Centro da lente no referencial da carcaca: origem do feixe.
const LENS := Vector2(-90,-71)
const PIECES := ["cable","base","lower","upper","housing","eye","pupil","lid_top","lid_bottom"]
## O retangulo do laser cresce com o alcance; o feixe e gerado no shader em
## unidades do rig, entao nada e esticado.
const LASER_MIN_EXTENT := 480.0
@export var action: Action = Action.WATCH
@export var playing := true
@export var laser_reach := 235.0
@export var laser_angle := 2.20
var playhead := 0.0
var pose := {}
var pieces := {}
var laser: Polygon2D
var contours: Dictionary
var _laser_extent := LASER_MIN_EXTENT
## Contornos e geometria estaticos, lidos uma vez para todas as instancias. No
## combate cada Olhudo do pool monta o proprio rig sem reler o JSON.
static var _contours_cache: Dictionary = {}
static var _geometry_cache: Dictionary = {}
static var _bounds := Rect2()
static func load_contours() -> Dictionary:
	if _contours_cache.is_empty():
		_contours_cache = JSON.parse_string(FileAccess.get_file_as_string(CONTOURS_PATH))
	return _contours_cache
static func piece_geometry(name: String) -> Array:
	if not _geometry_cache.has(name):
		var vertices := PackedVector2Array(); var uv := PackedVector2Array()
		for xy in load_contours()[name]:
			var source := Vector2(xy[0],xy[1]); uv.append(source)
			vertices.append(component_point(name,source))
		_geometry_cache[name] = [vertices,uv]
	return _geometry_cache[name]
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	contours = load_contours()
	for name in PIECES:
		var part := Polygon2D.new(); part.name = name
		part.texture = load(ATLAS)
		var geometry := piece_geometry(name)
		part.polygon = geometry[0]; part.uv = geometry[1]
		if name.begins_with("lid_"):
			var material := ShaderMaterial.new(); material.shader = preload("res://art/olhudo_lid.gdshader")
			part.material = material
		add_child(part); pieces[name] = part
	laser = Polygon2D.new(); laser.name = "Laser"
	laser.polygon = _laser_polygon(LASER_MIN_EXTENT)
	var material := ShaderMaterial.new(); material.shader = preload("res://art/olhudo_laser.gdshader")
	laser.material = material; laser.z_index = 10; add_child(laser)
	apply_pose(compute_pose(action,playhead))
static func _laser_polygon(extent: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-45,-70),Vector2(extent,-70),Vector2(extent,70),Vector2(-45,70)])
static func component_point(name: String,p: Vector2) -> Vector2:
	match name:
		"base": return (p-Vector2(400,610))*.42
		"lower": return (p-Vector2(585,720))*.24
		"upper": return (p-Vector2(1195,635))*.20
		"eye": p = (p-Vector2(663,259))*Vector2(.60,.85)+Vector2(157,253)
		"pupil": p = (p-Vector2(1068,260))*Vector2(.40,.42)+Vector2(150,253)
		"lid_top": p += Vector2(-10,-843)
		"lid_bottom": p += Vector2(-467,-720)
		"cable": return (p-Vector2(1175,925))*Vector2(-.34,.34)
	return (p-Vector2(330,395))*.5
static func curve(t: float,keys: Array) -> float:
	for i in range(1,keys.size()):
		if t <= keys[i].x: return lerpf(keys[i-1].y,keys[i].y,smoothstep(keys[i-1].x,keys[i].x,t))
	return keys.back().y
static func compute_pose(mode: int,time: float) -> Dictionary:
	var t := fposmod(time,DURATION); var phase := t/DURATION*TAU
	var p := {"time":time,"lower":.055*sin(phase),"upper":-.08*sin(phase),"head":.075*sin(phase),"cable":.025*sin(phase+.3),"gaze":Vector2(5*sin(phase),2*cos(phase)),"blink":0.0,"charge":0.0,"emission":0.0}
	p.blink = curve(t,[Vector2(0,0),Vector2(2.8,0),Vector2(2.94,1),Vector2(3.02,1),Vector2(3.18,0),Vector2(3.6,0)])
	if mode == Action.ATTACK:
		# Load the linkage slowly, then release it in 110 ms. The complete
		# joint disks stay connected; no body translation or scale substitutes
		# for the articulation. Recovery contains an opposing spring rebound.
		var drive := curve(t,[Vector2(0,0),Vector2(.18,0),Vector2(.62,-.65),Vector2(.74,-.65),Vector2(.85,1.15),Vector2(.94,1.08),Vector2(1.12,.68),Vector2(1.40,-.20),Vector2(1.68,.08),Vector2(2.02,0),Vector2(3.6,0)])
		p.lower = -.55*drive; p.upper = .90*drive; p.head = -.70*drive
		# Unfold the support toward the target; counter-rotate the head.
		# Each link keeps its original length and shared joint position.
		var extension := smoothstep(0.0,1.15,maxf(drive,0.0))
		p.lower -= .90*extension
		p.upper += .40*extension
		p.head += .50*extension
		p.cable = curve(t,[Vector2(0,0),Vector2(.74,-.09),Vector2(.88,.25),Vector2(1.10,-.16),Vector2(1.45,.10),Vector2(1.9,0),Vector2(3.6,0)])
		p.gaze = Vector2(-8,2)
		p.blink = curve(t,[Vector2(0,0),Vector2(.40,.38),Vector2(.74,.55),Vector2(.81,0),Vector2(1.1,0),Vector2(1.4,.25),Vector2(1.8,0),Vector2(2.8,0),Vector2(2.94,1),Vector2(3.02,1),Vector2(3.18,0),Vector2(3.6,0)])
	if mode == Action.POWER:
		var lock := curve(t,[Vector2(0,0),Vector2(.6,1),Vector2(2.2,1),Vector2(2.8,0),Vector2(3.6,0)])
		p.lower = lerpf(p.lower,-.06,lock); p.upper = lerpf(p.upper,.1,lock); p.head = lerpf(p.head,-.035,lock)
		p.gaze = p.gaze.lerp(Vector2(-5,1),lock)
		p.charge = curve(t,[Vector2(0,0),Vector2(.6,0),Vector2(1.4,1),Vector2(1.45,0),Vector2(3.6,0)])
		p.emission = curve(t,[Vector2(0,0),Vector2(1.4,0),Vector2(1.44,1),Vector2(1.95,1),Vector2(2.13,0),Vector2(3.6,0)])
	return p
## Transicao continua entre acoes: interpola angulos, olhar e intensidades.
static func blend_pose(a: Dictionary,b: Dictionary,weight: float) -> Dictionary:
	var p := b.duplicate()
	for key in b:
		if a.has(key):
			if b[key] is Vector2: p[key] = (a[key] as Vector2).lerp(b[key],weight)
			elif b[key] is float: p[key] = lerpf(a[key],b[key],weight)
	return p
static func transforms(p: Dictionary) -> Dictionary:
	var lower := Transform2D(p.lower,BASE_JOINT)
	var upper := lower*Transform2D(p.upper,LOWER_END)
	var head := upper*Transform2D(p.head,UPPER_END)
	return {"base":Transform2D(0,BASE_JOINT),"lower":lower,"upper":upper,"housing":head,"eye":head,"pupil":head*Transform2D(0,p.gaze),"cable":head*Transform2D(.12+p.cable,Vector2(52,-73)),"lid_top":head*Transform2D(0,lid_slide(true,p.blink)),"lid_bottom":head*Transform2D(0,lid_slide(false,p.blink))}
static func lid_slide(top: bool,blink: float) -> Vector2:
	return Vector2(0,lerpf(-72.5,35.0,blink) if top else lerpf(65.0,-35.0,blink))
## Limites do rig montado em repouso, para posicionar o Olhudo no combate.
static func rest_bounds() -> Rect2:
	if _bounds.has_area(): return _bounds
	var frames := transforms(compute_pose(Action.WATCH,0.0))
	var first := true
	for name in ["cable","base","lower","upper","housing"]:
		for v in piece_geometry(name)[0]:
			var point: Vector2 = frames[name]*v
			if first: _bounds = Rect2(point,Vector2.ZERO); first = false
			else: _bounds = _bounds.expand(point)
	return _bounds
func apply_pose(p: Dictionary) -> void:
	pose = p
	var frames := transforms(p)
	for name in pieces:
		pieces[name].transform = frames[name]
		if name.begins_with("lid_"):
			var offset := lid_slide(name == "lid_top",p.blink)
			pieces[name].material.set_shader_parameter("slide",offset)
	laser.transform = frames.housing*Transform2D(laser_angle,LENS+p.gaze)
	laser.visible = p.charge > .0001 or p.emission > .0001
	laser.material.set_shader_parameter("clock",p.time)
	laser.material.set_shader_parameter("charge",p.charge)
	laser.material.set_shader_parameter("emission",p.emission)
	laser.material.set_shader_parameter("reach",laser_reach)
	var needed := maxf(LASER_MIN_EXTENT,laser_reach+30.0)
	if absf(needed-_laser_extent) > 8.0:
		_laser_extent = needed
		laser.polygon = _laser_polygon(needed)
## Combate: aponta o feixe para um ponto no referencial do rig (alvo travado
## ou parede que interceptou o raio) e aplica a pose.
func apply_pose_aimed(p: Dictionary,local_target: Vector2) -> void:
	var frames := transforms(p)
	var housing: Transform2D = frames.housing
	var lens: Vector2 = housing*(LENS+p.gaze)
	var offset := local_target-lens
	laser_reach = maxf(offset.length(),1.0)
	laser_angle = offset.angle()-housing.get_rotation()
	apply_pose(p)
## Posicao da lente no referencial do rig, para o aviso do combate sair dela.
static func lens_point(p: Dictionary) -> Vector2:
	return (transforms(p).housing as Transform2D)*(LENS+p.gaze)
func _process(delta: float) -> void:
	if playing:
		playhead += delta; apply_pose(compute_pose(action,playhead))
