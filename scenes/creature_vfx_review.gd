extends Node2D
const RIGS := [preload("res://art/parafuseta_puppet.gd"),preload("res://art/rato_morto_puppet.gd")]
var actors: Array[Node2D] = []
var playhead := 0.0
var paused := false
var slow := false
var frame := 0
var capture := false
var verify := false
var baseline := PackedByteArray()
func _ready() -> void:
	get_viewport().content_scale_size = Vector2i(1280,720)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for argument in OS.get_cmdline_user_args():
		if argument == "--capture-vfx": capture = true
		if argument == "--verify-vfx": verify = true
		if argument.begins_with("--time="):
			playhead = argument.trim_prefix("--time=").to_float()
			paused = true
	if verify:
		playhead = 1.6
		paused = true
	for i in 2:
		var name: String = ["parafuseta","rato_morto"][i]
		var actor := load("res://scenes/%s_rigid.tscn" % name).instantiate() as Node2D
		actor.playing = false
		actor.position = Vector2(350,340) if i == 0 else Vector2(955,465)
		actor.action = 2
		add_child(actor)
		actors.append(actor)
func _process(delta: float) -> void:
	frame += 1
	if verify:
		playhead = 2.2 if frame >= 65 and frame <= 100 else 1.6
	if not paused:
		playhead += delta*(.25 if slow else 1.0)
	for i in 2:
		var action := 0 if verify and frame >= 105 else 2
		actors[i].apply_pose(RIGS[i].compute_pose(action,playhead))
	queue_redraw()
	if capture and frame == 4:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/visual/vfx-revisao.png")
		get_tree().quit()
	if verify and frame in [4,64,104,108]:
		await RenderingServer.frame_post_draw
		if frame == 4:
			baseline = get_viewport().get_texture().get_image().get_data()
		elif frame in [64,104]:
			if baseline != get_viewport().get_texture().get_image().get_data():
				push_error("VFX changes visually for an identical playhead during pause or replay")
				get_tree().quit(1)
		else:
			for actor in actors:
				for child in actor.get_node("Effects").get_children():
					if child.name.begins_with("CreatureEnergy_") and child.visible:
						push_error("Power VFX remains visible after switching to walk")
						get_tree().quit(1)
						return
			print("VFX integration: native scenes render, pause and replay identical, action switch clears effects")
			get_tree().quit()
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE: paused = not paused
		KEY_S: slow = not slow
		KEY_R: playhead = 0
		KEY_ESCAPE: get_tree().quit()
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("#10191f"))
	draw_line(Vector2(640,105),Vector2(640,650),Color("#30414b"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(35,45),"SCRAP-A-BOT  /  PODERES",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color("#e3eff3"))
	draw_string(font,Vector2(0,90),"PARAFUSETA",HORIZONTAL_ALIGNMENT_CENTER,640,22,Color("#ffb865"))
	draw_string(font,Vector2(640,90),"RATO MORTO",HORIZONTAL_ALIGNMENT_CENTER,640,22,Color("#8ed7ff"))
	draw_string(font,Vector2(35,695),"ESPAÇO: pausar   ·   S: câmera lenta   ·   R: reiniciar",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#94acb9"))
