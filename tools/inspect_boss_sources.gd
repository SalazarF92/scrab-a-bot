extends Node2D
var _frame := 0
var _original: Texture2D
var _press: Texture2D
func _ready() -> void:
	_original = load("res://assets/art/enemies_atlas.png")
	_press = load("res://assets/art/mini_prensa_rigid_atlas.png")
	queue_redraw()
func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 3:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://docs/visual/boss-source-inspection.png")
		get_tree().quit()
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 900), Color("#25343D"))
	draw_texture_rect_region(_original, Rect2(20, 50, 598, 806), Rect2(954, 402, 299, 403))
	draw_texture_rect_region(_press, Rect2(650, 50, 600, 467), Rect2(20, 65, 450, 350))
	draw_string(ThemeDB.fallback_font, Vector2(20, 30), "FROSTBYTE: ARTE ORIGINAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	draw_string(ThemeDB.fallback_font, Vector2(650, 30), "PRENSA: OLHOS E CABECA", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
