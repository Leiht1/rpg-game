extends RefCounted
## Single footprint source for physical bodies, authority movement and QA.
static var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/mine_puzzle.json"))
static func polygon(kind: String) -> PackedVector2Array:
	var result:=PackedVector2Array()
	for point in config.collision[kind]:result.append(Vector2(point[0],point[1]))
	return result
static func body(parent: Node2D, kind: String, offset: Vector2=Vector2.ZERO) -> StaticBody2D:
	var result:=StaticBody2D.new();result.name="VolumeCollision";result.position=offset;result.set_meta("mine_volume",kind)
	var shape:=CollisionPolygon2D.new();shape.polygon=polygon(kind);result.add_child(shape);parent.add_child(result);return result
static func contains(at: Vector2, shape: PackedVector2Array, radius: float=10.0) -> bool:
	if Geometry2D.is_point_in_polygon(at,shape):return true
	for i in shape.size():
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at,shape[i],shape[(i+1)%shape.size()]))<radius:return true
	return false
static func blocks(local: Vector2, mine: Dictionary, radius: float=10.0) -> bool:
	if mine.get("phase")!="open":return false
	for point in config.lamps:
		if contains(local-Vector2(point[0],point[1]),polygon("lamp"),radius):return true
	var puzzle: Dictionary=mine.get("puzzle",{})
	if not puzzle.get("solved",false):return contains(local-Vector2(config.rubble[0],config.rubble[1]),polygon("rubble"),radius)
	if contains(local-Vector2(config.chest[0],config.chest[1]),polygon("chest"),radius):return true
	for i in config.ores.size():
		if puzzle.get("ores",[]).size()>i and int(puzzle.ores[i].hits)<int(config.hits):
			var point: Array=config.ores[i]
			if contains(local-Vector2(point[0],point[1]),polygon("ore"),radius):return true
	return false
