extends SceneTree
const SOURCE := Vector2(954, 402)
const PIVOT := SOURCE + Vector2(149.5, 201.5)
func _poly(coords: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for xy in coords:
		out.append(SOURCE + Vector2(xy[0], xy[1]))
	return out
func _entry(poly: PackedVector2Array, pivot: Vector2 = PIVOT) -> Dictionary:
	var points := []
	for v in poly:
		points.append([v.x, v.y])
	return {"pivot": [pivot.x, pivot.y], "fit": 1.0, "points": points}
func _init() -> void:
	var head := _poly([[132,0],[299,0],[299,195],[259,195],[253,158],[247,193],[241,165],[234,145],[230,166],[222,185],[217,153],[211,141],[207,171],[202,182],[197,146],[191,139],[187,162],[180,145],[175,133],[170,177],[163,162],[156,129],[151,127],[145,119],[132,119]])
	var chin := _poly([[133,256],[146,243],[156,210],[167,248],[178,249],[188,226],[199,265],[211,242],[222,274],[238,263],[254,278],[276,269],[299,275],[299,356],[133,356]])
	var left := _poly([[0,352],[133,352],[133,403],[0,403]])
	var right := _poly([[133,356],[299,356],[299,403],[133,403]])
	var remaining: Array[PackedVector2Array] = [_poly([[0,0],[299,0],[299,403],[0,403]])]
	for piece in [head, chin, left, right]:
		var next: Array[PackedVector2Array] = []
		for region in remaining:
			next.append_array(Geometry2D.clip_polygons(region, piece))
		remaining = next
	var backing := _entry(_poly([[36,96],[127,20],[246,67],[255,382],[127,394],[29,379]]))
	backing["color"] = "#152b3b"
	var data := {"backing": backing,"head": _entry(head), "jaw": _entry(chin), "foot_l": _entry(left), "foot_r": _entry(right)}
	for i in remaining.size():
		data["cabinet_%d" % i] = _entry(remaining[i])
	data["shard"] = _entry(_poly([[156,211],[163,244],[158,251],[151,242]]), SOURCE + Vector2(157,236))
	var file := FileAccess.open("res://assets/art/frostbyte_original_parts.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	print("Original Frostbyte partition: %d pieces, source pixels unchanged" % data.size())
	quit()
