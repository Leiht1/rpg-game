extends RefCounted
## One reserved coordinate pocket in the shared world, outside surface chunks.
static func origin(extent: float) -> Vector2:return Vector2(extent+4096,4096)
static func pocket(at: Vector2, extent: float) -> bool:return at.x>extent+2048
static func walkable(at: Vector2, extent: float, radius: float=10) -> bool:
	# Keep feet on the painted floor, before the foreground exit beam and posts.
	var floor_outline:=PackedVector2Array([Vector2(-680,-355),Vector2(680,-355),Vector2(790,-160),Vector2(790,100),Vector2(660,300),Vector2(230,340),Vector2(-230,340),Vector2(-660,300),Vector2(-790,100),Vector2(-790,-160)])
	var local:=at-origin(extent)
	if not Geometry2D.is_point_in_polygon(local,floor_outline):return false
	for i in floor_outline.size():
		if local.distance_to(Geometry2D.get_closest_point_to_segment(local,floor_outline[i],floor_outline[(i+1)%floor_outline.size()]))<radius:return false
	return true
static func initial() -> Dictionary:
	return {"puzzle":preload("res://scripts/mine_puzzle.gd").initial(),"site":{},"investigated":false,"recipe":false,"phase":"sealed","fuse_due":-1.0,"opened_at":-1.0,"entered":false}
