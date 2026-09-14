extends SceneTree
const Rig = preload("res://art/parafuseta_puppet.gd")
func _init() -> void:
	var area := 0.0
	for key in Rig.parts():
		if Rig.parts()[key].get("overlay",false):
			continue
		var polygon := Rig.uvs(key,false)
		var indices := Geometry2D.triangulate_polygon(polygon)
		for i in range(0,indices.size(),3):
			area += absf((polygon[indices[i+1]]-polygon[indices[i]]).cross(polygon[indices[i+2]]-polygon[indices[i]]))*.5
	var mouth_area := 0.0
	var points: Array = Rig.Mouth.COLLARS[0]
	for i in points.size():
		var a := Vector2(points[i][0],points[i][1])
		var b := Vector2(points[(i+1)%points.size()][0],points[(i+1)%points.size()][1])
		mouth_area += a.cross(b)*.5
	if absf(area-(310*390-absf(mouth_area))) > .1:
		push_error("Original sprite partition has missing or duplicate regions: %s" % area)
		quit(1)
		return
	var samples := 0
	for action in 3:
		var duration: float = [Rig.WALK_DURATION, Rig.ATTACK_DURATION, Rig.POWER_DURATION][action]
		for frame in range(int(duration * 120)):
			var pose := Rig.compute_pose(action as Rig.Action, float(frame) / 120)
			if float(pose.blast) > .001 and float(pose.vent) < .999:
				push_error("Fire emitted before duct shutters fully open")
				quit(1)
				return
			for part in Rig.frames(pose):
				var xf: Transform2D = part.transform
				if not xf.get_scale().is_equal_approx(Vector2.ONE) or absf(xf.determinant() - 1) > .00001:
					push_error("Non-rigid transform: " + part.name)
					quit(1)
					return
				var poly := Rig.polygon(part.part)
				for i in range(poly.size() - 1):
					var before := poly[i].distance_to(poly[i + 1])
					var after := (xf * poly[i]).distance_to(xf * poly[i + 1])
					if absf(before - after) > .0001:
						push_error("Piece deformation: " + part.name)
						quit(1)
						return
					samples += 1
		for t in [0.0, .22, .65, .74, .82, .9, .94, 1.04, 1.22, 1.3, 1.9, 2.30, 2.7, 2.72, 2.82, duration]:
			if t > duration:
				continue
			var a := Rig.compute_pose(action as Rig.Action, t - .00001)
			var b := Rig.compute_pose(action as Rig.Action, t + .00001)
			if absf(a.vent - b.vent) > .001 or absf(a.jaw - b.jaw) > .1 or (a.body_offset as Vector2).distance_to(b.body_offset) > .1:
				push_error("Discontinuous pose")
				quit(1)
				return
	print("=== TUDO OK === / %d rigid edge lengths; unit scale on every part; continuous cycles" % samples)
	quit()
