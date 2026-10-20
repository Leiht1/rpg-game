extends SceneTree
var stats: Dictionary={}
func _initialize() -> void:call_deferred('run')
func run() -> void:
	Engine.max_fps=60;root.get_node('AudioFX').muted=true
	var cells:=1024
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with('--cells='):cells=int(arg.get_slice('=',1))
	var path:='res://reports/world-map-v3/perf-%d-save.json'%cells
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	Engine.set_meta('map_v3_cells',cells);Engine.set_meta('map_v3_seed',81273);Engine.set_meta('map_v3_save',path)
	var before:=OS.get_static_memory_usage();var start:=Time.get_ticks_usec()
	var w=load('res://tests/world_map_v3_fixture.gd').new();root.add_child(w)
	while not w.started:await process_frame
	stats.cells=cells;stats.startup_ms=(Time.get_ticks_usec()-start)/1000.;stats.ready_static_mib=OS.get_static_memory_usage()/1048576.;stats.world_memory_delta_mib=(OS.get_static_memory_usage()-before)/1048576.
	w.environment_view.simulation.paused=true;w.player.automated=true
	for i in 60:await process_frame
	var frames: Array[float]=[]
	for i in 180:
		start=Time.get_ticks_usec();w.player.input_override=Vector2.RIGHT if i<90 else Vector2.DOWN
		await process_frame;frames.append((Time.get_ticks_usec()-start)/1000.)
	w.player.input_override=Vector2.ZERO
	frames.sort();stats.world_p50_ms=frames[90];stats.world_p95_ms=frames[171];stats.world_max_ms=frames[-1]
	var map: Control=w.map_view
	start=Time.get_ticks_usec();map.open_map();await process_frame;stats.map_first_frame_ms=(Time.get_ticks_usec()-start)/1000.
	start=Time.get_ticks_usec();var count:=0
	while count<1200:
		await process_frame;count+=1
		if map.working.x<0 and map.pending.is_empty():break
	stats.local_map_ready_ms=(Time.get_ticks_usec()-start)/1000.;stats.local_map_tiles=map.cache.size()
	frames.clear()
	for i in 180:
		start=Time.get_ticks_usec()
		map.zoom=[4.,8.,16.][(i/30)%3]
		map.center=w.player.position+Vector2(sin(i*.04),cos(i*.04))*700
		await process_frame;frames.append((Time.get_ticks_usec()-start)/1000.)
	frames.sort();stats.map_p50_ms=frames[90];stats.map_p95_ms=frames[171];stats.map_max_ms=frames[-1]
	stats.final_static_mib=OS.get_static_memory_usage()/1048576.;stats.video_mib=Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.;stats.max_tile_frame_ms=map.max_build_ms
	stats.cache_tiles=map.cache.size();stats.viewport=str(root.size);stats.adapter=RenderingServer.get_video_adapter_name()
	FileAccess.open('res://reports/world-map-v3/perf-%d.json'%cells,FileAccess.WRITE).store_string(JSON.stringify(stats,'  '));print(JSON.stringify(stats))
	w.persistent_world=false;w.item_service.writable=false;w.queue_free()
	for i in 6:await process_frame
	quit()
