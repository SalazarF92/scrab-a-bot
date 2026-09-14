extends SceneTree
const Rig = preload("res://art/parafuseta_puppet.gd")
func _init() -> void:
	var root := Node2D.new()
	root.name = "ParafusetaRigid"
	root.set_script(load("res://art/parafuseta_rigid.gd"))
	var tex := load(Rig.ATLAS_PATH) as Texture2D
	for item in Rig.frames(Rig.compute_pose(Rig.Action.IDLE, 0)):
		var node := Polygon2D.new()
		node.name = item.name
		node.polygon = Rig.polygon(item.part)
		node.uv = Rig.uvs(item.part, false)
		node.texture = tex
		if Rig.parts()[item.part].has("color"):
			node.texture = null
			node.color = Color(Rig.parts()[item.part].color)
		node.transform = item.transform
		root.add_child(node)
		node.owner = root
	var effects := Node2D.new()
	effects.name = "Effects"
	effects.set_script(load("res://art/parafuseta_rigid_fx.gd"))
	root.add_child(effects)
	effects.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	var error := ResourceSaver.save(packed, "res://scenes/parafuseta_rigid.tscn")
	root.free()
	quit(error)
