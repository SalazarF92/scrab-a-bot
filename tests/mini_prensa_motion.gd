extends SceneTree
const Rig = preload("res://art/mini_prensa_puppet.gd")
func _init() -> void:
	var samples := 0
	for action in 3:
		var duration: float = [Rig.WALK_DURATION, Rig.ATTACK_DURATION, Rig.POWER_DURATION][action]
		for frame in range(int(duration * 120)):
			var pose := Rig.compute_pose(action as Rig.Action, float(frame) / 120)
			if float(pose.blast) > .001 and float(pose.hatch_open) < .999:
				push_error("Fire emitted before hatch fully open")
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
		for t in [0.0, .5, .7, .72, .76, .82, .88, .98, 1.05, 1.22, 1.72, 1.85, 2.18, duration]:
			if t > duration:
				continue
			var a := Rig.compute_pose(action as Rig.Action, t - .00001)
			var b := Rig.compute_pose(action as Rig.Action, t + .00001)
			if absf(a.hatch_open - b.hatch_open) > .001 or absf(a.jaw - b.jaw) > .1 or (a.body_offset as Vector2).distance_to(b.body_offset) > .1:
				push_error("Discontinuous pose")
				quit(1)
				return
	print("=== TUDO OK === / %d rigid edge lengths; unit scale on every part; continuous cycles" % samples)
	quit()
