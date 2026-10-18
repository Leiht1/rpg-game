extends "res://scripts/nature_prop.gd"
## Approved second study: unchanged PNG geometry with live ground-colored overlap.
var enabled := true
var edge := PackedVector2Array()
var foot := Vector2.ZERO
var footprint := 12.0
static var edge_cache := {}

func prepare() -> void:
	var key := texture.resource_path
	if not edge_cache.has(key):
		var img := texture.get_image()
		var samples := PackedVector2Array()
		# Ignore translucent antialias fringe; find the actual lower painted edge.
		for x in range(0,img.get_width(),2):
			for y in range(img.get_height()-1,int(img.get_height()*.75),-1):
				if img.get_pixel(x,y).a>.65:
					samples.append(Vector2(x,y));break
		edge_cache[key]=samples
	var scale_factor := display_size.x/texture.get_width()
	edge=PackedVector2Array()
	for p in edge_cache[key]:
		var pt:Vector2=p*scale_factor+Vector2(-display_size.x*.5,-display_size.y+8)
		# Tree lower quarters include branches in some art: only the trunk/root width.
		if kind>=2 or absf(pt.x)<display_size.x*.20:edge.append(pt)
	var low := -1000.0
	for p in edge:low=maxf(low,p.y)
	foot=Vector2(0,low-1.0)
	footprint=display_size.x*(.115 if kind<2 else .37)

func _draw() -> void:
	if not enabled or kind>=4:
		super._draw();return
	if texture==null:return
	# Two asymmetric, very quiet transition lobes, never a closed soil ring.
	soft_patch(foot+Vector2(-footprint*.35,-1),Vector2(footprint*.85,footprint*.37),.10,detail_seed)
	soft_patch(foot+Vector2(footprint*.48,1),Vector2(footprint*.70,footprint*.25),.10,detail_seed+1.2)
	# A narrow contact band follows the actual painted bottom, not the canvas bottom.
	for i in range(0,edge.size()-2,2):
		var a:=edge[i];var b:=edge[i+2]
		if a.distance_to(b)>footprint:continue
		var points:=PackedVector2Array([a+Vector2(-1,-1),b+Vector2(1,-1),b+Vector2(3,4),a+Vector2(1,4)])
		draw_polygon(points,PackedColorArray([Color(.21,.26,.18,.21),Color(.21,.26,.18,.21),Color(.21,.26,.18,0),Color(.21,.26,.18,0)]))
	draw_texture_rect(texture,Rect2(Vector2(-display_size.x*.5,-display_size.y+8),display_size),false,Color(1,1,1,.48 if faded else 1.))
	# Slightly wider/taller, separated lobes of the actual ground, not a dirt tint.
	if edge.size()>4:
		var count:=3 if kind<2 else 4
		for i in count:
			var index:=mini(edge.size()-1,int((.13+i*(.72/(count-1))+detail_seed*.045)*edge.size()))
			var p:=edge[index]+Vector2(0,1)
			var width:=4.0+detail_seed*2.0
			var height:=3.8+1.3*sin(i*2.4+detail_seed*5.)
			var points:=PackedVector2Array([p+Vector2(-width,1.8),p+Vector2(-width*.8,-.4),p+Vector2(-width*.35,-height*.70),p+Vector2(.5,-height),p+Vector2(width*.42,-height*.40),p+Vector2(width,-.2),p+Vector2(width*.85,2.2)])
			var colors:=PackedColorArray()
			var uvs:=PackedVector2Array()
			for j in points.size():
				colors.append(Color(1,1,1,.92 if j>=1 and j<=5 else 0.))
				uvs.append(Vector2(-1,-1))
			draw_polygon(points,colors,uvs)

func soft_patch(center:Vector2,radius:Vector2,opacity:float,phase:float)->void:
	# Triangles interpolate alpha to zero: no stacked hard ellipses or banded rings.
	for i in 24:
		var a:=i*TAU/24.0;var b:=(i+1)*TAU/24.0
		var ra:=1.0+.12*sin(a*3+phase*11)+.07*cos(a*5+phase*4)
		var rb:=1.0+.12*sin(b*3+phase*11)+.07*cos(b*5+phase*4)
		var ca:=Color(1,1,1,opacity);var clear:=Color(1,1,1,0)
		draw_polygon(PackedVector2Array([center,center+Vector2(cos(a),sin(a))*radius*ra,center+Vector2(cos(b),sin(b))*radius*rb]),PackedColorArray([ca,clear,clear]),PackedVector2Array([Vector2(-1,-1),Vector2(-1,-1),Vector2(-1,-1)]))
