extends SceneTree
const OUT := "res://reports/cooking-build-v2/"
const PATH := "user://cooking-build-v2-test.json"
var checks: Array=[]
var world: Node
var service: Node
var camps: RefCounted
var capture := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func shot(name_value: String) -> void:
	if not capture: return
	await frames(3);await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OUT+name_value+".png")
func empty_inventory() -> void:
	for i in 40: service.inventory.slots[i]={}
	service.inventory.changed.emit()
func feed_wood(id: String) -> String:
	for i in 40:
		if service.inventory.slots[i].get("item_id")=="wood": return camps.feed(id,i,service.inventory.slots[i].duplicate(true),1)
	return "需要木材"
func write_fixture(data: Dictionary) -> void:
	var file := FileAccess.open(PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
func load_test_chunk(point: Vector2) -> void:
	var coord: Vector2i=world.stream.chunk_at(point)
	if world.stream.loaded.has(coord): return
	var packet: Dictionary=world.generator.build_chunk(coord)
	var stamps: Array[Dictionary]=[];packet.ground_stamps=stamps
	world.stream.install_chunk(packet)
func run() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	service=world.item_service;camps=service.camps
	world.environment_view.simulation.paused=true;world.player.set_physics_process(false)
	while not world.stream.viewport_ready(world.player.position,Vector2(640,360)): await process_frame
	await frames(6)
	service.save_path=PATH;world.persistent_world=true
	check(service.database.errors.is_empty() and service.craft_book.errors.is_empty(),"item and recipe definitions valid")
	check(not service.craft_book.recipes.has("hand_supply_pouch"),"removed pouch recipe stays absent")
	check(service.database.item("roasted_carrot").effects.hunger>service.database.item("wild_carrot").effects.hunger,"cooked carrot improves hunger yield")
	check(service.database.item("roasted_mushroom").effects.hunger>service.database.item("brown_mushroom").effects.hunger,"cooked mushroom improves hunger yield")
	var at := Vector2.ZERO
	for y in range(-600,601,24):
		if at!=Vector2.ZERO: break
		for x in range(-600,601,24):
			var candidate: Vector2=world.generator.spawn+Vector2(x,y)
			world.player.position=candidate+Vector2(0,75)
			if world.generator.can_walk(world.player.position,16) and camps.placement_reason(candidate).is_empty(): at=candidate;break
	check(at!=Vector2.ZERO,"a legal real-world dry placement found near spawn")
	if at==Vector2.ZERO: await finish();return
	world.player.position=at+Vector2(0,75);world.player.camera.position_smoothing_enabled=false;world.player.camera.force_update_scroll();await frames(4)
	empty_inventory()
	for id in {"wood":4,"stone":6,"flint":1}: service.inventory.add(id,int({"wood":4,"stone":6,"flint":1}[id]))
	check(not service.craft_book.recipes.has("hand_simple_campfire"),"campfire absent from crafting data")
	check(camps.build_book.recipes.size()==1,"one real building definition")
	var materials_before: Array=service.inventory.slots.duplicate(true)
	world.camp_ui.begin_build("hand_simple_campfire")
	check(world.camp_ui.placing and service.inventory.slots==materials_before,"begin build previews without material consumption")
	world.item_ui.drag_pointer=root.get_canvas_transform()*at;world.camp_ui._process(.01)
	await shot("placement-preview")
	world.camp_ui.close_panel()
	check(not world.camp_ui.placing and not world.player.input_blocked and service.inventory.slots==materials_before,"cancel clears preview and restores inputs without material consumption")
	check(not camps.build(world.generator.spawn,"hand_simple_campfire",materials_before).is_empty() and service.inventory.slots==materials_before,"invalid placement preserves materials")
	check(not camps.placement_reason(world.player.position).is_empty(),"player overlap rejected")
	check(not camps.placement_reason(Vector2.ZERO).is_empty(),"map boundary rejected")
	world.stream.set_process(false)
	var lake: Vector4=world.generator.lakes[0]
	var water := Vector2(lake.x,lake.y)
	load_test_chunk(water);world.player.position=water+Vector2(0,75)
	check(camps.placement_reason(water).contains("干燥"),"real lake water rejects camp placement")
	var path: PackedVector2Array=world.generator.connections[0]
	var passage: Vector2=path[0].lerp(path[1],.5)
	load_test_chunk(passage);world.player.position=passage+Vector2(0,75)
	check(camps.placement_reason(passage).contains("通行"),"real primary corridor rejects camp placement")
	world.player.position=at+Vector2(0,75);world.stream.set_process(true)
	world.player.camera.force_update_scroll();await frames()
	world.camp_ui.begin_build("hand_simple_campfire")
	service.inventory.add("branch",1)
	check(not camps.build(at,"hand_simple_campfire",materials_before).is_empty() and camps.states.is_empty(),"inventory changes invalidate pending placement")
	world.camp_ui.close_panel()
	var previous_path: String=service.save_path
	service.save_path="user://missing-directory/build.json"
	check(not camps.build(at,"hand_simple_campfire",service.inventory.slots.duplicate(true)).is_empty() and camps.states.is_empty() and service.inventory.count_item("wood")==4,"disk failure rolls back building and materials")
	service.save_path=previous_path
	world.camp_ui.begin_build("hand_simple_campfire")
	var place_click := InputEventMouseButton.new();place_click.button_index=MOUSE_BUTTON_LEFT;place_click.pressed=true
	place_click.position=root.get_canvas_transform()*at
	world.item_ui._input(place_click)
	check(camps.states.size()==1 and not world.camp_ui.placing,"left click commits legal building through UI handler")
	check(service.inventory.count_item("simple_campfire")==0 and service.inventory.count_item("wood")==0 and service.inventory.count_item("stone")==0 and service.inventory.count_item("flint")==0,"building consumes exact costs with no inventory product")
	world.item_ui._input(place_click)
	check(camps.states.size()==1,"repeated confirmation cannot create duplicate building")
	var id: String=camps.states.keys()[0]
	var node: Node2D=camps.visuals[id]
	check(node.is_in_group("world_interactables") and node.base.texture!=null,"world object uses generated art and E interaction group")
	check(camps.placement_reason(at)!="","existing campfire overlap rejected")
	check(not camps.act(id,"toggle").is_empty() and not camps.states[id].lit,"cannot ignite without fuel")
	check(not feed_wood(id).is_empty(),"fuel addition without wood rejected")
	service.inventory.add("wood",4)
	check(feed_wood(id).is_empty() and service.inventory.count_item("wood")==3 and camps.states[id].fuel==120,"wood atomically exchanged for 120 fuel seconds")
	check(camps.states[id].lit,"fuel impact automatically ignites fire")
	await frames()
	check(node.flame.visible,"flame visible when burning")
	check(preload("res://scripts/world_interaction.gd").execute(world.stream,world.player,node),"original E execution opens camp interface")
	check(world.camp_ui.panel.visible and world.player.input_blocked,"cooking UI owns input")
	world.camp_ui.close_panel()
	world.player.facing="back"
	var interact := InputEventKey.new();interact.keycode=KEY_E;interact.physical_keycode=KEY_E;interact.pressed=true
	root.push_input(interact,true);await frames()
	check(world.camp_ui.panel.visible,"native E input opens cookbook directly")
	interact.pressed=false;root.push_input(interact,true)
	check(preload("res://scripts/world_interaction.gd").caption(node,service.inventory)=="E 烹饪","campfire directly advertises cooking")
	check(world.camp_ui.recipes.size()==camps.rules.recipes.size(),"every real recipe present")
	var mystery_count := 0
	for child in world.camp_ui.recipes[0].get_parent().get_children():
		if child is Button and child.text.begins_with("？") and child.disabled: mystery_count+=1
	check(mystery_count==4,"four disabled mystery UI placeholders")
	await shot("fire-day-panel")
	check(not camps.act(id,"cook","roast_carrot").is_empty(),"missing ingredient cannot start cooking")
	service.inventory.add("wild_carrot",2);service.inventory.add("brown_mushroom",2)
	check(camps.act(id,"cook","roast_carrot").is_empty(),"start carrot cooking")
	check(service.inventory.count_item("wild_carrot")==1 and camps.states[id].recipe=="roast_carrot","deduction and job coexist in same snapshot")
	check(not camps.act(id,"cook","roast_carrot").is_empty() and service.inventory.count_item("wild_carrot")==1,"duplicate start cannot deduct ingredient twice")
	camps.advance(4)
	check(camps.states[id].elapsed==4 and camps.states[id].fuel==116,"fuel and progress share normal simulation seconds")
	world.camp_ui.close_panel();camps.states[id].fuel=2;camps.advance(2)
	check(camps.states[id].elapsed==6,"closing panel does not cancel cooking")
	camps.advance(20);await frames()
	check(camps.states[id].elapsed==6 and camps.states[id].fuel==0 and not node.flame.visible,"fuel expiry pauses cooking fuel and flame")
	service.save_state()
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(saved.campfires.objects[id].elapsed==6 and saved.campfires.objects[id].recipe=="roast_carrot","mid-cooking progress persisted with deducted ingredient")
	var coord: Vector2i=world.stream.chunk_at(at)
	world.stream.set_process(false)
	world.stream.unload_chunk(coord);await frames();check(not is_instance_valid(node),"real chunk unload releases world visual and flame nodes")
	check(camps.states[id].elapsed==6,"unload retains cooking state")
	var packet: Dictionary=world.generator.build_chunk(coord)
	var empty_stamps: Array[Dictionary]=[];packet.ground_stamps=empty_stamps
	world.stream.install_chunk(packet);world.stream.set_process(true)
	node=camps.visuals[id];check(camps.visuals.size()==1,"real chunk reload creates one visual only")
	camps.install(coord);check(camps.visuals.size()==1,"repeated chunk install remains idempotent")
	feed_wood(id);camps.advance(6)
	check(camps.states[id].ready and camps.states[id].elapsed==12,"cooking reaches exactly one ready product")
	camps.advance(50);check(camps.states[id].recipe=="roast_carrot" and camps.states[id].ready,"ready product survives continued fire")
	world.camp_ui.open(id);world.camp_ui.refresh()
	check(world.camp_ui.output_icon.texture==service.texture("roasted_carrot","icon") and world.camp_ui.output_text.text.contains("可领取"),"ready output uses actual product icon and claim state")
	await shot("ready-product")
	var obtained_events: Array=[]
	service.item_obtained.connect(func(item: String,count: int): obtained_events.append([item,count]))
	var before: Array=service.inventory.slots.duplicate(true)
	for i in range(8,40):service.inventory.slots[i]={"item_id":"stone","count":99}
	check(not camps.act(id,"claim").is_empty() and camps.states[id].ready,"full bag leaves product in campfire")
	check(obtained_events.is_empty(),"full bag emits no successful acquisition")
	service.inventory.slots=before
	check(camps.act(id,"claim").is_empty() and service.inventory.count_item("roasted_carrot")==1,"claim uses original inventory insertion")
	check(not camps.act(id,"claim").is_empty() and service.inventory.count_item("roasted_carrot")==1,"repeat claim cannot duplicate product")
	check(obtained_events==[["roasted_carrot",1]],"claim emits exactly one actual acquisition")
	service.body.hunger=20;service.body.health=100
	var food_slot := -1
	for i in 40:
		if service.inventory.slots[i].get("item_id")=="roasted_carrot":food_slot=i
	world.item_ui.open_item_menu(food_slot,Vector2(400,200));world.item_ui.run_item_action(false)
	check(service.body.hunger==32 and service.inventory.count_item("roasted_carrot")==0,"actual right-click use feeds through original BodyState")
	service.inventory.add("roasted_carrot",1);service.body.hunger=100
	for i in 40:
		if service.inventory.slots[i].get("item_id")=="roasted_carrot":food_slot=i
	check(not service.inventory.use_slot(food_slot) and service.inventory.count_item("roasted_carrot")==1,"fully healthy and full hunger does not consume cooked food")
	check(camps.act(id,"cook","roast_mushroom").is_empty(),"second existing ingredient starts mushroom recipe")
	camps.states[id].fuel=3;camps.advance(8);await frames()
	check(camps.states[id].elapsed==3 and camps.states[id].fuel==0 and not camps.states[id].lit and not node.flame.visible,"fuel exhaustion advances only actual burn time then pauses and hides flame")
	camps.advance(30);check(camps.states[id].elapsed==3,"paused job keeps ingredient and progress")
	feed_wood(id);check(camps.states[id].lit,"new fuel automatically reignites exhausted camp")
	camps.advance(7)
	check(camps.states[id].ready and camps.act(id,"claim").is_empty(),"resume produces and claims mushroom once")
	service.body.hunger=10
	for i in 40:
		if service.inventory.slots[i].get("item_id")=="roasted_mushroom": food_slot=i
	check(service.inventory.move_slot(food_slot,0) and service.inventory.use_slot(0) and service.body.hunger==20,"cooked mushroom hotbar use follows existing food path")
	var fuel: float=camps.states[id].fuel
	world.environment_view.simulation.paused=true;await frames(8)
	check(camps.states[id].fuel==fuel,"environment pause prevents fuel advancement")
	world.environment_view.preview=true;world.environment_view.simulation.paused=false;await frames(8)
	check(camps.states[id].fuel==fuel,"debug day preview prevents fuel advancement")
	world.environment_view.preview=false;world.environment_view.simulation.paused=true
	world.environment_view.simulation.set_time(0);await frames()
	check(camps.states[id].fuel==fuel,"setting world hour does not catch up fuel")
	await shot("fire-night")
	check(world.environment_view.material_effect.get_shader_parameter("camp_count")==1,"environment shader receives burning camp light")
	camps.advance(float(camps.states[id].fuel));await frames();await shot("fire-night-off")
	check(world.environment_view.material_effect.get_shader_parameter("camp_count")==0,"extinguish removes warm illumination")
	feed_wood(id);camps.act(id,"cook","roast_carrot");camps.advance(5)
	service.resource_hits["camp:test:ore"]=2;service.consumed["camp:test:pickup"]=true
	service.inventory.add("stone_pickaxe",1)
	for i in range(8,40):
		if service.inventory.slots[i].get("item_id")=="stone_pickaxe":service.inventory.move_slot(i,1);service.inventory.equip(1);break
	service.save_state()
	var original: Dictionary=service.snapshot().duplicate(true)
	camps.states={};camps.rebuild();service.load_state();await frames()
	check(service.writable and camps.states[id].elapsed==5 and camps.states[id].lit,"same-process restart restores mid-cooking fuel progress and ignition")
	check(service.inventory.has_capability("mine") and service.inventory.get_slot(1).item_id=="stone_pickaxe","equipped hotbar references preserved")
	check(service.resource_hits["camp:test:ore"]==2 and service.consumed.has("camp:test:pickup"),"harvest and consumed history preserved")
	check(service.inventory.count_item("roasted_carrot")==1,"previously claimed product is not regenerated on restore")
	for bad in [999,-1,INF]:
		var data: Dictionary=original.campfires.duplicate(true)
		if bad==999:data.version=999
		else:data.objects[id].fuel=bad
		check(not camps.validate(data),"illegal or unknown camp data rejected: "+str(bad))
	var invalid: Dictionary=original.duplicate(true);invalid.campfires.version=999
	write_fixture(invalid)
	var source_text := FileAccess.get_file_as_string(PATH)
	service.load_state();service.save_state()
	check(not service.writable and FileAccess.get_file_as_string(PATH)==source_text,"unknown camp version protects original source file")
	service.writable=true
	var legacy: Dictionary=original.duplicate(true);legacy.erase("campfires")
	write_fixture(legacy);service.load_state();await frames()
	check(service.writable and camps.states.is_empty() and service.inventory.has_capability("mine"),"old save initializes empty camps and retains equipped inventory")
	write_fixture(original);service.load_state();await frames()
	world.camp_ui.open(id)
	for size_value in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=size_value;root.content_scale_size=size_value;world.camp_ui.fit();await frames()
		var panel: Panel=world.camp_ui.panel
		check(Rect2(Vector2.ZERO,Vector2(size_value)).encloses(Rect2(panel.position,panel.size*panel.scale)),"fixed camp panel fits viewport "+str(size_value))
		var rect := panel.get_rect();world.camp_ui.selected="roast_mushroom";world.camp_ui.refresh();await frames()
		check(panel.get_rect()==rect,"recipe changes keep panel dimensions "+str(size_value))
		await shot("panel-%d"%size_value.x)
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;world.camp_ui.close_panel()
	# Save a known mid-job state for an independent process to read.
	service.clock=15;service.dirty=true;service._process(.01)
	var periodic: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(periodic.campfires.objects[id].elapsed==5,"existing periodic save persists camp progress")
	service.body.hunger=41;service.dirty=true
	world.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var closing: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(closing.body.hunger==41 and closing.campfires.objects[id].elapsed==5,"normal window close notification saves current original snapshot and camp state")
	world.camp_ui.close_panel()
	var notice_ui: Control=world.item_ui.obtained
	notice_ui.pending.clear();notice_ui.remaining=0
	var events_before := obtained_events.size()
	service.inventory.add("broad_leaf",6)
	check(service.start_craft("hand_leaf_fiber",3).is_empty(),"batch craft starts through original service")
	service.advance_craft(1.5)
	check(obtained_events.size()==events_before+1 and obtained_events.back()==["plant_fiber",9],"batch acquisition reports actual total nine")
	notice_ui._process(.01)
	check(not notice_ui.caption.text.is_empty() and notice_ui.caption.text.contains("9") and notice_ui.icon.texture==service.texture("plant_fiber","icon"),"unified toast displays real icon name and batch quantity")
	notice_ui.set_process(false)
	await shot("obtained-batch")
	service.item_obtained.emit("roasted_mushroom",1)
	check(notice_ui.pending.size()==1,"rapid acquisitions queue without overwriting active quantity")
	notice_ui._process(2.1)
	check(notice_ui.caption.text.contains("烤蘑菇") and notice_ui.pending.is_empty(),"queued second item shown after first")
	notice_ui._process(2.1)
	check(not notice_ui.card.visible,"toast disappears after duration")
	notice_ui.set_process(true)
	var count_before := obtained_events.size()
	service.inventory.add("broad_leaf",2);service.start_craft("hand_leaf_fiber",1);service.cancel_craft()
	check(obtained_events.size()==count_before,"cancelled craft emits no acquisition")
	world.camp_ui.open(id)
	camps.rules.recipes.roast_carrot.default_unlocked=false
	world.camp_ui.selected="roast_carrot";world.camp_ui.refresh()
	check(world.camp_ui.cook_button.disabled and not camps.act(id,"cook","roast_carrot").is_empty(),"locked defined recipe cannot start through UI or service")
	camps.rules.recipes.roast_carrot.erase("default_unlocked")
	world.camp_ui.close_panel()
	world.item_ui.toggle_craft();world.item_ui.craft_panel.set_mode(true);await frames()
	check(world.item_ui.craft_panel.recipe_buttons.size()==1 and world.item_ui.craft_panel.once.text=="建造","building mode only shows actual facility")
	await shot("building-list")
	world.item_ui.craft_panel.set_mode(false);await frames()
	check(world.item_ui.craft_panel.recipe_buttons.size()==5 and not world.item_ui.craft_panel.recipe_buttons.has("hand_simple_campfire"),"crafting mode only shows five inventory products")
	await shot("crafting-list")
	world.item_ui.close_panels()
	service.inventory.add("simple_campfire",1)
	var old_slot := -1
	for i in 40:
		if service.inventory.slots[i].get("item_id")=="simple_campfire": old_slot=i;break
	check(service.inventory.use_slot(old_slot) and world.camp_ui.placing,"legacy campfire inventory item still opens original placement")
	world.camp_ui.close_panel()
	check(service.inventory.count_item("simple_campfire")==1,"cancelling legacy placement preserves existing inventory item")
	await finish()

func finish() -> void:
	var failed: int=checks.filter(func(row):return not row.pass).size()
	FileAccess.open(OUT+("window" if capture else "headless")+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("CAMPFIRE V1: ",checks.size()," checks; ",failed," failures")
	service.dirty=false;world.persistent_world=false;world.queue_free();await frames(6)
	quit(0 if failed==0 else 1)

