class_name WildGenerator
extends RefCounted

## Four deterministic layers: region graph -> macro weights -> subenvironment -> props/water.
const BASE_VERSION := "windrest-biome-0.5.0"
const REGION_SPAN := 8192.0 # Historical view-study compatibility; not the new region scale.
const CELL := 48
const CHUNK_CELLS := 24
const CHUNK_PX := CELL * CHUNK_CELLS
const TEX_RES := 144
const TEX_STEP := float(CHUNK_PX) / TEX_RES
const PROP_STEP := 144
var world_seed: int
var map_cells: int
var extent: float
var region_sites := {}
var region_cores: Array[Vector2] = []
var region_scales: Array[float] = []
var region_kinds: Array[int] = []
var region_neighbors: Array[Vector2i] = []
var rivers: Array[Dictionary] = []
var river_bins := {}
var connections: Array[PackedVector2Array] = []
var traversal_routes: Array[Dictionary] = []
var elevation := FastNoiseLite.new()
var moisture := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var warp := FastNoiseLite.new()
var region_warp := FastNoiseLite.new()
var phase: float
var lake_bins := {}
var lakes: Array[Vector4] = []
var spawn := Vector2.ZERO

func _init(seed_value: int = 271828, size_cells: int = 1024, plan: Dictionary = {}) -> void:
	world_seed=seed_value
	map_cells=clampi(size_cells,128,1536)
	extent=map_cells*CELL
	moisture.seed=world_seed^117
	moisture.frequency=1.0/clampf(extent*.045,650.,2200.)
	moisture.fractal_octaves=2
	elevation.seed=world_seed^912
	elevation.frequency=1.0/clampf(extent*.055,750.,2700.)
	elevation.fractal_octaves=2
	detail.seed=world_seed^713
	detail.frequency=.006
	detail.fractal_octaves=2
	warp.seed=world_seed^318
	warp.frequency=.00018
	warp.fractal_octaves=3
	region_warp.seed=world_seed^527
	region_warp.frequency=2.8/extent
	region_warp.fractal_octaves=2
	if not plan.is_empty():
		region_scales.assign(plan.scales)
		region_kinds.assign(plan.kinds)
		region_neighbors.assign(plan.neighbors)
		rivers.assign(plan.rivers)
		river_bins=plan.river_bins
		region_sites=plan.sites
		region_cores.assign(plan.cores)
		connections.assign(plan.connections)
		traversal_routes.assign(plan.routes)
		spawn=plan.spawn
		lakes.assign(plan.lakes)
		lake_bins=plan.bins
		return
	_build_structure()
	_build_connections()
	_choose_spawn()
	_build_lakes()

func plan_snapshot() -> Dictionary:
	# Read-only after construction. Workers own noises; share no mutable RNG/noise state.
	return {"scales":region_scales,"kinds":region_kinds,"neighbors":region_neighbors,"rivers":rivers,"river_bins":river_bins,"sites":region_sites,"cores":region_cores,"connections":connections,"routes":traversal_routes,"spawn":spawn,"lakes":lakes,"bins":lake_bins}

func random_at(x: int, y: int, salt: int = 0) -> float:
	var h := (world_seed & 0x7fffffff) ^ ((x * 374761393) & 0x7fffffff) ^ ((y * 668265263) & 0x7fffffff) ^ (salt * 69069)
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = (h ^ (h >> 16)) & 0x7fffffff
	return float(h) / 2147483647.0

