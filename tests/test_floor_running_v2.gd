extends SceneTree
const OUT="res://reports/planting-ui-floor-v2/"
func _initialize()->void:call_deferred("run")
func run()->void:
	Engine.set_meta("integration_seed",98171023)
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	var p=w.player;var b=w.item_service.builds
	w.environment_view.set_process(false)
	while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
	var center:Vector2=p.position
	# Isolated rendering fixture: remove only test-world obstacles on this short running course.
	for node in get_nodes_in_group("trees")+get_nodes_in_group("world_interactables"):
		if node.position.distance_to(center)<400:node.queue_free()
	await process_frame;await physics_frame
	for y in range(-3,4):
		for x in range(-3,4):b.states["floor-%d-%d"%[x,y]]=b.candidate("wood_floor",center+Vector2(x*96,y*64),false,true,0)
	b.refresh_all();p.automated=true;p.run_override=true
	var samples=[]
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP]:
		p.input_override=direction
		for i in 18:await physics_frame
		await RenderingServer.frame_post_draw
		samples.append({"direction":str(direction),"running":p.running,"moving":p.moving,"displacement":str(p.last_displacement),"camera":str(p.camera.get_screen_center_position())})
		root.get_texture().get_image().save_png(OUT+"run-%d.png"%samples.size())
	p.input_override=Vector2.ZERO
	var passed:bool=samples.all(func(v):return v.running and v.moving)
	var filter_ok:bool=b.visuals.values().all(func(v):return v.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	FileAccess.open(OUT+"floor-running.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":samples,"all_moving":passed,"floor_filter":filter_ok,"pass":passed and filter_ok},"  "))
	print("FLOOR RUNNING ",passed," filter ",filter_ok)
	w.persistent_world=false;w.item_service.dirty=false;w.queue_free();await process_frame;await process_frame;quit(0 if passed and filter_ok else 1)
