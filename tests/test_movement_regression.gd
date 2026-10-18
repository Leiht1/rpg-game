extends "res://tests/capture_world_v06.gd"
func advance(count:int)->void:
	for i in count:await physics_frame
func run()->void:
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	w.player.automated=true
	var path:PackedVector2Array=w.generator.connections[0]
	var direction:Vector2=(path[1]-path[0]).normalized()
	w.player.position=path[0]+direction*250.
	w.player.reset_physics_interpolation();w.player.camera.reset_smoothing()
	await settle()
	check(w.player.camera.process_callback==Camera2D.CAMERA2D_PROCESS_PHYSICS,"camera physics timing")
	check(w.player.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_ON,"actor interpolation enabled")
	var start:Vector2=w.player.position;var gait:float=w.player.gait_distance
	w.player.input_override=direction;w.player.run_override=false
	await advance(60)
	var walk:float=w.player.position.distance_to(start)
	check(absf(walk-200.)<8.,"walk speed unchanged",walk)
	check(absf(w.player.gait_distance-gait-walk)<1.,"gait follows actual collision resolved distance")
	start=w.player.position;gait=w.player.gait_distance
	w.player.run_override=true;await advance(60)
	var run_distance:float=w.player.position.distance_to(start)
	check(absf(run_distance-310.)<12.,"run speed unchanged",run_distance)
	check(w.player.gait_distance>gait and w.player.animation_player.current_animation.ends_with("run"),"run clip and phase continue")
	w.player.input_override=Vector2.ZERO;await advance(5)
	start=w.player.position;gait=w.player.gait_distance;await advance(20)
	check(w.player.position==start and w.player.gait_distance==gait and w.player.animation_player.current_animation.ends_with("breathe"),"stop position stable and idle clip")
	w.player.input_override=direction;await key_m()
	start=w.player.position;gait=w.player.gait_distance;await advance(20)
	check(w.player.position==start and w.player.gait_distance==gait,"M freezes physics and gait")
	await key_m();await advance(15)
	check(w.player.position.distance_to(start)>20.,"M release restores movement")
	w.player.input_override=Vector2.ZERO
	w.player.facing="left";w.player.update_animation()
	var visual:Node2D=w.player.character.get_node("Visual")
	check(visual.scale.x==-1. and visual.position.x==128.,"left flip preserves native pivot")
	w.player.facing="right";w.player.update_animation()
	check(visual.scale.x==1. and visual.position.x==0.,"right flip restores native pivot")
	# Probe a real tree with normal physics, then move to its existing interaction side.
	var tree:Node2D
	for prop in get_nodes_in_group("trees"):
		if w.generator.can_walk(prop.position+Vector2(-95,0),20):tree=prop;break
	check(tree!=null,"real tree available for collision and interaction")
	if tree!=null:
		w.player.position=tree.position+Vector2(-90,0)
		w.player.reset_physics_interpolation();w.player.camera.reset_smoothing()
		await settle();w.player.input_override=Vector2.RIGHT;w.player.run_override=false
		await advance(45);w.player.input_override=Vector2.ZERO
		check(w.player.position.x<tree.position.x-15.,"tree trunk still blocks player")
		w.player.position=tree.position+Vector2(-45,0);w.player.reset_physics_interpolation()
		w.player.try_interact()
		check(w.player.action=="chop","chop still starts")
		var id:String=tree.get_meta("prop_id")
		await advance(30)
		check(int(w.stream.tree_hits.get(id,0))==1,"chop commits exactly once")
		await advance(28)
		check(int(w.stream.tree_hits.get(id,0))==1,"chop does not duplicate hit")
		w.player.cancel_action()
		var drop:Node2D=w.stream.spawn_drop(w.player.position+Vector2(-20,0),"interpolation-check")
		w.player.try_interact()
		check(w.player.action=="pickup","pickup still starts")
		await advance(45)
		check(not is_instance_valid(drop) or drop.get_meta("collected",false),"pickup completes once")
	var failures:=0
	for item in checks:
		if not item.pass:failures+=1
	FileAccess.open("res://reports/movement-jitter/regression.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"walk_distance":walk,"run_distance":run_distance},"  "))
	w.queue_free();await process_frame
	print("MOVEMENT ",checks.size()," FAILURES ",failures);quit(1 if failures else 0)
