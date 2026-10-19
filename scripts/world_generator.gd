extends "res://scripts/world_generator_base.gd"
## Approved V0.6: topology -> room union/coast -> ecology -> inland water.
const VERSION := "windrest-continent-0.6.0"
const PROP_VERSION := "windrest-props-0.7.1"
var rooms:Array[Dictionary]=[]
var links:Array[Dictionary]=[]
var field:Image
var ecology_field:Image
const GRID:=385

func _init(seed_value:int=271828,size_cells:int=1024,plan:Dictionary={}) -> void:
	if not plan.is_empty():
		rooms.assign(plan.rooms);links.assign(plan.links);field=plan.field;ecology_field=plan.get("ecology_field",null)
	super(seed_value,size_cells,plan)

func plan_snapshot()->Dictionary:
	var plan:=super.plan_snapshot()
	plan.merge({"rooms":rooms,"links":links,"field":field,"ecology_field":ecology_field,"version":VERSION})
	return plan

func _build_structure()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=world_seed^604619
	var count:=rng.randi_range(12,18)
	var raw:Array[Vector2]=[Vector2.ZERO]
	var parents:Array[int]=[-1]
	var degrees:Array[int]=[0]
	# Task-level tree is complete before any room gets a spatial coordinate.
	for i in range(1,count):
		var eligible:Array[int]=[]
		for j in i:
			if degrees[j]<3:eligible.append(j)
		var parent:int=i-1 if degrees[i-1]<3 and rng.randf()<.40 else eligible[rng.randi_range(0,eligible.size()-1)]
		parents.append(parent);degrees[parent]+=1;degrees.append(1)
	# Embed the fixed topology, allowing asymmetric growth in any direction.
	for i in range(1,count):
		var best:=Vector2.ZERO;var best_score:=-INF
		var a:=parents[i]
		for attempt in 180:
			var candidate:=raw[a]+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(.85,1.35 if attempt<120 else 2.1)
			var gap:=INF
			for j in i:
				if j!=a:gap=minf(gap,candidate.distance_to(raw[j]))
			if gap<.80:continue
			var score:=rng.randf()+minf(gap,1.3)*.16-(.45 if attempt>=120 else 0.)
			if score>best_score:best_score=score;best=candidate
		raw.append(best)
	var low:=raw[0];var high:=raw[0]
	for p in raw:low=low.min(p);high=high.max(p)
	var stretch:=Vector2(rng.randf_range(.78,1.12),rng.randf_range(.78,1.12))
	var scale:=.88/(maxf((high-low).x*stretch.x,(high-low).y*stretch.y)+2.25)
	var center:=(low+high)*.5
	for i in count:
		var p:=(raw[i]-center)*stretch*scale*extent+Vector2.ONE*extent*.5
		var radius:=rng.randf_range(.51,.89)*scale*extent
		rooms.append({"p":p,"r":Vector2(radius,radius*rng.randf_range(.70,1.28)),"angle":rng.randf()*TAU,"phase":rng.randf()*TAU})
		region_cores.append(p);region_scales.append(1.);region_kinds.append(0)
		if i>0:
			links.append({"a":parents[i],"b":i,"width":rng.randf_range(.27,.60)*scale*extent})
	# Add a few short, non-crossing chords. Broad room overlap also forms shared borders.
	var extra:=rng.randi_range(1,3)
	for a in count:
		if extra<=0:break
		for b in range(a+1,count):
			if parents[b]==a or raw[a].distance_to(raw[b])>1.75:continue
			var crosses:=false
			for edge in links:
				if a in [edge.a,edge.b] or b in [edge.a,edge.b]:continue
				if Geometry2D.segment_intersects_segment(region_cores[a],region_cores[b],region_cores[edge.a],region_cores[edge.b])!=null:crosses=true
			if crosses:continue
			links.append({"a":a,"b":b,"width":rng.randf_range(.30,.55)*scale*extent});extra-=1;break
	# Ecology follows rooms after the continent graph exists. Size is inherited from rooms.
	for i in count:
		var degree:=0
		for edge in links:
			if edge.a==i or edge.b==i:degree+=1
		region_kinds[i]=2 if degree>=3 and rng.randf()<.65 else rng.randi_range(0,2)
	for i in 6:region_kinds[i]=(i+world_seed%3)%3
	for i in count:region_sites[Vector2i(i,0)]=Vector3(region_cores[i].x,region_cores[i].y,region_kinds[i])
	for edge in links:region_neighbors.append(Vector2i(edge.a,edge.b))
	field=Image.create(GRID,GRID,false,Image.FORMAT_RGBAF)
	ecology_field=Image.create(GRID,GRID,false,Image.FORMAT_RGBAF)
	for y in GRID:
		for x in GRID:
			var p:=Vector2(x,y)*extent/(GRID-1.)
			var q:=p+Vector2(region_warp.get_noise_2dv(p),region_warp.get_noise_2d(p.y+extent,p.x))*extent*.026
			var land:=-INF;var distances:=Vector3(INF,INF,INF)
			var ecology_distances:=Vector4(INF,INF,INF,INF)
			for i in count:
				var room:=rooms[i]
				var rel:Vector2=(q-room.p).rotated(-room.angle)/room.r
				var angle:=rel.angle()
				var rim:float=1.+.13*sin(angle*3.+room.phase)+.08*sin(angle*5.-room.phase)
				var d:float=(rel.length()-rim)*minf(room.r.x,room.r.y)
				land=maxf(land,-d)
				distances[region_kinds[i]]=minf(distances[region_kinds[i]],d)
				# Whole room territories share the same four-way regional competition.
				var ecology_kind:int=3 if i>=6 and i%4==world_seed%4 else region_kinds[i]
				ecology_distances[ecology_kind]=minf(ecology_distances[ecology_kind],d)
			for edge in links:
				var a:=region_cores[edge.a];var b:=region_cores[edge.b]
				var distance:=p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))
				land=maxf(land,edge.width-distance)
			land+=warp.get_noise_2dv(p)*extent*.006+detail.get_noise_2dv(p)*extent*.0015
			# Ocean margin is part of the continent bounds, never a green world edge.
			land=minf(land,minf(minf(p.x,p.y),minf(extent-p.x,extent-p.y))-extent*.035)
			var nearest:=minf(distances.x,minf(distances.y,distances.z))
			var width:=extent*(.006+.008*moisture.get_noise_2dv(p)+.008)
			var weights:=Vector3.ZERO
			for k in 3:weights[k]=1.-smoothstep(0.,width,distances[k]-nearest)
			weights/=weights.x+weights.y+weights.z
			field.set_pixel(x,y,Color(weights.x,weights.y,weights.z,land))
			var ecology_nearest:float=minf(minf(ecology_distances.x,ecology_distances.y),minf(ecology_distances.z,ecology_distances.w))
			var ecology_weights:=Vector4.ZERO
			for k in 4:ecology_weights[k]=1.-smoothstep(0.,width,ecology_distances[k]-ecology_nearest)
			ecology_weights/=ecology_weights.x+ecology_weights.y+ecology_weights.z+ecology_weights.w
			ecology_field.set_pixel(x,y,Color(ecology_weights.x,ecology_weights.y,ecology_weights.z,ecology_weights.w))

