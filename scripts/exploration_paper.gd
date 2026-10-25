extends Control
## Existing painted paper texture, cut to distinct page contours. No window frame.
var kind:="letter"
var texture: Texture2D=preload("res://assets/ui/survival_guide_v1/letter.png")
func _draw() -> void:
	var outline:=PackedVector2Array([Vector2(16,9),Vector2(152,13),Vector2(282,6),Vector2(525,14),Vector2(546,30),Vector2(550,373),Vector2(535,397),Vector2(360,403),Vector2(185,397),Vector2(23,405),Vector2(8,380),Vector2(12,230),Vector2(5,98)])
	if kind=="note":
		outline=PackedVector2Array([Vector2(28,17),Vector2(154,12),Vector2(282,21),Vector2(525,10),Vector2(546,30),Vector2(548,342),Vector2(521,352),Vector2(528,365),Vector2(491,370),Vector2(477,390),Vector2(420,380),Vector2(397,400),Vector2(328,385),Vector2(302,399),Vector2(260,387),Vector2(230,401),Vector2(193,391),Vector2(152,405),Vector2(23,394),Vector2(13,304),Vector2(19,219),Vector2(7,190),Vector2(18,168),Vector2(11,101)])
	var shadow:=PackedVector2Array();var uv:=PackedVector2Array()
	for p in outline:shadow.append(p+Vector2(5,8));uv.append(p/Vector2(560,416))
	draw_colored_polygon(shadow,Color(0.12,.10,.07,.26))
	draw_polygon(outline,PackedColorArray([Color.WHITE]),uv,texture)
	# Quiet light/dark fold pairs, away from the text's main contrast.
	draw_line(Vector2(283,24),Vector2(278,385),Color(.52,.39,.23,.08),1,true)
	draw_line(Vector2(285,24),Vector2(280,385),Color(1,1,.94,.24),1,true)
	draw_colored_polygon(PackedVector2Array([Vector2(523,17),Vector2(541,34),Vector2(520,35)]),Color(.83,.75,.58,.5))
	if kind=="map":draw_map()
func draw_map() -> void:
	var ink:=Color(.29,.38,.36,.57)
	var river:=PackedVector2Array([Vector2(109,227),Vector2(158,238),Vector2(192,264),Vector2(262,263),Vector2(309,285),Vector2(355,282),Vector2(407,316),Vector2(446,320)])
	draw_polyline(river,ink,3,true)
	var bank:=river.duplicate()
	for i in bank.size():bank[i]+=Vector2(0,11)
	draw_polyline(bank,Color(.32,.43,.43,.25),2,true)
	for x in [156,208,267]:
		draw_polyline(PackedVector2Array([Vector2(x,218),Vector2(x+16,185),Vector2(x+33,220)]),Color(.39,.36,.29,.33),2,true)
	for i in 13:
		var p:=Vector2(146+i*15,326-sin(i*.17)*44)
		draw_line(p,p+Vector2(6,-2),Color(.43,.29,.19,.51),2,true)
	draw_circle(Vector2(141,328),8,Color(.44,.30,.20,.13))
	draw_line(Vector2(135,322),Vector2(147,334),ink,2,true)
	draw_line(Vector2(147,322),Vector2(135,334),ink,2,true)
	# Incomplete human mark; no final destination or mine location.
	draw_arc(Vector2(369,261),8,0,TAU,20,ink,1.5,true)
	draw_line(Vector2(369,270),Vector2(369,287),ink,2,true)
	draw_line(Vector2(369,277),Vector2(389,265),ink,1.5,true)
