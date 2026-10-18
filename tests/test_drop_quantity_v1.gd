extends SceneTree
var world: Node
var checks: Array=[]
const OUT := "res://reports/drop-quantity-v1/"
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=4) -> void:
	for i in n: await process_frame
func drag_data(ui: Control,index: int) -> Dictionary:
	var stack: Dictionary=ui.service.inventory.slots[index].duplicate(true)
	return {"inventory":ui.service.inventory,"slot":index,"item_id":stack.item_id,"count":stack.count,"snapshot":stack}
func shot(name_value: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_value+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT);Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	world.environment_view.simulation.paused=true;world.player.set_physics_process(false)
	while not world.stream.viewport_ready(world.player.position,Vector2(640,360)): await process_frame
	await frames()
	var ui: Control=world.item_ui;var s: Node=world.item_service;var camps: RefCounted=s.camps
	for i in 40: s.inventory.slots[i]={}
	s.inventory.slots[8]={"item_id":"wood","count":10}
	var before: Dictionary=s.inventory.slots[8].duplicate(true)
	ui.drop_on_ground(drag_data(ui,8))
	check(ui.item_modal_open() and ui.quantity_action=="ground" and s.inventory.slots[8]==before,"ground stack opens quantity without debit")
	check(ui.quantity_limit()==10,"ground permits full stack")
	ui.split_amount.text="0";ui.validate_split();check(ui.split_confirm.disabled,"zero disabled")
	ui.split_amount.text="11";ui.confirm_split();check(s.inventory.slots[8]==before and ui.item_modal_open(),"excess rejected")
	ui.split_amount.text="3";ui.validate_split();await shot("ground-quantity")
	ui.confirm_split();check(s.inventory.slots[8].count==7 and s.loose.values().any(func(row): return row.item_id=="wood" and row.count==3),"ground discards requested three only")
	ui.confirm_split();check(s.inventory.slots[8].count==7,"duplicate confirm no debit")
	ui.drop_on_ground(drag_data(ui,8));ui.close_item_actions();check(s.inventory.slots[8].count==7,"cancel no debit")
	ui.drop_on_ground(drag_data(ui,8));s.inventory.slots[8].count=6;ui.split_amount.text="2";ui.confirm_split();check(s.inventory.slots[8].count==6 and not ui.item_modal_open(),"changed source rejected")
	ui.open_split(8);check(ui.quantity_action=="split" and ui.split_confirm.text=="拆分" and ui.quantity_limit()==5,"existing split keeps distinct limits and label");ui.close_item_actions()
	var at: Vector2=world.player.position+Vector2(0,60)
	camps.states["quantity"]={"x":at.x,"y":at.y,"fuel":0.0,"lit":false,"recipe":"","elapsed":0.0,"ready":false};camps.rebuild();camps.install(world.stream.chunk_at(at))
	world.player.camera.force_update_scroll();await frames()
	var screen: Vector2=root.get_canvas_transform()*at
	ui.drop_on_ground(drag_data(ui,8),screen)
	check(ui.quantity_action=="fuel" and world.player.action.is_empty() and camps.states.quantity.fuel==0 and s.inventory.slots[8].count==6,"fuel waits for quantity before throw")
	ui.split_amount.text="2";ui.validate_split();await shot("fuel-quantity");ui.confirm_split()
	check(world.player.action=="throw" and world.player.camp_throw.count==2 and s.inventory.slots[8].count==6,"fuel confirmation starts requested gesture without early debit")
	world.player.camp_throw.advance(.71)
	check(s.inventory.slots[8].count==4 and camps.states.quantity.fuel==240,"impact consumes two and adds exact fuel")
	world.player.cancel_action()
	ui.drop_on_ground(drag_data(ui,8),screen);ui.close_item_actions();check(world.player.action.is_empty() and s.inventory.slots[8].count==4,"fuel cancel no action or debit")
	camps.states.quantity.fuel=1190
	ui.drop_on_ground(drag_data(ui,8),screen);check(not ui.item_modal_open() and s.inventory.slots[8].count==4,"insufficient fuel capacity refuses without consuming")
	camps.states.quantity.fuel=0
	s.inventory.slots[9]={"item_id":"stone","count":5}
	ui.drop_on_ground(drag_data(ui,9),screen);check(not ui.item_modal_open() and s.inventory.slots[9].count==5,"nonfuel stack rejected without ground fallback")
	s.inventory.slots[8]={"item_id":"wood","count":1};ui.drop_on_ground(drag_data(ui,8),screen)
	check(not ui.item_modal_open() and world.player.action=="throw","single fuel throws without quantity dialog");world.player.cancel_action()
	s.inventory.slots[9]={"item_id":"stone","count":1};ui.drop_on_ground(drag_data(ui,9));check(s.inventory.slots[9].is_empty() and not ui.item_modal_open(),"single ground item drops directly")
	s.inventory.add("wild_carrot",2);s.inventory.add("wildflower",2)
	world.camp_ui.open("quantity");world.camp_ui.mode="free";world.camp_ui.last_detail="";world.camp_ui.refresh()
	var choice: OptionButton=world.camp_ui.ingredient_choices[0]
	check(choice.get_theme_constant("icon_max_width")==18,"selected ingredient icon eighteen pixels")
	var icon_index: int=world.camp_ui.current_options.find("wild_carrot")
	check(choice.get_popup().get_item_icon_max_width(icon_index)==18,"popup ingredient icon eighteen pixels")
	choice.select(icon_index);choice.item_selected.emit(icon_index);choice.show_popup();await shot("small-ingredient-popup");choice.get_popup().hide()
	var failed: Array=checks.filter(func(row): return not row.pass)
	FileAccess.open(OUT+("window-tests.json" if "--capture" in OS.get_cmdline_user_args() else "tests.json"),FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"))
	print("DROP QUANTITY: ",checks.size()," checks, ",failed.size()," failed")
	world.persistent_world=false;world.free();await process_frame;quit(0 if failed.is_empty() else 1)
