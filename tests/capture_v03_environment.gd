extends SceneTree
func _initialize()->void:call_deferred("run")
func capture(w:Node2D,p:Vector2,label:String)->void:
	w.player.position=p
	w.player.camera.reset_smoothing()
	w.stream.update_target(p)
	while not w.stream.viewport_ready(p,Vector2(640,360)):await process_frame
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/v03-%s.png"%label)
func run()->void:
	var w=load("res://scenes/world.tscn").instantiate();root.add_child(w)
	w.player.automated=true;w.player.set_physics_process(false)
	while not w.started:await process_frame
	await capture(w,w.generator.spawn,"after")
	var forest:=Vector2.ZERO
	var mountain:=Vector2.ZERO
	for radius in [1000,2000,3500,5000]:
		for i in 24:
			var p:Vector2=w.generator.spawn+Vector2.from_angle(i*TAU/24)*radius
			var v:Vector4=w.generator.sample(p)
			if v.z>.005 or not w.generator.can_walk(p):continue
			if v.x>.65 and forest==Vector2.ZERO:forest=p
			if v.y>.55 and mountain==Vector2.ZERO:mountain=p
	if forest!=Vector2.ZERO:await capture(w,forest,"forest")
	if mountain!=Vector2.ZERO:await capture(w,mountain,"mountain")
	var bank:Vector2=Vector2(w.generator.river_x(w.generator.spawn.y)-260,w.generator.spawn.y)
	await capture(w,bank,"shore")
	print("ENVIRONMENT ",forest," ",mountain," ",bank)
	quit()
