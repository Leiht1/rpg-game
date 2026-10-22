extends SceneTree
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
	if not value:push_error("FAIL "+message);quit(1)
func _initialize() -> void:run.call_deferred()
func run() -> void:
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
	if not snapshot.get("ok",false):return
	entered.initial_snapshot=snapshot.snapshot
	world=load("res://scripts/network_game_world.gd").new();world.session_data=entered;root.add_child(world);current_scene=world
	for i in 500:
		if world.started and world.actors.size()==1:break
		await create_timer(.05).timeout
	verify(world.started,"original world loaded")
	verify(world.actors.size()==1,"second real player visible")
	verify(world.actors.values().all(func(actor):return actor.collision_layer==0 and actor.collision_mask==0),"remote interpolated players do not push local prediction")
	var idle_at: Vector2=world.player.position
	await create_timer(.35).timeout
	verify(world.player.position.distance_to(idle_at)<.1,"overlapping players stay still without movement input")
	verify(world.item_service.inventory.slots[8].item_id=="branch","server inventory restored")
	verify(world.item_service.inventory.count_item("modern_outfit")==0,"new character receives no outfit")
	if int(fixture.index)==0:
		await pickup_fixture("online-v1:drops:sync-first:0")
		mark("picked-first")
		await wait_marker("picked-second")
	else:
		await wait_marker("picked-first")
		for i in 200:
			if world.item_service.consumed.has("online-v1:drops:sync-first:0"):break
			await create_timer(.05).timeout
		verify(world.item_service.consumed.has("online-v1:drops:sync-first:0"),"other player's pickup synchronized")
		verify(world.stream.drops.all(func(drop):return is_instance_valid(drop)),"no freed drop remains after remote pickup")
		await pickup_fixture("online-v1:drops:sync-second:0")
		mark("picked-second")
	world.item_service.start_craft("hand_stone_axe",1)
	for i in 500:
		if world.commands.is_empty() and world.item_service.inventory.count_item("stone_axe")>0:break
		await create_timer(.05).timeout
	verify(world.item_service.inventory.count_item("stone_axe")==1,"original craft UI route completes exactly once: "+world.last_error)
	var service=world.item_service
	var index: int=service.inventory.find_slot("stone_axe") if service.inventory.has_method("find_slot") else -1
	for i in 40:
		if service.inventory.slots[i].get("item_id")=="stone_axe":index=i;break
	verify(index>=0,"crafted tool slot")
	service.inventory.equip(index)
	for i in 100:
		if service.inventory.equipment.get("main_hand",{}).get("item_id")=="stone_axe":break
		await create_timer(.05).timeout
	verify(service.inventory.equipment.get("main_hand",{}).get("item_id")=="stone_axe","original equipment route: "+world.last_error)
	var queued: int=world.commands.size()
	verify(not world.get_node("Fishing").try_start() and world.commands.size()==queued,"ordinary interaction must not enqueue fishing without a rod")
	var hovered=world.item_ui.cells[index]
	world.item_ui.show_item_hover(index,hovered)
	world.item_ui.hover_wait=0.0
	var before_snapshot: Dictionary=service.snapshot()
	var started:=Time.get_ticks_usec()
	world.apply_snapshot(before_snapshot)
	print("UNCHANGED_SNAPSHOT_MS ",(Time.get_ticks_usec()-started)/1000.0)
	verify(world.item_ui.hover_wait==0.0,"unchanged inventory snapshot must not restart hover delay")
	world.confirm_return()
	verify(world.return_dialog.visible and not world.stopping,"return requires confirmation")
	world.return_dialog.hide();world.return_dialog.canceled.emit()
	verify(not world.stopping,"cancel return stays in world")
	var before: float=service.body.energy
	for i in 200:
		if service.body.energy<before:break
		await create_timer(.05).timeout
	verify(service.body.energy<before,"server body clock reaches HUD")
	verify(world.commands.is_empty(),"all commands acknowledged")
	await key(KEY_Y,true);await key(KEY_Y,false)
	verify(world.typing and world.entry.visible,"chat entry opens")
	await key(KEY_ESCAPE,true);await key(KEY_ESCAPE,false)
	verify(not world.typing and not world.entry.visible,"chat Escape cancels")
	await key(KEY_B,true);await key(KEY_B,false)
	verify(world.item_ui.bag.visible,"original backpack opens")
	await key(KEY_B,true);await key(KEY_B,false)
	# Original shortcut controls receive real pointer/key events.
	var cell=world.item_ui.cells[7]
	var pointer: Vector2=cell.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=pointer;Input.parse_input_event(motion)
	await process_frame
	var click:=InputEventMouseButton.new();click.position=pointer;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;Input.parse_input_event(click)
	await process_frame
	click=click.duplicate();click.pressed=false;Input.parse_input_event(click)
	await process_frame
	verify(service.inventory.selected==7,"pointer shortcut slot 8")
	await key(KEY_2,true);await key(KEY_2,false)
	verify(service.inventory.selected==1,"number shortcut slot 2")
	var start: Vector2=world.player.position
	var direction:=Vector2.ZERO
	var code:=KEY_D
	for pair in [[Vector2.RIGHT,KEY_D],[Vector2.LEFT,KEY_A],[Vector2.DOWN,KEY_S],[Vector2.UP,KEY_W]]:
		var safe: bool=world.stream.clear_reach(start,start+pair[0]*330)
		for distance in range(0,331,10):
			if not world.generator.can_walk(start+pair[0]*distance):safe=false;break
		if safe:direction=pair[0];code=pair[1];break
	verify(not direction.is_zero_approx(),"clear movement corridor")
	await key(code,true)
	await create_timer(1.0).timeout
	sample_frames=true
	var backwards:=0
	var previous: Vector2=world.player.position
	for frame in 180:
		await physics_frame
		if (world.player.position-previous).dot(direction)<-.5:backwards+=1
		previous=world.player.position
	sample_frames=false
	frame_times.sort()
	print("MOVEMENT_FRAME_MS median=",frame_times[frame_times.size()/2]," p95=",frame_times[int(frame_times.size()*.95)]," max=",frame_times[-1]," over33=",frame_times.filter(func(v):return v>33.4).size()," samples=",frame_times.size())
	await key(code,false)
	var travelled: float=(world.player.position-start).dot(direction)
	remote_times.sort()
	print("REMOTE_SYNC_MS samples=",remote_times.size()," p95=",remote_times[int((remote_times.size()-1)*.95)] if not remote_times.is_empty() else -1," max_step=",remote_max_step)
	verify(blocked_prediction==0,"movement never waits for prediction capacity during sample")
	verify(remote_times.size()>=10,"remote movement updates frequently during sample")
	verify(remote_max_step<20,"remote movement has no large per-frame jump")
	print("PREDICTION max_pending=",max_pending," ack_age=",max_ack_age," blocked=",blocked_prediction," loading=",blocked_loading)
	print("FULL_GAME_MOVEMENT distance=",travelled," backwards=",backwards)
	verify(travelled>120,"full game sustained movement")
	verify(backwards<=2,"full game does not repeatedly pull back")
	var stopped: Vector2=world.player.position
	await create_timer(1.0).timeout
	print("FULL_GAME_STOP drift=",world.player.position.distance_to(stopped)," pending=",world.player.pending_inputs.size()," correction=",world.player.correction)
	verify(world.player.position.distance_to(stopped)<3,"full game stable stop")
	var done:=FileAccess.open(folder.path_join("done"+str(int(fixture.index))),FileAccess.WRITE);done.store_string("done");done.close()
	for i in 400:
		if FileAccess.file_exists(folder.path_join("done"+str(1-int(fixture.index)))):break
		await create_timer(.05).timeout
	if int(fixture.index)==0:
		var previous_loose:Dictionary=world.item_service.loose.duplicate()
		var wood_slot:=-1
		for i in 40:
			if world.item_service.inventory.slots[i].get("item_id")=="wood":wood_slot=i;break
		verify(wood_slot>=0,"wood available for solo pickup fixture")
		world.item_service.discard(wood_slot,1)
		var solo_id:=""
		for i in 200:
			for id in world.item_service.loose:
				if not previous_loose.has(id):solo_id=id;break
			if not solo_id.is_empty():break
			await create_timer(.05).timeout
		verify(not solo_id.is_empty(),"discard synchronized before other player leaves")
		mark("solo-ready");await wait_marker("other-left")
		for i in 200:
			if world.actors.is_empty():break
			await create_timer(.05).timeout
		verify(world.actors.is_empty(),"departed player disappears")
		await pickup_fixture(solo_id)
		mark("solo-done")
		await world.close_world()
	else:
		await wait_marker("solo-ready")
		await world.close_world();mark("other-left");await wait_marker("solo-done")
	entered=await network.call_api("character",{})
	verify(entered.get("ok",false),"reenter character")
	response=await network.call_api("move",{"seq":1,"dx":0,"dy":0,"inputs":[]})
	verify(response.get("ok",false),"reenter accepts first movement sequence")
	await network.call_api("leave_lobby",{})
	print("FULL_GAME_NATIVE_PASS ",checks)
	quit()

