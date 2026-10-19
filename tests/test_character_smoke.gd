extends SceneTree

# Short integration check for the accepted v11 side walk at 200 px/s.
var failures: Array[String]=[]
var world: Node2D

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	call_deferred("run")

func ticks(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	world=load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	world.player.automated=true
	var deadline := Time.get_ticks_msec()+20000
	while not world.started and Time.get_ticks_msec()<deadline: await process_frame
	check(world.started,"Game startup did not complete within 20 seconds")
	if not world.started: quit(1); return
	var player: WildPlayer=world.player
	player.set_physics_process(false)
	check(WildPlayer.WALK_SPEED==200.0,"Movement speed is not 200 px/s")
	check(is_equal_approx(WildPlayer.WALK_SPEED/float(player.actor.stride_world_units)*8,13.8),"Walk cadence must remain 13.8 frames/s")
	check(player.actor.template_version=="windrest-character-template-5","Wrong runtime template")
	check(player.actor.idle_cycle_ms==1800,"Wrong breathing cycle")
	for view in ["front","back","side"]:
		for action in ["idle","walk"]:
			var name: String=view+"_"+action
			check(player.sprite.sprite_frames.get_frame_count(name)==(4 if action=="idle" else 8),"Wrong frame count: "+name)
			check(player.sprite.sprite_frames.get_animation_loop(name),"Clip must loop: "+name)
		var cycle := 0.0
		for i in 4:
			cycle+=player.sprite.sprite_frames.get_frame_duration(view+"_idle",i)/player.sprite.sprite_frames.get_animation_speed(view+"_idle")
		check(is_equal_approx(cycle,1.8),"SpriteFrames breath timing mismatch: "+view)
	for facing in ["front","back","right","left"]:
		player.facing=facing;player.moving=false
		for sample in [[0.001,0],[.451,1],[.901,2],[1.351,3],[1.801,0]]:
			player.idle_clock=sample[0];player.update_animation()
			check(player.sprite.frame==sample[1],"Breathing phase mismatch: "+facing)
			check(player.sprite.flip_h==(facing=="left"),"Mirror mismatch: "+facing)
			check(player.sprite.offset==Vector2(0,-48) and player.sprite.scale==Vector2.ONE,"Sprite root/scale changed")
	# Eight actual-render samples: inhale and walk frame 5 for each facing.
	var captures := Image.create(704,416,false,Image.FORMAT_RGBA8)
	world.debug_label.hide()
	for col in 4:
		player.facing=["front","back","right","left"][col]
		for row in 2:
			player.moving=row==1;player.idle_clock=.451
			player.gait_distance=float(player.actor.stride_world_units)*4.001/8
			player.update_animation()
			await process_frame
			await RenderingServer.frame_post_draw
			var capture: Image=root.get_texture().get_image()
			var center: Vector2=player.get_global_transform_with_canvas().origin
			captures.blit_rect(capture,Rect2i(Vector2i(center)-Vector2i(88,166),Vector2i(176,208)),Vector2i(col*176,row*208))
			if col==0 and row==0: capture.save_png("res://reports/character-world.png")
	captures.save_png("res://reports/character-smoke-poses.png")
	player.set_physics_process(true)
	var distances: Array[float]=[]
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2(1,1),Vector2(-1,1),Vector2(-1,-1),Vector2(1,-1)]:
		player.input_override=Vector2.ZERO;player.position=world.generator.spawn
		await ticks(2)
		var start := player.position
		player.input_override=direction
		await ticks(12)
		var distance := player.position.distance_to(start)
		distances.append(distance)
		check(absf(distance-40.0)<.2,"200 px/s or diagonal normalization mismatch: %.4f"%distance)
		check(player.moving and str(player.sprite.animation).ends_with("_walk"),"Movement did not enter walk")
		var expected_frame := int(player.gait_distance/float(player.actor.stride_world_units)*8)%8
		check(player.sprite.frame==expected_frame,"Walk phase differs from actual travel")
		player.input_override=Vector2.ZERO
		await ticks(2)
		check(not player.moving and str(player.sprite.animation).ends_with("_idle") and player.sprite.frame==0,"Stop did not enter neutral breathing")
	player.position=world.generator.spawn;player.input_override=Vector2.DOWN
	var visited := {}
	for i in 40:
		await ticks(1);visited[player.sprite.frame]=true
	check(visited.size()==8,"Travel did not show all eight walk frames")
	player.input_override=Vector2.ZERO
	await ticks(2)
	var stopped := player.position
	await ticks(30)
	check(player.position.is_equal_approx(stopped) and not player.moving,"Breathing moved the physics body")
	check(player.sprite.frame==1,"Real idle clock did not reach the second breathing pose")
	var result := {"status":"pass" if failures.is_empty() else "fail","failures":failures,
		"godot_version":Engine.get_version_info().string,"template":"windrest-character-template-5",
		"movement_speed":WildPlayer.WALK_SPEED,"movement_distances_12_ticks":distances,
		"idle_cycle_ms":1800,"breathing_boundary_samples":20,"walk_frames_visited":visited.size(),
		"rendered_direction_pose_samples":8,"scope":"Import, actual rendering, eight short movement directions, distance-driven gait, stop and brief idle. No map/performance/full regression."}
	FileAccess.open("res://reports/character-smoke-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("CHARACTER_SMOKE ",result.status," | ",failures.size()," failures")
	world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
