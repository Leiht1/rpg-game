extends SceneTree
var world: Node
var ui: Control
var service: Node
var checks: Array = []
var failures: Array[String] = []
var pointer := Vector2.ZERO
const OUT := "res://reports/item-actions-v031/"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: failures.append(label); push_error(label)
func frames(count: int = 2) -> void:
	for i in count: await process_frame
func motion(at: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position=at; event.global_position=at; event.relative=at-pointer
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	pointer=at
	root.push_input(event,true)
	await frames()
func button(at: Vector2, pressed: bool, code: int = MOUSE_BUTTON_LEFT, ctrl: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position=at; event.global_position=at; event.button_index=code; event.pressed=pressed; event.ctrl_pressed=ctrl
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed and code==MOUSE_BUTTON_LEFT else 0
	root.push_input(event,true)
	await frames()
func click(at: Vector2, code: int = MOUSE_BUTTON_LEFT, ctrl: bool = false) -> void:
	await motion(at)
	await button(at,true,code,ctrl)
	await button(at,false,code,ctrl)
func key(code: int, unicode_value: int = 0) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code; event.keycode=code; event.unicode=unicode_value; event.pressed=true
	root.push_input(event,true)
	await frames()
	event=InputEventKey.new(); event.physical_keycode=code; event.keycode=code
	root.push_input(event,true)
	await frames()
func drag_start(index: int) -> void:
	var at: Vector2=ui.cells[index].get_global_rect().get_center()
	await motion(at)
	await button(at,true)
	await motion(at+Vector2(18,0),true)
	check(root.gui_is_dragging(),"native item drag starts")
func drag_to(index: int, to: Vector2) -> void:
	await drag_start(index)
	await motion(to,true)
	await button(to,false)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func count_id(id: String) -> int:
	var count := 0
	for slot in service.inventory.slots:
		if slot.get("item_id","")==id: count+=int(slot.count)
	return count

func run() -> void:
	Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(world)
	if world.player==null: quit(1); return
	world.player.automated=true
	while not world.started: await process_frame
	service=world.item_service
	ui=world.item_ui
	world.environment_view.simulation.set_time(10)
	world.environment_view.simulation.paused=true
	for id in service.database.ids():
		if service.database.item(id).get("equippable",false): continue
		check(service.texture(id,"icon")!=null and service.texture(id,"world")!=null,"formal approved visuals "+str(id))
	check(str(service.database.item("wildflower").world_visual).begins_with("res://assets/items/v03/"),"formal path outside prototypes")
	service.inventory.add("wild_berry",10)
	service.inventory.add("wood",7)
	service.inventory.move_slot(9,0)
	service.inventory.add("stone",4)
	service.inventory.slots[1]={"item_id":"wild_berry","count":5}
	ui.refresh()
	await key(KEY_B)
	check(ui.bag.visible,"B opens bag")
	var at: Vector2=ui.cells[8].get_global_rect().get_center()
	await click(at,MOUSE_BUTTON_RIGHT)
	check(ui.item_menu.visible and count_id("wild_berry")==15,"right click opens menu without consuming")
	await shot("right-click-menu")
	await click(ui.use_button.get_global_rect().get_center())
	check(service.inventory.slots[8].count==9 and not ui.item_modal_open(),"menu use consumes one")
	var before_drops: int=service.loose.size()
	await click(ui.cells[9].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(ui.use_button.disabled,"material use is disabled")
	await click(ui.destroy_button.get_global_rect().get_center())
	check(service.inventory.slots[9].is_empty() and service.loose.size()==before_drops,"destroy removes whole stack without a world drop")
	await click(ui.cells[0].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT,true)
	check(ui.item_menu.visible and count_id("wood")==7 and service.loose.size()==before_drops,"old Ctrl right no longer discards")
	await click(Vector2(250,500))
	check(not ui.item_modal_open() and count_id("wood")==7,"outside click dismisses menu safely")
	await click(ui.cells[8].get_global_rect().get_center(),MOUSE_BUTTON_LEFT,true)
	check(ui.split_panel.visible and service.inventory.slots[8].count==9,"Ctrl left opens quantity input")
	await key(KEY_1,49)
	check(service.inventory.slots[1].count==5 and ui.split_amount.text=="1","quantity typing does not trigger hotbar")
	for invalid in ["0","9","-2","1.5","abc"]:
		ui.split_amount.text=invalid; ui.validate_split(); ui.confirm_split()
		check(ui.split_confirm.disabled and service.inventory.slots[8].count==9,"invalid split rejected "+invalid)
	ui.split_amount.text="3"; ui.validate_split()
	await shot("split-quantity")
	await click(ui.split_confirm.get_global_rect().get_center())
	check(service.inventory.slots[8].count==6 and service.inventory.slots[9].count==3 and count_id("wild_berry")==14,"split creates separate bag stack without count loss")
	service.inventory.slots[10]={"item_id":"branch","count":1}; ui.refresh()
	await click(ui.cells[10].get_global_rect().get_center(),MOUSE_BUTTON_LEFT,true)
	check(not ui.item_modal_open(),"one item cannot open split dialog")
	await click(ui.cells[9].get_global_rect().get_center(),MOUSE_BUTTON_LEFT,true)
	await key(KEY_ESCAPE)
	check(not ui.item_modal_open() and ui.bag.visible and service.inventory.slots[9].count==3,"Escape cancels split without closing bag")
	var original: Array=service.inventory.slots.duplicate(true)
	for i in range(8,40): service.inventory.slots[i]={"item_id":"stone","count":99}
	service.inventory.slots[8]={"item_id":"wild_berry","count":6}; ui.refresh()
	await click(ui.cells[8].get_global_rect().get_center(),MOUSE_BUTTON_LEFT,true)
	ui.split_amount.text="2"; ui.validate_split(); ui.confirm_split()
	check(ui.split_panel.visible and ui.split_error.text.contains("没有空格") and service.inventory.slots[8].count==6,"full bag split keeps all quantities")
	ui.close_item_actions(); service.inventory.restore(original)
	# Title-bar move uses actual GUI events; slots remain ordinary item drags.
	var old: Vector2=ui.bag.position
	var heading: Control=ui.bag.get_child(0).get_child(0).get_child(0)
	var start: Vector2=heading.get_global_rect().get_center()
	await motion(start); await button(start,true)
	await motion(start+Vector2(120,-80),true); await button(start+Vector2(120,-80),false)
	check(ui.bag.position.distance_to(old+Vector2(120,-80))<1 and not ui.bag_dragging,"bag title drag moves panel and releases")
	await shot("draggable-bag")
	# Invalid UI target must cancel rather than discard.
	await drag_to(8,ui.bag.get_global_rect().position+Vector2(6,130))
	check(service.inventory.slots[8].count==6 and service.loose.size()==before_drops,"dropping on panel padding cancels")
	await drag_to(8,ui.bag_button.get_global_rect().get_center())
	check(service.inventory.slots[8].count==6 and service.loose.size()==before_drops,"dropping on navigation cancels")
	await drag_to(8,Vector2(260,520))
	check(service.inventory.slots[8].is_empty() and service.loose.size()==before_drops+1,"native bag drag onto ground discards whole stack")
	var dropped: Node2D
	for node in world.stream.drops:
		if node.get_meta("origin","")=="player": dropped=node
	check(dropped!=null,"player drop visible")
	if dropped:
		check(dropped.get_meta("airborne",false) and dropped.visual.position!=Vector2.ZERO,"drop has visible airborne phase")
		check(not service.pickup(dropped),"cannot pick airborne drop")
		await shot("drop-in-flight")
		await frames(35)
		check(not dropped.get_meta("airborne",false) and dropped.visual.position==Vector2.ZERO,"drop lands and finishes bounce")
		check(dropped.position.distance_to(world.player.position)<45 and int(dropped.get_meta("count"))==6,"landing at feet preserves stack")
		await shot("drop-landed")
		var total := count_id("wild_berry")
		ui.close_panels()
		await key(KEY_E)
		for i in 48: await physics_frame
		check(count_id("wild_berry")==total+6 and not is_instance_valid(dropped),"landed discarded stack can be picked up with E")
	# Closed-bag hotbar drag also discards, and restores movement after release.
	await drag_to(0,Vector2(260,520))
	check(service.inventory.slots[0].is_empty() and count_id("wood")==0,"hotbar drag onto ground discards whole stack")
	await shot("drop-in-flight")
	await frames(35)
	await shot("drop-landed")
	check(not world.player.input_blocked,"hotbar drag end restores movement")
	# Save/load preserves split/destroy edits and settled loose stack, never replaying flight.
	service.save_path="user://item-actions-v031-test.json"
	world.persistent_world=true
	service.save_state()
	var saved: Dictionary=JSON.parse_string(JSON.stringify(service.snapshot()))
	service.inventory.restore(ItemInventory.new(service.database).slots); service.loose={}
	service.load_state()
	check(JSON.parse_string(JSON.stringify(service.snapshot()))==saved,"new inventory actions and drops persist atomically")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
	world.persistent_world=false
	FileAccess.open(OUT+"tests.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"checks":checks,"failures":failures},"\t"))
	print("ITEM_ACTIONS ",checks.size()," checks / ",failures.size()," failures")
	service.dirty=false
	world.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
