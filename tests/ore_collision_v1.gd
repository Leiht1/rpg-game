extends "res://tests/mine_playable_preview.gd"
var checks: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("ORE_CHECK ",ok," ",label)
func smoke() -> void:
	var s=w.item_service;var m=s.chapter.mine;var center: Vector2=m.at()+Vector2(0,500)
	w.environment_view.simulation.paused=true;s.combat.state.boars.clear();w.player.camera.position_smoothing_enabled=false;w.player.automated=true;w.player.set_physics_process(false)
	for index in 64:
		var candidate: Vector2=m.at()+Vector2(600+(index%8)*160,-560+floori(index/8)*160)
		var clear:=true
		for offset in [Vector2.ZERO,Vector2(-120,0),Vector2(120,0),Vector2(0,-120),Vector2(0,120)]:
			if not w.generator.can_walk(candidate+offset,30):clear=false
		if clear:center=candidate;break
	w.player.position=center;w.stream.update_target(center)
	while not w.stream.viewport_ready(center,Vector2(640,360)):await process_frame
	for prop in w.object_root.get_children():
		if prop!=w.player and prop.position.distance_to(center)<220:prop.queue_free()
	await create_timer(.1).timeout
	var kinds: Array=["stone_outcrop","flint_outcrop","copper_outcrop","silver_outcrop","gold_outcrop"]
	for kind in kinds:
		var ore=s.create_harvest("collision-test:"+kind,{"kind":kind,"x":center.x,"y":center.y})
		await physics_frame
		for side in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			w.player.position=center+side*100;w.player.reset_physics_interpolation();w.player.input_blocked=false;w.player.input_override=-side;w.player.set_physics_process(true)
			await create_timer(.8).timeout
			w.player.input_override=Vector2.ZERO;w.player.set_physics_process(false)
			var delta: Vector2=w.player.position-center
			print("ORE_POSITION ",kind," ",side," ",delta)
			var blocked: bool=delta.x<-42 if side==Vector2.LEFT else delta.x>35 if side==Vector2.RIGHT else delta.y<-35 if side==Vector2.UP else delta.y>=10
			check(blocked and delta.length()<float(ore.definition.range),kind+" blocks "+str(side)+" while remaining in mining range")
			if side==Vector2.LEFT:
				w.player.camera.reset_smoothing();w.player.camera.force_update_scroll();await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://reports/ore-collision-v1/"+kind+"-left.png")
		ore.feedback(w.player.position,true);await create_timer(.1).timeout
		check(not is_instance_valid(ore.collision),kind+" completed mining removes collision")
		ore.queue_free();await process_frame
	var failures:=checks.filter(func(c):return not c.pass).size()
	var f=FileAccess.open("res://reports/ore-collision-v1/checks.json",FileAccess.WRITE);f.store_string(JSON.stringify(checks,"  "));f.close()
	print("ORE_TOTAL ",checks.size()," FAILURES ",failures);quit(1 if failures else 0)
