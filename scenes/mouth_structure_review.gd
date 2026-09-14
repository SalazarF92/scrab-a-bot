extends Node2D
const Mouth = preload("res://art/creature_mouth.gd")
var time := 0.0
var frame := 0
var native := false
func _ready() -> void:
	get_viewport().content_scale_size = Vector2i(1280,720)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	native = "--native-power" in OS.get_cmdline_user_args()
	if native:
		for i in 2:
			var path: String = ["parafuseta","rato_morto"][i]
			var instance := load("res://scenes/%s_rigid.tscn" % path).instantiate() as Node2D
			instance.action = 2
			instance.position = Vector2(330+i*620,370)
			add_child(instance)
func _process(delta: float) -> void:
	time += delta
	frame += 1
	queue_redraw()
	if "--capture-mouth" in OS.get_cmdline_user_args() and frame == 3:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/visual/bocas-estrutura.png")
		get_tree().quit()
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("#18252e"))
	if native: return
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(35,42),"BOCAS — CAVIDADE, ARCADA E MANDÍBULA",HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color.WHITE)
	for boss in 2:
		for pose in 3:
			var openness: float = [0,.5,1][pose]
			if not "--capture-mouth" in OS.get_cmdline_user_args():
				openness = .5-.5*cos(time*2+pose*.6)
			var p := {"body_tilt":0.0,"body_offset":Vector2.ZERO,"mouth_open":openness}
			var src := Vector2(187,234)-Vector2(155,200) if boss == 0 else Vector2(424,313)-Vector2(484,220)
			var root := Transform2D(0,Vector2.ONE*2.2,0,Vector2(220+pose*420,220+boss*310)-src*2.2)
			Mouth.draw(self,boss,p,root,Color.WHITE,false)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			draw_string(font,Vector2(pose*420,85+boss*310),("PARAFUSETA" if boss == 0 else "RATO MORTO")+" · "+["FECHADA","MEIA ABERTURA","ABERTA"][pose],HORIZONTAL_ALIGNMENT_CENTER,420,17,Color("#98c6d2"))