func _build_structure() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=world_seed^4019
	# Fewer territories on small maps; best-candidate spacing avoids tiny cells.
	var count:=rng.randi_range(8,12) if map_cells>=768 else rng.randi_range(5,8) if map_cells>=384 else rng.randi_range(3,5)
	for i in count:
		var best:=Vector2.ZERO
		var clearance:=-1.0
		for attempt in 45:
			var candidate:=Vector2(rng.randf_range(.10,.90),rng.randf_range(.10,.90))*extent
			var distance:=INF
			for core in region_cores:distance=minf(distance,candidate.distance_squared_to(core))
			if distance>clearance:clearance=distance;best=candidate
		region_cores.append(best)
		region_scales.append(rng.randf_range(.90,1.12))
		region_kinds.append(-1)
	# Build actual spatial adjacency, then choose a three-biome assignment minimizing
	# same-kind shared edges. Repeated families are independent territory nodes.
	var edges:={}
	var labels:=PackedInt32Array()
	for y in 192:
		for x in 192:
			var id:=region_at((Vector2(x,y)+Vector2.ONE*.5)*extent/192.)
			labels.append(id)
			for other in [labels[y*192+x-1] if x>0 else id,labels[(y-1)*192+x] if y>0 else id]:
				if other!=id:edges[Vector2i(mini(id,other),maxi(id,other))]=true
	region_neighbors.assign(edges.keys())
	var best_score:=INF
	var best_kinds:Array[int]=[]
	for trial in 160:
		var kinds:Array[int]=[]
		for i in count:kinds.append(rng.randi_range(0,2))
		for sweep in 5:
			for i in count:
				var cost:=[0,0,0]
				for edge in region_neighbors:
					if edge.x==i:cost[kinds[edge.y]]+=1
					elif edge.y==i:cost[kinds[edge.x]]+=1
				var offset:=rng.randi_range(0,2)
				var chosen:=offset
				for k in 3:
					var candidate:=(k+offset)%3
					if cost[candidate]<cost[chosen]:chosen=candidate
				kinds[i]=chosen
		var score:=0.0
		for edge in region_neighbors:
			if kinds[edge.x]==kinds[edge.y]:score+=1.
		var seen:={}
		var components:=[0,0,0]
		for i in count:
			if seen.has(i):continue
			components[kinds[i]]+=1
			var queue:Array[int]=[i];seen[i]=true
			while not queue.is_empty():
				var current:int=queue.pop_back()
				for edge in region_neighbors:
					var other:=edge.y if edge.x==current else edge.x if edge.y==current else -1
					if other>=0 and not seen.has(other) and kinds[other]==kinds[i]:seen[other]=true;queue.append(other)
		for k in 3:
			if components[k]<(2 if count>=8 else 1):score+=100.
		if score<best_score:best_score=score;best_kinds=kinds.duplicate()
	region_kinds=best_kinds
	for i in count:
		var core:=region_cores[i]
		region_sites[Vector2i(i,0)]=Vector3(core.x,core.y,region_kinds[i])

func region_at(p: Vector2) -> int:
	var q:=p+Vector2(region_warp.get_noise_2d(p.x,p.y),region_warp.get_noise_2d(p.y+extent,p.x))*extent*.035
	var nearest:=INF
	var chosen:=0
	for i in region_cores.size():
		var distance:=q.distance_to(region_cores[i])/region_scales[i]
		if distance<nearest:nearest=distance;chosen=i
	return chosen

func macro_weights(p: Vector2) -> Vector3:
	var q:=p+Vector2(region_warp.get_noise_2d(p.x,p.y),region_warp.get_noise_2d(p.y+extent,p.x))*extent*.035
	var distances:=Vector3(INF,INF,INF)
	for i in region_cores.size():
		var kind:=region_kinds[i]
		distances[kind]=minf(distances[kind],q.distance_to(region_cores[i])/region_scales[i])
	var nearest:=minf(distances.x,minf(distances.y,distances.z))
	var width:=clampf(extent*.009,100.,440.)
	var weights:=Vector3.ZERO
	for kind in 3:weights[kind]=1.0-smoothstep(0.,width,distances[kind]-nearest)
	return weights/(weights.x+weights.y+weights.z)

func _build_connections() -> void:
	# Minimum spanning graph between all primary regions; no road texture is painted.
	var reached: Array[int]=[0]
	while reached.size()<region_cores.size():
		var best:=INF
		var from_index:=0
		var to_index:=1
		for a in reached:
			for b in region_cores.size():
				if b in reached:continue
				if not Vector2i(mini(a,b),maxi(a,b)) in region_neighbors:continue
				var distance:=region_cores[a].distance_squared_to(region_cores[b])
				if distance<best:best=distance;from_index=a;to_index=b
		var start:=region_cores[from_index]
		var finish:=region_cores[to_index]
		var normal:=(finish-start).normalized().orthogonal()
		var bend:=0.0 # Straight protected backbone; borders remain naturally warped.
		var path:=PackedVector2Array()
		for i in 9:
			var t:=i/8.0
			path.append(start.lerp(finish,t)+normal*sin(t*PI)*bend)
		connections.append(path)
		reached.append(to_index)
	# Long internal natural passages stay within their parent ecology.
	var step:=extent/128.0
	for node in region_cores.size():
		var kind:=region_kinds[node]
		var origin:=region_cores[node]
		var best_length:=0.0
		var best_path:=PackedVector2Array()
		for i in 18:
			var direction:=Vector2.from_angle(i*PI/18.0)
			var ends: Array[Vector2]=[]
			for sign_value in [-1.,1.]:
				var point:=origin
				while true:
					var next:Vector2=point+direction*step*sign_value
					if next.x<600 or next.y<600 or next.x>extent-600 or next.y>extent-600 or macro_weights(next)[kind]<.94:break
					point=next
				ends.append(point)
			var length:=ends[0].distance_to(ends[1])
			if length>best_length:best_length=length;best_path=PackedVector2Array(ends)
		if best_path.size()==2:
			connections.append(best_path)
			traversal_routes.append({"kind":kind,"points":best_path,"length":best_length})

