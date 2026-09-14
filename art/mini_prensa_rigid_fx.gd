extends Node2D
const Rig = preload("res://art/mini_prensa_puppet.gd")
func _draw() -> void:
	Rig.PressureFlame.hide_all(self)
	var rig := get_parent()
	if not rig.pose.is_empty() and not rig.exploded:
		Rig._draw_energy(self, rig.pose, Color.WHITE)
