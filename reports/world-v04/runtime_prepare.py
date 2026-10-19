from pathlib import Path
Path('tests/world_v04_fixture.gd').write_text('''extends "res://scripts/world.gd"
func load_world_identity(_path:String=WORLD_ID_PATH)->void:
	world_seed=int(Engine.get_meta("world_v04_seed",271828))
	map_cells=1024
	persistent_world=false
func save_world_identity(_path:String=WORLD_ID_PATH)->void:pass
''',encoding='utf-8')
Path('tests/capture_world_v04.gd').write_text('''extends SceneTree
var w:Node2D
var checks:Array=[]
var seeds:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func settle()->void:
	w.stream.update_target(w.player.position)
	var deadline=Time.get_ticks_msec()+30000
	while not w.stream.viewport_ready(w.player.position,Vector2(680,400)) and Time.get_ticks_msec()<deadline:await process_frame
	check(w.stream.viewport_ready(w.player.position,Vector2(680,400)),"stream ready seed %d"%w.world_seed)
	while not w.started:await process_frame
	for i in 6:await process_frame
func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/world-v04/seed-%d-%s.png"%[w.world_seed,label])
func key_m()->void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_M;event.pressed=true
	Input.parse_input_event(event);await process_frame
	event=InputEventKey.new();event.physical_keycode=KEY_M;event.pressed=false;Input.parse_input_event(event)
func run()->void:
	for seed_value in [271828,81273,902106]:
		Engine.set_meta("world_v04_seed",seed_value)
		w=load("res://tests/world_v04_fixture.gd").new();root.add_child(w)
		w.player.automated=true;w.player.camera.position_smoothing_enabled=false
		await settle();await shot("spawn")
		while w.map_view.row<512:await process_frame
		await key_m()
		check(w.map_view.visible and w.player.input_blocked,"M opens live map %d"%seed_value)
		await shot("M-map")
		var sample_match=true
		for y in range(0,512,64):
			for x in range(0,512,64):
				var value=w.generator.sample((Vector2(x,y)+Vector2.ONE*.5)/512.*w.generator.extent)
				var col=Color("adc979").lerp(Color("6d9c68"),smoothstep(.25,.75,value.x)).lerp(Color("aaa58c"),smoothstep(.25,.75,value.y))
				if value.z>.35:col=Color("70afb9")
				if w.map_view.image.get_pixel(x,y).distance_to(col)>.015:sample_match=false
		check(sample_match,"M map samples same live generator %d"%seed_value)
		w.map_view.zoom=4.;w.map_view.center=Vector2(-1e7,1e7);w.map_view.clamp_center()
		var half=w.generator.extent/8.
		check(w.map_view.center==Vector2(half,w.generator.extent-half),"M map zoom/pan clamp %d"%seed_value)
		await key_m();check(not w.map_view.visible and not w.player.input_blocked,"M closes and releases movement %d"%seed_value)
		# Exact original-speed physics, no teleport acceleration or manual displacement.
		var route:Dictionary=w.generator.traversal_routes[2]
		var points:PackedVector2Array=route.points
		var span:float=route.length
		var start=points[0].lerp(points[1],.5-5120./span)
		var goal=points[0].lerp(points[1],.5+5120./span)
		w.player.position=start;w.player.camera.reset_smoothing();await settle();await shot("walk-0")
		var distance=0.;var gaps=0;var biome_counts={};var frames=0;var shots=0
		var began=Time.get_ticks_msec()
		while frames<4200 and w.player.position.distance_to(goal)>6:
			w.player.input_override=(goal-w.player.position).normalized()
			await physics_frame;frames+=1
			distance=w.player.position.distance_to(start)
			var biome=w.generator.biome(w.player.position)
			biome_counts[biome]=int(biome_counts.get(biome,0))+1
			if not w.stream.viewport_ready(w.player.position,Vector2(640,360)):gaps+=1
			if distance>=(shots+1)*5000 and shots<2:shots+=1;await shot("walk-%d"%shots)
		w.player.input_override=Vector2.ZERO
		check(distance>10220,"normal walking covers eight screen widths %d"%seed_value)
		check(biome_counts.size()==1 and biome_counts.has("草原"),"walk stays in same major ecology %d"%seed_value)
		check(gaps==0,"no unloaded ground while walking %d"%seed_value)
		await shot("walk-end")
		# Both other region cores and forest internal contrast, no changes to art.
		for kind in [0,1]:
			w.player.position=w.generator.region_cores[kind];w.player.camera.reset_smoothing();await settle();await shot("region-%d"%kind)
		var density_views=[]
		var origin:Vector2=w.generator.region_cores[0]
		var low=origin;var high=origin;var low_value=1.;var high_value=0.
		for y in range(-3000,3001,300):
			for x in range(-3000,3001,300):
				var point=origin+Vector2(x,y)
				if w.generator.macro_weights(point).x<.99 or not w.generator.can_walk(point,30):continue
				var value=w.generator.subenvironment(point).x
				if value<low_value:low_value=value;low=point
				if value>high_value:high_value=value;high=point
		for pair in [["forest-sparse",low],["forest-dense",high]]:
			w.player.position=pair[1];w.player.camera.reset_smoothing();await settle();await shot(pair[0])
		seeds.append({"seed":seed_value,"walk_distance":distance,"walk_physics_frames":frames,"walk_seconds_at_60hz":frames/60.,"wall_seconds":(Time.get_ticks_msec()-began)/1000.,"biome_frames":biome_counts,"missing_viewport_frames":gaps,"sparse_dense_field":[low_value,high_value],"max_install_ms":w.stream.max_install_ms,"last_build_ms":w.stream.last_build_ms})
		print("COMPLETED_SEED ",JSON.stringify(seeds[-1]))
		w.queue_free();await process_frame
	# Identity migration must preserve seed/size while recording the new generator next save.
	var base=load("res://scripts/world.gd").new()
	var temp="user://world-v04-identity-test.json"
	FileAccess.open(temp,FileAccess.WRITE).store_string(JSON.stringify({"seed":81273,"map_cells":512,"generator":"windrest-biome-0.3.0"}))
	base.load_world_identity(temp)
	check(base.world_seed==81273 and base.map_cells==512,"previous world identity keeps seed and size across version upgrade")
	base.save_world_identity(temp)
	var saved=JSON.parse_string(FileAccess.get_file_as_string(temp))
	check(saved.generator==WildGenerator.VERSION,"new generator version stored with identity")
	DirAccess.remove_absolute(temp);base.free()
	var failures=0
	for item in checks:
		if not item.pass:failures+=1
	var report={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"seeds":seeds,"note":"normal WALK_SPEED 200, actual physics and collisions; no accelerated travel. Stream timing samples only, not a presentation/frame-rate guarantee."}
	FileAccess.open("res://reports/world-v04/runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit(1 if failures else 0)
''',encoding='utf-8')
print('runtime validation prepared')
