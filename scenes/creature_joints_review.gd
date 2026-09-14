extends Node2D
const RIGS := [preload("res://art/parafuseta_puppet.gd"),preload("res://art/rato_morto_puppet.gd")]
var actors: Array[Node2D] = []
var time := 0.0
var action := 0
var paused := false
var capture := false
var frame := 0
var cycle := false
func _ready() -> void:
	get_viewport().content_scale_size = Vector2i(1280,720)
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture-joints": capture = true
		if arg == "--record-joints": cycle = true
		if arg.begins_with("--time="):
			time = arg.trim_prefix("--time=").to_float()
			paused = true
		if arg.begins_with("--action="): action = arg.trim_prefix("--action=").to_int()
	for i in 2:
		var name: String = ["parafuseta","rato_morto"][i]
		var actor := load("res://scenes/%s_rigid.tscn" % name).instantiate() as Node2D
		actor.playing = false
		actor.position = Vector2(320,345) if i == 0 else Vector2(950,400)
		actor.scale = Vector2.ONE*1.3
		add_child(actor)
		actors.append(actor)
func _process(delta: float) -> void:
	frame += 1
	if not paused: time += delta
	if cycle: action = int(time/3.2)%3
	var pose_time := fposmod(time,3.2) if cycle else time
	for i in 2: actors[i].apply_pose(RIGS[i].compute_pose(action,pose_time))
	queue_redraw()
	if capture and frame == 4:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/visual/juntas-revisao.png")
		get_tree().quit()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode in [KEY_1,KEY_2,KEY_3]:
		action = event.keycode-KEY_1
		time = 0
		cycle = false
	if event.keycode == KEY_SPACE: paused = not paused
	if event.keycode == KEY_R: time = 0
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("#34434b"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(35,45),"ARTICULAÇÕES — PARAFUSETA E RATO MORTO",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color.WHITE)
	draw_line(Vector2(640,80),Vector2(640,660),Color("#687a81"))
	draw_string(font,Vector2(35,695),["MOVIMENTO","GOLPE","PODER"][action],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("#bbcbd1"))
