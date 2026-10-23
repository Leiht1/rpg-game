extends SceneTree
var world: Node
var fixture: Dictionary
var folder: String
var samples: Array=[]
var sampling:=false
var missing_remote_frames:=0
var remote_attack_frames:=0
var pending:=0
var ack_age:=0
var blocked:=0
var origin:=Vector2.ZERO
var travel:=0.0
var frame_time:=0
var attack_started:=0
var attack_response: Array=[]
func _initialize() -> void:run.call_deferred()
func _process(delta: float) -> bool:
	if sampling:
		var now:=Time.get_ticks_usec()
		if frame_time>0:samples.append((now-frame_time)/1000.0)
		frame_time=now
		if attack_started>0 and not world.player.combat_render_state.get("attack",{}).is_empty():
			attack_response.append((now-attack_started)/1000.0);attack_started=0
		if world.actors.size()!=int(fixture.players)-1:missing_remote_frames+=1
		for actor in world.actors.values():
			if not actor.character.is_visible_in_tree():missing_remote_frames+=1
			if not actor.remote_combat.get("attack",{}).is_empty():remote_attack_frames+=1
		travel=maxf(travel,origin.distance_to(world.player.position))
		pending=maxi(pending,world.player.pending_inputs.size())
		ack_age=maxi(ack_age,Time.get_ticks_msec()-world.player.confirmed_at)
		if world.player.pending_inputs.size()>=85 or Time.get_ticks_msec()-world.player.confirmed_at>=1500:blocked+=1
	return false
func check(ok: bool, label: String) -> void:
	if not ok:push_error(label);quit(1)
func marker(label: String) -> void:
	var f:=FileAccess.open(folder.path_join(label+str(int(fixture.index))),FileAccess.WRITE);f.store_string("ready");f.close()
func barrier(label: String) -> void:
	marker(label)
	for attempt in 1200:
		var ready:=true
		for i in int(fixture.players):ready=ready and FileAccess.file_exists(folder.path_join(label+str(i)))
		if ready:return
		await create_timer(.05).timeout
	check(false,"barrier timed out: "+label)
func run() -> void:
	# Frequent Windows stdout writes distort frame timing; measure normal play.
	Engine.set_meta("network_timings",{})
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			folder=arg.trim_prefix("--fixture=").get_base_dir();fixture=JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--fixture=")))
	var net=root.get_node("Network")
	var response: Dictionary=await net.call_api("login",{"username":fixture.username,"password":fixture.password})
	check(response.get("ok",false),"login")
	await barrier("login")
	response=await net.call_api("resume",{})
	response=await net.call_api("character",{"appearance":response.character.appearance})
	check(response.get("ok",false),"enter")
	await barrier("enter")
	var snapshot: Dictionary=await net.call_api("game_snapshot",{})
	check(snapshot.get("ok",false),"snapshot")
	response.initial_snapshot=snapshot.snapshot
	world=load("res://scripts/network_game_world.gd").new();world.session_data=response;root.add_child(world);current_scene=world
	for i in 1200:
		if world.started and world.actors.size()==int(fixture.players)-1:break
		await create_timer(.05).timeout
	check(world.started and world.actors.size()==int(fixture.players)-1,"world and peers started")
	await barrier("world")
	await create_timer(2).timeout
	var direction:=KEY_D
	var start: Vector2=world.player.position
	origin=start
	for pair in [[Vector2.DOWN,KEY_S],[Vector2.UP,KEY_W],[Vector2.RIGHT,KEY_D],[Vector2.LEFT,KEY_A]]:
		var clear:=true
		for distance in range(0,501,10):
			if not world.generator.can_walk(start+pair[0]*distance):clear=false;break
			var portal: Dictionary=world.item_service.combat.state.spawn
			for side in [-1,1]:
				if (start+pair[0]*distance).distance_to(Vector2(portal.x+side*70,portal.y-16))<26:clear=false
		if clear:direction=pair[1];break
	var opposite:={KEY_S:KEY_W,KEY_W:KEY_S,KEY_D:KEY_A,KEY_A:KEY_D}
	sampling=true
	# Stay inside the validated 500-unit corridor for the full 20-second run.
	for leg in 10:
		var key:=InputEventKey.new();key.physical_keycode=direction if leg%2==0 else opposite[direction];key.pressed=true;Input.parse_input_event(key)
		if leg in [2,5,8]:
			attack_started=Time.get_ticks_usec();world.item_service.combat.attack(Vector2.DOWN)
		await create_timer(2).timeout
		key=key.duplicate();key.pressed=false;Input.parse_input_event(key)
	await create_timer(1).timeout
	sampling=false;samples.sort()
	print("PERFORMANCE players=",fixture.players," frames=",samples.size()," median=",samples[samples.size()/2]," p95=",samples[int(samples.size()*.95)]," max=",samples[-1]," pending=",pending," ack_age=",ack_age," blocked=",blocked," travel=",travel)
	print("REMOTE_CHECK missing_frames=",missing_remote_frames," attack_frames=",remote_attack_frames)
	print("ATTACK_RESPONSE_MS ",JSON.stringify(attack_response))
	check(attack_response.size()==3,"local attack response missing")
	for operation in Engine.get_meta("network_timings"):
		var times: Array=Engine.get_meta("network_timings")[operation];times.sort()
		print("API_SUMMARY ",operation," ",JSON.stringify({"samples":times.size(),"median_ms":times[times.size()/2],"p95_ms":times[int((times.size()-1)*.95)],"max_ms":times[-1]}))
	check(missing_remote_frames==0 and remote_attack_frames>0,"remote visibility/attack presentation")
	check(blocked==0 and travel>300,"prediction stalled or movement did not happen")
	await barrier("done")
	await world.close_world()
	quit(0)
