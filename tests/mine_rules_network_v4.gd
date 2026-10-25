extends SceneTree
var failed:=false
var checks:=0
var sample_frames:=false
var frame_times:Array=[]
var max_pending:=0
var max_ack_age:=0
var blocked_prediction:=0
var blocked_loading:=0
var remote_times:Array=[]
var last_remote_sample:=-1.0
var last_remote_arrival:=0
var remote_max_step:=0.0
var last_remote_position:=Vector2.INF
func _process(delta:float)->bool:
	if sample_frames:
		frame_times.append(delta*1000.0)
		if not world.actors.is_empty():
			var actor=world.actors.values()[0]
			if actor.sample_time!=last_remote_sample:
				if last_remote_arrival>0:remote_times.append(Time.get_ticks_msec()-last_remote_arrival)
				last_remote_sample=actor.sample_time;last_remote_arrival=Time.get_ticks_msec()
			if last_remote_position.is_finite():remote_max_step=maxf(remote_max_step,actor.position.distance_to(last_remote_position))
			last_remote_position=actor.position
		max_pending=maxi(max_pending,world.player.pending_inputs.size())
		max_ack_age=maxi(max_ack_age,Time.get_ticks_msec()-world.player.confirmed_at)
		if world.player.pending_inputs.size()>=85 or Time.get_ticks_msec()-world.player.confirmed_at>=1500:blocked_prediction+=1
		if world.player.blocked_by_loading:blocked_loading+=1
	return false
