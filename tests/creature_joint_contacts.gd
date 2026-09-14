extends SceneTree
const RIGS := [preload("res://art/parafuseta_puppet.gd"),preload("res://art/rato_morto_puppet.gd")]
# Probes at the actual painted connections, including the bar formerly sliced
# through its middle. Sample the moving member's surface against all rig pieces.
const CONTACTS := [
	[["arm_l",78,293],["leg_l",78,293],["leg_l",44,293],["arm_r",247,285],["leg_r",247,285],["arm_r",215,300],["arm_l",100,237],["arm_r",184,276],["foot",113,318],["head",130,158],["head",159,177]],
	[["paw_front",373,342],["paw_back",355,308],["paw_right",570,316],["tail",593,248]]]
func _init() -> void:
	var image: Image = (load(RIGS[0].ATLAS_PATH) as Texture2D).get_image()
	var checked := 0
	for boss in 2:
		var rig = RIGS[boss]
		var pivot := Vector2(155,200) if boss == 0 else Vector2(484,220)
		var groups := {}
		for key in rig.parts():
			var group: String = rig.parts()[key].get("group",key)
			if not groups.has(group): groups[group] = []
			groups[group].append(rig.polygon(key))
		var hole := PackedVector2Array()
		for xy in rig.Mouth.COLLARS[boss]: hole.append(Vector2(xy[0],xy[1]))
		var probes := []
		for contact in CONTACTS[boss]:
			for i in 17:
				var source := Vector2(contact[1],contact[2])
				if i > 0: source += Vector2.from_angle(i*TAU/8.0)*(4 if i <= 8 else 8)
				if Geometry2D.is_point_in_polygon(source,hole): continue
				var interior := true
				for delta in [Vector2.ZERO,Vector2(3,0),Vector2(-3,0),Vector2(0,3),Vector2(0,-3)]:
					if image.get_pixelv(Vector2i(source+delta)).a < .9: interior = false
				if interior: probes.append([contact[0],source-pivot])
		for action in 3:
			var duration: float = [rig.WALK_DURATION,rig.ATTACK_DURATION,rig.POWER_DURATION][action]
			for frame in 85:
				var transforms := {}
				var inverse := {}
				for item in rig.frames(rig.compute_pose(action,frame*duration/84.0)):
					var group: String = rig.parts()[item.part].get("group",item.part)
					transforms[group] = item.transform
					inverse[group] = item.transform.affine_inverse()
				for probe in probes:
					var point: Vector2 = transforms[probe[0]]*probe[1]
					var covered := false
					for group in groups:
						var local: Vector2 = inverse[group]*point
						var pixel := Vector2i(local+pivot)
						if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height(): continue
						if image.get_pixelv(pixel).a < .5: continue
						for poly in groups[group]:
							if Geometry2D.is_point_in_polygon(local,poly):
								covered = true
								break
						if covered: break
					if not covered:
						push_error("Open joint boss=%d action=%d frame=%d group=%s source=%s" % [boss,action,frame,probe[0],probe[1]+pivot])
						quit(1)
						return
					checked += 1
	print("=== TUDO OK === / Joint contacts: %d opaque surface probes passed across both rigs and all three cycles" % checked)
	quit()
