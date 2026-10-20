extends SceneTree
var checks: Array=[]
var w: Node
var map: Control
var measurements: Dictionary={}
var capture_dir:='res://reports/world-map-v3/'
var resume:=false
func _initialize() -> void:call_deferred('run')
func check(ok: bool,name: String) -> void:
	checks.append({'pass':ok,'name':name});print('CHECK ',ok,' ',name)
	if not ok:push_error(name)
func key(code: int) -> void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e)
	await process_frame
	e=InputEventKey.new();e.physical_keycode=code;e.pressed=false;Input.parse_input_event(e)
	await process_frame
func settle(frames: int=6) -> void:
	for i in frames:await process_frame
func ready_map() -> void:
	await settle(3)
	var frames:=0
	while (map.working.x>=0 or not map.pending.is_empty()) and frames<1800:
		await process_frame;frames+=1
	await settle(3)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir+name+'.png')
func run() -> void:
	Engine.max_fps=60
	root.get_node('AudioFX').muted=true
	resume=OS.get_cmdline_user_args().has('--resume')
	var old_resume:=OS.get_cmdline_user_args().has('--old')
	var expected_cells:=1024 if old_resume else 1536
	var path:='res://reports/world-map-v3/distribution-1024-81273-save.json' if old_resume else 'res://reports/world-map-v3/runtime-save.json'
	Engine.set_meta('map_v3_cells',expected_cells);Engine.set_meta('map_v3_save',path)
	if not resume and FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	var begin:=Time.get_ticks_usec()
	w=load('res://tests/world_map_v3_fixture.gd').new();root.add_child(w)
	while not w.started:await process_frame
	measurements.startup_ms=(Time.get_ticks_usec()-begin)/1000.
	measurements.navigation_ms=w.item_service.navigation_ms
	measurements.static_memory_mib=OS.get_static_memory_usage()/1048576.
	map=w.map_view
	var service: Node=w.item_service
	w.environment_view.simulation.paused=true
	check(service.writable,'test save valid')
	check(w.map_cells==expected_cells and w.generator.extent==expected_cells*48,'real world uses saved size')
	check(w.generator.can_walk(w.player.position,20),'actual entry dry and safe')
	check(service.merchant.state.size()>0 and is_instance_valid(service.merchant.actor),'single merchant exists')
	var merchant_count:=0
	for actor in w.object_root.get_children():
		if actor.get_script()==preload('res://scripts/merchant_actor.gd'):merchant_count+=1
	check(merchant_count==1,'merchant singleton in scene')
	var camps:={}
	for id in service.builds.states:
		if id.begins_with('abandoned:'):camps[id.get_slice(':',2)]=true
	check(camps.size()<=5,'abandoned camps bounded')
	measurements.camps=camps.size()
	var exploration: RefCounted=service.exploration
	if resume:
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		check(exploration.valid(saved.world_exploration) and exploration.serialize().bits==saved.world_exploration.bits,'independent process restores exact exploration')
		check(w.player.position==Vector2(saved.player_position.x,saved.player_position.y),'independent process restores position')
		check(saved.seed==w.world_seed and saved.map_cells==w.map_cells,'independent process restores identity')
		await finish('resume-old' if old_resume else 'resume');return
	check(exploration.explored(w.player.position),'spawn explored')
	check(exploration.bits.count(0)>exploration.bits.size()*.98,'new world mostly unknown')
	var initial: Dictionary=exploration.serialize()
	await key(KEY_M);await ready_map()
	check(map.visible and w.player.input_blocked and map.zoom==8,'M opens local map and blocks movement')
	check(map.world_to_screen(w.player.position).distance_to(map.map_rect.get_center())<1,'local map centres real actor')
	var point: Vector2=w.player.position+Vector2(500,400)
	check(map.screen_to_world(map.world_to_screen(point)).distance_to(point)<.01,'coordinate roundtrip')
	await shot('01-initial-fog')
	var camera_zoom: Vector2=w.player.camera.zoom
	for i in 4:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_WHEEL_UP;e.pressed=true;e.position=map.map_rect.get_center();Input.parse_input_event(e);await process_frame
	check(map.zoom>8 and w.player.camera.zoom==camera_zoom,'scroll zoom isolated from game camera')
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=map.map_rect.get_center();Input.parse_input_event(e);await process_frame
	var before: Vector2=map.center
	var motion:=InputEventMouseMotion.new();motion.position=map.map_rect.get_center()+Vector2(80,40);motion.relative=Vector2(80,40);Input.parse_input_event(motion);await process_frame
	e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false;e.position=motion.position;Input.parse_input_event(e);await process_frame
	check(map.center.distance_to(before)>10,'real left drag pans')
	check(exploration.serialize()==initial,'map interactions reveal nothing')
	await settle(10);check(map.center.distance_to(w.player.position)>10,'pan does not snap back')
	e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;e.position=map.recenter.get_global_rect().get_center();Input.parse_input_event(e);await process_frame
	e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=false;e.position=map.recenter.get_global_rect().get_center();Input.parse_input_event(e);await process_frame
	check(map.center.distance_to(w.player.position)<1,'return to actor button')
	map.center=Vector2(-1e8,1e8);map.clamp_center()
	var half: float=w.generator.extent/(map.zoom*2.)
	check(map.center==Vector2(half,w.generator.extent-half),'edge clamp fills map')
	await key(KEY_M);await key(KEY_M)
	check(map.center.distance_to(w.player.position)<1,'reopen recentres')
	await key(KEY_M)
	# Actual normal physics movement, without teleporting or giving test items.
	w.player.automated=true
	var start: Vector2=w.player.position
	w.player.input_override=Vector2.RIGHT
	for i in 120:await physics_frame
	w.player.input_override=Vector2.DOWN
	for i in 120:await physics_frame
	w.player.input_override=Vector2.ZERO
	check(w.player.position.distance_to(start)>80,'normal physics traversal')
	check(exploration.serialize()!=initial and exploration.explored(start) and exploration.explored(w.player.position),'walking reveals and retains trail')
	measurements.walk_distance=w.player.position.distance_to(start)
	check(service.save_state(),'atomic save success')
	var saved_text:=FileAccess.get_file_as_string(path)
	var saved_exploration: Dictionary=exploration.serialize()
	var original_path: String=service.save_path
	service.save_path='res://reports/world-map-v3/no-such-directory/state.json'
	exploration.reveal(w.player.position+Vector2(2000,0));service.dirty=true
	check(not service.save_state() and service.dirty,'failed save keeps unsaved exploration dirty')
	check(FileAccess.get_file_as_string(path)==saved_text,'failed save preserves prior snapshot')
	service.save_path=original_path
	exploration.restore(saved_exploration)
	# Invalid exploration is rejected before applying any inventory or world fields.
	var corrupted: Dictionary=JSON.parse_string(saved_text);corrupted.world_exploration.sha256='invalid'
	var bad_path:='res://reports/world-map-v3/corrupt-save.json'
	FileAccess.open(bad_path,FileAccess.WRITE).store_string(JSON.stringify(corrupted))
	service.load_state(bad_path)
	check(not service.writable and exploration.serialize()==saved_exploration,'corruption protects original and exploration')
	service.writable=true
	# Legacy missing field initializes just the current position, without claiming history.
	var legacy: Dictionary=JSON.parse_string(saved_text);legacy.erase('world_exploration');legacy.erase('world_id')
	var legacy_path:='res://reports/world-map-v3/legacy-save.json'
	FileAccess.open(legacy_path,FileAccess.WRITE).store_string(JSON.stringify(legacy))
	service.load_state(legacy_path)
	check(service.writable,'legacy missing exploration accepted')
	# Put actual landmarks in view for aesthetic review; reveal only in this fixture.
	var sites:={}
	for y in 100:
		for x in 100:
			var p: Vector2=Vector2(x+.5,y+.5)/100.*w.generator.extent
			var weights: Color=w.generator.ecology_weights(p)
			if w.generator.sample(p).z<.02:
				if weights.r>.2 and weights.b>.2 and not sites.has('grass-forest'):sites['grass-forest']=p
				if weights.r>.2 and weights.a>.2 and not sites.has('forest-rock'):sites['forest-rock']=p
			if absf(w.generator.coast_distance(p))<180 and not sites.has('coast'):sites.coast=p
	var lake: Vector4=w.generator.lakes[0];sites.lake=Vector2(lake.x,lake.y)
	var original_player: Vector2=w.player.position
	w.player.set_physics_process(false)
	await key(KEY_M)
	map.zoom=8.
	for name in sites:
		var p: Vector2=sites[name]
		# Diagnostic patch, not a full-world unlock and never saved to preview.
		for dy in range(-5,6):
			for dx in range(-5,6):exploration.reveal(p+Vector2(dx,dy)*900)
		map.center=p;map.clamp_center();await ready_map()
		await shot('v3-'+name)
		if name=='lake':
			for z in [4.,16.]:
				map.zoom=z;await ready_map();await shot('v3-lake-zoom-'+str(int(z)))
			map.zoom=8.
		# Same-seed, same-position legacy cartography rendered in Godot.
		var modern: bool=map.detailed;map.detailed=false;map.cache.clear();await ready_map();await shot('old-'+name)
		map.detailed=modern;map.cache.clear()
	check(sites.size()==4,'all requested terrain review locations found')
	# Entirely unknown viewport pixels cannot vary with hidden terrain cache.
	exploration.restore(saved_exploration)
	map.center=Vector2(60000,60000);map.zoom=8;await ready_map()
	await RenderingServer.frame_post_draw
	var concealed: Image=root.get_texture().get_image()
	map.detailed=false;map.cache.clear();await ready_map()
	await RenderingServer.frame_post_draw
	var concealed_again: Image=root.get_texture().get_image();var leaks:=0
	for y in range(int(map.map_rect.position.y)+20,int(map.map_rect.end.y)-20,10):
		for x in range(int(map.map_rect.position.x)+20,int(map.map_rect.end.x)-20,10):
			if concealed.get_pixel(x,y)!=concealed_again.get_pixel(x,y):leaks+=1
	check(leaks==0,'GPU fog hides terrain and all decorations without leaks')
	map.detailed=true
	# Repeated pan/zoom/open cycle: bounded memory and cache.
	var frames: Array[float]=[]
	var memory_before:=OS.get_static_memory_usage()
	for i in 240:
		var start_time:=Time.get_ticks_usec()
		map.zoom=[1.,2.,4.,8.,16.,32.][(i/20)%6]
		map.center=Vector2.ONE*w.generator.extent*.5+Vector2(sin(i*.05),cos(i*.05))*10000
		if i%30==0:map.close_map();map.open_map()
		await process_frame;frames.append((Time.get_ticks_usec()-start_time)/1000.)
	frames.sort()
	check(map.cache.size()<=map.CACHE_LIMIT and map.pending.size()<2000,'cache and requests remain bounded')
	measurements.map_frame_p50_ms=frames[120];measurements.map_frame_p95_ms=frames[228];measurements.map_frame_max_ms=frames[-1]
	measurements.cache_tiles=map.cache.size();measurements.generated_tiles=map.generated_tiles
	measurements.max_tile_build_frame_ms=map.max_build_ms
	measurements.repeat_view_memory_delta_mib=(OS.get_static_memory_usage()-memory_before)/1048576.
	measurements.video_memory_mib=Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.
	map.close_map();w.player.position=original_player
	exploration.restore(saved_exploration);service.dirty=true
	check(service.save_state(),'final restart snapshot saved')
	await finish('window')
func finish(name: String) -> void:
	var failed:=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(capture_dir+name+'.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failed':failed,'measurements':measurements,'engine':Engine.get_version_info().string,'adapter':RenderingServer.get_video_adapter_name()},'  '))
	print('MAP V3 ',name,' ',checks.size(),' checks ',failed,' failed')
	w.persistent_world=false;w.item_service.writable=false;w.queue_free();await settle(6)
	quit(0 if failed==0 else 1)
