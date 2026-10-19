extends SceneTree
var w:Node2D
var p:WildPlayer
var frames:Array[float]=[]
func _initialize()->void:call_deferred("run")
func ready_view()->void:
	w.stream.update_target(p.position)
	while not w.stream.viewport_ready(p.position,Vector2(700,450)):await process_frame
func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/ecology-v03-%d-%s.png"%[w.world_seed,label])
func route()->Vector2:
	var gen=w.generator
	for sy in range(1,5):
		for sx in range(1,5):
			var site:Vector3=gen.region_sites[Vector2i(sx,sy)]
			if int(site.z)!=2:continue
			for offset in range(-1800,1801,180):
				var start=Vector2(site.x-1600,site.y+offset)
				var valid=true
				for step in range(0,3201,48):
					var pos=start+Vector2(step,0)
					if not gen.can_walk(pos,30) or gen.biome(pos)!="草原":valid=false;break
				if not valid:continue
				var lo=w.stream.chunk_at(start-Vector2(150,150));var hi=w.stream.chunk_at(start+Vector2(3350,150))
				for y in range(lo.y,hi.y+1):
					for x in range(lo.x,hi.x+1):
						for entry in gen.props_for_chunk(Vector2i(x,y)):
							if entry.kind>=4:continue
							var closest=Vector2(clampf(entry.position.x,start.x,start.x+3200),start.y)
							if closest.distance_to(entry.position)<90:valid=false
				if valid:return start
	return Vector2.ZERO
func run()->void:
	w=load("res://scenes/world.tscn").instantiate();root.add_child(w)
	p=w.player;p.automated=true;p.camera.position_smoothing_enabled=false
	await ready_view()
	var start=route()
	if start==Vector2.ZERO:push_error("no clear exploration route");quit(1);return
	p.position=start;p.camera.reset_smoothing();await ready_view()
	while not w.started:await process_frame
	await shot("walk-0")
	p.input_override=Vector2.RIGHT
	var gaps=0;var biomes={};var samples=[];var last=Time.get_ticks_usec()
	for frame in 960:
		await physics_frame
		var now=Time.get_ticks_usec();frames.append((now-last)/1000.0);last=now
		if not w.stream.viewport_ready(p.position,Vector2(640,360)):gaps+=1
		var biome=w.generator.biome(p.position);biomes[biome]=int(biomes.get(biome,0))+1
		if (frame+1)%240==0:
			samples.append({"seconds":(frame+1)/60.0,"position":str(p.position),"biome":biome})
			await shot("walk-%d"%((frame+1)/240))
	p.input_override=Vector2.ZERO
	var travel=p.position.distance_to(start)
	# Also show forest, mountain and both sides of a genuine terrain transition.
	for kind in [0,1]:
		for site in w.generator.region_sites.values():
			var point=Vector2(site.x,site.y)
			if int(site.z)==kind and point.x>1500 and point.y>1500 and point.x<w.generator.extent-1500 and point.y<w.generator.extent-1500 and w.generator.can_walk(point):
				p.position=point;p.camera.reset_smoothing();await ready_view();await shot("region-%d"%kind);break
	var transition=Vector2.ZERO
	for y in range(2000,45000,512):
		for x in range(2000,45000,256):
			var a=Vector2(x,y);var b=a+Vector2(500,0)
			if w.generator.can_walk(a,30) and w.generator.can_walk(b,30) and w.generator.biome(a) in ["森林","山地","草原"] and w.generator.biome(b) in ["森林","山地","草原"] and w.generator.biome(a)!=w.generator.biome(b):transition=(a+b)*.5;break
		if transition!=Vector2.ZERO:break
	if transition!=Vector2.ZERO:
		for offset in [-320,0,320]:
			p.position=transition+Vector2(offset,0);p.camera.reset_smoothing();await ready_view();await shot("transition-%d"%offset)
	frames.sort()
	var report={"seed":w.world_seed,"generator":w.generator.VERSION,"engine":Engine.get_version_info().string,"normal_walk_seconds":16,"distance":travel,"biome_frames":biomes,"samples":samples,"missing_viewport_frames":gaps,"physics_frame_interval_median_ms":frames[480],"physics_frame_interval_p95_ms":frames[912],"max_install_ms":w.stream.max_install_ms,"last_build_ms":w.stream.last_build_ms,"loaded":w.stream.total_loaded,"unloaded":w.stream.total_unloaded,"note":"Normal WALK_SPEED=200, no acceleration; physics interval includes screenshot waits; no full performance guarantee."}
	FileAccess.open("res://reports/ecology-v03-%d-exploration.json"%w.world_seed,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("EXPLORATION ",JSON.stringify(report))
	quit(0 if travel>3150 and gaps==0 and biomes.size()==1 else 1)
