extends Node2D
const Rig = preload("res://art/mini_prensa_puppet.gd")
func _draw() -> void:
	var rig := get_parent()
	if not rig.pose.is_empty() and not rig.exploded:
		Rig.draw_core_port(self, rig.pose)
