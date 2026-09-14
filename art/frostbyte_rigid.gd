@tool
extends Node2D
const Rig = preload("res://art/frostbyte_puppet.gd")
@export_enum("Walk", "Attack", "Power", "Idle") var action: int = 0
@export var playing := true
@export var exploded := false
var playhead := 0.0
var pose: Dictionary = {}
func _ready() -> void:
	apply_pose(Rig.compute_pose(action as Rig.Action, 0))
func _process(delta: float) -> void:
	if playing and not Engine.is_editor_hint():
		playhead += delta
		apply_pose(Rig.compute_pose(action as Rig.Action, playhead))
func apply_pose(value: Dictionary) -> void:
	pose = value
	for item in Rig.frames(pose, 1.0 if exploded else 0.0):
		var piece := get_node_or_null(NodePath(item.name)) as Polygon2D
		if piece != null:
			piece.transform = item.transform
	var eyes := get_node_or_null("Eyes") as Node2D
	if eyes != null:
		eyes.queue_redraw()
	var effects := get_node_or_null("Effects") as Node2D
	if effects != null:
		effects.queue_redraw()
