extends SceneTree
const OUT := "res://reports/cooking-discovery-v1/"
const PATH := "user://cooking-discovery-v1-test.json"
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
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_value+".png")
func empty_inventory() -> void:
	for i in 40: service.inventory.slots[i]={}
	service.inventory.changed.emit()
func write_fixture(data: Dictionary) -> void:
	var f := FileAccess.open(PATH,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
func run() -> void:
	capture="--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	service=world.item_service;camps=service.camps
	world.environment_view.simulation.paused=true;world.player.set_physics_process(false)
	while not world.stream.viewport_ready(world.player.position,Vector2(640,360)): await process_frame
	await frames(5)
	world.persistent_world=true;service.save_path=PATH
	if "--restart-read" in OS.get_cmdline_user_args():
		service.load_state()
		check(service.writable,"fresh process save writable")
		check(camps.known("fruit_platter") and camps.known("harvest_platter"),"fresh process discoveries retained")
		check(camps.states.has("test") and camps.states.test.ready and camps.states.test.recipe=="harvest_platter","fresh process pending output retained")
		check(service.inventory.count_item("herb_roasted_mushroom")==1,"fresh process claimed herb output retained")
		check(camps.act("test","claim").is_empty(),"fresh process pending output claims")
		check(not camps.act("test","claim").is_empty(),"fresh process repeat claim refused")
		check(service.inventory.count_item("field_harvest_platter")==1,"fresh process exactly one output")
		var failed: Array=checks.filter(func(c): return not c.pass)
		var report := FileAccess.open(OUT+"restart-tests.json",FileAccess.WRITE);report.store_string(JSON.stringify({"checks":checks,"count":checks.size(),"failed":failed.size()},"\t"));report.close()
		print("RESTART: ",checks.size()," checks, ",failed.size()," failed")
		world.persistent_world=false;world.free();await frames(6);quit(0 if failed.is_empty() else 1);return
	empty_inventory();camps.states.clear();camps.discovered.clear()
	var at: Vector2=world.player.position+Vector2(0,60)
	camps.states["test"]={"x":at.x,"y":at.y,"fuel":1000.0,"lit":true,"recipe":"","elapsed":0.0,"ready":false};camps.rebuild();camps.install(world.stream.chunk_at(at))
	check(service.database.errors.is_empty(),"database validates")
	var active := 0
	for key in camps.rules.recipes:
		var r: Dictionary=camps.rules.recipes[key]
		if r.get("legacy_only",false): continue
		active+=1
		check(not service.database.item(r.output).is_empty(),"output exists "+key)
		for id in r.materials: check(not service.database.item(id).is_empty(),"ingredient exists "+key+"/"+id)
	check(active==camps.rules.recipes.values().filter(func(row):return not row.get("legacy_only",false)).size(),"all current active recipes")
	for id in service.database.ids():
		var d: Dictionary=service.database.item(id)
		if d.get("use_action")=="eat": check(d.effects.keys().all(func(key):return key in ["hunger","hallucination"]) and int(d.effects.hunger)>0,"current edible effects "+id)
	check(service.database.item("roasted_carrot").effects.hunger==6,"carrot current hunger six")
	check(service.database.item("roasted_mushroom").effects.hunger==7,"mushroom current hunger seven")
	for entry in [["herb_roasted_mushroom",10],["roasted_fruit_platter",36],["field_harvest_platter",40]]:
		check(service.database.item(entry[0]).effects.hunger==entry[1],"new hunger "+entry[0])
		check(service.texture(entry[0],"icon")!=null,"unique icon loads "+entry[0])
	check(camps.match_materials({"brown_mushroom":1,"broad_leaf":2})=="herb_mushroom","reverse order matches")
	check(camps.match_materials({"brown_mushroom":1})=="roast_mushroom","current simple mushroom combination remains available")
	check(camps.match_materials({"wildflower":1.5,"brown_mushroom":2}).is_empty(),"fractional counts rejected")
	check(camps.match_materials({"wildflower":1,"brown_mushroom":2,"wood":1}).is_empty(),"extra material rejected")
	service.inventory.add("brown_mushroom",8);service.inventory.add("wildflower",8);service.inventory.add("wild_berry",8);service.inventory.add("wild_apple",3);service.inventory.add("wild_carrot",3)
	var before: Array=service.inventory.slots.duplicate(true)
	check(not camps.act("test","cook","nonexistent").is_empty() and before==service.inventory.slots,"unknown recipe refused without debit")
	check(not camps.act("test","cook","fruit_platter").is_empty(),"book cannot start hidden recipe")
	check(not camps.act("test","experiment","",{"wild_apple":1}).is_empty() and before==service.inventory.slots,"invalid combination unchanged")
	service.save_path="user://nonexistent-cooking-dir/save.json"
	check(not camps.act("test","cook","roast_carrot").is_empty() and before==service.inventory.slots and camps.states.test.recipe.is_empty(),"start disk failure rollback")
	service.save_path=PATH
	check(camps.act("test","experiment","",{"wildflower":1,"wild_apple":1,"wild_berry":2}).is_empty(),"hidden combination starts")
	check(not camps.known("fruit_platter"),"start does not discover")
	before=service.inventory.slots.duplicate(true)
	check(not camps.act("test","experiment","",{"wildflower":1,"wild_apple":1,"wild_berry":2}).is_empty() and before==service.inventory.slots,"repeated start no second debit")
	world.camp_ui.open("test");world.camp_ui.mode="free";world.camp_ui.ingredient_ids.assign(["wildflower","wild_apple","wild_berry",""]);world.camp_ui.ingredient_counts.assign([1,1,2,1]);world.camp_ui.refresh()
	check(not world.camp_ui.output_text.text.contains("野果"),"hidden cooking output not leaked")
	check(world.camp_ui.recipes.size()==active,"current active recipe cards plus future placeholders")
	await frames()
	check(world.camp_ui.ingredient_spins[0].get_global_rect().end.x<world.camp_ui.status.get_global_rect().position.x,"free controls stay inside left column")
	check(not world.camp_ui.recipes[camps.rules.recipes.keys().filter(func(key):return not camps.rules.recipes[key].get("legacy_only",false)).find("fruit_platter")].text.contains("野果") and world.camp_ui.recipes[camps.rules.recipes.keys().filter(func(key):return not camps.rules.recipes[key].get("legacy_only",false)).find("fruit_platter")].icon==null,"hidden card has no real name or icon")
	await shot("hidden-combination")
	var amount_edit: LineEdit=world.camp_ui.ingredient_spins[0].get_line_edit()
	amount_edit.grab_focus();await frames();amount_edit.select_all()
	var number_key := InputEventKey.new();number_key.physical_keycode=KEY_2;number_key.keycode=KEY_2;number_key.unicode=50;number_key.pressed=true
	root.push_input(number_key);await frames()
	check(amount_edit.text=="2","native quantity text input reaches focused editor")
	world.camp_ui.ingredient_spins[0].apply();amount_edit.release_focus()
	check(world.camp_ui.ingredient_counts[0]==2,"quantity edit updates selected material count")
	camps.advance(5);camps.states.test.lit=false;camps.burning.erase("test");camps.advance(100)
	check(camps.states.test.elapsed==5 and not camps.known("fruit_platter"),"extinguished pauses without discovery")
	world.camp_ui.close_panel();camps.states.test.lit=true;camps.burning.test=true;camps.advance(11)
	check(camps.states.test.ready and camps.known("fruit_platter"),"closed window completion discovers")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check(saved.campfires.discovered.has("fruit_platter") and saved.campfires.objects.test.ready,"ready and discovery saved together")
	camps.discovered.clear();camps.states.clear();service.load_state()
	check(camps.known("fruit_platter") and camps.states.test.ready,"save reload restores discovery and ready")
	empty_inventory()
	for i in 40: service.inventory.slots[i]={"item_id":"wood","count":50}
	var obtained: Array=[];service.item_obtained.connect(func(id: String, count: int): obtained.append([id,count]))
	check(not camps.act("test","claim").is_empty() and camps.states.test.ready and obtained.is_empty(),"full bag retains output no obtained event")
	service.inventory.slots[8]={}
	service.save_path="user://nonexistent-cooking-dir/save.json"
	check(not camps.act("test","claim").is_empty() and camps.states.test.ready and service.inventory.slots[8].is_empty(),"claim disk failure rollback")
	service.save_path=PATH
	check(camps.act("test","claim").is_empty() and service.inventory.count_item("roasted_fruit_platter")==1 and obtained.size()==1,"claim once awards once")
	check(not camps.act("test","claim").is_empty() and obtained.size()==1,"repeat claim no award")
	empty_inventory();service.inventory.add("roasted_mushroom",1);service.body.hunger=20;service.body.health=45;service.body.stamina=37
	var old_hunger: float=service.body.hunger
	for i in 40:
		if service.inventory.slots[i].get("item_id")=="roasted_mushroom": service.inventory.use_slot(i);break
	check(service.body.hunger==old_hunger+float(service.database.item("roasted_mushroom").effects.hunger) and service.body.health==45 and service.body.stamina==37,"old mushroom eats hunger-only")
	# Pre-upgrade tasks retain original output and require no ingredient migration.
	camps.states.test.recipe="roast_mushroom";camps.states.test.elapsed=9;camps.states.test.ready=false;camps.states.test.lit=true;camps.burning.test=true;camps.advance(1)
	check(camps.states.test.ready and camps.act("test","claim").is_empty() and service.inventory.count_item("roasted_mushroom")==1,"legacy paid task yields original item")
	empty_inventory();service.inventory.add("broad_leaf",4);service.inventory.add("wild_carrot",3);service.inventory.add("brown_mushroom",4);service.inventory.add("wildflower",4);service.inventory.add("wild_berry",4)
	check(camps.act("test","cook","herb_mushroom").is_empty(),"known book herb recipe starts");camps.advance(10);check(camps.act("test","claim").is_empty(),"herb claim works")
	before=service.inventory.slots.duplicate(true)
	check(not camps.act("test","experiment","",{"wild_berry":2,"wild_apple":1,"wildflower":1}).is_empty() and before==service.inventory.slots and camps.states.test.recipe.is_empty(),"matching recipe with missing ingredient consumes nothing")
	world.camp_ui.open("test");world.camp_ui.mode="free";world.camp_ui.ingredient_ids.fill("");world.camp_ui.last_detail="";world.camp_ui.refresh()
	var choice: OptionButton=world.camp_ui.ingredient_choices[0]
	var carrot_index: int=world.camp_ui.current_options.find("wild_carrot")
	choice.select(carrot_index);choice.item_selected.emit(carrot_index)
	check(world.camp_ui.ingredient_ids[0]=="wild_carrot" and world.camp_ui.selected_materials()=={"wild_carrot":1},"native choice signal selects real inventory ingredient")
	check(world.camp_ui.ingredient_choices[1].is_item_disabled(carrot_index),"duplicate ingredient disabled in other slots")
	choice.select(0);choice.item_selected.emit(0)
	check(world.camp_ui.selected_materials().is_empty(),"native choice removal clears selection")
	choice.select(carrot_index);choice.item_selected.emit(carrot_index)
	world.camp_ui.cook_button.pressed.emit()
	check(camps.states.test.recipe=="roast_carrot" and service.inventory.count_item("wild_carrot")==2,"known recipe starts via free mode button")
	before=service.inventory.slots.duplicate(true);world.camp_ui.cook_button.pressed.emit()
	check(before==service.inventory.slots,"repeated UI start cannot debit twice")
	world.camp_ui.close_panel();world.camp_ui.open("test")
	check(camps.states.test.recipe=="roast_carrot" and before==service.inventory.slots,"closing and reopening retains task without debit")
	camps.advance(12);world.camp_ui.claim_button.pressed.emit()
	check(service.inventory.count_item("roasted_carrot")==1 and camps.states.test.recipe.is_empty(),"free known recipe output claims via UI")
	check(camps.act("test","experiment","",{"wildflower":1,"wild_berry":1,"brown_mushroom":1,"wild_carrot":1}).is_empty(),"four material hidden harvest starts")
	camps.advance(20);check(camps.known("harvest_platter") and camps.states.test.ready,"harvest completion discovers")
	world.camp_ui.open("test");world.camp_ui.mode="book";world.camp_ui.selected="harvest_platter";world.camp_ui.last_detail="";world.camp_ui.refresh()
	check(world.camp_ui.output_text.text.contains("原野丰收") and world.camp_ui.recipes[camps.rules.recipes.keys().filter(func(key):return not camps.rules.recipes[key].get("legacy_only",false)).find("harvest_platter")].text=="原野丰收烤盘","completion reveals output and recipe card")
	for size_value in [Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),ProjectSettings.get_setting("display/window/size/viewport_height"))]:
		root.size=size_value;world.camp_ui.fit();await frames()
		check(world.camp_ui.panel.size==Vector2(1030,560),"fixed panel "+str(size_value))
		await shot("book-"+str(size_value.x))
		world.camp_ui.mode="free";world.camp_ui.last_detail="";world.camp_ui.refresh();await frames()
		check(world.camp_ui.ingredient_spins[2].get_global_rect().end.x<world.camp_ui.status.get_global_rect().position.x,"free controls no overlap "+str(size_value))
		await shot("free-"+str(size_value.x))
		world.camp_ui.mode="book";world.camp_ui.last_detail="";world.camp_ui.refresh()
	world.camp_ui.mode="free";world.camp_ui.last_detail="";world.camp_ui.refresh();await shot("free-slots")
	var schema: Dictionary=camps.serialize()
	check(camps.validate(schema),"new schema validates")
	schema.discovery_version=999;check(not camps.validate(schema),"future discovery version refused")
	schema=camps.serialize();schema.discovered={"nonexistent":true};check(not camps.validate(schema),"unknown discovery refused")
	var old: Dictionary=camps.serialize();old.erase("discovered");old.erase("discovery_version");check(camps.validate(old),"old schema still accepted")
	var final_save: Dictionary=service.snapshot().duplicate(true)
	var old_save: Dictionary=final_save.duplicate(true);old_save.campfires=old
	write_fixture(old_save);service.load_state()
	check(service.writable and camps.states.test.ready and camps.known("harvest_platter"),"old save without discovery fields loads ready task safely")
	write_fixture(final_save);service.load_state()
	var future_save: Dictionary=final_save.duplicate(true);future_save.campfires.discovery_version=999;write_fixture(future_save)
	service.load_state();check(not service.writable,"future discovery schema protects source save")
	check(JSON.parse_string(FileAccess.get_file_as_string(PATH)).campfires.discovery_version==999,"protected future source remains untouched")
	service.writable=true;write_fixture(final_save);service.load_state()
	var failures: Array=checks.filter(func(c): return not c.pass)
	var f := FileAccess.open(OUT+("window-tests.json" if capture else "tests.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"count":checks.size(),"failed":failures.size()},"\t"));f.close()
	print("COOKING DISCOVERY: ",checks.size()," checks, ",failures.size()," failed")
	world.persistent_world=false;world.free();await frames(6);quit(0 if failures.is_empty() else 1)


