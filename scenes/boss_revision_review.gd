extends Node2D
const Frost = preload("res://art/frostbyte_puppet.gd")
const Press = preload("res://art/mini_prensa_puppet.gd")
const Eyes = preload("res://art/boss_eyes.gd")
var _time := 0.0
var _frame := 0
var _compare := false
var _native := false
var _frost: Texture2D
var _press: Texture2D
func _ready() -> void:
	_native = "--native-power" in OS.get_cmdline_user_args()
	if _native:
		for i in 2:
			var path := "res://scenes/frostbyte_rigid.tscn" if i == 0 else "res://scenes/mini_prensa_rigid.tscn"
			var boss := load(path).instantiate() as Node2D
			boss.action = 2
			boss.position = Vector2(330 + 620*i, 350)
			add_child(boss)
	_compare = "--compare-original" in OS.get_cmdline_user_args()
	_frost = load(Frost.ATLAS_PATH)
	_press = load(Press.ATLAS_PATH)
func _process(delta: float) -> void:
	_time += delta
	_frame += 1
	queue_redraw()
	if _native and _frame == 240:
		get_tree().quit()
	if _compare and _frame == 3:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/visual/frostbyte-comparacao.png")
		get_tree().quit()
func _draw() -> void:
	var vp := get_viewport_rect().size
	var unit := minf(vp.x / 1280, vp.y / 720)
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, vp), Color("#18252E"))
	if _native:
		return
	if _compare:
		draw_string(font, Vector2(35,50)*unit, "FROSTBYTE 500 — MESMA TEXTURA ORIGINAL", HORIZONTAL_ALIGNMENT_LEFT, -1, int(27*unit), Color("#DEEFF5"))
		var sf := 1.15 * unit
		var a := Vector2(vp.x*.26, vp.y*.54)
		var b := Vector2(vp.x*.74, vp.y*.54)
		draw_texture_rect_region(_frost, Rect2(a - Vector2(149.5,201.5)*sf, Vector2(299,403)*sf), Rect2(954,402,299,403))
		var p := Frost.compute_pose(Frost.Action.IDLE, 0)
		p.gaze = Vector2.ZERO
		Frost.draw_puppet(self, _frost, b, sf, p)
		draw_string(font, Vector2(0,vp.y-40*unit), "ARTE ORIGINAL", HORIZONTAL_ALIGNMENT_CENTER, vp.x*.5, int(18*unit), Color("#8ECBD9"))
		draw_string(font, Vector2(vp.x*.5,vp.y-40*unit), "RECORTES ORIGINAIS + OLHOS ARTICULADOS", HORIZONTAL_ALIGNMENT_CENTER, vp.x*.5, int(18*unit), Color("#8ECBD9"))
	else:
		draw_string(font, Vector2(35,50)*unit, "OLHOS — MOVIMENTO DAS PUPILAS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(26*unit), Color("#DEEFF5"))
		var f := Frost.compute_pose(Frost.Action.IDLE, _time)
		var p := Press.compute_pose(Press.Action.IDLE, _time)
		var rect_f := Rect2(1095,465,122,92)
		var rect_p := Rect2(197,135,211,105)
		var width := vp.x*.40
		var sf := width / rect_f.size.x
		var sp := width / rect_p.size.x
		var dst_f := Rect2(Vector2(vp.x*.05, vp.y*.5 - rect_f.size.y*sf*.5), rect_f.size*sf)
		var dst_p := Rect2(Vector2(vp.x*.55, vp.y*.5 - rect_p.size.y*sp*.5), rect_p.size*sp)
		draw_texture_rect_region(_frost, dst_f, rect_f)
		var f_head := Transform2D(float(f.body_tilt), f.body_offset) * Transform2D(0, Vector2(0,float(f.jaw))) * Transform2D(0,-Vector2(1103.5,603.5))
		var f_map := Transform2D(0,Vector2.ONE*sf,0,dst_f.position - rect_f.position*sf)
		Eyes.draw_frost(self,f,f_map * f_head.affine_inverse(),Color.WHITE)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_texture_rect_region(_press, dst_p, rect_p)
		var p_head := Transform2D(float(p.body_tilt),p.body_offset) * Transform2D(0,Vector2(0,-115+float(p.jaw))) * Transform2D(0,Vector2.ONE*.6,0,Vector2(-250,-245)*.6)
		var p_map := Transform2D(0,Vector2.ONE*sp,0,dst_p.position - rect_p.position*sp)
		Eyes.draw_press(self,p,p_map * p_head.affine_inverse(),Color.WHITE)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		draw_string(font,Vector2(0,125*unit),"FROSTBYTE 500",HORIZONTAL_ALIGNMENT_CENTER,vp.x*.5,int(22*unit),Color("#8ECBD9"))
		draw_string(font,Vector2(vp.x*.5,125*unit),"MINI-PRENSA 500",HORIZONTAL_ALIGNMENT_CENTER,vp.x*.5,int(22*unit),Color("#FFB46C"))
		draw_string(font,Vector2(0,vp.y-45*unit),"Pupilas originais com tamanho fixo • olhar interpolado",HORIZONTAL_ALIGNMENT_CENTER,vp.x,int(17*unit),Color("#A5BDC6"))
