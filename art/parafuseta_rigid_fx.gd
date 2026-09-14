@tool
extends Node2D
const Rig = preload("res://art/parafuseta_puppet.gd")
func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _draw() -> void:
	Rig.Energy.hide_all(self)
	var parent := get_parent()
	if not parent.pose.is_empty() and not parent.exploded:
		Rig.draw_details(self,parent.pose,load(Rig.ATLAS_PATH))