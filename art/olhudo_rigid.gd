extends Node2D
enum Action { WATCH, ATTACK, POWER }
const ATLAS := "res://assets/art/olhudo_components.png"
const DURATION := 3.6
const BASE_JOINT := Vector2(50,100)
const LOWER_END := Vector2(177,-175)*.24
const UPPER_END := Vector2(-275,0)*.20
@export var action: Action = Action.WATCH
@export var playing := true
@export var laser_reach := 235.0
@export var laser_angle := 2.20
var playhead := 0.0
var pose := {}
var pieces := {}
var laser: Polygon2D
var contours: Dictionary
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	contours = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/olhudo_contours.json"))
	for name in ["cable","base","lower","upper","housing","eye","pupil","lid_top","lid_bottom"]:
		var part := Polygon2D.new(); part.name = name
		part.texture = load(ATLAS)
		var vertices := PackedVector2Array(); var uv := PackedVector2Array()
		for xy in contours[name]:
			var source := Vector2(xy[0],xy[1]); uv.append(source)
			vertices.append(component_point(name,source))
		part.polygon = vertices; part.uv = uv
		if name.begins_with("lid_"):
			var material := ShaderMaterial.new(); material.shader = preload("res://art/olhudo_lid.gdshader")
			part.material = material
		add_child(part); pieces[name] = part
	laser = Polygon2D.new(); laser.name = "Laser"
	laser.polygon = PackedVector2Array([Vector2(-45,-70),Vector2(480,-70),Vector2(480,70),Vector2(-45,70)])
	var material := ShaderMaterial.new(); material.shader = preload("res://art/olhudo_laser.gdshader")
	laser.material = material; laser.z_index = 10; add_child(laser)
	apply_pose(compute_pose(action,playhead))
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
static func transforms(p: Dictionary) -> Dictionary:
	var lower := Transform2D(p.lower,BASE_JOINT)
	var upper := lower*Transform2D(p.upper,LOWER_END)
	var head := upper*Transform2D(p.head,UPPER_END)
	return {"base":Transform2D(0,BASE_JOINT),"lower":lower,"upper":upper,"housing":head,"eye":head,"pupil":head*Transform2D(0,p.gaze),"cable":head*Transform2D(.12+p.cable,Vector2(52,-73)),"lid_top":head*Transform2D(0,lid_slide(true,p.blink)),"lid_bottom":head*Transform2D(0,lid_slide(false,p.blink))}
static func lid_slide(top: bool,blink: float) -> Vector2:
	return Vector2(0,lerpf(-72.5,35.0,blink) if top else lerpf(65.0,-35.0,blink))
func apply_pose(p: Dictionary) -> void:
	pose = p
	var frames := transforms(p)
	for name in pieces:
		pieces[name].transform = frames[name]
		if name.begins_with("lid_"):
			var offset := lid_slide(name == "lid_top",p.blink)
			pieces[name].material.set_shader_parameter("slide",offset)
	laser.transform = frames.housing*Transform2D(laser_angle,Vector2(-90,-71)+p.gaze)
	laser.visible = p.charge > .0001 or p.emission > .0001
	laser.material.set_shader_parameter("clock",p.time)
	laser.material.set_shader_parameter("charge",p.charge)
	laser.material.set_shader_parameter("emission",p.emission)
	laser.material.set_shader_parameter("reach",laser_reach)
func _process(delta: float) -> void:
	if playing:
		playhead += delta; apply_pose(compute_pose(action,playhead))
