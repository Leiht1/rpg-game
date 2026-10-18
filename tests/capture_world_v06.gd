extends SceneTree
var w:Node2D
var checks:Array=[]
var reports:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String,details:Variant="")->void:
	checks.append({"name":label,"pass":ok,"details":details})
	if not ok:push_error(label+" "+str(details))
func settle()->void:
	w.stream.update_target(w.player.position)
	var end:=Time.get_ticks_msec()+30000
	while not w.stream.viewport_ready(w.player.position,Vector2(720,430)) and Time.get_ticks_msec()<end:await process_frame
	check(w.stream.viewport_ready(w.player.position,Vector2(720,430)),"stream settled %d"%w.world_seed)
	while not w.started:await process_frame
	for i in 6:await process_frame
func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/world-v06/seed-%d-%s.png"%[w.world_seed,label])
func key_m()->void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_M;event.pressed=true
	root.push_input(event,true)
	for i in 3:await process_frame
	event=InputEventKey.new();event.physical_keycode=KEY_M;event.pressed=false;root.push_input(event,true)
	for i in 3:await process_frame
func run()->void:
	var selected:=0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runtime-seed="):selected=int(arg.get_slice("=",1))
	var generation:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/world-v06/generation.json"))
	for report in generation.seeds.slice(0,5):
		var seed_value:int=int(report.seed)
		if selected!=0 and selected!=seed_value:continue
		Engine.set_meta("world_v06_seed",seed_value)
		w=load("res://prototypes/world-v06/world.gd").new();root.add_child(w)
		w.player.automated=true;w.player.camera.position_smoothing_enabled=false
		await settle();await shot("spawn")
		while w.map_view.row<512:await process_frame
		await key_m()
		check(w.map_view.visible and w.player.input_blocked,"M opens and blocks movement %d"%seed_value)
		check(w.map_view.zoom==1. and w.map_view.center==Vector2.ONE*w.generator.extent*.5,"M default covers entire world %d"%seed_value)
		await shot("M-full-world")
		var match_map:=true
		for y in range(0,512,32):
			for x in range(0,512,32):
				var expected:Color=w.generator.overview_color((Vector2(x,y)+Vector2.ONE*.5)/512.*w.generator.extent)
				var actual:Color=w.map_view.image.get_pixel(x,y)
				if Vector3(actual.r-expected.r,actual.g-expected.g,actual.b-expected.b).length()>.015:match_map=false
		check(match_map,"M cache matches full live world %d"%seed_value)
		w.map_view.zoom=4.;w.map_view.center=Vector2(-1e7,1e7);w.map_view.clamp_center()
		var half:float=w.generator.extent/8.
		check(w.map_view.center==Vector2(half,w.generator.extent-half),"map pan zoom clamps %d"%seed_value)
		await key_m()
		check(not w.map_view.visible and not w.player.input_blocked,"M closes releases movement %d"%seed_value)
		# Traverse protected region connection with actual player physics/collisions.
		var path:PackedVector2Array=w.generator.connections[0]
		var direction:Vector2=(path[-1]-path[0]).normalized()
		var start:Vector2=path[0]+direction*250.
		w.player.position=start;w.player.camera.reset_smoothing();await settle()
		var initial_chunk:Vector2i=w.stream.chunk_at(start)
		var gaps:=0;var frames:=0;var blocked:=0
		var wanted_distance:=1800.
		w.player.input_override=direction
		while frames<1500 and w.player.position.distance_to(start)<wanted_distance:
			await physics_frame;frames+=1
			if not w.stream.viewport_ready(w.player.position,Vector2(640,360)):gaps+=1
			if w.player.blocked_by_loading:blocked+=1
		w.player.input_override=Vector2.ZERO
		var distance:float=w.player.position.distance_to(start)
		check(distance>=wanted_distance-5.,"actual normal movement %d"%seed_value,distance)
		check(w.stream.chunk_at(w.player.position)!=initial_chunk,"actual chunk crossing %d"%seed_value)
		check(gaps==0 and blocked==0,"no missing viewport or loading stops %d"%seed_value,[gaps,blocked])
		await shot("walk-end")
		reports.append({"seed":seed_value,"distance":distance,"physics_frames":frames,"missing_view_frames":gaps,"loading_blocks":blocked,"map_total_build_ms":w.map_view.total_build_ms,"map_max_slice_ms":w.map_view.max_build_ms,"max_install_ms":w.stream.max_install_ms,"last_chunk_build_ms":w.stream.last_build_ms})
		print("RUNTIME_SEED ",JSON.stringify(reports[-1]))
		w.map_view.close_map()
		w.queue_free();await process_frame
		for i in 8:await process_frame
	var failures:=0
	for item in checks:
		if not item.pass:failures+=1
	FileAccess.open("res://reports/world-v06/runtime.json" if selected==0 else "res://reports/world-v06/runtime-%d.json"%selected,FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"checks":checks,"failures":failures,"seeds":reports,"note":"Actual normal player physics, loaded streaming and M key events. No accelerated movement. Timing samples are not FPS guarantees."},"  "))
	print("RUNTIME_TOTAL ",checks.size()," FAILURES ",failures)
	for i in 10:await process_frame
	quit(1 if failures else 0)