func corridor_distance(p: Vector2) -> float:
	var distance:=INF
	for path in connections:
		for i in range(1,path.size()):
			distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,path[i-1],path[i])))
	return distance

func _choose_spawn() -> void:
	# Select a real interior point; never rewrite its ground weights.
	var center:=Vector2.ONE*extent*.5
	spawn=region_cores[region_kinds.find(2)]
	var best:=INF
	for y in range(2,19):
		for x in range(2,19):
			var point:=Vector2(x,y)*extent/20.0
			var weights:=macro_weights(point)
			if weights.max_axis_index()!=2 or weights.z<.98:continue
			var boundary_clear:=true
			for offset in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
				if macro_weights(point+offset*extent*.025).z<.98:boundary_clear=false
			if not boundary_clear:continue
			var score:=point.distance_to(center)+random_at(x,y,251)*extent*.08
			if score<best:best=score;spawn=point

func _build_lakes() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=world_seed^7031
	var target:=rng.randi_range(3,6) if map_cells>=768 else rng.randi_range(1,3)
	var scale:=extent/49152.
	for attempt in 180:
		if lakes.size()>=target:break
		var point:=Vector2(rng.randf_range(.09,.91),rng.randf_range(.09,.91))*extent
		var lake:=Vector4(point.x,point.y,rng.randf_range(1500,2600)*scale,rng.randf_range(1100,2100)*scale)
		var radius:=maxf(lake.z,lake.w)*1.55+300.*scale
		if point.distance_to(spawn)<radius+600.*scale or corridor_distance(point)<radius:continue
		var overlaps:=false
		for previous in lakes:
			if point.distance_to(Vector2(previous.x,previous.y))<radius+maxf(previous.z,previous.w)*1.7:overlaps=true
		if overlaps:continue
		lakes.append(lake)
		_index_water(lake_bins,lake,point-Vector2.ONE*radius,point+Vector2.ONE*radius)
		# A connected, inland tributary terminates at this lake. It never reaches
		# the world border, another lake, spawn or the protected travel backbone.
		if rng.randf()>.65:continue
		var direction:=Vector2.from_angle(rng.randf()*TAU)
		var length:=rng.randf_range(3500,7000)*scale
		var width:=rng.randf_range(240,340)*scale
		var points:=PackedVector2Array([point])
		var safe:=true
		for j in range(1,25):
			var t:=j/24.
			var next:=point+direction*length*t+direction.orthogonal()*sin(t*PI*1.7)*length*.14
			if next.x<radius*.3 or next.y<radius*.3 or next.x>extent-radius*.3 or next.y>extent-radius*.3 or next.distance_to(spawn)<600.*scale+width or corridor_distance(next)<width+320.*scale:safe=false
			for previous in lakes:
				if previous==lake:continue
				if next.distance_to(Vector2(previous.x,previous.y))<maxf(previous.z,previous.w)*1.7+width:safe=false
			points.append(next)
		if not safe:continue
		var river:={"points":points,"width":width}
		rivers.append(river)
		for j in range(1,points.size()):
			var entry:={"a":points[j-1],"b":points[j],"width":width}
			_index_water(river_bins,entry,points[j-1].min(points[j])-Vector2.ONE*(width+350),points[j-1].max(points[j])+Vector2.ONE*(width+350))

func _index_water(bins: Dictionary, entry: Variant, low: Vector2, high: Vector2) -> void:
	var lo:=Vector2i(low/2048.)
	var hi:=Vector2i(high/2048.)
	for y in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			var key:=Vector2i(x,y)
			if not bins.has(key):bins[key]=[]
			bins[key].append(entry)

func sample(p: Vector2, _spawn_clearance: bool = true) -> Vector4:
	var weights:=macro_weights(p)
	var q:=p+Vector2(warp.get_noise_2d(p.x,p.y),warp.get_noise_2d(p.y+1200,p.x))*minf(240.,extent*.005)
	var water:=0.0
	for lake in lake_bins.get(Vector2i(q/2048),[]):
		var rel:Vector2=(q-Vector2(lake.x,lake.y))/Vector2(lake.z,lake.w)
		var angle:=atan2(rel.y,rel.x)
		var phase_value:=random_at(roundi(lake.x),roundi(lake.y),951)*TAU
		var radius:=.93+.19*sin(angle*3.+phase_value)+.13*sin(angle*5.-phase_value*.73)+.055*sin(angle*9.+phase_value*1.6)
		var bay_angle:=angle_difference(angle,phase_value)
		radius-=.25*exp(-bay_angle*bay_angle/.19)
		var signed_distance:float=(rel.length()-radius)*minf(lake.z,lake.w)
		water=maxf(water,1.-smoothstep(-65.,45.,signed_distance))
	for segment in river_bins.get(Vector2i(q/2048),[]):
		var closest:=Geometry2D.get_closest_point_to_segment(q,segment.a,segment.b)
		var width:float=segment.width*(1.+.10*warp.get_noise_2dv(q))
		water=maxf(water,1.-smoothstep(-35.,35.,q.distance_to(closest)-width))
	return Vector4(weights.x,weights.y,water,weights.z)

