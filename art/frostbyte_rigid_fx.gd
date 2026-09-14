extends Node2D
const Rig = preload("res://art/frostbyte_puppet.gd")
var _tex: Texture2D
func _ready() -> void:
	_tex = load(Rig.ATLAS_PATH)
func _draw() -> void:
	var rig := get_parent()
	if not rig.pose.is_empty() and not rig.exploded:
		Rig.draw_effects(self, rig.pose, _tex)
