extends SceneTree
const Rig = preload("res://art/mini_prensa_puppet.gd")
func _init() -> void:
	var root := Node2D.new()
	root.name = "MiniPrensaRigid"
	root.set_script(load("res://art/mini_prensa_rigid.gd"))
	var tex := load(Rig.ATLAS_PATH) as Texture2D
	for item in Rig.frames(Rig.compute_pose(Rig.Action.IDLE, 0)):
		if item.name == "CoreHatch":
			var port := Node2D.new()
			port.name = "CorePort"
			port.set_script(load("res://art/mini_prensa_core_port.gd"))
			root.add_child(port)
			port.owner = root
		var node := Polygon2D.new()
		node.name = item.name
		node.polygon = Rig.polygon(item.part)
		node.uv = Rig.uvs(item.part, false)
		node.texture = tex
		node.transform = item.transform
		root.add_child(node)
		node.owner = root
	var eyes := Node2D.new()
	eyes.name = "Eyes"
	eyes.set_script(load("res://art/boss_eyes_node.gd"))
	eyes.boss = 0
	root.add_child(eyes)
	eyes.owner = root
	var effects := Node2D.new()
	effects.name = "Effects"
	effects.set_script(load("res://art/mini_prensa_rigid_fx.gd"))
	root.add_child(effects)
	effects.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	var error := ResourceSaver.save(packed, "res://scenes/mini_prensa_rigid.tscn")
	root.free()
	quit(error)
