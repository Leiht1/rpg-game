extends SceneTree
var w:Node2D
var results:Array=[]
func _initialize()->void:call_deferred("run")
func settle()->void:
	w.stream.update_target(w.player.position)
	while not w.stream.viewport_ready(w.player.position,Vector2(720,450)):await process_frame
	for i in 10:await process_frame
func run()->void:
	for before in [true,false]:
		Engine.set_meta("view_before",before)
		Engine.set_meta("view_location",3)
		w=load("res://prototypes/view-v01/preview.tscn").instantiate()
		root.add_child(w)
		while not w.review_ready:await process_frame
		w.player.set_physics_process(false)
		for location in [3,4,5,6]:
			w.goto_view(location);await settle()
			await RenderingServer.frame_post_draw
			var label=["spawn","lake","forest","rocks"][location-3]
			root.get_texture().get_image().save_png("res://prototypes/view-v01/%s-%s.png"%[label,"before" if before else "after"])
			results.append({"before":before,"view":label,"position":str(w.player.position),"camera_zoom":str(w.player.camera.zoom),"lake_count":w.generator.lakes.size(),"loaded":w.stream.loaded.size()})
		if not before:
			w.goto_view(3);await settle()
			w.player.set_physics_process(true)
			w.player.input_override=Vector2.RIGHT
			var start=w.player.position
			for i in 20:await physics_frame
			w.player.input_override=Vector2.ZERO
			results.append({"test":"actual spawn movement","distance":w.player.position.distance_to(start),"pass":w.player.position.distance_to(start)>45})
		w.queue_free();await process_frame
	FileAccess.open("res://prototypes/view-v01/runtime.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	quit()
