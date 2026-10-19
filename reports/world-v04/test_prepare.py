from pathlib import Path
p=Path('scripts/world_generator.gd');s=p.read_text(encoding='utf-8').replace('size_cells: int = 1024) -> void:','size_cells: int = 1024, plan: Dictionary = {}) -> void:',1).replace('\t_build_structure()','''	if not plan.is_empty():
		region_sites=plan.sites
		region_cores.assign(plan.cores)
		connections.assign(plan.connections)
		traversal_routes.assign(plan.routes)
		spawn=plan.spawn
		lakes.assign(plan.lakes)
		lake_bins=plan.bins
		return
	_build_structure()''',1)
i=s.index('func random_at(');s=s[:i]+'''func plan_snapshot() -> Dictionary:
	# Read-only after construction. Workers own noises; share no mutable RNG/noise state.
	return {"sites":region_sites,"cores":region_cores,"connections":connections,"routes":traversal_routes,"spawn":spawn,"lakes":lakes,"bins":lake_bins}

'''+s[i:];p.write_text(s,encoding='utf-8')
p=Path('scripts/chunk_stream.gd');s=p.read_text(encoding='utf-8').replace('Gen.new(generator.world_seed,generator.map_cells)','Gen.new(generator.world_seed,generator.map_cells,generator.plan_snapshot())');p.write_text(s,encoding='utf-8')
p=Path('tests/test_world_v04.gd');p.write_text('''extends SceneTree
const Gen=preload("res://scripts/world_generator.gd")
var checks:Array=[]
var reports:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String,details:Variant="")->void:
	checks.append({"name":label,"pass":ok,"details":details})
	if not ok:push_error(label)
func run()->void:
	var hashes:Array=[]
	for seed_value in [271828,81273,902106]:
		var begin:=Time.get_ticks_usec()
		var gen=Gen.new(seed_value,1024)
		var build_ms=(Time.get_ticks_usec()-begin)/1000.0
		var repeat=Gen.new(seed_value,1024)
		var worker=Gen.new(seed_value,1024,gen.plan_snapshot())
		var labels:=PackedInt32Array()
		var counts=[0,0,0]
		var land:=PackedByteArray()
		var grid=192
		var cell=gen.extent/grid
		var image=Image.create(768,768,false,Image.FORMAT_RGB8)
		for y in grid:
			for x in grid:
				var point=(Vector2(x,y)+Vector2.ONE*.5)*cell
				var v=gen.sample(point)
				var kind=Vector3(v.x,v.y,v.w).max_axis_index()
				labels.append(kind);counts[kind]+=1
				land.append(1 if gen.can_walk(point,40) else 0)
		var visited={};var components:Array=[]
		for at in labels.size():
			if visited.has(at):continue
			var queue:Array[int]=[at];visited[at]=true;var cursor=0
			while cursor<queue.size():
				var index=queue[cursor];cursor+=1
				for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var point=Vector2i(index%grid,index/grid)+delta
					var next=point.y*grid+point.x
					if point.x<0 or point.y<0 or point.x>=grid or point.y>=grid or visited.has(next) or labels[next]!=labels[at]:continue
					visited[next]=true;queue.append(next)
			components.append({"kind":labels[at],"cells":queue.size(),"area":queue.size()*cell*cell})
		# Land connectivity sampled at 256 units. Protected corridors additionally checked at 32.
		var start=Vector2i(gen.spawn/cell);var start_index=start.y*grid+start.x
		var accessible={start_index:true};var todo:Array[int]=[start_index];var cursor=0
		while cursor<todo.size():
			var at=todo[cursor];cursor+=1
			for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var point=Vector2i(at%grid,at/grid)+delta
				var next=point.y*grid+point.x
				if point.x<0 or point.y<0 or point.x>=grid or point.y>=grid or accessible.has(next) or land[next]==0:continue
				accessible[next]=true;todo.append(next)
		var land_count=land.count(1)
		var reach=float(accessible.size())/land_count
		check(components.size()==3,"three continuous macro regions %d"%seed_value,components)
		check(counts.min()>4500,"all macro regions have large area %d"%seed_value,counts)
		check(reach>.999,"coarse land connectivity %d"%seed_value,reach)
		var corridor_clear=true
		for path in gen.connections:
			for i in range(1,path.size()):
				var distance=path[i-1].distance_to(path[i])
				for step_index in ceili(distance/32.0)+1:
					if not gen.can_walk(path[i-1].lerp(path[i],minf(1.,step_index*32./maxf(1.,distance))),25):corridor_clear=false
		check(corridor_clear,"all protected region passages dry %d"%seed_value)
		var routes_ok=true;var routes=[]
		for route in gen.traversal_routes:
			routes.append({"kind":route.kind,"length":route.length,"screen_widths":route.length/1280.,"points":str(route.points)})
			if route.length<10240:routes_ok=false
			var points:PackedVector2Array=route.points
			for i in ceili(route.length/64.)+1:
				var point=points[0].lerp(points[1],minf(1.,i*64./route.length))
				if gen.macro_weights(point).max_axis_index()!=route.kind:routes_ok=false
		check(routes_ok and routes.size()==3,"8 screen minimum routes stay in own biome %d"%seed_value,routes)
		var coord=Vector2i(gen.spawn/Gen.CHUNK_PX)
		var a=gen.build_chunk(coord);var b=gen.build_chunk(coord+Vector2i.RIGHT);var c=gen.build_chunk(coord+Vector2i.DOWN)
		var seam=true
		for i in Gen.TEX_RES+2:
			if a.image.get_pixel(145,i)!=b.image.get_pixel(1,i) or a.image.get_pixel(i,145)!=c.image.get_pixel(i,1):seam=false
		check(seam,"shared world coordinates have exact weight bytes %d"%seed_value)
		check(a.image.get_data()==repeat.build_chunk(coord).image.get_data() and a.props==repeat.props_for_chunk(coord),"seed reproduces chunk and props %d"%seed_value)
		check(a.image.get_data()==worker.build_chunk(coord).image.get_data() and a.props==worker.props_for_chunk(coord),"worker plan snapshot matches main %d"%seed_value)
		check(gen.sample(gen.spawn)==gen.sample(gen.spawn,false) and gen.can_walk(gen.spawn,60),"natural safe spawn without ground override %d"%seed_value)
		var variety=[INF,-INF]
		for i in 40:
			var sub=gen.subenvironment(gen.region_cores[0]+Vector2(i*100-2000,0))
			variety[0]=minf(variety[0],sub.x);variety[1]=maxf(variety[1],sub.x)
		check(variety[1]-variety[0]>.12,"forest internal density variation %d"%seed_value,variety)
		var hash_value=str(hash(labels));hashes.append(hash_value)
		for y in 768:
			for x in 768:
				var point=(Vector2(x,y)+Vector2.ONE*.5)/768.*gen.extent
				var v=gen.sample(point)
				var color=Color("adc979").lerp(Color("6d9c68"),smoothstep(.25,.75,v.x)).lerp(Color("aaa58c"),smoothstep(.25,.75,v.y))
				if v.z>.35:color=Color("70afb9")
				image.set_pixel(x,y,color)
		image.save_png("res://reports/world-v04/seed-%d-overview.png"%seed_value)
		reports.append({"seed":seed_value,"generator":Gen.VERSION,"plan_build_ms":build_ms,"counts":counts,"components":components,"land_reachable_fraction_256_grid":reach,"routes":routes,"lakes":gen.lakes.size(),"spawn":str(gen.spawn),"macro_hash":hash_value})
	check(hashes[0]!=hashes[1] and hashes[1]!=hashes[2] and hashes[0]!=hashes[2],"different seeds produce different world layouts")
	# Minimum supported world still builds safely, scaled to its actual size.
	var small=Gen.new(42,128)
	check(small.can_walk(small.spawn,30) and small.region_sites.size()==9,"small supported world uses same layered pipeline")
	var failures=0
	for item in checks:
		if not item.pass:failures+=1
	var result={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"seeds":reports,"note":"256-unit land floodfill is sampled evidence, not subpixel reachability proof. No character interaction regression."}
	FileAccess.open("res://reports/world-v04/generation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result));quit(1 if failures else 0)
''',encoding='utf-8')
print('worker snapshot and scoped generation tests prepared')
