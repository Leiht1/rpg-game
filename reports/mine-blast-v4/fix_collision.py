from pathlib import Path
p=Path('scripts/exploration_mine_view.gd');s=p.read_text(encoding='utf-8-sig')
s=s.replace('# The wooden sides remain solid after clearing; the open doorway stays clear.\n\tbody(exterior,Vector2(-116,-35),Vector2(44,100));body(exterior,Vector2(116,-35),Vector2(44,100))\n\tbody(exterior,Vector2(0,-91),Vector2(270,22))','# The painted shell is solid, including the back and the roof. Only the\n\t# foreground threshold is walkable; E transfers into the separate room.\n\tvar shell:=StaticBody2D.new();shell.name="MineShell";exterior.add_child(shell)\n\tvar outline:=CollisionPolygon2D.new()\n\toutline.polygon=PackedVector2Array([Vector2(-151,23),Vector2(-148,-52),Vector2(-110,-128),Vector2(-22,-169),Vector2(40,-160),Vector2(112,-124),Vector2(151,-42),Vector2(151,23),Vector2(66,23),Vector2(62,0),Vector2(-62,0),Vector2(-66,23)])\n\tshell.add_child(outline)')
p.write_text(s,encoding='utf8')
p=Path('scripts/mine_rules.gd');s=p.read_text(encoding='utf-8-sig');s=s.replace('return Rect2(origin(extent)+Vector2(-710,-340)+Vector2.ONE*radius,Vector2(1420,715)-Vector2.ONE*radius*2).has_point(at)','''# Keep feet on the painted floor, before the foreground exit beam and posts.
	var floor_outline:=PackedVector2Array([Vector2(-660,-340),Vector2(660,-340),Vector2(710,-160),Vector2(710,100),Vector2(600,250),Vector2(230,300),Vector2(-230,300),Vector2(-600,250),Vector2(-710,100),Vector2(-710,-160)])
	var local:=at-origin(extent)
	if not Geometry2D.is_point_in_polygon(local,floor_outline):return false
	for i in floor_outline.size():
		if local.distance_to(Geometry2D.get_closest_point_to_segment(local,floor_outline[i],floor_outline[(i+1)%floor_outline.size()]))<radius:return false
	return true''');p.write_text(s,encoding='utf8')
