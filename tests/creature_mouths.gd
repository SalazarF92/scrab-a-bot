extends SceneTree
const Mouth = preload("res://art/creature_mouth.gd")
func _init() -> void:
	for size in [Vector2(74,84),Vector2(99,96)]:
		for frame in 456:
			var t := float(frame)/240
			var a := Mouth.opening(1,t,1.9)
			var b := Mouth.opening(1,t+.00001,1.9)
			assert(a >= 0 and a <= 1)
			assert(absf(a-b) < .001)
			var xf := Mouth.jaw_transform(size,a)
			assert(xf.get_scale().is_equal_approx(Vector2.ONE))
			assert(absf((xf*Vector2.ZERO).distance_to(xf*size)-size.length()) < .0001)
		assert(Mouth.opening(1,.65,1.9) > .99)
		assert(Mouth.opening(1,1.0,1.9) < .001)
		assert(Mouth.jaw_transform(size,0).origin.distance_to(Mouth.jaw_transform(size,1).origin)>25)
	var contours: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/mouth_anatomy_contours.json"))
	assert(contours.size() == 6)
	for contour in contours:
		var poly := PackedVector2Array()
		for xy in contour: poly.append(Vector2(xy[0],xy[1]))
		assert(not Geometry2D.triangulate_polygon(poly).is_empty())
	print("Mouths: six textured components, rigid jaw motion, full closure and continuous opening verified")
	quit()
