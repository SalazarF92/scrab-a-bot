extends Node2D
const Rig = preload("res://art/olhudo_rigid.gd")
const Reference = preload("res://assets/art/expansion_atlas_alpha.png")
var actors: Array[Node2D] = []
var time := 0.0
var paused := false
var slow := false
var capture := false
var frame := 0
var construction := false
var verify := false
var snapshot := PackedByteArray()
func _ready() -> void:
	get_viewport().content_scale_size = Vector2i(1280,720)
	for arg in OS.get_cmdline_user_args():
		if arg == "--capture-olhudo": capture = true
		if arg == "--construction": construction = true
		if arg == "--verify-olhudo": verify = true; paused = true; time = 1.65
		if arg.begins_with("--time="): time = arg.trim_prefix("--time=").to_float(); paused = true
	for i in 3:
		var actor := preload("res://scenes/olhudo_rigid.tscn").instantiate()
		actor.playing = false; actor.position = Vector2(237+i*403,320); actor.scale = Vector2.ONE*1.05
		if i == 1: actor.position.x -= 30
		add_child(actor); actors.append(actor)
func _process(delta: float) -> void:
	frame += 1
	if not paused: time += delta*(.25 if slow else 1.0)
	for i in 3:
		actors[i].visible = not construction or i == 1
		actors[i].apply_pose(Rig.compute_pose(0 if construction else i,time))
	queue_redraw()
	if verify:
		if frame in [5,35,70]:
			await RenderingServer.frame_post_draw
			var pixels := get_viewport().get_texture().get_image().get_data()
			if frame == 5: snapshot = pixels
			elif pixels != snapshot: push_error("Olhudo pause/replay mismatch"); get_tree().quit(1)
		if frame == 36: time = .9
		if frame == 65: time = 1.65
		if frame == 71:
			for actor in actors:
				actor.apply_pose(Rig.compute_pose(0,1.65))
				if actor.laser.visible: push_error("Laser persists in watch action"); get_tree().quit(1); return
			print("Olhudo native integration: identical paused/replayed frames and clean action switching")
			get_tree().quit()
	if capture and frame == 5:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/visual/olhudo-construcao.png" if construction else "res://docs/visual/olhudo-preview.png")
		get_tree().quit()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_SPACE: paused = not paused
	if event.keycode == KEY_S: slow = not slow
	if event.keycode == KEY_R: time = 0
	if event.keycode == KEY_C: construction = not construction
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("18242d"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(38,48),"OLHUDO / WEBCAM DE SUCATA",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("f1d9b9"))
	draw_string(font,Vector2(38,80),"Componentes articulados · olho independente · laser com preparação de 0,8 s",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("9aacbb"))
	for i in 3:
		var x := 30+i*403
		draw_style_box(panel(),Rect2(x,114,388,473))
		var labels := ["01 / REFERÊNCIA","02 / RIG MONTADO","03 / COMPONENTES"] if construction else ["01 / VIGILÂNCIA","02 / GOLPE E RECUO","03 / MIRA E LASER"]
		draw_string(font,Vector2(x+18,147),labels[i],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e8b66f"))
		draw_ellipse_shadow(Vector2(x+194,516))
	if construction: draw_construction()
	draw_string(font,Vector2(38,637),"ESPAÇO pausa     S câmera lenta     R reinicia     C construção",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("b6c4c9"))
	draw_string(font,Vector2(38,669),"Rig reutilizável • Prévia de arte; comportamento de combate preservado",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("82949f"))
func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = Color("293942"); style.set_corner_radius_all(12)
	return style
func draw_ellipse_shadow(at: Vector2) -> void:
	var poly := PackedVector2Array()
	for i in 48: poly.append(at+Vector2.from_angle(i*TAU/48.0)*Vector2(110,15))
	draw_colored_polygon(poly,Color(0,0,0,.22))
func draw_construction() -> void:
	draw_texture_rect_region(Reference,Rect2(90,168,282,370),Rect2(965,55,289,380))
	var names := ["housing","eye","pupil","base","lower","upper","lid_top","lid_bottom","cable"]
	for i in names.size():
		var raw: Array = actors[1].contours[names[i]]
		var bounds := Rect2(Vector2(raw[0][0],raw[0][1]),Vector2.ZERO)
		for xy in raw: bounds = bounds.expand(Vector2(xy[0],xy[1]))
		var fit := minf(101/bounds.size.x,94/bounds.size.y)
		var center := Vector2(904+(i%3)*116,229+(i/3)*124)
		var poly := PackedVector2Array(); var uv := PackedVector2Array()
		for xy in raw:
			var p := Vector2(xy[0],xy[1]); poly.append(center+(p-bounds.get_center())*fit); uv.append(p/1254.0)
		draw_polygon(poly,PackedColorArray([Color.WHITE]),uv,load(Rig.ATLAS))
