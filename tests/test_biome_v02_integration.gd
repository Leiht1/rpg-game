extends SceneTree
const Gen=preload("res://scripts/world_generator.gd")
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func wait_ready(world)->bool:
	var deadline=Time.get_ticks_msec()+20000
	while not world.stream.viewport_ready(world.player.position,Vector2(640,360)) and Time.get_ticks_msec()<deadline:await process_frame
	return world.stream.viewport_ready(world.player.position,Vector2(640,360))
func run()->void:
	var world=load("res://scenes/world.tscn").instantiate();root.add_child(world)
	world.player.automated=true
	check(await wait_ready(world),"initial streamed viewport")
	var gen=world.generator
	var coord=world.stream.chunk_at(gen.spawn)
	var a=gen.build_chunk(coord);var right=gen.build_chunk(coord+Vector2i.RIGHT);var down=gen.build_chunk(coord+Vector2i.DOWN)
	var seam=true
	for i in Gen.TEX_RES+2:
		seam=seam and a.image.get_pixel(Gen.TEX_RES+1,i)==right.image.get_pixel(1,i)
		seam=seam and a.image.get_pixel(i,Gen.TEX_RES+1)==down.image.get_pixel(i,1)
	check(seam,"adjacent chunk RGBA weights equal on shared world coordinates")
	var again=Gen.new(world.world_seed,world.map_cells)
	check(a.image.get_data()==again.build_chunk(coord).image.get_data(),"chunk reproducible")
	var different=Gen.new(world.world_seed+1,world.map_cells)
	check(a.image.get_data()!=different.build_chunk(coord).image.get_data(),"seed changes macro field")
	world.save_world_identity("user://biome-v02-integration-test.json")
	var saved=world.world_seed
	world.world_seed=42;world.load_world_identity("user://biome-v02-integration-test.json")
	check(world.world_seed==saved,"saved seed restored")
	DirAccess.remove_absolute("user://biome-v02-integration-test.json")
	var points=[gen.spawn,gen.spawn,gen.spawn,gen.spawn,gen.spawn]
	var best=[-1.,-1.,-1.,-1.]
	for y in range(int(gen.spawn.y)-3000,int(gen.spawn.y)+3000,96):
		for x in range(int(gen.spawn.x)-3000,int(gen.spawn.x)+3000,96):
			var p=Vector2(x,y);var w=gen.sample(p)
			if not gen.can_walk(p,30):continue
			var scores=[w.x*(1-w.z),w.y*(1-w.z),1-absf(w.z-.4),minf(w.x,w.w)*(1-w.z)]
			for i in 4:
				if scores[i]>best[i]:best[i]=scores[i];points[i+1]=p
	for i in points.size():
		world.player.position=points[i];world.stream.update_target(points[i]);world.player.camera.reset_smoothing()
		check(await wait_ready(world),"streamed view %d"%i)
		for frame in 5:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/biome-v02-live-%d.png"%i)
	# Walk a real streamed seam near the safe clearing, without test teleport acceleration.
	var boundary=ceilf(gen.spawn.x/Gen.CHUNK_PX)*Gen.CHUNK_PX
	world.player.position=Vector2(boundary-100,gen.spawn.y)
	world.stream.update_target(world.player.position)
	check(await wait_ready(world),"seam viewport ready")
	world.player.input_override=Vector2.RIGHT
	var crossed=false
	for frame in 90:
		await physics_frame
		if world.player.position.x>boundary:crossed=true
	check(crossed,"normal player walks across streamed seam")
	world.player.input_override=Vector2.ZERO
	var report={"generator":Gen.VERSION,"seed":saved,"failures":failures,"seam_equal":seam,"normal_walk_crossed_seam":crossed,"scope":"formal 1024-cell streamed world, actual GPU views, seed metadata, coordinate seams"}
	FileAccess.open("res://reports/biome-v02-integration.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
