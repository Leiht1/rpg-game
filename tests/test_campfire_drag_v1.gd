extends SceneTree
const OUT := "res://reports/campfire-v1/"
var world: Node
var service: Node
var ui: Control
var camps: RefCounted
var id := ""
var at := Vector2.ZERO
var pointer := Vector2.ZERO
var checks: Array=[]
var capture := false
var notices: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func motion(p: Vector2, held: bool=false) -> void:
	var e := InputEventMouseMotion.new();e.position=p;e.global_position=p;e.relative=p-pointer;e.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	pointer=p;root.push_input(e,true);await frames()
func button(p: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new();e.position=p;e.global_position=p;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(e,true);await frames()
func drag(index: int, target: Vector2, bag_drag: bool=false) -> void:
	var source: Vector2=ui.cells[index].get_global_rect().get_center()
	await motion(source);await button(source,true);await motion(source+Vector2(20,0),true)
	if not root.gui_is_dragging():
		print("DRAG_START_RETRY slot=",index,"; first synthesized pointer attempt interrupted")
		await button(source,false);await motion(source);await frames(5)
		await button(source,true);await motion(source+Vector2(30,0),true)
	check(root.gui_is_dragging(),"native drag begins from slot "+str(index))
	if bag_drag:
		await motion(Vector2(6,300),true)
		check(not ui.bag.visible and ui.bag_hidden_for_world_drag,"bag temporarily folds after dragging out to reveal fire")
	await motion(target,true);await button(target,false)
func find_slot(item: String) -> int:
	for i in 40:
		if service.inventory.slots[i].get("item_id")==item:return i
	return -1
func step(dt: float) -> void:
	world.player._physics_process(dt)
	await frames()
func shot(name_value: String) -> void:
	if not capture:return
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_value+".png")
func run() -> void:
	capture="--capture" in OS.get_cmdline_user_args();Engine.max_fps=60
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	service=world.item_service;ui=world.item_ui;camps=service.camps
	service.notice.connect(func(message):notices.append(message))
	world.environment_view.simulation.paused=true;world.player.set_physics_process(false)
	while not world.stream.viewport_ready(world.player.position,Vector2(640,360)):await process_frame
	for y in range(-600,601,24):
		if at!=Vector2.ZERO:break
		for x in range(-600,601,24):
			var p: Vector2=world.generator.spawn+Vector2(x,y);world.player.position=p+Vector2(0,75)
			if world.generator.can_walk(world.player.position,16) and camps.placement_reason(p).is_empty():at=p;break
	check(at!=Vector2.ZERO,"real dry legal fire location available")
	world.player.position=at+Vector2(0,75);world.player.camera.position_smoothing_enabled=false;world.player.camera.force_update_scroll();await frames(5)
	service.inventory.add("simple_campfire",1)
	var index := find_slot("simple_campfire")
	check(camps.place(at,index,service.inventory.slots[index].duplicate(true)).is_empty(),"test fire placed with original item consumption")
	id=camps.states.keys()[0]
	service.inventory.add("wood",3);index=find_slot("wood");service.inventory.move_slot(index,0)
	var target: Vector2=root.get_canvas_transform()*(at-Vector2(0,25))
	await drag(0,target)
	check(world.player.action=="throw" and world.player.camp_throw.hand=="right","hotbar drag starts right-hand throw when unarmed")
	check(service.inventory.count_item("wood")==3 and camps.states[id].fuel==0,"start and wind-up do not consume or refuel")
	await step(.30);await shot("throw-right-windup")
	check(world.player.animation_player.current_animation=="camp/back_throw_right","native directional throwing animation actually selected")
	await step(.20);await shot("throw-right-flight")
	check(service.inventory.count_item("wood")==3 and camps.states[id].fuel==0,"item in flight remains uncommitted")
	await step(.21)
	check(service.inventory.count_item("wood")==0 and camps.states[id].fuel==360 and camps.states[id].lit,"impact consumes dragged stack and ignites with matching burn time")
	check(world.player.camp_throw.committed,"impact committed through authoritative service")
	check(not notices.any(func(message):return str(message).contains("燃时+") or str(message).contains("投入木材")),"successful fuel throw has no seconds or success notification")
	await step(.4)
	check(world.player.action.is_empty() and world.player.camp_throw.projectile==null,"one-shot recovery cleans temporary item sprite")
	var node: Node2D=camps.visuals[id]
	check(node.fuel_bar.value==360 and node.fuel_bar.visible and node.fuel_bar.position.y>0,"remaining-time bar fixed beneath fire")
	check(is_equal_approx(node.fuel_bar.scale.y,1.0/3.0) and node.fuel_bar.scale.x==1.0,"fuel bar height is one third with width unchanged")
	camps.advance(360);await frames()
	check(not camps.states[id].lit and not node.flame.visible and node.fuel_bar.value==0,"timeout extinguishes flame and empties persistent bar")
	service.inventory.add("branch",4);index=find_slot("branch")
	ui.toggle_bag();await frames()
	await drag(index,target,true)
	check(ui.bag.visible and not ui.bag_hidden_for_world_drag,"bag restored after world drop")
	check(world.player.action=="throw","bag drag routes to same throwing action")
	await step(.71);await step(.3)
	check(camps.states[id].lit and camps.states[id].fuel==120 and service.inventory.count_item("branch")==0,"bag fuel reignites expired fire")
	ui.close_panels()
	service.inventory.add("stone_pickaxe",1);index=find_slot("stone_pickaxe");service.inventory.equip(index)
	var equipped: String=service.inventory.equipment.main_hand.instance_id
	service.inventory.add("broad_leaf",2);index=find_slot("broad_leaf");service.inventory.move_slot(index,2)
	await drag(2,target)
	check(world.player.action=="throw" and world.player.camp_throw.hand=="left","main-hand equipment selects opposite left hand")
	await step(.30);await shot("throw-left-equipped")
	var tool: Sprite2D=world.player.character.get_node("Visual/Pelvis/ArmR/HeldTool")
	check(tool.visible and tool.get_meta("item_id")=="stone_pickaxe","equipped tool stays visible in original main hand")
	await step(.41);await step(.3)
	check(camps.states[id].fuel==140 and service.inventory.equipment.main_hand.instance_id==equipped,"left throw refuels without replacing or consuming equipment")
	# Noncombustibles over the camp must never fall through to ordinary discard.
	service.inventory.add("stone",2);index=find_slot("stone");service.inventory.move_slot(index,3)
	var loose_count: int=service.loose.size()
	await drag(3,target)
	check(world.player.action.is_empty() and service.inventory.count_item("stone")==2 and service.loose.size()==loose_count,"noncombustible drop preserves source and creates no ground discard")
	service.inventory.add("wood",2);index=find_slot("wood");service.inventory.move_slot(index,4)
	await drag(4,target);world.player.cancel_action();await step(1.0)
	check(service.inventory.count_item("wood")==2 and camps.states[id].fuel==140,"cancelled throw preserves all items and fuel")
	var map_data: Dictionary=service.inventory.slots[4].duplicate(true)
	world.player.camp_throw.start(world.player,id,4,map_data);world.map_view.open_map()
	check(world.player.action.is_empty() and service.inventory.count_item("wood")==2,"opening map cancels uncommitted throw without consumption")
	world.map_view.close_map()
	var data: Dictionary=service.inventory.slots[4].duplicate(true)
	check(world.player.camp_throw.start(world.player,id,4,data).is_empty(),"new toss begins after cancellation")
	check(not world.player.camp_throw.start(world.player,id,4,data).is_empty(),"repeat request while throwing rejected")
	service.inventory.move_slot(4,5);await step(.71);await step(.3)
	check(service.inventory.count_item("wood")==2 and camps.states[id].fuel==140,"source moved before impact rejects transaction without loss")
	data=service.inventory.slots[5].duplicate(true)
	world.player.camp_throw.start(world.player,id,5,data)
	for i in service.inventory.equipment_slots.size():
		if service.inventory.equipment_slots[i].id=="main_hand": service.inventory.unequip(40+i)
	await step(.71)
	check(service.inventory.count_item("wood")==2 and camps.states[id].fuel==140 and world.player.action.is_empty(),"equipment change cancels uncommitted throw")
	camps.states[id].fuel=1140
	service.inventory.add("branch",5);index=find_slot("branch");data=service.inventory.slots[index].duplicate(true)
	check(camps.feed_amount(id,data)==2,"only quantity fitting fuel capacity is selected")
	world.player.camp_throw.start(world.player,id,index,data);await step(.71);await step(.3)
	check(camps.states[id].fuel==1200 and service.inventory.count_item("branch")==3,"capacity overflow remains in original stack")
	check(not camps.feed_check(id,index,service.inventory.slots[index]).is_empty(),"full fire rejects further items")
	# Reach and identity revalidation at impact.
	camps.states[id].fuel=0;camps.states[id].lit=false;camps.burning.erase(id)
	data=service.inventory.slots[index].duplicate(true);world.player.camp_throw.start(world.player,id,index,data)
	world.player.position=at+Vector2(0,150);await step(.71);await step(.3)
	check(service.inventory.count_item("branch")==3 and camps.states[id].fuel==0,"out-of-reach impact leaves items untouched")
	world.player.position=at+Vector2(0,75)
	var real_data: Dictionary=service.inventory.slots[index].duplicate(true)
	check(world.player.camp_throw.start(world.player,id,index,real_data).is_empty(),"real-time toss starts")
	world.player.set_physics_process(true)
	while world.player.action=="throw": await process_frame
	world.player.set_physics_process(false)
	check(service.inventory.count_item("branch")==0 and camps.states[id].fuel==90 and camps.states[id].lit,"normal physics frames complete throw and atomic refuel")
	# Every facing uses the native library, with left/right hand variants.
	for facing in ["front","back","left","right"]:
		for hand in ["left","right"]:
			world.player.action="throw";world.player.camp_throw.hand=hand;world.player.facing=facing;world.player.action_clock=.30;world.player.update_animation()
			var view: String="side" if facing in ["left","right"] else facing
			check(world.player.animation_player.current_animation=="camp/%s_throw_%s"%[view,hand],"native pose selected "+facing+" "+hand)
			await shot("pose-"+facing+"-"+hand)
	world.player.cancel_action();world.player.update_animation()
	check(world.player.character.get_node("Visual/ArmLBehind").show_behind_parent,"left arm keeps original behind-body rendering contract")
	world.camp_ui.open(id)
	var buttons: Array=[]
	for child in world.camp_ui.panel.get_children():
		if child is Button:buttons.append(child.text)
	check(not buttons.has("添加木材") and not buttons.has("熄灭") and not buttons.has("点燃"),"cooking panel has no refuel ignition or extinguish buttons")
	check(not camps.act(id,"fuel").is_empty() and not camps.act(id,"toggle").is_empty(),"removed fire operations are unavailable through service as well")
	await shot("cooking-drag-only")
	var failed: int=checks.filter(func(row):return not row.pass).size()
	FileAccess.open(OUT+("drag-window" if capture else "drag-headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("CAMPFIRE DRAG: ",checks.size()," checks; ",failed," failures")
	service.dirty=false;world.queue_free();await frames(6);quit(0 if failed==0 else 1)