func key(code: int, pressed: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;Input.parse_input_event(event)
	await process_frame

func mark(label:String)->void:
	var file:=FileAccess.open(folder.path_join(label),FileAccess.WRITE);file.store_string("ready");file.close()
func wait_marker(label:String)->void:
	for i in 600:
		if FileAccess.file_exists(folder.path_join(label)):return
		await create_timer(.05).timeout
	verify(false,"timed out waiting for "+label)
func pickup_fixture(id:String)->void:
	var drop:Node2D
	for i in 200:
		for node in world.stream.drops:
			if is_instance_valid(node) and node.get_meta("drop_id","")==id:drop=node;break
		if is_instance_valid(drop) and not drop.get_meta("airborne",false):break
		await create_timer(.05).timeout
	verify(is_instance_valid(drop),"fixture drop visible: "+id)
	if not is_instance_valid(drop):return
	var motion:=InputEventMouseMotion.new();motion.position=drop.get_global_transform_with_canvas().origin;Input.parse_input_event(motion)
	await process_frame
	verify(world.player.selected_target()==drop,"target and pickup hint after synchronization: "+id)
	verify(preload("res://scripts/world_interaction.gd").caption(drop,world.item_service.inventory)=="E 拾取","pickup caption present")
	var before:int=world.item_service.inventory.count_item(str(drop.get_meta("item_id")))
	var item_id:String=str(drop.get_meta("item_id"))
	await key(KEY_E,true);await key(KEY_E,false)
	for i in 300:
		if world.item_service.consumed.has(id):break
		await create_timer(.05).timeout
	verify(world.item_service.consumed.has(id),"real E pickup confirmed: "+id+" "+world.last_error)
	verify(world.item_service.inventory.count_item(item_id)>before,"pickup inventory granted")
	verify(world.stream.drops.all(func(node):return is_instance_valid(node)),"pickup leaves no stale nodes")
