@tool
extends Node2D
## Editable scene: thirteen independent Polygon2D sprites with fixed geometry.
const Rig = preload("res://art/mini_prensa_puppet.gd")
@export_enum("Walk", "Attack", "Power", "Idle") var action: int = 0
@export var playing := true
@export var exploded := false
var playhead := 0.0
var pose: Dictionary = {}
func _ready() -> void:
	apply_pose(Rig.compute_pose(action as Rig.Action, playhead))
func _process(delta: float) -> void:
	if playing and not Engine.is_editor_hint():
		playhead += delta
		apply_pose(Rig.compute_pose(action as Rig.Action, playhead))
func apply_pose(value: Dictionary) -> void:
	pose = value
	for item in Rig.frames(pose, 1.0 if exploded else 0.0):
		var part := get_node_or_null(NodePath(item.name)) as Polygon2D
		if part != null:
			part.transform = item.transform
	var port := get_node_or_null("CorePort") as Node2D
	if port != null:
		port.queue_redraw()
	var eyes := get_node_or_null("Eyes") as Node2D
	if eyes != null:
		eyes.queue_redraw()
	var effects := get_node_or_null("Effects") as Node2D
	if effects != null:
		effects.queue_redraw()
