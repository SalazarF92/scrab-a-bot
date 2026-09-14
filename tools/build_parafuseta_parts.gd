extends SceneTree
const PIVOT := Vector2(155,200)
func poly(coords: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for xy in coords:
		p.append(Vector2(xy[0],xy[1]))
	return p
func _init() -> void:
	var cuts := {
		"head": poly([[0,0],[310,0],[310,207],[257,215],[235,215],[213,209],[188,199],[164,182],[116,150],[0,150]]),
		"jaw": poly([[138,222],[153,251],[177,253],[198,240],[218,215],[235,204],[222,245],[191,272],[165,278],[144,260]]),
		"arm_l": poly([[0,232],[86,224],[110,260],[94,280],[89,292],[77,301],[68,282],[52,270],[0,270]]),
		"leg_l": poly([[0,270],[52,270],[68,282],[77,301],[89,292],[94,280],[94,390],[0,390]]),
		"arm_r": poly([[169,258],[225,264],[310,264],[310,285],[247,285],[231,315],[202,322],[181,293]]),
		"leg_r": poly([[247,285],[310,285],[310,390],[196,390],[196,324],[231,315]]),
		"foot": poly([[96,309],[112,307],[126,317],[125,335],[127,390],[90,390]])}
	var remain: Array[PackedVector2Array] = [poly([[0,0],[310,0],[310,390],[0,390]])]
	var data := {}
	for key in cuts:
		var next: Array[PackedVector2Array] = []
		for region in remain:
			for clipped in Geometry2D.intersect_polygons(region,cuts[key]):
				var points := []
				for v in clipped:
					points.append([v.x,v.y])
				var name: String = key
				while data.has(name):
					name += "_fragment"
				data[name] = {"group":key,"pivot":[155,200],"fit":1.0,"points":points}
			next.append_array(Geometry2D.clip_polygons(region,cuts[key]))
		remain = next
	for i in remain.size():
		var points := []
		for v in remain[i]:
			points.append([v.x,v.y])
		data["body_%d" % i] = {"pivot":[155,200],"fit":1.0,"points":points}
	data = preload("res://tools/rig_joint_supports.gd").add(data,PIVOT,[
		["knee_l",Vector2(78,293),16,"arm_l","leg_l"],
		["knee_r",Vector2(247,285),16,"arm_r","leg_r"],
		["shoulder_l",Vector2(100,237),16,"body","arm_l"],
		["shoulder_r",Vector2(184,276),15,"body","arm_r"],
		["foot",Vector2(113,318),13,"body","foot"],
		["neck",Vector2(159,177),45,"body","head"]])
	var file := FileAccess.open("res://assets/art/parafuseta_original_parts.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"  "))
	print("Parafuseta: original sprite partitioned into %d rigid pieces" % data.size())
	quit()