func overview_color(p: Vector2) -> Color:
	var v:=sample(p)
	var env:=subenvironment(p)
	var color:=Color("adc979").lerp(Color("6d9c68"),smoothstep(.25,.75,v.x)).lerp(Color("aaa58c"),smoothstep(.25,.75,v.y))
	color=color.lightened((.5-env.x)*.09).lerp(Color("b4aa83"),smoothstep(.65,.95,env.y)*(1.-env.x)*.12)
	if v.z>.35:color=Color("70afb9")
	return color

func biome(p: Vector2) -> String:
	var v:=sample(p)
	if v.z>.56:return "湖泊"
	if v.z>.12:return "水岸"
	if v.y>=v.x and v.y>=v.w:return "山地"
	if v.x>=v.w:return "森林"
	return "草原"

func subenvironment(p: Vector2) -> Vector2:
	# Density/rockiness never change the parent macro biome or its textures.
	return Vector2(smoothstep(-.4,.4,moisture.get_noise_2dv(p)),smoothstep(-.4,.4,elevation.get_noise_2dv(p)))

func can_walk(p: Vector2, radius: float = 10.0) -> bool:
	if p.x<radius or p.y<radius or p.x>extent-radius or p.y>extent-radius:return false
	for offset in [Vector2.ZERO,Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
		if sample(p+offset).z>.56:return false
	return true

func props_for_chunk(coord: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var first:=Vector2i(Vector2(coord)*CHUNK_PX/PROP_STEP)
	for y in range(first.y,first.y+CHUNK_PX/PROP_STEP):
		for x in range(first.x,first.x+CHUNK_PX/PROP_STEP):
			var point:=Vector2((x+.18+random_at(x,y,1)*.64)*PROP_STEP,(y+.18+random_at(x,y,2)*.64)*PROP_STEP)
			if point.x<64 or point.y<64 or point.x>=extent-64 or point.y>=extent-64:continue
			if point.distance_to(spawn)<110+random_at(x,y,910)*70:continue
			var v:=sample(point)
			if v.z>.03:continue
			var env:=subenvironment(point)
			var cluster:=smoothstep(-.45,.35,detail.get_noise_2dv(point))
			var trees:float=(v.x*(.09+env.x*.65)+v.y*.012+v.w*(.015+env.x*.075))*cluster
			var rocks:float=(v.y*(.13+env.y*.47)+v.x*.035+v.w*.025)*(.4+cluster*.6)
			# Keep unobtrusive natural foot passages; no special ground or decoration.
			var passage:=corridor_distance(point)
			if passage<85+random_at(x,y,911)*20:trees=0.;rocks=0.
			var roll:=random_at(x,y,3)
			var kind:=-1
			if roll<trees:kind=0 if random_at(x,y,7)<.7 else 1
			elif roll<trees+rocks:kind=2 if random_at(x,y,7)<.7 else 3
			elif roll>.96:kind=4+mini(2,int(random_at(x,y,8)*3))
			if kind>=0:result.append({"position":point,"kind":kind,"scale":.8+random_at(x,y,5)*.35,"id":"%d:%d"%[x,y]})
	return result

func rocky_weight(_p: Vector2) -> float:
	return 0.0

func build_chunk(coord: Vector2i) -> Dictionary:
	var begin := Time.get_ticks_usec()
	var bytes := PackedByteArray()
	bytes.resize((TEX_RES+6)*(TEX_RES+6)*4)
	var environment:=Image.create(26,26,false,Image.FORMAT_RGBA8)
	var index := 0
	var origin := Vector2(coord) * CHUNK_PX
	for y in 26:
		for x in 26:
			var env:=subenvironment(origin+Vector2(x-1,y-1)*CELL)
			environment.set_pixel(x,y,Color(env.x,env.y,rocky_weight(origin+Vector2(x-1,y-1)*CELL),1.))
	for y in range(-3,TEX_RES+3):
		for x in range(-3,TEX_RES+3):
			var p := origin + Vector2(x,y)*TEX_STEP
			var v := sample(p)
			bytes[index] = roundi(v.x*255)
			bytes[index+1] = roundi(v.y*255)
			bytes[index+2] = roundi(v.w*255)
			bytes[index+3] = roundi(v.z*255)
			index += 4
	return {"coord":coord,"image":Image.create_from_data(TEX_RES+6,TEX_RES+6,false,Image.FORMAT_RGBA8,bytes),
		"environment":environment,"props":props_for_chunk(coord),"build_ms":(Time.get_ticks_usec()-begin)/1000.0}

