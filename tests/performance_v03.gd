extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=load("res://scenes/world.tscn").instantiate();root.add_child(w)
	w.player.automated=true
	while not w.started:await process_frame
	var values:Array[float]=[]
	var begin:=Time.get_ticks_msec()
	var previous:=Time.get_ticks_usec()
	var origin:Vector2=w.player.position
	while Time.get_ticks_msec()-begin<12000:
		var seconds:=(Time.get_ticks_msec()-begin)/1000.0
		w.player.input_override=Vector2.DOWN if seconds<6 else Vector2.UP
		w.player.run_override=seconds>=6
		await process_frame
		var now:=Time.get_ticks_usec()
		if seconds>1:values.append((now-previous)/1000.0)
		previous=now
	values.sort()
	var sum:=0.0
	for value in values:sum+=value
	var report={"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"seconds":12,"scope":"normal walk then Shift-speed run near clearing, ground material and map cache budget; no accelerated stress or full regression","samples":values.size(),"mean_frame_ms":sum/values.size(),"p95_frame_ms":values[int(values.size()*.95)],"max_frame_ms":values.back(),"map_max_slice_ms":w.map_view.max_build_ms,"map_total_build_ms":w.map_view.total_build_ms,"loaded_chunks":w.stream.loaded.size(),"nodes":get_node_count(),"max_chunk_install_ms":w.stream.max_install_ms,"memory_mib":OS.get_static_memory_usage()/1048576.0,"distance_from_start":w.player.position.distance_to(origin)}
	var f:=FileAccess.open("res://reports/v03-performance.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
	print("V03 PERFORMANCE ",JSON.stringify(report));quit()