func _field(p:Vector2)->Color:
	var uv:=(p/extent*(GRID-1)).clamp(Vector2.ZERO,Vector2.ONE*(GRID-1.001))
	var x:=floori(uv.x);var y:=floori(uv.y)
	return field.get_pixel(x,y).lerp(field.get_pixel(x+1,y),uv.x-x).lerp(field.get_pixel(x,y+1).lerp(field.get_pixel(x+1,y+1),uv.x-x),uv.y-y)

func coast_distance(p:Vector2)->float:return _field(p).a
func macro_weights(p:Vector2)->Vector3:
	var v:=_field(p);return Vector3(v.r,v.g,v.b)
func _build_connections()->void:
	for edge in links:connections.append(PackedVector2Array([region_cores[edge.a],region_cores[edge.b]]))
func _choose_spawn()->void:
	var best:=-INF
	for y in range(10,90):
		for x in range(10,90):
			var p:=Vector2(x,y)*extent/100.
			if macro_weights(p).z<.99 or coast_distance(p)<extent*.025:continue
			var score:=random_at(x,y,606)+minf(coast_distance(p)/extent,.10)*2.
			if score>best:best=score;spawn=p
func _build_lakes()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=world_seed^70631
	var unit:=extent/49152.
	var target:=rng.randi_range(3,5)
	for attempt in 900:
		if lakes.size()>=target:break
		var room:Dictionary=rooms[rng.randi_range(0,rooms.size()-1)]
		var p:Vector2=room.p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(.15,.85)*room.r.x
		var lake:=Vector4(p.x,p.y,rng.randf_range(440.,850.)*unit,rng.randf_range(350.,720.)*unit)
		var radius:=maxf(lake.z,lake.w)*1.7+100.*unit
		if coast_distance(p)<radius+150.*unit or corridor_distance(p)<radius+130.*unit or p.distance_to(spawn)<radius+600.*unit:continue
		var overlaps:=false
		for old in lakes:
			if p.distance_to(Vector2(old.x,old.y))<radius+maxf(old.z,old.w)*1.7:overlaps=true
		if overlaps:continue
		lakes.append(lake);_index_water(lake_bins,lake,p-Vector2.ONE*radius,p+Vector2.ONE*radius)
		# Continuous meandering inland tributaries, never carved through protected graph.
		for trial in 10:
			if trial>0 and rng.randf()<.25:break
			var direction:=Vector2.from_angle(rng.randf()*TAU)
			var length:=rng.randf_range(1400.,3100.)*unit
			var width:=rng.randf_range(75.,120.)*unit
			var points:=PackedVector2Array([p]);var safe:=true
			for j in range(1,25):
				var fraction:=j/24.
				var next:=p+direction*length*fraction+direction.orthogonal()*sin(fraction*PI*1.7)*length*.15
				if coast_distance(next)<width+240.*unit or corridor_distance(next)<width+160.*unit or next.distance_to(spawn)<700.*unit:safe=false
				for old in lakes:
					if old==lake:continue
					if next.distance_to(Vector2(old.x,old.y))<maxf(old.z,old.w)*1.7+width:safe=false
				points.append(next)
			if not safe:continue
			rivers.append({"points":points,"width":width})
			for j in range(1,points.size()):
				var a:Vector2=points[j-1];var b:Vector2=points[j]
				_index_water(river_bins,{"a":a,"b":b,"width":width},a.min(b)-Vector2.ONE*(width+350),a.max(b)+Vector2.ONE*(width+350))
			break
