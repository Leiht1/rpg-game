from pathlib import Path
p=Path('scripts/world_generator.gd');old=p.read_text(encoding='utf-8');tail=old[old.index('func build_chunk('):]
s='''class_name WildGenerator
extends RefCounted

## Four deterministic layers: region graph -> macro weights -> subenvironment -> props/water.
const VERSION := "windrest-biome-0.4.0"
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

func _init(seed_value: int = 271828, size_cells: int = 1024) -> void:
	world_seed=seed_value
	map_cells=clampi(size_cells,128,1024)
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
	_build_structure()
	_build_connections()
	_choose_spawn()
	_build_lakes()

func random_at(x: int, y: int, salt: int = 0) -> float:
	var h := (world_seed & 0x7fffffff) ^ ((x * 374761393) & 0x7fffffff) ^ ((y * 668265263) & 0x7fffffff) ^ (salt * 69069)
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = (h ^ (h >> 16)) & 0x7fffffff
	return float(h) / 2147483647.0

func _build_structure() -> void:
	# Three connected families, not independently typed cells on a repeating grid.
	var rotation:=random_at(0,0,201)*TAU
	var center:=Vector2.ONE*extent*.5
	for kind in 3:
		var angle:=rotation+kind*TAU/3.0+(random_at(kind,0,202)-.5)*.38
		var distance:=extent*(.24+random_at(kind,0,203)*.105)
		var core:=center+Vector2.from_angle(angle)*distance
		region_cores.append(core)
		region_sites[Vector2i(kind,0)]=Vector3(core.x,core.y,kind)
		# Nearby same-biome extensions create unequal, nonconvex silhouettes.
		for arm in range(1,3):
			var reach:=extent*(.035+random_at(kind,arm,205)*.045)
			var extension:=core+Vector2.from_angle(angle+(arm*2-3)*(.75+random_at(kind,arm,204)))*reach
			extension=extension.clamp(Vector2.ONE*extent*.08,Vector2.ONE*extent*.92)
			region_sites[Vector2i(kind,arm)]=Vector3(extension.x,extension.y,kind)

func macro_weights(p: Vector2) -> Vector3:
	var q:=p+Vector2(region_warp.get_noise_2d(p.x,p.y),region_warp.get_noise_2d(p.y+extent,p.x))*extent*.055
	var distances:=Vector3(INF,INF,INF)
	for site in region_sites.values():
		var kind:=int(site.z)
		distances[kind]=minf(distances[kind],q.distance_to(Vector2(site.x,site.y)))
	var nearest:=minf(distances.x,minf(distances.y,distances.z))
	var width:=clampf(extent*.022,220.,1100.)
	var weights:=Vector3.ZERO
	for kind in 3:weights[kind]=1.0-smoothstep(0.,width,distances[kind]-nearest)
	return weights/(weights.x+weights.y+weights.z)

func _build_connections() -> void:
	# Minimum spanning graph between all primary regions; no road texture is painted.
	var reached: Array[int]=[0]
	while reached.size()<3:
		var best:=INF
		var from_index:=0
		var to_index:=1
		for a in reached:
			for b in 3:
				if b in reached:continue
				var distance:=region_cores[a].distance_squared_to(region_cores[b])
				if distance<best:best=distance;from_index=a;to_index=b
		var start:=region_cores[from_index]
		var finish:=region_cores[to_index]
		var normal:=(finish-start).normalized().orthogonal()
		var bend:=(random_at(from_index,to_index,240)-.5)*extent*.035
		var path:=PackedVector2Array()
		for i in 9:
			var t:=i/8.0
			path.append(start.lerp(finish,t)+normal*sin(t*PI)*bend)
		connections.append(path)
		reached.append(to_index)
	# Long internal natural passages stay within their parent ecology.
	var step:=extent/128.0
	for kind in 3:
		var origin:=region_cores[kind]
		var best_length:=0.0
		var best_path:=PackedVector2Array()
		for i in 18:
			var direction:=Vector2.from_angle(i*PI/18.0)
			var ends: Array[Vector2]=[]
			for sign_value in [-1.,1.]:
				var point:=origin
				while true:
					var next:=point+direction*step*sign_value
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
	spawn=region_cores[2]
	var best:=INF
	for y in range(2,19):
		for x in range(2,19):
			var point:=Vector2(x,y)*extent/20.0
			var weights:=macro_weights(point)
			if weights.max_axis_index()!=2 or weights.z<.98:continue
			var score:=point.distance_to(center)+random_at(x,y,251)*extent*.015
			if score<best:best=score;spawn=point

func _build_lakes() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=world_seed
	for by in ceili(extent/6144.0):
		for bx in ceili(extent/6144.0):
			for i in rng.randi_range(3,6):
				var point:=Vector2(bx,by)*6144+Vector2(rng.randf_range(650,5494),rng.randf_range(550,5594))
				var lake:=Vector4(point.x,point.y,rng.randf_range(280,680),rng.randf_range(230,510))
				if point.x>extent-1000 or point.y>extent-1000 or point.distance_to(spawn)<1400:continue
				# Reduce old lake density; protect the region connection skeleton.
				if random_at(roundi(point.x),roundi(point.y),934)>=.5:continue
				if corridor_distance(point)<maxf(lake.z,lake.w)*1.6+400:continue
				# Water belongs to wet catchments, rather than a uniform sprinkling.
				var wet:=smoothstep(-.55,.5,moisture.get_noise_2dv(point))
				if random_at(roundi(point.x),roundi(point.y),935)>wet*.75+.25:continue
				lakes.append(lake)
				var lo:=Vector2i((point-Vector2(lake.z,lake.w)*1.9)/2048)
				var hi:=Vector2i((point+Vector2(lake.z,lake.w)*1.9)/2048)
				for y in range(lo.y,hi.y+1):
					for x in range(lo.x,hi.x+1):
						var key:=Vector2i(x,y)
						if not lake_bins.has(key):lake_bins[key]=[]
						lake_bins[key].append(lake)

func sample(p: Vector2, _spawn_clearance: bool = true) -> Vector4:
	var weights:=macro_weights(p)
	var q:=p+Vector2(warp.get_noise_2d(p.x,p.y),warp.get_noise_2d(p.y+1200,p.x))*240
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
	return Vector4(weights.x,weights.y,water,weights.z)

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

'''+tail
p.write_text(s,encoding='utf-8')
# Remove only the spawn-only art override. New lake art remains an unapproved separate preview.
p=Path('scripts/terrain.gdshader');s=p.read_text(encoding='utf-8');s=s.replace(' float safe=1.-smoothstep(200.,470.,distance(p,ground_origin));\n base=mix(base,sample_ground(spawn_tex,p),safe);\n','');p.write_text(s,encoding='utf-8')
# Preserve a saved world's seed/size across generator upgrades, without promising old layout.
p=Path('scripts/world.gd');s=p.read_text(encoding='utf-8').replace('data.get("generator")==Gen.VERSION','str(data.get("generator","")).begins_with("windrest-biome-")');p.write_text(s,encoding='utf-8')
p=Path('prototypes/view-v01/formal_v03.gd');s=p.read_text(encoding='utf-8').replace('\tworld_seed = seed_value','\tregion_sites.clear()\n\tlakes.clear()\n\tlake_bins.clear()\n\tworld_seed = seed_value',1);p.write_text(s,encoding='utf-8')
print('four-layer generator written')
