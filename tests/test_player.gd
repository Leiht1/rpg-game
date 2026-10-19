extends SceneTree

var failures: Array[String] = []
var results := {}
var world: Node2D

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message); push_error(message)

func _initialize() -> void:
	call_deferred("run")

func ticks(count: int) -> void:
	for i in count: await physics_frame

func release_all() -> void:
	for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)

func run() -> void:
	world=load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	var attempts := 0
	while not world.started and attempts<1200:
		await process_frame
		attempts+=1
	check(world.started,"Initial visible chunks never became ready")
	var player: WildPlayer=world.player
	check(is_equal_approx(WildPlayer.WALK_SPEED,200.0),"Normal movement speed must be 200 px/s")
	check(is_equal_approx(WildPlayer.WALK_SPEED/float(player.actor.stride_world_units)*8,13.8),"Walk cadence must remain 13.8 frames/s")
	check(player.actor.template_version=="windrest-character-template-5","Wrong character template version")
	for view in ["front","back","side"]:
		check(player.sprite.sprite_frames.get_frame_count(view+"_walk")==8,"Walk must contain eight poses")
		check(player.sprite.sprite_frames.get_frame_count(view+"_idle")==4,"Idle must contain the four approved breathing poses")
		check(player.sprite.sprite_frames.get_animation_loop(view+"_walk"),"Walk must loop")
		check(player.sprite.sprite_frames.get_animation_loop(view+"_idle"),"Breathing must loop")
		var idle_seconds := 0.0
		for i in 4:
			var seconds: float=player.sprite.sprite_frames.get_frame_duration(view+"_idle",i)/player.sprite.sprite_frames.get_animation_speed(view+"_idle")
			check(is_equal_approx(seconds,.45),"Breathing frame must last 450 ms")
			idle_seconds+=seconds
		check(is_equal_approx(idle_seconds,1.8),"Breathing cycle must last 1.8 seconds")
	# Boundary samples catch treating the exported 60 Hz speed as 60 poses/second.
	for facing in ["front","back","right","left"]:
		player.facing=facing
		player.moving=false
		for sample in [[0.0,0],[.449,0],[.45,1],[.899,1],[.9,2],[1.349,2],[1.35,3],[1.799,3],[1.8,0],[2.25,1],[3.6,0]]:
			player.idle_clock=sample[0]
			player.update_animation()
			check(player.sprite.frame==sample[1],"Wrong breath phase for %s at %.3f seconds"%[facing,sample[0]])
			check(player.sprite.animation==("side_idle" if facing in ["left","right"] else facing+"_idle"),"Wrong breath direction")
			check(player.sprite.flip_h==(facing=="left"),"Wrong idle mirror")
			check(player.sprite.offset==Vector2(0,-48) and player.sprite.scale==Vector2.ONE,"Breathing changed sprite scale/root")
	player.idle_clock=0
	var breathing_cycles := {}
	var distances: Array[float]=[]
	var actions := [["move_right"],["move_down"],["move_left"],["move_up"],
		["move_right","move_down"],["move_left","move_down"],["move_left","move_up"],["move_right","move_up"]]
	for group in actions:
		release_all()
		player.position=world.generator.spawn
		await ticks(2)
		var start := player.position
		for action in group: Input.action_press(action)
		await ticks(30)
		release_all()
		var distance := player.position.distance_to(start)
		distances.append(distance)
		check(absf(distance-100.0)<2.0,"Wrong movement speed for %s: %.3f"%[str(group),distance])
		check(player.moving,"Walk did not activate")
		check(player.animation_frame>=0 and player.animation_frame<player.sprite.sprite_frames.get_frame_count(player.sprite.animation),"Invalid walk frame")
		var direction: Vector2=Vector2.ZERO
		for action in group:
			direction+= {"move_right":Vector2.RIGHT,"move_left":Vector2.LEFT,"move_up":Vector2.UP,"move_down":Vector2.DOWN}[action]
		var expected := "side_walk" if absf(direction.x)>=absf(direction.y) else ("front_walk" if direction.y>0 else "back_walk")
		check(player.sprite.animation==expected,"Wrong direction clip for %s"%str(group))
		check(player.sprite.flip_h==(direction.x<0 and absf(direction.x)>=absf(direction.y)),"Wrong left mirror")
		await ticks(2)
		check(player.sprite.animation==expected.replace("_walk","_idle"),"Stop lost current facing")
		check(not player.moving,"Stopped player kept walking")
		check(player.sprite.frame==0,"Stopping must begin at the neutral breathing frame")
		if actions.find(group)<4:
			var idle_start := player.position
			var idle_frames := {}
			var frame_ticks := [0,0,0,0]
			for i in 108:
				await ticks(1)
				idle_frames[player.sprite.frame]=true
				frame_ticks[player.sprite.frame]+=1
				check(player.sprite.animation==expected.replace("_walk","_idle"),"Idle cycle lost facing")
				check(not player.moving and player.position.is_equal_approx(idle_start),"Breathing moved the physics body")
			check(idle_frames.size()==4,"A stopped player did not complete every breathing phase")
			for held in frame_ticks: check(absi(held-27)<=1,"Breathing pose did not last 27 physics ticks")
			breathing_cycles[player.facing]=frame_ticks
	await ticks(3)
	check(not player.moving,"Idle did not activate after release")
	check(str(player.sprite.animation).ends_with("_idle"),"Sprite stayed in walk after release")
	var min_distance: float=distances.min()
	var max_distance: float=distances.max()
	check(max_distance-min_distance<2.0,"Diagonal movement is faster")
	# A real travelled loop must reach every authored pose and wrap without a clock reset.
	player.position=world.generator.spawn
	Input.action_press("move_down")
	var visited := {}
	for i in 96:
		await ticks(1)
		visited[player.sprite.frame]=true
	release_all()
	await ticks(2)
	check(visited.size()==player.sprite.sprite_frames.get_frame_count("front_walk"),"Travel did not play a complete walk cycle")
	player.position=world.generator.spawn
	for i in 180:
		release_all()
		Input.action_press(actions[i%8][0])
		await ticks(1)
		var expected: String = ["side_walk","front_walk","side_walk","back_walk","side_walk","side_walk","side_walk","side_walk"][i%8]
		# These rapid inputs each contain the first action in the group.
		check(player.sprite.animation==expected,"Rapid turn chose wrong clip at %d"%i)
		check(player.sprite.flip_h==(i%8 in [2,5,6]),"Rapid turn mirror mismatch at %d"%i)
		check(player.sprite.offset==Vector2(0,-48),"Foot anchor changed during turn")
		var phase_frame := int(player.gait_distance/float(player.actor.stride_world_units)*player.sprite.sprite_frames.get_frame_count(player.sprite.animation))%player.sprite.sprite_frames.get_frame_count(player.sprite.animation)
		check(player.sprite.frame==phase_frame,"Turn reset gait phase")
		release_all()
		await ticks(1)
		check(str(player.sprite.animation).ends_with("_idle"),"Rapid stop failed")
		check(player.sprite.frame==0,"Rapid stop did not reset the breathing entry frame")
	release_all()
	player.position=world.generator.spawn
	await ticks(2)
	# Exercise physical key bindings, rather than only synthetic action strengths.
	for pair in [[KEY_W,Vector2.UP],[KEY_A,Vector2.LEFT],[KEY_S,Vector2.DOWN],[KEY_D,Vector2.RIGHT]]:
		var event := InputEventKey.new()
		event.physical_keycode=pair[0]
		event.keycode=pair[0]
		event.pressed=true
		Input.parse_input_event(event)
		await ticks(3)
		check(player.velocity.normalized().dot(pair[1])>.99,"WASD physical key does not map")
		event.pressed=false
		Input.parse_input_event(event)
		await ticks(2)
	# Find actual tree and rock bodies, approach each at normal physics speed.
	var collisions := {}
	for target_kind in [0,2]:
		var target: Node2D=null
		for prop in world.object_root.get_children():
			if prop!=player and prop.kind==target_kind and world.stream.viewport_ready(prop.position+Vector2(0,70),Vector2(640,360)):
				target=prop
				break
		check(target!=null,"No prop found for collision test")
		if target!=null:
			player.position=target.position+Vector2(0,75)
			await ticks(2)
			Input.action_press("move_up")
			await ticks(80)
			var blocked_phase := player.gait_distance
			await ticks(10)
			check(is_equal_approx(player.gait_distance,blocked_phase),"Gait advanced against a blocking prop")
			check(not player.moving,"Blocked player kept walking")
			check(str(player.sprite.animation).ends_with("_idle"),"Blocked player did not enter breathing")
			release_all()
			var gap := player.position.distance_to(target.position)
			check(gap>20 and gap<50,"Failed tree/rock collision: %.3f"%gap)
			collisions[str(target_kind)]=gap
	# Approach a generated lake shore through the real player physics path.
	var lake: Vector4=world.generator.lakes[3]
	var shore_start := Vector2(lake.x+lake.z+120,lake.y)
	while not world.generator.can_walk(shore_start): shore_start.x+=40
	player.position=shore_start
	world.stream.update_target(shore_start)
	var wait_count := 0
	while not world.stream.viewport_ready(shore_start,Vector2(640,360)) and wait_count<1200:
		await process_frame
		wait_count+=1
	Input.action_press("move_left")
	await ticks(210)
	release_all()
	await ticks(2)
	check(world.generator.can_walk(player.position),"Player entered impassable lake")
	check(not world.generator.can_walk(player.position+Vector2(-6,0)),"Shore collision did not stop the player at water edge")
	results["lake_shore_stopped"]=world.generator.can_walk(player.position) and not world.generator.can_walk(player.position+Vector2(-6,0))
	var event := InputEventMouseButton.new()
	event.pressed=true
	event.button_index=MOUSE_BUTTON_WHEEL_DOWN
	for i in 20: player._unhandled_input(event)
	check(is_equal_approx(player.camera.zoom.x,.65),"Minimum zoom limit failed")
	event.button_index=MOUSE_BUTTON_WHEEL_UP
	for i in 40: player._unhandled_input(event)
	check(is_equal_approx(player.camera.zoom.x,1.65),"Maximum zoom limit failed")
	check(player.camera.position_smoothing_enabled,"Camera smoothing missing")
	check(world.object_root.y_sort_enabled,"Y sorting missing")
	results.merge({"status":"pass" if failures.is_empty() else "fail","movement_distances_30_ticks":distances,
		"normal_speed_px_per_second":WildPlayer.WALK_SPEED,"walk_frames_per_direction":8,
		"idle_frames_per_direction":4,"idle_cycle_ms":1800,"breathing_pose_ticks_by_direction":breathing_cycles,
		"idle_boundary_samples":44,"breathing_physics_body_stationary":true,
		"stride_world_units":player.actor.stride_world_units,
		"walk_frames_per_second_at_normal_speed":WildPlayer.WALK_SPEED/float(player.actor.stride_world_units)*8,
		"rapid_switch_and_stop_cycles":180,"complete_character_sprites":1,"collision_center_distance":collisions,
		"physical_WASD":true,"camera_zoom_range":[.65,1.65],"failures":failures})
	FileAccess.open("res://reports/player-tests.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("PLAYER_TESTS ",results.status," | ",failures.size()," failures")
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
