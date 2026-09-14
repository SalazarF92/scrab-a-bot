extends SceneTree
const Rig = preload("res://art/rato_morto_puppet.gd")
func _init() -> void:
	var root := Node2D.new()
	root.name = "RatoMortoRigid"
	root.set_script(load("res://art/rato_morto_rigid.gd"))
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
	effects.set_script(load("res://art/rato_morto_rigid_fx.gd"))
	root.add_child(effects)
	effects.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	var error := ResourceSaver.save(packed, "res://scenes/rato_morto_rigid.tscn")
	root.free()
	quit(error)
