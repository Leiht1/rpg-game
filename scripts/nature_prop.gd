extends Node2D

var candidate_mode := 0
var texture: Texture2D
var display_size := Vector2.ZERO
var kind := 0
var faded := false
var detail_seed := 0.0

func _draw() -> void:
	if texture == null: return
	# Ground integration is drawn by the existing prop: no additional nodes.
	var w := (26.0 if kind<2 else display_size.x*.43)
	if kind<4 and candidate_mode==0:
		# Irregular translucent soil/leaf bed, varied radius and contour per coordinate.
		for layer in range(5,0,-1):
			var contour := PackedVector2Array()
			for j in 13:
				var a := float(j)/13.0*TAU
				var radius := w*(1.0+layer*.16)*(1.0+.20*sin(j*2.3+detail_seed*19))
				contour.append(Vector2(cos(a)*radius,sin(a)*radius*.39+3))
			draw_colored_polygon(contour,Color(.54,.51,.30,.025 if kind<2 else .035))
		for layer in range(6,0,-1):
			draw_set_transform(Vector2(4,1),0,Vector2(1,.30))
			draw_circle(Vector2.ZERO,w*(.55+layer*.11),Color(.23,.30,.16,.018))
			draw_set_transform(Vector2.ZERO)
		for i in range(3+int(detail_seed*4)):
			var a := float(i)*2.399+detail_seed*6.28
			var pt := Vector2(cos(a)*w*(.7+detail_seed*.5),sin(a)*w*.33+3)
			if kind<2:
				draw_set_transform(pt,a,Vector2(1,.45))
				draw_colored_polygon(PackedVector2Array([Vector2(-3,0),Vector2(0,-2),Vector2(4,0),Vector2(0,2)]),Color(.57,.57+detail_seed*.12,.30,.52))
				draw_set_transform(Vector2.ZERO)
			else:
				draw_colored_polygon(PackedVector2Array([pt+Vector2(-3,1),pt+Vector2(-2,-2),pt+Vector2(2,-3),pt+Vector2(4,1)]),Color(.58,.62,.45,.65))
		# Tight, soft footprint beneath the painted base, offset toward the light's opposite.
		for layer in range(4,0,-1):
			draw_set_transform(Vector2(2,3),0,Vector2(1,.24))
			draw_circle(Vector2.ZERO,w*(.45+layer*.10),Color(.20,.27,.16,.035))
			draw_set_transform(Vector2.ZERO)
	if kind<4 and candidate_mode>0:
		var contour:=PackedVector2Array()
		for i in 12:
			var a:=i*TAU/12.0
			var r:=1.0+.13*sin(i*2.3+detail_seed*19)
			contour.append(Vector2(cos(a)*w*r,sin(a)*w*(.24 if kind<2 else .35)*r)+Vector2(4,4))
		draw_colored_polygon(contour,Color(.22,.29,.16,.23))
	draw_texture_rect(texture,Rect2(Vector2(-display_size.x*.5,-display_size.y+8),display_size),false,Color(1,1,1,.48 if faded else 1.0))

	if kind<4 and candidate_mode==0:
		for i in range(2+int(detail_seed*3)):
			var x := (float(i)/4.0-.4)*w*1.5+detail_seed*9
			var pt := Vector2(x,6+sin(i*2.7+detail_seed)*2)
			draw_polyline(PackedVector2Array([pt+Vector2(-2,-3),pt,pt+Vector2(2,-5)]),Color(.43,.61,.31,.72),1.3,true)

func update_occlusion(actor_position: Vector2) -> void:
	if kind > 1: return
	var delta := actor_position-global_position
	var next := delta.y < 18 and delta.y > -display_size.y+20 and absf(delta.x)<display_size.x*.48
	if next != faded:
		faded=next
		queue_redraw()
