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

	var q=world.item_service.chapter;var m=q.mine
	verify(m.state.phase=="sealed" and m.state.recipe,"shared sealed mine and discovered recipe restored")
	await barrier("loaded")
	world.player.input_blocked=false;world.player.facing="back"
	var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=true
	world.player._unhandled_input(event)
	for step in 400:
		if m.state.phase=="open" and world.commands.is_empty():break
		await create_timer(.05).timeout
	verify(m.state.phase=="open","authority finalizes single shared blast")
	verify(m.count_pack() in [0,1],"inventory never duplicated or negative")
	await process_frame;await physics_frame;await process_frame
	var view=world.item_service.chapter_view.get_node("MineView")
	verify(not view.rubble.visible and view.barrier.get_child(0).disabled,"both actual clients remove rock and collider")
	await barrier("opened")
	if int(fixture.index)==0:m.interact("enter")
	await create_timer(2).timeout
	verify(m.travel.inside==(int(fixture.index)==0),"first player's entry does not teleport second player")
	if int(fixture.index)==1:m.interact("enter")
	for step in 150:
		if m.travel.inside and world.commands.is_empty():break
		await create_timer(.05).timeout
	verify(m.travel.inside and world.player.position.distance_to(m.origin())<400,"each actual client enters mine pocket")
	verify(world.generator.can_walk(world.player.position),"authority arrival on walkable floor")
	await barrier("inside")
	world.player.set_physics_process(true);world.player.automated=true;world.player.input_override=Vector2.RIGHT
	await create_timer(.35).timeout
	world.player.input_override=Vector2.ZERO
	await create_timer(.5).timeout
	world.player.set_physics_process(false)
	verify(world.player.position.x>m.origin().x+15,"real predicted movement and server acknowledgement inside")
	# Walk back to the return threshold with normal movement inputs.
	world.player.set_physics_process(true);world.player.input_override=Vector2.LEFT
	await create_timer(.35).timeout;world.player.input_override=Vector2.ZERO
	await create_timer(.5).timeout;world.player.set_physics_process(false)
	if int(fixture.index)==1:m.interact("exit")
	await create_timer(2).timeout
	verify(m.travel.inside==(int(fixture.index)==0),"one client exits while other remains inside")
	var before_position: Vector2=world.player.position
	world.stopping=true;network.token=""
	var login_again: Dictionary=await network.call_api("login",{"username":fixture.username,"password":fixture.password})
	verify(login_again.get("ok",false),"new authenticated session")
	var resumed: Dictionary=await network.call_api("resume",{})
	verify(resumed.get("ok",false),"resume own character")
	var entered_again: Dictionary=await network.call_api("character",{"appearance":resumed.character.appearance})
	verify(entered_again.get("ok",false),"reenter shared world")
	var response2: Dictionary=await network.call_api("game_snapshot",{})
	verify(response2.get("ok",false),"fresh snapshot")
	verify(response2.snapshot.mine_travel.inside==(int(fixture.index)==0),"fresh authentication restores personal region")
	verify(Vector2(response2.snapshot.player_position.x,response2.snapshot.player_position.y).distance_to(before_position)<30,"fresh authentication restores own location")
	verify(response2.snapshot.exploration_chapter.mine.phase=="open","no repeat explosion on reconnect")
	var packs:=0
	for slot in response2.snapshot.slots:
		if slot.get("item_id","")=="miner_blast_pack":packs+=int(slot.count)
	FileAccess.open("res://reports/mine-v1/network/client"+str(int(fixture.index))+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"packs":packs,"inside":response2.snapshot.mine_travel.inside,"failed":failed}))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/mine-v1/network/client"+str(int(fixture.index))+".png")
	print("MINE NETWORK ",fixture.index,": ",checks," checks failed=",failed)
	world.stopping=true;Engine.remove_meta("network_game_controller");world.queue_free();await process_frame;quit(1 if failed else 0)

func barrier(label: String) -> void:
	var marker:=FileAccess.open(folder.path_join(label+str(int(fixture.index))),FileAccess.WRITE);marker.store_string("ready");marker.close()
	for step in 600:
		if FileAccess.file_exists(folder.path_join(label+str(1-int(fixture.index)))):return
		await create_timer(.05).timeout
	verify(false,"peer barrier "+label)
