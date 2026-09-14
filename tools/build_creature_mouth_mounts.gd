extends SceneTree
const HOLES := [
	[[145,215],[156,204],[176,195],[199,195],[220,199],[232,208],[225,231],[206,259],[186,274],[168,278],[149,265],[140,245]],
	[[398,259],[423,264],[445,274],[467,279],[486,291],[487,309],[471,333],[435,356],[409,365],[389,357],[373,336],[370,306],[380,279]]]
func _init() -> void:
	for boss in 2:
		var name: String = ["parafuseta","rato_morto"][boss]
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/%s_original_parts.json" % name))
		var hole := PackedVector2Array()
		for xy in HOLES[boss]: hole.append(Vector2(xy[0],xy[1]))
		var result := {}
		for key in source:
			var entry: Dictionary = source[key]
			var poly := PackedVector2Array()
			for xy in entry.points: poly.append(Vector2(xy[0],xy[1]))
			if Geometry2D.intersect_polygons(poly,hole).is_empty():
				result[key] = entry
				continue
			var indices := Geometry2D.triangulate_polygon(poly)
			var count := 0
			for i in range(0,indices.size(),3):
				var triangle := PackedVector2Array([poly[indices[i]],poly[indices[i+1]],poly[indices[i+2]]])
				for clipped in Geometry2D.clip_polygons(triangle,hole):
					var part := entry.duplicate(true)
					part.group = entry.get("group",key)
					part.points = []
					for point in clipped: part.points.append([point.x,point.y])
					result["%s_%d" % [key,count]] = part
					count += 1
		var file := FileAccess.open("res://assets/art/%s_mouth_parts.json" % name,FileAccess.WRITE)
		file.store_string(JSON.stringify(result))
	print("Original painted mouths removed from source geometry; surrounding pixels retained")
	quit()
