extends SceneTree
const Rig = preload("res://art/olhudo_rigid.gd")
func _init() -> void:
	var checks := 0
	for action in 3:
		for frame in 433:
			var p := Rig.compute_pose(action,frame/120.0)
			var xf := Rig.transforms(p)
			for key in xf:
				assert(xf[key].get_scale().is_equal_approx(Vector2.ONE),"Animated scale: "+key)
				assert(absf(xf[key].determinant()-1.0) < .00001,"Non rigid part")
			assert((xf.base*Vector2.ZERO).distance_to(xf.lower*Vector2.ZERO) < .0001,"Base joint separated")
			assert((xf.lower*Rig.LOWER_END).distance_to(xf.upper*Vector2.ZERO) < .0001,"Elbow separated")
			assert((xf.upper*Rig.UPPER_END).distance_to(xf.housing*Vector2.ZERO) < .0001,"Head mount separated")
			if p.emission > 0:
				assert(p.blink == 0,"Laser behind closed shutter")
				assert(frame/120.0 >= 1.4,"Laser before .8 second warning")
			checks += 1
		var before := Rig.compute_pose(action,Rig.DURATION-.000001)
		var after := Rig.compute_pose(action,0)
		for key in ["lower","upper","head","cable","blink","charge","emission"]:
			assert(absf(before[key]-after[key]) < .0001,"Cycle discontinuity: "+key)
	var contours: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/olhudo_contours.json"))
	var armed := Rig.transforms(Rig.compute_pose(Rig.Action.ATTACK,.74))
	var strike := Rig.transforms(Rig.compute_pose(Rig.Action.ATTACK,.85))
	var lens := Vector2(-90,-71)
	var advance: float = (armed.housing*lens).x-(strike.housing*lens).x
	assert(advance > 125,"Attack lacks the extended forward strike")
	assert(strike.housing.origin.x < strike.base.origin.x-90,"Support joint does not unfold forward")
	print("Forward lens travel: %.1f px; head mount ahead of base: %.1f px" % [advance,strike.base.origin.x-strike.housing.origin.x])
	assert((armed.base.origin as Vector2).is_equal_approx(strike.base.origin),"Stationary clamp slides during attack")
	assert(contours.size() == 9,"Missing reconstructed parts")
	var lids := []
	for name in ["lid_top","lid_bottom"]:
		var poly := PackedVector2Array()
		for xy in contours[name]: poly.append(Rig.component_point(name,Vector2(xy[0],xy[1]))+Rig.lid_slide(name == "lid_top",1))
		lids.append(poly)
	var covered := 0; var total := 0
	for y in range(-117,-24,3):
		for x in range(-122,-49,3):
			var point := Vector2(x,y)
			if ((point-Vector2(-86.5,-71))/Vector2(39,51)).length() > .9: continue
			total += 1
			if Geometry2D.is_point_in_polygon(point,lids[0]) or Geometry2D.is_point_in_polygon(point,lids[1]): covered += 1
	print("Eyelid coverage: %d / %d" % [covered,total])
	assert(float(covered)/total > .98,"Eyelids do not close the optical aperture")
	print("Olhudo: %d poses, fixed-size pieces, connected pivots, continuous cycles, .8s warning and closed eyelids verified" % checks)
	quit()
