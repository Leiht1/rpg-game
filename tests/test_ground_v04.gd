extends SceneTree
var checks:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(label:String,value:bool)->void:
	checks[label]=value
	if not value:push_error(label)
func shot(name:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/ground-v04-"+name+".png")
func run()->void:
	var w=load("res://scenes/ground_preview.tscn").instantiate()
	root.add_child(w)
	w.player.automated=true
	while not w.started:await process_frame
	w.player.input_override=Vector2.ZERO
	w.player.camera.position_smoothing_enabled=false
	for mode in 3:
		w.stream.set_candidate(mode)
		w.update_comparison()
		for i in 4:await process_frame
		await shot(["old","a","b"][mode])
	var legacy=load("res://scripts/chunk_stream.gd").new()
	check("legacy default remains unchanged",legacy.candidate_mode==0)
	legacy.free()
	var layer:Node2D
	var tuft:Dictionary
	for entry in w.stream.loaded.values():
		if entry.candidate.tufts.size()>0:
			for t in entry.candidate.tufts:
				if (entry.candidate.position+t.p).distance_to(w.generator.spawn)<150:
					layer=entry.candidate;tuft=t;break
		if layer!=null:break
	check("fixed world grass near clearing",layer!=null)
	if layer==null:quit(1);return
	var anchor:Vector2=tuft.p
	w.player.position=layer.position+anchor+Vector2(-20,0)
	w.player.camera.zoom=Vector2.ONE*2
	w.player.set_physics_process(false)
	w.player.last_displacement=Vector2(3,0)
	w.player.running=false
	for i in 20:await process_frame
	var walk:float=absf(tuft.bend)
	check("walk bends nearby fixed tuft",walk>.02)
	w.player.running=true
	for i in 20:await process_frame
	check("run stronger than walk",absf(tuft.bend)>walk)
	for i in 24:
		w.player.last_displacement=Vector2.ZERO if i>=6 else Vector2(3,0)
		for f in 3:await process_frame
		await shot("grass-%02d"%i)
	for i in 90:await process_frame
	check("idle recovers",absf(tuft.bend)<.01)
	check("root position never translated",tuft.p==anchor)
	for entry in w.stream.loaded.values():
		for t in entry.candidate.tufts:
			check("dry grass only",w.generator.sample(entry.candidate.position+t.p).z<=.005)
		var copy=load("res://scripts/ground_candidate.gd").new()
		copy.configure(w.generator,w.stream.chunk_at(entry.candidate.position),[])
		check("deterministic positions "+str(entry.candidate.position),copy.tufts==entry.candidate.tufts or copy.tufts.map(func(t):return t.p)==entry.candidate.tufts.map(func(t):return t.p))
		copy.free()
	w.player.set_physics_process(true)
	w.player.camera.zoom=Vector2.ONE
	w.player.position=w.generator.spawn
	var frames:Array[float]=[]
	var start:=Time.get_ticks_msec()
	var previous:=Time.get_ticks_usec()
	while Time.get_ticks_msec()-start<12000:
		var seconds:=(Time.get_ticks_msec()-start)/1000.0
		w.player.input_override=Vector2.DOWN if seconds<6 else Vector2.UP
		w.player.run_override=seconds>=6
		await process_frame
		var now:=Time.get_ticks_usec()
		frames.append((now-previous)/1000.0);previous=now
	frames.sort()
	var sum:=0.0
	for f in frames:sum+=f
	var report={"checks":checks,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"mean_ms":sum/frames.size(),"p95_ms":frames[int(frames.size()*.95)],"max_ms":frames.back(),"chunk_install_max_ms":w.stream.max_install_ms,"nodes":get_node_count(),"sample_frames":frames.size(),"scope":"12 second walking/running local candidate preview; no full regression"}
	var file:=FileAccess.open("res://reports/ground-v04-checks.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	quit(0 if not checks.values().has(false) else 1)
