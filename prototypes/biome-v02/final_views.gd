extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://prototypes/biome-v02/preview.tscn").instantiate();root.add_child(scene)
	for value in [271828,81273,902106]:
		scene.regenerate(value,false)
		for frame in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://prototypes/biome-v02/seed-%s-view--1.png"%value)
	scene.focus(-2)
	var samples=[]
	for i in 120:
		var start=Time.get_ticks_usec();await process_frame;samples.append((Time.get_ticks_usec()-start)/1000.0)
	samples.sort()
	var report={"frames":120,"median_frame_ms":samples[60],"p95_frame_ms":samples[114],"renderer":RenderingServer.get_video_adapter_name(),"scope":"spawn game camera, vsync enabled; not full world benchmark"}
	FileAccess.open("res://prototypes/biome-v02/performance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report));quit()
