@tool
extends SceneTree

func _init() -> void:
	var base := Image.load_from_file("res://assets/art/isolated_mini_prensa.png")
	var anim := Image.load_from_file("res://assets/art/mini_prensa_animated.png")
	
	if base == null or anim == null:
		print("Error loading source textures")
		quit(1)
		return
		
	var w := base.get_width()
	var h := base.get_height()
	
	var atlas := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	
	# =========================================================================
	# PIECE 1: LOWER CHASSIS (Rect: 330, 0, 320, 240)
	# =========================================================================
	var chassis := Image.create(320, 240, false, Image.FORMAT_RGBA8)
	
	# Step 3 from guide: "Reconstruir fundos ocultos"
	# Fill the entire neck cavity and background behind the lower teeth with
	# textured dark rusted iron so when the head lifts, it never shows a void!
	for cy in range(0, 95):
		for cx in range(40, 280):
			var dx: float = (float(cx) - 155.0) / 105.0
			var dy: float = (float(cy) - 50.0) / 45.0
			if dx * dx + dy * dy <= 1.0:
				var rust_col := Color(0.19, 0.13, 0.10, 1.0)
				# Add subtle noise/shading
				if cy > 35:
					rust_col = Color(0.14, 0.09, 0.07, 1.0)
				chassis.set_pixel(cx, cy, rust_col)
				
	# Now blit the lower body from base onto chassis
	# base has y from 190 to h
	for by in range(190, h):
		for bx in w:
			var p := base.get_pixel(bx, by)
			if p.a > 0.05:
				var target_y := by - 190 + 12
				var target_x := bx
				if target_x < 320 and target_y < 240:
					chassis.set_pixel(target_x, target_y, p)
					
	# Clean up any transparent gaps in the neck between x=165..215, y=20..60:
	for cy in range(20, 70):
		for cx in range(160, 220):
			var p := chassis.get_pixel(cx, cy)
			if p.a < 0.8:
				chassis.set_pixel(cx, cy, Color(0.18, 0.12, 0.10, 1.0))
				
	# =========================================================================
	# PIECE 2: UPPER HEAD (Rect: 0, 0, 320, 240)
	# =========================================================================
	var head := Image.create(320, 240, false, Image.FORMAT_RGBA8)
	for hy in range(0, 230):
		for hx in w:
			var p := base.get_pixel(hx, hy)
			if p.a > 0.05:
				head.set_pixel(hx, hy, p)
				
	# Fill upper mouth roof (behind the upper hanging teeth):
	for hy in range(165, 230):
		for hx in range(65, 255):
			var p := head.get_pixel(hx, hy)
			if p.a < 0.3:
				var dist_center := absf(float(hx) - 160.0) / 95.0
				if dist_center < 1.0:
					head.set_pixel(hx, hy, Color(0.15, 0.10, 0.08, 1.0))
					
	# =========================================================================
	# PIECE 3: FURNACE CORE (Rect: 660, 0, 160, 140)
	# =========================================================================
	var core := Image.create(160, 140, false, Image.FORMAT_RGBA8)
	for cy in 140:
		for cx in 160:
			var sx := 435 + cx
			var sy := 765 + cy
			var c := anim.get_pixel(sx, sy)
			var nx: float = (float(cx) - 80.0) / 75.0
			var ny: float = (float(cy) - 70.0) / 65.0
			var r2: float = nx * nx + ny * ny
			if r2 < 1.0:
				var edge_fade := clampf((1.0 - r2) * 2.5, 0.0, 1.0)
				c.a *= edge_fade
				core.set_pixel(cx, cy, c)
				
	# =========================================================================
	# PIECE 4: GEAR COG (Rect: 830, 0, 70, 70)
	# =========================================================================
	var gear := Image.create(70, 70, false, Image.FORMAT_RGBA8)
	var g_center_src := Vector2i(523, 857)
	for gy in 70:
		for gx in 70:
			var sx := g_center_src.x - 35 + gx
			var sy := g_center_src.y - 35 + gy
			var c := anim.get_pixel(sx, sy)
			var d := Vector2(gx - 35, gy - 35).length()
			if d <= 32.0:
				var a := clampf((32.0 - d) * 1.5, 0.0, 1.0)
				c.a *= a
				gear.set_pixel(gx, gy, c)

	# =========================================================================
	# PIECE 5 & 6: FEET (Rects: (0, 250, 110, 85) & (120, 250, 110, 85))
	# =========================================================================
	var foot_l := Image.create(110, 85, false, Image.FORMAT_RGBA8)
	foot_l.blit_rect_mask(base, base, Rect2i(0, 335, 110, 83), Vector2i(0, 0))

	var foot_r := Image.create(110, 85, false, Image.FORMAT_RGBA8)
	foot_r.blit_rect_mask(base, base, Rect2i(207, 335, 110, 83), Vector2i(0, 0))

	# =========================================================================
	# PIECE 7: CHIMNEY CAP (Rect: 240, 250, 120, 60)
	# =========================================================================
	var chimney := Image.create(120, 60, false, Image.FORMAT_RGBA8)
	chimney.blit_rect_mask(base, base, Rect2i(100, 5, 120, 55), Vector2i(0, 0))

	# =========================================================================
	# PIECE 8 & 9: PISTON SLEEVE & ROD
	# =========================================================================
	var piston_sleeve := Image.create(40, 90, false, Image.FORMAT_RGBA8)
	piston_sleeve.blit_rect_mask(base, base, Rect2i(25, 250, 40, 90), Vector2i(0, 0))

	var piston_rod := Image.create(24, 100, false, Image.FORMAT_RGBA8)
	piston_rod.blit_rect_mask(base, base, Rect2i(65, 145, 24, 100), Vector2i(0, 0))

	# =========================================================================
	# ASSEMBLE ATLAS
	# =========================================================================
	atlas.blit_rect(head, Rect2i(0, 0, 320, 240), Vector2i(0, 0))
	atlas.blit_rect(chassis, Rect2i(0, 0, 320, 240), Vector2i(330, 0))
	atlas.blit_rect(core, Rect2i(0, 0, 160, 140), Vector2i(660, 0))
	atlas.blit_rect(gear, Rect2i(0, 0, 70, 70), Vector2i(830, 0))
	atlas.blit_rect(foot_l, Rect2i(0, 0, 110, 85), Vector2i(0, 250))
	atlas.blit_rect(foot_r, Rect2i(0, 0, 110, 85), Vector2i(120, 250))
	atlas.blit_rect(chimney, Rect2i(0, 0, 120, 60), Vector2i(240, 250))
	atlas.blit_rect(piston_sleeve, Rect2i(0, 0, 40, 90), Vector2i(370, 250))
	atlas.blit_rect(piston_rod, Rect2i(0, 0, 24, 100), Vector2i(420, 250))

	atlas.save_png("res://assets/art/mini_prensa_pieces.png")
	print("Atlas regenerated successfully!")
	quit(0)
