extends RefCounted

# Both rigid members contain a complete socket behind their visible cut edges.
# Source UVs stay fixed: these are overlapping pieces, never stretched pixels.
static func add(data: Dictionary, pivot: Vector2, joints: Array) -> Dictionary:
	var result := {}
	var source := Image.load_from_file("res://assets/art/enemies_atlas.png")
	for spec in joints:
		var center: Vector2 = spec[1]
		var radius: int = ceili(spec[2])
		var origin := Vector2i(center)-Vector2i.ONE*(radius+1)
		var size := Vector2i.ONE*(radius*2+3)
		var mask := BitMap.new()
		mask.create(size)
		# Underlaps must remain inside the painted silhouette; otherwise the
		# stationary member leaves a second outline next to the rotating member.
		for y in size.y:
			for x in size.x:
				var at := origin+Vector2i(x,y)
				var opaque := true
				for offset in [Vector2i.ZERO,Vector2i(2,0),Vector2i(-2,0),Vector2i(0,2),Vector2i(0,-2)]:
					var pixel: Vector2i = at+offset
					if pixel.x < 0 or pixel.y < 0 or pixel.x >= source.get_width() or pixel.y >= source.get_height() or source.get_pixelv(pixel).a < .8:
						opaque = false
						break
				mask.set_bit(x,y,opaque and Vector2(at).distance_to(center) < radius)
		var surfaces := mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,size),.5)
		for group in [spec[3], spec[4]]:
			for i in surfaces.size():
				var points := []
				for local in surfaces[i]:
					var point: Vector2 = local+Vector2(origin)
					points.append([point.x,point.y])
				result["socket_%s_%s_%d" % [spec[0],group,i]] = {"overlay":true,"group":group,"pivot":[pivot.x,pivot.y],"fit":1.0,"points":points}
	result.merge(data)
	return result
