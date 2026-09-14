class_name CreatureMouth
extends RefCounted
const TEXTURE_PATH := "res://assets/art/mouth_anatomy_atlas.png"
static var _texture: Texture2D
static var _repair: Texture2D
# Fixed silhouettes exclude the opaque checkerboard supplied by the generator.
static var contours: Array = []
const COLLARS := [
	[[145,215],[156,204],[176,195],[199,195],[220,199],[232,208],[225,231],[206,259],[186,274],[168,278],[149,265],[140,245]],
	[[398,259],[423,264],[445,274],[467,279],[486,291],[487,309],[471,333],[435,356],[409,365],[389,357],[373,336],[370,306],[380,279]]]
static func _collar(canvas: CanvasItem,boss: int,p: Dictionary,root: Transform2D,tint: Color) -> void:
	var poly := PackedVector2Array()
	var uv := PackedVector2Array()
	var bounds := Rect2(Vector2(COLLARS[boss][0][0],COLLARS[boss][0][1]),Vector2.ZERO)
	for xy in COLLARS[boss]: bounds = bounds.expand(Vector2(xy[0],xy[1]))
	if _repair == null:
		_repair = load("res://assets/art/mouth_mount_repairs.png")
	for xy in COLLARS[boss]:
		var point := Vector2(xy[0],xy[1])
		poly.append(point)
		uv.append(point/1254.0)
	var pivot := Vector2(155,200) if boss == 0 else Vector2(484,220)
	canvas.draw_set_transform_matrix(root*Transform2D(p.body_tilt,p.body_offset)*Transform2D(0,-pivot))
	canvas.draw_polygon(poly,PackedColorArray([tint]),uv,_repair)
static func jaw_transform(size: Vector2,openness: float) -> Transform2D:
	var hinge := Vector2(-size.x*.37,-size.y*.06)
	var angle := lerpf(-.10,.24,openness)
	return Transform2D(angle,hinge-hinge.rotated(angle)+Vector2(0,lerpf(-size.y*.24,size.y*.10,openness)))
static func opening(action: int,time: float,duration: float) -> float:
	var t := fposmod(time,duration)
	if action == 1:
		return _curve(t,[Vector2(0,.22),Vector2(.58,1),Vector2(.74,1),Vector2(.93,0),Vector2(1.1,0),Vector2(duration,.22)])
	if action == 2:
		return _curve(t,[Vector2(0,.22),Vector2(.72,.88),Vector2(2.7,.88),Vector2(duration,.22)])
	return .22+.08*sin(time/duration*TAU)
static func _curve(t: float,keys: Array) -> float:
	for i in range(1,keys.size()):
		if t <= keys[i].x:
			return lerpf(keys[i-1].y,keys[i].y,smoothstep(keys[i-1].x,keys[i].x,t))
	return keys.back().y
static func _part(canvas: CanvasItem,index: int,at: Vector2,size: Vector2,xf: Transform2D,tint: Color,mask: PackedVector2Array = PackedVector2Array()) -> void:
	if contours.is_empty():
		contours = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/mouth_anatomy_contours.json"))
	var bounds := Rect2(Vector2(contours[index][0][0],contours[index][0][1]),Vector2.ZERO)
	for xy in contours[index]:
		bounds = bounds.expand(Vector2(xy[0],xy[1]))
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	for xy in contours[index]:
		var v := Vector2(xy[0],xy[1])
		vertices.append((v-bounds.position)/bounds.size*size-size*.5+at)
		uv.append(v/Vector2(1536,1024))
	canvas.draw_set_transform_matrix(xf)
	if mask.is_empty():
		canvas.draw_polygon(vertices,PackedColorArray([tint]),uv,_texture)
	else:
		for clipped in Geometry2D.intersect_polygons(vertices,mask):
			if clipped.size() < 3 or Geometry2D.triangulate_polygon(clipped).is_empty(): continue
			var clipped_uv := PackedVector2Array()
			for point in clipped:
				clipped_uv.append(((point-at+size*.5)/size*bounds.size+bounds.position)/Vector2(1536,1024))
			canvas.draw_polygon(clipped,PackedColorArray([tint]),clipped_uv,_texture)
static func draw(canvas: CanvasItem,boss: int,p: Dictionary,root: Transform2D,tint: Color,include_mount: bool = true) -> void:
	if _texture == null:
		_texture = load(TEXTURE_PATH)
	if include_mount:
		_collar(canvas,boss,p,root,tint)
	var source := Vector2(187,234) if boss == 0 else Vector2(424,313)
	var pivot := Vector2(155,200) if boss == 0 else Vector2(484,220)
	var size := Vector2(74,84) if boss == 0 else Vector2(99,96)
	var xf := root*Transform2D(p.body_tilt,p.body_offset)*Transform2D(.12,source-pivot)
	var i := boss*3
	var rotation := jaw_transform(size,float(p.mouth_open))
	var mask := PackedVector2Array()
	for point in [Vector2(-1000,-1000),Vector2(1000,-1000),Vector2(1000,size.y*.32),Vector2(-1000,size.y*.32)]:
		mask.append(rotation*point)
	_part(canvas,i,Vector2.ZERO,size,xf,tint,mask)
	_part(canvas,i+2,Vector2(0,size.y*.19),Vector2(size.x*.9,size.y*.57),xf*rotation,tint)
	_part(canvas,i+1,Vector2(0,-size.y*.28),Vector2(size.x*.88,size.y*.39),xf,tint)
	canvas.draw_set_transform_matrix(root)
