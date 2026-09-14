extends Node2D
const SHADER = preload("res://art/creature_energy.gdshader")
var shader_material: ShaderMaterial
func _init() -> void:
	shader_material = ShaderMaterial.new()
	shader_material.shader = SHADER
	material = shader_material
	z_index = 5
func _draw() -> void:
	draw_rect(Rect2(-115,-95,230,310),Color.WHITE)
static func hide_all(canvas: CanvasItem,boss: int = -1) -> void:
	var prefix := "CreatureEnergy_" if boss < 0 else "CreatureEnergy_%d_" % boss
	for child in canvas.get_children():
		if child.name.begins_with(prefix):
			child.visible = false
static func sync(canvas: CanvasItem,boss: int,p: Dictionary,xf: Transform2D) -> void:
	var key := "CreatureEnergy_%d_%d" % [boss,int(p.action)]
	var node := canvas.get_node_or_null(NodePath(key)) as Node2D
	if node == null:
		node = load("res://art/creature_energy.gd").new()
		node.name = key
		canvas.add_child(node)
	node.transform = xf
	var phase := fposmod(float(p.time), 3.2)
	var residual := smoothstep(2.2, 2.45, phase) * (1.0 - smoothstep(2.7, 3.12, phase)) if int(p.action) == 2 else 0.0
	var charge := smoothstep(.18,.68,phase)*(1.0-smoothstep(.80,1.05,phase)) if int(p.action) == 2 else 0.0
	node.visible = float(p.blast) > .001 or residual > .001 or charge > .001
	node.shader_material.set_shader_parameter("playhead",float(p.time))
	node.shader_material.set_shader_parameter("intensity",float(p.blast))
	node.shader_material.set_shader_parameter("species",boss)
	node.shader_material.set_shader_parameter("residual",residual)
	node.shader_material.set_shader_parameter("charge",charge)
	node.queue_redraw()
