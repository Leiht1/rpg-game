extends Control
## Original vector dial: 24-hour clockwise sectors, continuous hand, blended weather.
var simulation: Node
const CENTER = Vector2(70,70)
const INK = Color("514b3d")

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(140,164)

func point(hour:float, radius:float)->Vector2:
	return CENTER+Vector2.from_angle(hour/24.0*TAU-PI/2)*radius

func sector(start:float, end:float, color:Color)->void:
	var points:=PackedVector2Array([CENTER])
	for i in range(65): points.append(point(lerpf(start,end,float(i)/64),59))
	draw_colored_polygon(points,color)

func _draw()->void:
	if not is_instance_valid(simulation):return
	draw_circle(CENTER+Vector2(0,3),68,Color(0,0,0,.16))
	draw_circle(CENTER,67,INK)
	draw_circle(CENTER,64,Color("d7cba8"))
	sector(0,5,Color("505c74"))
	sector(5,8,Color("dfbd7d"))
	sector(8,17,Color("f0da91"))
	sector(17,20,Color("c68d5d"))
	sector(20,24,Color("505c74"))
	draw_arc(CENTER,60,0,TAU,128,INK,1.5,true)
	for hour in 24:
		var color:=Color("f5e8bf") if hour<5 or hour>=20 else Color("7a684b")
		draw_line(point(hour,54 if hour%6==0 else 57),point(hour,60),color,2 if hour%6==0 else 1,true)
	var dial_font := ThemeDB.fallback_font
	for entry in [["12",0.0],["3",6.0],["6",12.0],["9",18.0]]:
		var at := point(float(entry[1]),46.0)
		var width := dial_font.get_string_size(entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		draw_string(dial_font,at+Vector2(-width/2.0,4.0),entry[0],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("fff4d6"))
	# Weather rests inside a quiet central medallion; ring remains readable.
	draw_circle(CENTER,33,INK)
	draw_circle(CENTER,30,Color("e6dfc3"))
	var weights:Vector3=simulation.blend
	var rain:float=weights.z+weights.y
	if weights.x>.001: draw_sun(weights.x)
	if rain>.001: draw_cloud(rain)
	if rain>.001:
		for x in [-13,0,13]:
			draw_line(CENTER+Vector2(x,12),CENTER+Vector2(x-3,19),Color(.35,.52,.65,rain),2.2,true)
	if weights.y>.001:
		var bolt:=PackedVector2Array([CENTER+Vector2(3,-3),CENTER+Vector2(-6,10),CENTER+Vector2(0,10),CENTER+Vector2(-3,24),CENTER+Vector2(10,6),CENTER+Vector2(3,6)])
		draw_colored_polygon(bolt,Color(1,.83,.27,weights.y))
		bolt.append(bolt[0])
		draw_polyline(bolt,Color(.48,.37,.16,weights.y),1.2,true)
	# Narrow hand moves continuously over the ring, leaving icon unobscured.
	var hour:float=simulation.minute/60.0
	var tip:=point(hour,57)
	var base:=point(hour,36)
	var normal:Vector2=(tip-base).normalized().orthogonal()*4
	draw_colored_polygon(PackedVector2Array([tip,base+normal,base-normal]),Color("fff0ca"))
	draw_polyline(PackedVector2Array([tip,base+normal,base-normal,tip]),INK,1.4,true)
	# Small day plaque is part of the same widget.
	var plaque:=Rect2(26,132,88,26)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("e6dfc3");style.border_color=INK
	style.set_border_width_all(2);style.set_corner_radius_all(8)
	draw_style_box(style,plaque)
	var text:="第 %d 天"%simulation.day
	var font:=ThemeDB.fallback_font
	var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
	draw_string(font,Vector2(70-width/2,150),text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,INK)

func draw_sun(alpha:float)->void:
	var color:=Color(.85,.58,.22,alpha)
	for i in 8:
		var dir:=Vector2.from_angle(float(i)*TAU/8)
		draw_line(CENTER+dir*16,CENTER+dir*21,color,2,true)
	draw_circle(CENTER,11,color)
	draw_circle(CENTER+Vector2(-2,-2),8,Color(1,.81,.39,alpha))

func draw_cloud(alpha:float)->void:
	var edge:=Color(.37,.43,.45,alpha)
	var fill:=Color(.69,.73,.71,alpha)
	# Single cloud silhouette, softly rounded and intentionally low detail.
	for entry in [[Vector2(-13,1),8.0],[Vector2(-5,-7),11.0],[Vector2(7,-5),10.0],[Vector2(15,2),7.0]]:
		draw_circle(CENTER+entry[0],entry[1]+1.5,edge)
	for entry in [[Vector2(-13,1),8.0],[Vector2(-5,-7),11.0],[Vector2(7,-5),10.0],[Vector2(15,2),7.0]]:
		draw_circle(CENTER+entry[0],entry[1],fill)
	draw_style_box(cloud_base(fill),Rect2(CENTER+Vector2(-15,-1),Vector2(32,10)))

func cloud_base(color:Color)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=color
	style.set_corner_radius_all(4)
	return style
