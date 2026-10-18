extends Node2D
## One ground canvas for the small study, always below actors/props; no chunk clipping.
var props:Array=[]
var enabled := false
func _draw()->void:
	if not enabled:return
	for prop in props:
		if not is_instance_valid(prop) or not prop.visible:continue
		if prop.kind>=2:continue
		var center:Vector2=prop.position+prop.foot+Vector2(prop.display_size.x*.13,prop.display_size.y*.06)
		# Crown-sized, short right/down projection with much less opacity than contact.
		for i in 24:
			var a:=i*TAU/24.0;var b:=(i+1)*TAU/24.0
			var radius:Vector2=Vector2(prop.display_size.x*.43,prop.display_size.x*.24)
			var ra:=1.+.13*sin(a*3+prop.detail_seed*10)
			var rb:=1.+.13*sin(b*3+prop.detail_seed*10)
			draw_polygon(PackedVector2Array([center,center+Vector2(cos(a),sin(a))*radius*ra,center+Vector2(cos(b),sin(b))*radius*rb]),PackedColorArray([Color(.24,.32,.23,.11),Color(.24,.32,.23,0),Color(.24,.32,.23,0)]))
