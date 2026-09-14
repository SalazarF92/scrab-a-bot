extends Node2D
const Rig = preload("res://art/olhudo_rigid.gd")
var actors: Array[Node2D] = []
var time := 0.0
var paused := false
var capture := false
var frame := 0
func _ready() -> void:
	get_viewport().content_scale_size = Vector2i(1280,720)
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture": capture = true
		if arg.begins_with("--time="): time = arg.trim_prefix("--time=").to_float(); paused = true
	for i in 2:
		var actor := preload("res://scenes/olhudo_rigid.tscn").instantiate()
		actor.playing = false
		actor.position = Vector2(355+i*635,360)
		actor.scale = Vector2.ONE*1.35
		add_child(actor); actors.append(actor)
func _process(delta: float) -> void:
	frame += 1
	if not paused: time += delta
	for i in 2: actors[i].apply_pose(Rig.compute_pose(Rig.Action.ATTACK,time if i == 0 or paused else time*.25))
	queue_redraw()
	if capture and frame == 5:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/visual/olhudo-ataque.png")
		get_tree().quit()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_SPACE: paused = not paused
	if event.keycode == KEY_R: time = 0
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("293942"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(35,45),"OLHUDO / INVESTIDA MECÂNICA",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("f1d9b9"))
	draw_string(font,Vector2(35,81),"Arma o suporte • lança a carcaça • absorve o impacto",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("b6c4c9"))
	draw_line(Vector2(640,115),Vector2(640,675),Color("536673"))
	draw_string(font,Vector2(35,145),"VELOCIDADE NORMAL",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e8b66f"))
	draw_string(font,Vector2(675,145),"CÂMERA LENTA / 25%",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e8b66f"))
	draw_string(font,Vector2(35,675),"ESPAÇO pausa     R reinicia",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("b6c4c9"))
