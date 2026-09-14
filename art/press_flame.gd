class_name PressureFlameEmitter
extends Node2D
const FIRE_SHADER = preload("res://art/press_flame.gdshader")
var _material: ShaderMaterial
var _time := 0.0
var _power := 0.0
func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = FIRE_SHADER
	material = _material
	z_index = 4
func update_flame(time: float, strength: float) -> void:
	_time = time
	_power = strength
	visible = strength > .001
	_material.set_shader_parameter("playhead", time)
	_material.set_shader_parameter("intensity", strength)
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(-105, -35, 210, 405), Color.WHITE)
static func sync(canvas: CanvasItem, pose: Dictionary, origin: Vector2, root: Transform2D) -> void:
	var name := "PressureFlame_%d" % int(pose.action)
	var emitter := canvas.get_node_or_null(NodePath(name)) as Node2D
	if emitter == null:
		emitter = load("res://art/press_flame.gd").new()
		emitter.name = name
		canvas.add_child(emitter)
	emitter.transform = root * Transform2D(float(pose.body_tilt), origin)
	emitter.update_flame(float(pose.time), float(pose.blast) * float(pose.hatch_open))
static func hide_all(canvas: CanvasItem) -> void:
	for child in canvas.get_children():
		if child.name.begins_with("PressureFlame_"):
			child.visible = false
