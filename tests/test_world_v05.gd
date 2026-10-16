extends SceneTree
const Gen=preload("res://scripts/world_generator.gd")
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
		if seen[at]:continue
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
func unique_count(values:Array)->int:
	var unique:={}
	for value in values:unique[value]=true
	return unique.size()
func run()->void:
	var hashes:Array=[];var node_counts:Array=[];var component_counts:Array=[]
	for seed_value in [271828,81273,902106,42,170219,630947,104729,524287,8675309,314159]:
		var began:=Time.get_ticks_usec()
		var gen=Gen.new(seed_value,1024)
		var build_ms:float=(Time.get_ticks_usec()-began)/1000.
		var repeat=Gen.new(seed_value,1024)
		var worker=Gen.new(seed_value,1024,gen.plan_snapshot())
		var grid:=192;var step:float=gen.extent/grid
		var labels:=PackedInt32Array();var land:=PackedInt32Array();var water:=PackedInt32Array()
		var areas:Array=[];areas.resize(gen.region_cores.size());areas.fill(0)
		var biome_areas:=[0,0,0];var mismatch:=0
		var env_min:=[1.,1.,1.];var env_max:=[0.,0.,0.]
		for y in grid:
			for x in grid:
				var p:=(Vector2(x,y)+Vector2.ONE*.5)*step
				var v:Vector4=gen.sample(p)
				var kind:=Vector3(v.x,v.y,v.w).max_axis_index()
				labels.append(kind);areas[gen.region_at(p)]+=1;biome_areas[kind]+=1
				land.append(1 if gen.can_walk(p,25) else 0)
				water.append(1 if v.z>.56 else 0)
				var env:Vector2=gen.subenvironment(p)
				env_min[kind]=minf(env_min[kind],env.x);env_max[kind]=maxf(env_max[kind],env.x)
				if gen.sample(p)!=repeat.sample(p) or gen.sample(p)!=worker.sample(p):mismatch+=1
		var comps:=components(labels,grid)
		var major:Array=[];var tiny:=0;var repeats:=[0,0,0]
		for c in comps:
			if c.cells>=grid*grid*.015:major.append(c);repeats[c.kind]+=1
			else:tiny+=c.cells
		var land_comps:=components(land,grid);var accessible:=0;var land_total:=0
		for c in land_comps:
			if c.kind==1:land_total+=c.cells;accessible=maxi(accessible,c.cells)
		var water_comps:=components(water,grid);var wet_sizes:Array=[]
		for c in water_comps:
			if c.kind==1:wet_sizes.append(c.cells)
		var reach:=float(accessible)/land_total
		check(gen.region_cores.size()>=8 and gen.region_cores.size()<=12,"node count %d"%seed_value)
		check(major.size()>=7 and major.size()<=12,"large connected ecologies %d"%seed_value,major)
		check(repeats.min()>=2,"every biome repeats in separate places %d"%seed_value,repeats)
		check(float(areas.min())/(grid*grid)>.02 and float(areas.max())/(grid*grid)<.28,"territory area limits %d"%seed_value,areas)
		check(float(biome_areas.min())/(grid*grid)>.15 and float(biome_areas.max())/(grid*grid)<.55,"biome coverage %d"%seed_value,biome_areas)
		check(tiny<grid*grid*.005,"no meaningful micro fragments %d"%seed_value,tiny)
		check(reach>.999,"land connectivity %d"%seed_value,reach)
		check(wet_sizes.size()>=1 and wet_sizes.size()<=8 and wet_sizes.min()>=20,"large continuous water bodies %d"%seed_value,wet_sizes)
		check(mismatch==0,"full grid repeat and worker determinism %d"%seed_value,mismatch)
		var spawn_good:bool=gen.can_walk(gen.spawn,60) and gen.macro_weights(gen.spawn).z>.98
		for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:spawn_good=spawn_good and gen.macro_weights(gen.spawn+d*gen.extent*.02).z>.95
		check(spawn_good,"natural meadow interior spawn %d"%seed_value)
		var dry:=true
		for path in gen.connections:
			for j in range(1,path.size()):
				var length:float=path[j-1].distance_to(path[j])
				for n in ceili(length/48.)+1:
					if not gen.can_walk(path[j-1].lerp(path[j],minf(1.,n*48./maxf(length,1.))),25):dry=false
		check(dry,"protected travel routes dry %d"%seed_value)
		for k in 3:check(env_max[k]-env_min[k]>.35,"subenvironment variety %d/%d"%[seed_value,k])
		var coord:=Vector2i(gen.spawn/Gen.CHUNK_PX)
		var a:Dictionary=gen.build_chunk(coord);var b:Dictionary=gen.build_chunk(coord+Vector2i.RIGHT);var c:Dictionary=gen.build_chunk(coord+Vector2i.DOWN)
		var seam:=true
		for i in Gen.TEX_RES+6:
			if a.image.get_pixel(147,i)!=b.image.get_pixel(3,i) or a.image.get_pixel(i,147)!=c.image.get_pixel(i,3):seam=false
		for i in 26:
			if a.environment.get_pixel(25,i)!=b.environment.get_pixel(1,i) or a.environment.get_pixel(i,25)!=c.environment.get_pixel(i,1):seam=false
		check(seam,"terrain and subenvironment chunk seams %d"%seed_value)
		check(a.props==repeat.props_for_chunk(coord) and a.props==worker.props_for_chunk(coord),"prop repeat and worker match %d"%seed_value)
		var image:=Image.create(512,512,false,Image.FORMAT_RGB8)
		for y in 512:
			for x in 512:image.set_pixel(x,y,gen.overview_color((Vector2(x,y)+Vector2.ONE*.5)/512.*gen.extent))
		image.save_png("res://reports/world-v05/seed-%d-overview.png"%seed_value)
		var fingerprint:=str(hash(labels));hashes.append(fingerprint);node_counts.append(gen.region_cores.size());component_counts.append(major.size())
		reports.append({"seed":seed_value,"nodes":gen.region_cores.size(),"major_components":major,"biome_repeats":repeats,"node_areas":areas,"biome_areas":biome_areas,"land_reachable_fraction":reach,"water_component_cells":wet_sizes,"lakes":gen.lakes.size(),"rivers":gen.rivers.size(),"spawn":str(gen.spawn),"hash":fingerprint,"plan_build_ms":build_ms,"chunk_build_ms":a.build_ms,"neighbors":str(gen.region_neighbors)})
		print("SEED ",JSON.stringify(reports[-1]))
	check(unique_count(hashes)==10,"ten different macro layouts")
	check(unique_count(node_counts)>=3 and unique_count(component_counts)>=3,"count variation across seeds")
	for size_value in [128,256,512]:
		var gen=Gen.new(42,size_value)
		check(gen.can_walk(gen.spawn,20) and gen.region_cores.size()<10,"smaller map scaled plan %d"%size_value)
	var failures:=0
	for item in checks:
		if not item.pass:failures+=1
	FileAccess.open("res://reports/world-v05/generation.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"generator":Gen.VERSION,"checks":checks,"failures":failures,"seeds":reports,"note":"192 square floodfill sampled evidence, not subpixel proof. Overview PNGs are generator data visualizations."},"  "))
	print("TOTAL ",checks.size()," FAILURES ",failures);quit(1 if failures else 0)
