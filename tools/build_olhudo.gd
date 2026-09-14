extends SceneTree
const REGIONS := [Rect2i(0,0,480,430),Rect2i(510,100,310,310),Rect2i(980,160,200,210),Rect2i(20,450,430,365),Rect2i(480,450,350,350),Rect2i(850,530,395,200),Rect2i(20,865,435,290),Rect2i(480,945,350,255),Rect2i(900,790,340,420)]
const NAMES := ["housing","eye","pupil","base","lower","upper","lid_top","lid_bottom","cable"]
func _init() -> void:
	var source := Image.load_from_file("res://assets/art/olhudo_components.png")
	var data := {}
	for i in REGIONS.size():
		var rect: Rect2i = REGIONS[i]
		var visited := PackedByteArray()
		visited.resize(rect.size.x*rect.size.y)
		var queue := PackedVector2Array()
		for x in rect.size.x:
			queue.append(Vector2(x,0)); queue.append(Vector2(x,rect.size.y-1))
		for y in rect.size.y:
			queue.append(Vector2(0,y)); queue.append(Vector2(rect.size.x-1,y))
		var cursor := 0
		while cursor < queue.size():
			var p := Vector2i(queue[cursor]); cursor += 1
			if p.x < 0 or p.y < 0 or p.x >= rect.size.x or p.y >= rect.size.y: continue
			var index := p.y*rect.size.x+p.x
			if visited[index] != 0: continue
			visited[index] = 1
			var c := source.get_pixelv(p+rect.position)
			if c.a > .1 and (minf(c.r,minf(c.g,c.b)) < .40 or maxf(c.r,maxf(c.g,c.b))-minf(c.r,minf(c.g,c.b)) > .085): continue
			visited[index] = 2
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]: queue.append(Vector2(p+d))
		var mask := BitMap.new(); mask.create(rect.size)
		for y in rect.size.y:
			for x in rect.size.x: mask.set_bit(x,y,visited[y*rect.size.x+x] != 2)
		var contours := mask.opaque_to_polygons(Rect2i(Vector2i.ZERO,rect.size),.7)
		var largest := PackedVector2Array()
		var max_area := 0.0
		for contour in contours:
			var area := 0.0
			for j in contour.size(): area += contour[j].cross(contour[(j+1)%contour.size()])
			if absf(area) > max_area: max_area = absf(area); largest = contour
		if largest.is_empty(): push_error("Missing component: "+NAMES[i]); quit(1); return
		var points := []
		for point in largest: points.append([point.x+rect.position.x,point.y+rect.position.y])
		data[NAMES[i]] = points
	var file := FileAccess.open("res://assets/art/olhudo_contours.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	print("Olhudo: nine component silhouettes, original raster preserved")
	quit()
