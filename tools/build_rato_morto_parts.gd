extends SceneTree
const PIVOT := Vector2(484,220)
func poly(coords: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for xy in coords:
		p.append(Vector2(xy[0],xy[1]))
	return p
func _init() -> void:
	var cuts := {
		"tail": poly([[478,10],[638,10],[638,272],[594,272],[586,247],[598,209],[587,185],[564,168],[522,160],[489,146],[478,120]]),
		"jaw": poly([[386,293],[400,318],[424,326],[449,313],[475,302],[484,303],[475,328],[445,345],[410,361],[410,393],[380,393],[380,326]]),
		"paw_back": poly([[330,273],[357,279],[366,306],[374,322],[351,345],[330,346]]),
		"paw_front": poly([[330,337],[360,326],[383,332],[402,349],[399,393],[330,393]]),
		"paw_right": poly([[547,304],[572,293],[622,293],[638,393],[529,393],[537,341]])}
	var remain: Array[PackedVector2Array] = [poly([[330,10],[638,10],[638,393],[330,393]])]
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
				data[name] = {"group":key,"pivot":[484,220],"fit":1.0,"points":points}
			next.append_array(Geometry2D.clip_polygons(region,cuts[key]))
		remain = next
	for i in remain.size():
		var points := []
		for v in remain[i]:
			points.append([v.x,v.y])
		data["body_%d" % i] = {"pivot":[484,220],"fit":1.0,"points":points}
	data = preload("res://tools/rig_joint_supports.gd").add(data,PIVOT,[
		["front",Vector2(373,342),15,"body","paw_front"],
		["back",Vector2(355,308),14,"body","paw_back"],
		["right",Vector2(570,316),19,"body","paw_right"],
		["tail",Vector2(593,248),17,"body","tail"]])
	var file := FileAccess.open("res://assets/art/rato_morto_original_parts.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"  "))
	print("Rato Morto: original sprite partitioned into %d rigid pieces" % data.size())
	quit()
