extends SceneTree
func _init() -> void:
	var image := Image.load_from_file("res://assets/art/mouth_anatomy_atlas.png")
	var w := image.get_width()
	var h := image.get_height()
	var visited := PackedByteArray()
	visited.resize(w*h)
	var queue := PackedInt32Array()
	for x in w:
		queue.append(x)
		queue.append((h-1)*w+x)
	for y in h:
		queue.append(y*w)
		queue.append(y*w+w-1)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		if visited[index] != 0:
			continue
		visited[index] = 1
		var x := index % w
		var y := index / w
		var c := image.get_pixel(x,y)
		if minf(c.r,minf(c.g,c.b)) < .58 or maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b)) > .065:
			continue
		visited[index] = 2
		if x > 0: queue.append(index-1)
		if x+1 < w: queue.append(index+1)
		if y > 0: queue.append(index-w)
		if y+1 < h: queue.append(index+w)
	var bitmap := BitMap.new()
	bitmap.create(Vector2i(w,h))
	for y in h:
		for x in w:
			bitmap.set_bit(x,y,visited[y*w+x] != 2)
	var result := []
	for row in 2:
		for col in 3:
			var region := Rect2i(col*512,row*512,512,512)
			var contours := bitmap.opaque_to_polygons(region,1.0)
			var largest := PackedVector2Array()
			for contour in contours:
				if contour.size() > largest.size(): largest = contour
			var points := []
			for v in largest:
				points.append([v.x+region.position.x,v.y+region.position.y])
			result.append(points)
	var file := FileAccess.open("res://assets/art/mouth_anatomy_contours.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	print("Six static mouth silhouettes traced; source texture unchanged")
	quit()
