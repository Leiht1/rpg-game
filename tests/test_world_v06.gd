extends SceneTree
const Gen=preload("res://prototypes/world-v06/generator.gd")
var checks:Array=[]
var reports:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String,details:Variant="")->void:
	checks.append({"name":label,"pass":ok,"details":details})
	if not ok:push_error(label+" "+str(details))
func components(labels:PackedInt32Array,grid:int)->Array:
	var seen:=PackedByteArray();seen.resize(labels.size())
	var result:Array=[]
	for at in labels.size():
		if seen[at] or labels[at]<0:continue
		var queue:Array[int]=[at];seen[at]=1;var cursor:=0
		while cursor<queue.size():
			var index:=queue[cursor];cursor+=1
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var p:Vector2i=Vector2i(index%grid,index/grid)+d
				if p.x<0 or p.y<0 or p.x>=grid or p.y>=grid:continue
				var next:int=p.y*grid+p.x
				if seen[next] or labels[next]!=labels[at]:continue
				seen[next]=1;queue.append(next)
		result.append({"kind":labels[at],"cells":queue.size()})
	return result
func run()->void:
	# Fixed PRNG draw, no discarding unfavourable seeds.
	var rng:=RandomNumberGenerator.new();rng.seed=2026101606
	var seeds:Array[int]=[]
	for i in 10:seeds.append(rng.randi_range(1,2147483000))
	for seed_value in seeds:
		var began:=Time.get_ticks_usec()
		var gen=Gen.new(seed_value,1024)
		var plan_ms:float=(Time.get_ticks_usec()-began)/1000.
		var repeat=Gen.new(seed_value,1024)
		var worker=Gen.new(seed_value,1024,gen.plan_snapshot())
		var grid:=384;var step:float=gen.extent/grid
		var land:=PackedInt32Array();var biomes:=PackedInt32Array();var counts:=[0,0,0]
		var edge_water:=true;var mismatch:=0;var dry:=0
		var low:Vector2=Vector2.ONE*gen.extent;var high:=Vector2.ZERO
		for y in grid:
			for x in grid:
				var p:=(Vector2(x,y)+Vector2.ONE*.5)*step
				var v:Vector4=gen.sample(p)
				var walk:bool=gen.can_walk(p,25)
				land.append(1 if walk else -1)
				var kind:=Vector3(v.x,v.y,v.w).max_axis_index() if walk else -1
				biomes.append(kind)
				if walk:counts[kind]+=1;dry+=1;low=low.min(p);high=high.max(p)
				if (x==0 or y==0 or x==grid-1 or y==grid-1) and v.z<.99:edge_water=false
				if x%7==0 and y%7==0:
					if v!=repeat.sample(p) or v!=worker.sample(p):mismatch+=1
		var groups:=components(land,grid);var largest:=0
		for group in groups:largest=maxi(largest,group.cells)
		var reach:=float(largest)/maxi(1,dry)
		check(reach>.999,"mainland sampled connectivity %d"%seed_value,reach)
		check(edge_water,"all world edges ocean %d"%seed_value)
		check(mismatch==0,"repeat and worker samples %d"%seed_value)
		check(gen.can_walk(gen.spawn,150) and gen.macro_weights(gen.spawn).z>.98,"natural inland grass spawn %d"%seed_value)
		var route_dry:=true
		for path in gen.connections:
			for i in ceili(path[0].distance_to(path[1])/48.)+1:
				if not gen.can_walk(path[0].move_toward(path[1],i*48.),25):route_dry=false
		check(route_dry,"all graph edges traversable %d"%seed_value)
		var coord:=Vector2i(gen.spawn/Gen.CHUNK_PX)
		var a:Dictionary=gen.build_chunk(coord);var b:Dictionary=gen.build_chunk(coord+Vector2i.RIGHT);var c:Dictionary=gen.build_chunk(coord+Vector2i.DOWN)
		var seam:=true
		for i in Gen.TEX_RES+6:
			if a.image.get_pixel(147,i)!=b.image.get_pixel(3,i) or a.image.get_pixel(i,147)!=c.image.get_pixel(i,3):seam=false
		check(seam,"chunk terrain border %d"%seed_value)
		check(a.props==worker.props_for_chunk(coord) and a.props==repeat.props_for_chunk(coord),"props deterministic %d"%seed_value)
		var resources:=[0,0]
		for cy in range(coord.y-2,coord.y+3):
			for cx in range(coord.x-2,coord.x+3):
				for prop in gen.props_for_chunk(Vector2i(cx,cy)):
					if prop.kind<4 and prop.position.distance_to(gen.spawn)<2000:resources[0 if prop.kind<2 else 1]+=1
		check(resources[0]>0 and resources[1]>0,"nearby trees and rocks %d"%seed_value,resources)
		var image:=Image.create(768,768,false,Image.FORMAT_RGB8)
		for y in 768:
			for x in 768:image.set_pixel(x,y,gen.overview_color((Vector2(x,y)+Vector2.ONE*.5)/768.*gen.extent))
		image.save_png("res://reports/world-v06/seed-%d-overview.png"%seed_value)
		var degree:Array=[];degree.resize(gen.region_cores.size());degree.fill(0)
		for edge in gen.links:degree[edge.a]+=1;degree[edge.b]+=1
		var branches:=0;var leaves:=0
		for d in degree:
			if d>=3:branches+=1
			if d==1:leaves+=1
		var nodes:Array=[];var edges:Array=[]
		for i in gen.region_cores.size():nodes.append({"x":gen.region_cores[i].x,"y":gen.region_cores[i].y,"kind":gen.region_kinds[i],"id":i})
		for edge in gen.links:edges.append({"a":edge.a,"b":edge.b,"width":edge.width})
		var biome_components:=[0,0,0]
		for group in components(biomes,grid):
			if group.cells>dry*.005:biome_components[group.kind]+=1
		reports.append({"seed":seed_value,"land_fraction":float(dry)/(grid*grid),"mainland_reachable_fraction":reach,"land_components":groups,"biome_land_cells":counts,"biome_components_over_half_percent":biome_components,"branches":branches,"leaves":leaves,"loops":edges.size()-nodes.size()+1,"nodes":nodes,"edges":edges,"extent":gen.extent,"spawn":[gen.spawn.x,gen.spawn.y],"land_bounds":[low.x,low.y,high.x,high.y],"land_aspect":(high.x-low.x)/(high.y-low.y),"lakes":gen.lakes.size(),"rivers":gen.rivers.size(),"nearby_resources":resources,"plan_build_ms":plan_ms,"chunk_build_ms":a.build_ms,"hash":str(hash(land)+hash(biomes))})
		print("SEED ",seed_value," land ",reports[-1].land_fraction," reach ",reach," water ",gen.lakes.size(),"/",gen.rivers.size())
	for size_value in [128,256,512]:
		var gen=Gen.new(seeds[0],size_value)
		check(gen.can_walk(gen.spawn,25),"small map spawn %d"%size_value)
	var failures:=0
	for item in checks:
		if not item.pass:failures+=1
	FileAccess.open("res://reports/world-v06/generation.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"generator":Gen.CANDIDATE_VERSION,"checks":checks,"failures":failures,"seeds":reports,"method":"10 consecutive RNG draws, seed 2026101606; 384 square floodfill with 25-unit foot clearance; sampled evidence, not subpixel proof. All results retained. PNGs are generator data diagrams, not art."},"  "))
	print("TOTAL ",checks.size()," FAILURES ",failures);quit(1 if failures else 0)

