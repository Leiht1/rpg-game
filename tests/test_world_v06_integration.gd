extends "res://tests/capture_world_v06.gd"
const Formal=preload("res://scripts/world_generator.gd")
const Candidate=preload("res://prototypes/world-v06/generator.gd")
func run()->void:
	for seed_value in [271828,447349832,1671081329]:
		var formal=Formal.new(seed_value,1024)
		var candidate=Candidate.new(seed_value,1024)
		var worker=Formal.new(seed_value,1024,formal.plan_snapshot())
		var mismatch:=0
		for y in 80:
			for x in 80:
				var p:Vector2=(Vector2(x,y)+Vector2.ONE*.5)*formal.extent/80.
				if formal.sample(p)!=candidate.sample(p) or formal.sample(p)!=worker.sample(p):mismatch+=1
		check(mismatch==0 and formal.spawn==candidate.spawn,"formal equals approved candidate and worker %d"%seed_value)
		var coord:=Vector2i(formal.spawn/1152.)
		check(formal.props_for_chunk(coord)==candidate.props_for_chunk(coord),"approved props retained %d"%seed_value)
	check(Formal.VERSION=="windrest-continent-0.6.0","formal version")
	var base=load("res://scripts/world.gd").new()
	var legacy_path:="user://integration-legacy-test.json"
	var new_path:="user://integration-v06-test.json"
	var legacy_text:=JSON.stringify({"seed":81273,"map_cells":512,"generator":"windrest-biome-0.5.0"})
	FileAccess.open(legacy_path,FileAccess.WRITE).store_string(legacy_text)
	base.load_legacy_identity(legacy_path)
	base.save_world_identity(new_path)
	var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(new_path))
	check(FileAccess.get_file_as_string(legacy_path)==legacy_text,"legacy identity remains byte identical")
	check(saved.seed==81273 and saved.map_cells==512 and saved.generator==Formal.VERSION and saved.migrated_from=="windrest-biome-0.5.0","migration saves seed size and explicit version")
	check(not base.migration_notice.is_empty(),"migration visible notice")
	base.world_seed=0;base.load_world_identity(new_path)
	check(base.world_seed==81273 and base.map_cells==512,"V06 identity restart restores seed size")
	var future_text:=JSON.stringify({"seed":99,"generator":"future-version"})
	FileAccess.open(new_path,FileAccess.WRITE).store_string(future_text)
	base.load_world_identity(new_path);base.save_world_identity(new_path)
	check(not base.persistent_world and FileAccess.get_file_as_string(new_path)==future_text,"unknown identity protected from silent replacement")
	DirAccess.remove_absolute(legacy_path);DirAccess.remove_absolute(new_path)
	for node in [base.object_root,base.ui,base.title,base.hint,base.debug_label,base.loading_cover,base.loading_label]:node.free()
	base.free()
	Engine.set_meta("integration_seed",447349832)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	await settle()
	check(w.generator.get_script()==Formal and w.stream.generator==w.generator,"formal entry and streaming use V06")
	while w.map_view.row<512:await process_frame
	await key_m()
	check(w.map_view.visible and w.player.input_blocked,"formal M opens")
	check(w.map_view.center==Vector2.ONE*w.generator.extent*.5 and w.map_view.zoom==1.,"formal map complete fit")
	await shot("formal-M-full-world")
	var mismatch:=0
	for y in range(0,512,32):
		for x in range(0,512,32):
			var color:Color=w.generator.overview_color((Vector2(x,y)+Vector2.ONE*.5)*w.generator.extent/512.)
			var actual:Color=w.map_view.image.get_pixel(x,y)
			if Vector3(color.r-actual.r,color.g-actual.g,color.b-actual.b).length()>.015:mismatch+=1
	check(mismatch==0,"formal M cache equals live continent")
	w.map_view.zoom=4.;w.map_view.center=Vector2(-1e7,1e7);w.map_view.clamp_center()
	var half:float=w.generator.extent/8.
	check(w.map_view.center==Vector2(half,w.generator.extent-half),"formal map zoom pan clamp")
	await key_m()
	check(not w.map_view.visible and not w.player.input_blocked,"formal M closes")
	var path:PackedVector2Array=w.generator.connections[0]
	var direction:Vector2=(path[1]-path[0]).normalized()
	var start:Vector2=path[0]+direction*250.
	w.player.position=start;w.player.camera.reset_smoothing();await settle()
	var initial:Vector2i=w.stream.chunk_at(start)
	w.player.input_override=direction
	var frames:=0;var gaps:=0;var blocks:=0
	while frames<1500 and w.player.position.distance_to(start)<1800.:
		await physics_frame;frames+=1
		if not w.stream.viewport_ready(w.player.position,Vector2(640,360)):gaps+=1
		if w.player.blocked_by_loading:blocks+=1
	w.player.input_override=Vector2.ZERO
	var distance:float=w.player.position.distance_to(start)
	check(distance>=1795. and w.stream.chunk_at(w.player.position)!=initial,"formal normal physics crosses chunks",distance)
	check(gaps==0 and blocks==0,"formal streaming no viewport gaps or stalls",[gaps,blocks])
	await shot("formal-walk-end")
	var metrics:={"normal_distance":distance,"physics_frames":frames,"missing_view_frames":gaps,"loading_stops":blocks,"last_chunk_build_ms":w.stream.last_build_ms,"max_install_ms":w.stream.max_install_ms,"map_total_build_ms":w.map_view.total_build_ms,"map_max_slice_ms":w.map_view.max_build_ms}
	var failures:=0
	for item in checks:
		if not item.pass:failures+=1
	FileAccess.open("res://reports/world-v06/integration.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"generator":Formal.VERSION,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"checks":checks,"failures":failures,"metrics":metrics},"  "))
	w.queue_free();await process_frame
	print("INTEGRATION ",checks.size()," FAILURES ",failures);quit(1 if failures else 0)
