extends SceneTree
const Frost = preload("res://art/frostbyte_puppet.gd")
const Press = preload("res://art/mini_prensa_puppet.gd")
func _init() -> void:
	if Frost.ATLAS_PATH != "res://assets/art/enemies_atlas.png":
		push_error("Frostbyte must use original atlas")
		quit(1)
		return
	var area := 0.0
	for key in Frost.parts():
		if key == "shard" or Frost.parts()[key].has("color"):
			continue
		var poly := Frost.uvs(key, false)
		for point in poly:
			if point.x < 954 or point.x > 1253 or point.y < 402 or point.y > 805:
				push_error("Frostbyte samples outside original sprite")
				quit(1)
				return
		var indices := Geometry2D.triangulate_polygon(poly)
		for i in range(0,indices.size(),3):
			area += absf((poly[indices[i+1]]-poly[indices[i]]).cross(poly[indices[i+2]]-poly[indices[i]]))*.5
	if absf(area - 299.0*403.0) > .1:
		push_error("Source partition has gaps or overlapping areas: %s" % area)
		quit(1)
		return
	for rig in [Frost, Press]:
		for action in 3:
			var duration: float = [rig.WALK_DURATION,rig.ATTACK_DURATION,rig.POWER_DURATION][action]
			var gaze_min := 100.0
			var gaze_max := -100.0
			for frame in range(int(duration*240)):
				var p: Dictionary = rig.compute_pose(action,float(frame)/240)
				gaze_min = minf(gaze_min, p.gaze.x)
				gaze_max = maxf(gaze_max, p.gaze.x)
			if gaze_max-gaze_min < .2:
				push_error("Missing gaze animation")
				quit(1)
				return
	print("=== TUDO OK === / original Frostbyte UV partition; animated eyes on all six actions")
	quit()
