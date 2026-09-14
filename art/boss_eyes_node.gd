extends Node2D
@export_enum("Press", "Frostbyte") var boss: int = 0
const Eyes = preload("res://art/boss_eyes.gd")
func _draw() -> void:
	var rig := get_parent()
	if not rig.pose.is_empty() and not rig.exploded:
		if boss == 0:
			Eyes.draw_press(self, rig.pose, Transform2D.IDENTITY, Color.WHITE)
		else:
			Eyes.draw_frost(self, rig.pose, Transform2D.IDENTITY, Color.WHITE)