var fixture: Dictionary={}
var world: Node
var folder: String
func verify(value: bool, message: String) -> void:
	checks+=1
	if not value:failed=true;push_error("FAIL "+message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	pass
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="):
			folder=argument.trim_prefix("--fixture=").get_base_dir()
			fixture=JSON.parse_string(FileAccess.get_file_as_string(argument.trim_prefix("--fixture=")))
	var network=root.get_node("Network")
	var response: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
	verify(response.get("ok",false),"login: "+str(response.get("error","")))
	var ready:=FileAccess.open(folder.path_join("login"+str(int(fixture.index))),FileAccess.WRITE);ready.store_string("ready");ready.close()
	for wait_login in 600:
		if FileAccess.file_exists(folder.path_join("login"+str(1-int(fixture.index)))):break
		await create_timer(.05).timeout
	response=await network.call_api("resume",{})
	verify(response.get("ok",false),"resume")
	var entered: Dictionary=await network.call_api("character",{"appearance":response.character.appearance})
	verify(entered.get("ok",false) and entered.get("gameplay_enabled",false),"full game enabled: "+str(entered.get("error","")))
	var entered_ready:=FileAccess.open(folder.path_join("entered"+str(int(fixture.index))),FileAccess.WRITE);entered_ready.store_string("ready");entered_ready.close()
	for wait_enter in 600:
		if FileAccess.file_exists(folder.path_join("entered"+str(1-int(fixture.index)))):break
		await create_timer(.05).timeout
	var snapshot: Dictionary=await network.call_api("game_snapshot",{})
	verify(snapshot.get("ok",false),"original server snapshot: "+str(snapshot.get("error","")))
	if not snapshot.get("ok",false):quit(1);return
	entered.initial_snapshot=snapshot.snapshot
	world=load("res://scripts/network_game_world.gd").new();world.session_data=entered;root.add_child(world);current_scene=world
	for i in 500:
		if world.started and world.actors.size()==1:break
		await create_timer(.05).timeout
	verify(world.started,"original world loaded")
	verify(world.actors.size()==1,"second real player visible")
	world.player.set_physics_process(false)

	var q=world.item_service.chapter;var m=q.mine;var p=q.puzzle
	var view=world.item_service.chapter_view.get_node("PuzzleView")
	verify(m.travel.inside and not p.state.solved,"old mine state migrates inside without reset")
	verify(view.targets.size()==10 and view.ores.is_empty(),"new layout hidden reward on both clients")
	verify(view.art.chest.texture.resource_path.contains("mine-scene-v2"),"new buried chest on both clients")
	await barrier("loaded")
	# Two real authenticated E intents at the same first lamp: one advances, next resets.
	m.interact("lamp:0")
	await settled();await barrier("same-first");await create_timer(1).timeout
	verify(p.state.progress==1 and p.state.order==[0],"simultaneous same lamp recorded once without reset")
	if int(fixture.index)==0:
		for id in [2,1]:
			await walk_to(p.point("lamps",id)+Vector2(0,52));m.interact("lamp:"+str(id));await settled()
	await barrier("wrong-three");await create_timer(1).timeout
	verify(p.state.progress==3 and p.state.order==[0,2,1] and not p.state.solved,"shared wrong prefix stays lit without early feedback")
	if int(fixture.index)==0:
		await walk_to(p.point("lamps",3)+Vector2(0,52));m.interact("lamp:3");await settled()
	await barrier("wrong-four");await create_timer(1).timeout
	verify(p.state.progress==0 and p.state.order.is_empty() and not p.state.solved,"only fourth wrong lamp resets shared attempt")
	if int(fixture.index)==0:
		for i in 3:
			await walk_to(p.point("lamps",i)+Vector2(0,52));m.interact("lamp:"+str(i));await settled()
	await barrier("three-lit");await create_timer(1).timeout
	verify(p.state.progress==3 and p.state.order==[0,1,2],"both clients see correct three persistent lamps")
	await walk_to(p.point("lamps",3)+Vector2(-8+int(fixture.index)*16,52))
	await barrier("last-ready");m.interact("lamp:3");await settled();await create_timer(3).timeout
	verify(p.state.solved and p.state.progress==4,"simultaneous final lamp commits once permanently")
	verify(not view.rubble.visible and view.rubble_parts.all(func(n):return not n.visible),"both clients finish same side collapse")
	verify(view.ores.size()==3 and view.targets.chest.visible,"both clients reveal three ores and buried chest")
	verify(not view.art.chest.texture.resource_path.contains("buildings/"),"reward chest does not reuse camp visuals")
	verify(world.player.camera.offset==Vector2.ZERO,"camera shake restores original coordinates")
	await barrier("solved")
	world.stopping=true;network.token=""
	var login_again: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
	verify(login_again.get("ok",false),"fresh authentication")
	var resumed: Dictionary=await network.call_api("resume",{})
	var entered_again: Dictionary=await network.call_api("character",{"appearance":resumed.character.appearance})
	verify(entered_again.get("ok",false),"reenter original world")
	var final: Dictionary=await network.call_api("game_snapshot",{})
	verify(final.get("ok",false) and final.snapshot.exploration_chapter.mine.puzzle.solved,"reconnect preserves completed puzzle")
	verify(final.snapshot.mine_travel.inside,"reconnect preserves original personal region")
	FileAccess.open("res://reports/mine-collision-clues-v4/network/client"+str(int(fixture.index))+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"solved":p.state.solved,"inside":m.travel.inside,"failed":failed}))
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://reports/mine-collision-clues-v4/network/client"+str(int(fixture.index))+".png")
	print("MINE SCENE NETWORK ",fixture.index,": ",checks," checks failed=",failed)
	Engine.remove_meta("network_game_controller");world.queue_free();await process_frame;quit(1 if failed else 0)
func settled() -> void:
	for i in 200:
		if world.commands.is_empty():break
		await create_timer(.05).timeout
	await create_timer(.25).timeout
func walk_to(target: Vector2) -> void:
	world.player.automated=true;world.player.set_physics_process(true)
	for i in 500:
		var delta: Vector2=target-world.player.position
		if delta.length()<12:break
		world.player.input_override=delta.normalized();await create_timer(.035).timeout
	world.player.input_override=Vector2.ZERO;await create_timer(.5).timeout;world.player.set_physics_process(false)
	verify(world.player.position.distance_to(target)<35,"original network movement reaches lamp")
func barrier(label: String) -> void:
	var marker:=FileAccess.open(folder.path_join(label+str(int(fixture.index))),FileAccess.WRITE);marker.store_string("ready");marker.close()
	for step in 600:
		if FileAccess.file_exists(folder.path_join(label+str(1-int(fixture.index)))):return
		await create_timer(.05).timeout
	verify(false,"peer barrier "+label)
