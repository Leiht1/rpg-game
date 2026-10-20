extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var records:Array=[]
	for before in [true,false]:
		Engine.set_meta("view_before",before)
		Engine.set_meta("view_location",4)
		var w=load("res://prototypes/view-v01/preview.tscn").instantiate();root.add_child(w)
		while not w.review_ready:await process_frame
		w.player.set_physics_process(false)
		while not w.stream.viewport_ready(w.player.position+w.player.camera.position,Vector2(720,450)):await process_frame
		for i in 10:await process_frame
		await RenderingServer.frame_post_draw
		var path="res://prototypes/view-v01/lake-%s.png"%("before" if before else "after")
		root.get_texture().get_image().save_png(path)
		records.append({"before":before,"player":str(w.player.position),"camera_offset":str(w.player.camera.position),"zoom":str(w.player.camera.zoom),"image":path})
		w.queue_free();await process_frame
	FileAccess.open("res://prototypes/view-v01/lake-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
	quit()