func ecology_weights(p:Vector2)->Color:
	if ecology_field==null:return Color(macro_weights(p).x,macro_weights(p).y,macro_weights(p).z,0.)
	var uv:=(p/extent*(GRID-1)).clamp(Vector2.ZERO,Vector2.ONE*(GRID-1.001))
	var x:=floori(uv.x);var y:=floori(uv.y)
	return ecology_field.get_pixel(x,y).lerp(ecology_field.get_pixel(x+1,y),uv.x-x).lerp(ecology_field.get_pixel(x,y+1).lerp(ecology_field.get_pixel(x+1,y+1),uv.x-x),uv.y-y)

func sample(p:Vector2,_spawn_clearance:bool=true)->Vector4:
	var value:=super.sample(p,false)
	value.z=maxf(value.z,1.-smoothstep(-48.,64.,coast_distance(p)))
	var ecology:=ecology_weights(p)
	value.x=ecology.r;value.y=ecology.g;value.w=ecology.b
	return value

func rocky_weight(p: Vector2) -> float:
	return ecology_weights(p).a

func overview_color(p: Vector2) -> Color:
	var v:=sample(p)
	if v.z>.35:return Color("70afb9")
	var weights:=ecology_weights(p)
	return Color("6d9c68")*weights.r+Color("aaa58c")*weights.g+Color("adc979")*weights.b+Color("929ca6")*weights.a

func biome(p:Vector2)->String:
	if coast_distance(p)<0.:return "海洋"
	var v:=sample(p)
	if v.z>.56:return "湖泊"
	if v.z>.12:return "水岸"
	if rocky_weight(p)>=maxf(v.x,maxf(v.y,v.w)):return "岩石区"
	var name := super.biome(p)
	return "泥地" if name=="山地" else name




func props_for_chunk(coord: Vector2i) -> Array[Dictionary]:
	# Preserve terrain and original tree/decor RNG; retire only legacy scenery rocks.
	var result: Array[Dictionary]=[]
	for row in super.props_for_chunk(coord):
		if row.kind not in [2,3]: result.append(row)
	return result
