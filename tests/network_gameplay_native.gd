extends SceneTree
var checks:=0
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
	response=await network.call_api("resume",{})
	verify(response.get("ok",false),"resume")
	var entered: Dictionary=await network.call_api("character",{"appearance":response.character.appearance})
	verify(entered.get("ok",false) and entered.get("gameplay_enabled",false),"full game enabled: "+str(entered.get("error","")))
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
	var backwards:=0
	var previous: Vector2=world.player.position
	for frame in 70:
		await physics_frame
		if (world.player.position-previous).dot(direction)<-.5:backwards+=1
		previous=world.player.position
	await key(code,false)
	var travelled: float=(world.player.position-start).dot(direction)
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
	await world.close_world()
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
