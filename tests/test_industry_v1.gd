extends SceneTree
var OUT="res://reports/industry-formal-v1/" if "formal" in OS.get_cmdline_user_args() else "res://reports/industry-v1/"
var SAVE=OUT+"isolated-save.json"
const Fresh=preload("res://scripts/food_freshness.gd")
var w: Node
var s: Node
var checks: Array=[]
var events: Array=[]
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:call_deferred("run")
func frames(n: int=3) -> void:
	for i in n:await process_frame
func make_build(id: String, kind: String, offset: Vector2=Vector2(70,0)) -> void:
	var row: Dictionary=s.builds.candidate(kind,w.player.position+offset,false,false,0)
	s.builds.states[id]=row
	s.builds.install(w.stream.chunk_at(Vector2(row.x,row.y)))
	s.builds.visuals[id].body.collision_layer=0
func stock() -> void:
	for i in 40:s.inventory.slots[i]={}
	for id in ["wood","copper_ore","silver_ore","gold_ore","copper_ingot","copper_plate","copper_parts","metal_connector","silver_ingot","stone","plant_fiber","potato","cabbage","wild_carrot","wild_berry","wool","flint","branch","broad_leaf","carrot_seed"]:
		s.inventory.add(id,20)
func cmd(id: String, action: String, index: int=0,key: String="", count: int=1, materials: Dictionary={}) -> String:
	return s.industry.act(id,action,index,key,count,materials)
func approved_art(path: String) -> bool:
	if path.begins_with("res://assets/industry/v1/"):
		var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/industry/v1/provenance.json"))
		return source.approval=="approved_by_user" and source.files.get(path.get_file(),"")==FileAccess.get_sha256(path)
	if path.begins_with("res://assets/camp_expansion/v2/"):
		var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/camp_expansion/v2/provenance.json"))
		if source.status!="approved_user":return false
		for row in source.files:
			if "res://"+row.runtime==path:return row.sha256==FileAccess.get_sha256(path)
	return false
func finish() -> void:
	var failed: Array=checks.filter(func(c):return not c.pass)
	var f=FileAccess.open(OUT+("window" if "window" in OS.get_cmdline_user_args() else "restart" if "read" in OS.get_cmdline_user_args() else "headless")+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"));f.close()
	print("INDUSTRY V1: ",checks.size()," checks; ",failed.size()," failures")
	w.persistent_world=false;w.free();await frames(6);quit(0 if failed.is_empty() else 1)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Engine.set_meta("industry_preview",not "formal" in OS.get_cmdline_user_args());Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
	s=w.item_service;s.set_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	await frames(5);s.save_path=SAVE;w.persistent_world=true
	s.item_obtained.connect(func(id,count):events.append([id,count]))
	if "read" in OS.get_cmdline_user_args():
		s.load_state();check(s.writable,"restart snapshot accepted")
		check(s.builds.states.has("furnace"),"restart retains facilities")
		check(not s.builds.states.lamp.machine.enabled,"restart retains switched off lamp")
		check(is_equal_approx(s.builds.states.fridge.contents[0].spoilage,.5),"restart retains chilled fraction")
		check(s.builds.states.trough.machine.feed.get("wild_berry",0)==2,"restart retains feed count")
		check(s.inventory.slots[39].get("spoilage",-1)==1.0,"restart retains rotten stack")
		check(s.builds.states.oven.machine.jobs[3].recipe=="oven_large_hodgepodge" and s.builds.states.oven.machine.jobs[3].materials.wild_carrot==3,"restart retains fallback recipe and paid quantities")
		await finish();return
	check(s.database.errors.is_empty(),"item definitions valid")
	check(s.camps.build_book.errors.is_empty(),"building recipe definitions valid")
	check(s.craft_book.errors.is_empty(),"original crafting definitions valid")
	if "formal" in OS.get_cmdline_user_args():
		check(not Engine.get_meta("industry_preview") and not s.preview,"formal mode without preview switches")
		var pro: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/industry/v1/provenance.json"))
		check(pro.approval=="approved_by_user" and pro.files.size()==35,"explicit approval covers exactly current 35 files")
		for filename in pro.files:
			var path: String="res://assets/industry/v1/"+filename
			check(FileAccess.get_sha256(path)==pro.files[filename],"approved PNG hash "+filename)
			check(ResourceLoader.exists(path) and load(path) is Texture2D,"formal imported texture "+filename)
		for row in s.camps.build_book.recipes.values():
			if row.get("industry",false): check(row.default_unlocked,"formal construction recipe open "+row.recipe_id)
		for kind in s.builds.definitions:
			var d: Dictionary=s.builds.definitions[kind]
			if d.get("industry",false):check(approved_art(d.art),"formal building art retains approved source SHA "+kind)
		for id in s.database.ids():
			var d: Dictionary=s.database.item(id)
			if d.get("industry",false):check(approved_art(d.icon) and s.texture(id,"icon")!=null,"formal inventory art retains approved source SHA "+id)
		check(s.stack_texture({"item_id":"roasted_carrot","count":1,"spoilage":1.0},"icon")==load("res://assets/industry/v1/rotten_roasted_carrot.png"),"rotten food uses formal art")
	stock()
	make_build("furnace","stone_furnace");make_build("metal","metal_workbench");make_build("oven","copper_oven");make_build("lamp","copper_lamp");make_build("trough","feed_trough");make_build("fridge","refrigerator");make_build("cabinet","reinforced_cabinet")
	await frames()
	check(s.builds.states.cabinet.contents.size()==24,"reinforced cabinet has 24 slots")
	check(s.builds.states.fridge.contents.size()==12,"refrigerator has 12 slots")
	check(cmd("furnace","start",0,"smelt_copper").is_empty(),"furnace starts with paid ore")
	check(s.inventory.count_item("copper_ore")==18,"smelting consumes two ore once")
	s.industry.advance(10,4)
	check(s.builds.states.furnace.machine.jobs[0].elapsed==0,"no fuel pauses progress")
	check(cmd("furnace","claim").length()>0,"unfinished output cannot be claimed")
	check(cmd("furnace","fuel",0,"stone").length()>0,"invalid fuel rejected")
	check(cmd("furnace","fuel",0,"wood").is_empty(),"fuel added transactionally")
	check(cmd("furnace","ignite").is_empty(),"manual furnace ignition")
	s.industry.advance(10,4)
	check(s.builds.states.furnace.machine.jobs[0].elapsed==10,"powered furnace advances")
	check(cmd("furnace","start",0,"smelt_silver").is_empty(),"second metal queues")
	check(s.builds.states.furnace.machine.queue.size()==1,"queue persisted in building")
	s.industry.advance(14,5.6)
	check(s.builds.states.furnace.machine.completed.size()==1 and s.builds.states.furnace.machine.completed[0].ready,"copper completes in output tray")
	var old_path: String=s.save_path;s.save_path="res://reports/industry-v1/missing/invalid.json"
	var count: int=s.inventory.count_item("copper_ingot")
	check(cmd("furnace","claim").length()>0,"claim save failure reported")
	check(s.inventory.count_item("copper_ingot")==count and s.builds.states.furnace.machine.completed.size()==1,"failed claim restores output and inventory")
	s.save_path=old_path
	check(cmd("furnace","claim").is_empty(),"claim successful")
	check(events.back()==["copper_ingot",1],"claim uses unified obtained event")
	check(cmd("furnace","claim").length()>0,"duplicate claim blocked")
	s.industry.advance(32,12.8)
	check(s.builds.states.furnace.machine.completed.size()==1 and s.builds.states.furnace.machine.completed[0].ready,"queued silver completes")
	check(cmd("furnace","claim").is_empty(),"silver claimed")
	for id in ["metal_copper_plate","metal_copper_parts","metal_metal_connector","metal_copper_axe","metal_copper_pickaxe","metal_copper_shovel","metal_copper_hammer","metal_fishing_rod","metal_silver_lantern"]:
		s.craft_station_id="metal"
		var output: String=s.craft_book.recipe(id).output_id
		var before_output: int=s.inventory.count_item(output)
		check(s.start_craft(id,1).is_empty(),"start current metal crafting "+id)
		s.advance_craft(1.5)
		check(s.inventory.count_item(output)==before_output+int(s.craft_book.recipe(id).output_count),"atomic current metal crafting output "+id)
	s.craft_station_id=""
	for id in ["copper_axe","copper_pickaxe","copper_shovel","copper_hammer"]:
		check(s.database.item(id).durability==250,"250 durability "+id)
		check(s.database.item(id).stats.labor_speed>1.0,"labor speed improves "+id)
	var rod: Dictionary=s.inventory.instance("fishing_rod")
	s.inventory.slots[0]=rod;check(s.inventory.equip(0),"fishing rod equips via hotbar alias")
	check(s.inventory.has_capability("fishing_ready") and not s.inventory.has_capability("mine"),"rod reserves interface without mining")
	s.inventory.equipment.clear();s.inventory.hotbar_equipment.clear()
	stock()
	check(cmd("oven","fuel",0,"wood",2).is_empty(),"oven shared fuel added")
	check(cmd("oven","ignite").is_empty(),"manual oven ignition")
	for i in 4:check(cmd("oven","start",i,"",1,{"wild_carrot":1}).is_empty(),"independent oven slot "+str(i))
	check(cmd("oven","start",0,"",1,{"wild_carrot":1}).is_empty() and s.builds.states.oven.machine.queue.size()==1,"occupied oven slot admits one paid queued job")
	var slots: Array=s.inventory.slots.duplicate(true)
	check(cmd("oven","start",3,"",1,{"stone":1}).length()>0 and s.inventory.slots==slots,"bad recipe never consumes")
	s.industry.advance(6,2.4)
	check(s.builds.states.oven.machine.jobs.all(func(j):return j.elapsed==6),"all four independent jobs advance")
	check(s.builds.states.oven.machine.fuel==234,"one fuel supply burns once for four jobs")
	s.builds.states.oven.machine.fuel=0
	s.industry.advance(8,3.2)
	check(s.builds.states.oven.machine.jobs[0].elapsed==6,"oven pauses without losing progress")
	cmd("oven","fuel",0,"wood");cmd("oven","ignite");s.industry.advance(6,2.4)
	check(s.builds.states.oven.machine.completed.size()==4,"four parallel jobs move to output tray")
	var carrot_before: int=s.inventory.count_item("roasted_carrot")
	check(cmd("oven","claim_all").is_empty() and s.inventory.count_item("roasted_carrot")==carrot_before+4,"one claim collects four independent products")
	s.industry.advance(12,4.8)
	check(cmd("oven","claim_all").is_empty() and s.inventory.count_item("roasted_carrot")==carrot_before+5,"queued fifth product completes exactly once")
	check(s.builds.states.oven.machine.jobs.all(func(j):return j.is_empty()),"claimed slots return empty")
	check(s.industry.oven_recipe({"wild_carrot":1})=="roast_carrot","real recipe wins over fallback")
	check(s.industry.oven_recipe({"wild_carrot":2})=="oven_small_hodgepodge","two total ingredients make small hodgepodge")
	check(s.industry.oven_recipe({"wild_carrot":3})=="oven_large_hodgepodge","three quantities of one ingredient make large hodgepodge")
	check(s.industry.oven_recipe({}).is_empty() and s.industry.oven_recipe({"stone":1}).is_empty() and s.industry.oven_recipe({"wild_carrot":-1}).is_empty(),"fallback rejects empty nonfood and negative quantities")
	for spec in [[2,"small_hodgepodge",6],[3,"large_hodgepodge",12]]:
		var initial_count: int=s.inventory.count_item("wild_carrot")
		check(cmd("oven","start",0,"",1,{"wild_carrot":spec[0]}).is_empty(),"start "+spec[1])
		check(s.inventory.count_item("wild_carrot")==initial_count-spec[0],"fallback pays exact ingredient quantity "+spec[1])
		s.industry.advance(18,7.2)
		check(s.builds.states.oven.machine.completed.size()==1 and s.builds.states.oven.machine.completed[0].output.item_id==spec[1],"fallback output completes "+spec[1])
		var claim_slots: Array=s.inventory.slots.duplicate(true)
		for i in 40:s.inventory.slots[i]={"item_id":"stone","count":int(s.database.item("stone").max_stack)}
		check(not cmd("oven","claim").is_empty() and s.builds.states.oven.machine.completed.size()==1,"full inventory preserves ready "+spec[1])
		s.inventory.slots.assign(claim_slots)
		check(cmd("oven","claim").is_empty(),"claim "+spec[1])
		check(s.database.item(spec[1]).effects.hunger==spec[2] and s.database.item(spec[1]).effects.get("health",0)==0,"only hunger benefit "+spec[1])
	check(s.builds.states.lamp.machine.enabled,"copper lamp starts on")
	check(cmd("lamp","toggle").is_empty() and not s.builds.states.lamp.machine.enabled,"copper lamp toggles off without removal")
	check(cmd("lamp","fuel",0,"wood").length()>0,"standing lamp never accepts fuel")
	var food := {"item_id":"roasted_carrot","count":4,"spoilage":.5}
	s.inventory.slots[0]=food
	check(s.inventory.split_slot(0,2)>=8,"cooked stack splits")
	check(s.inventory.slots[0].spoilage==.5,"split preserves source fraction")
	var first: Dictionary=s.inventory.slots[0].duplicate(true)
	s.inventory.slots[1]={"item_id":"roasted_carrot","count":1,"spoilage":.1}
	s.inventory.move_slot(0,1)
	check(s.inventory.slots[0].spoilage==.1 and s.inventory.slots[1].spoilage==.5,"different freshness swaps without refreshing")
	check(Fresh.matches(first,{"item_id":"roasted_carrot","count":2,"spoilage":.51}),"aging does not invalidate drag identity")
	s.inventory.slots[2]={"item_id":"roasted_carrot","count":1,"spoilage":.5}
	check(s.builds.transfer("fridge",0,2,{},s.inventory.slots[2].duplicate(true)).is_empty(),"cooked food enters fridge")
	var external: Dictionary=s.builds.states.fridge.contents[0].duplicate(true)
	Fresh.advance(s.database,external,1440)
	Fresh.advance(s.database,s.builds.states.fridge.contents[0],1440,true)
	check(is_equal_approx(external.spoilage,.9),"ambient life is 2.5 days")
	check(is_equal_approx(s.builds.states.fridge.contents[0].spoilage,.5+1.0/7),"fridge preserves remaining ratio over seven days")
	s.inventory.slots[2]={"item_id":"stone","count":1}
	check(not s.builds.transfer("fridge",1,2,{},s.inventory.slots[2]).is_empty(),"fridge rejects nonfood")
	for id in s.database.ids():
		if s.database.item(id).get("food_kind")=="raw":
			var raw: Dictionary={"item_id":id,"count":1};Fresh.advance(s.database,raw,999999)
			check(not raw.has("spoilage"),"raw food never rots "+id)
	var legacy := ItemInventory.new(s.database);var old: Array=[]
	for i in 40:old.append({})
	old[8]={"item_id":"roasted_carrot","count":2}
	check(legacy.restore(old) and legacy.slots[8].spoilage==0,"legacy cooked food safely starts fresh")
	old[8].spoilage=-.1;check(not legacy.restore(old),"invalid negative spoilage rejected")
	old[8].spoilage=1.1;check(not legacy.restore(old),"out of range spoilage rejected")
	s.inventory.slots[3]={"item_id":"roasted_carrot","count":1,"spoilage":1.0};s.body.hunger=30;s.body.health=90
	check(s.inventory.use_slot(3),"rotten cooked food remains edible")
	check(is_equal_approx(s.body.hunger,30+float(s.database.item("roasted_carrot").effects.hunger)*.25) and s.body.health==85,"rotten meal gives quarter hunger and minus five health")
	check(s.body.discomfort>2.9 and s.body.discomfort<=3,"discomfort feedback is short and independent")
	check(cmd("trough","feed",0,"wild_berry",3).is_empty(),"trough accepts preferred feed")
	check(cmd("trough","take").length()>0,"trough has no withdrawal operation")
	check(cmd("trough","feed",0,"stone").length()>0,"trough rejects unsuitable material")
	var animal: Dictionary=s.animals.make_row("chicken",Vector2(s.builds.states.trough.x,s.builds.states.trough.y),true);animal.fed_until=0
	s.animals.states["test:chicken"]=animal
	s.industry.auto_feed()
	check(s.builds.states.trough.machine.feed.wild_berry==2 and s.animals.good(s.animals.states["test:chicken"]),"one feed renews tamed animal nutrition")
	s.industry.auto_feed();check(s.builds.states.trough.machine.feed.wild_berry==2,"already fed animal never consumes twice")
	var before_feed: Dictionary=s.builds.states.trough.duplicate(true)
	s.animals.states["test:chicken"].fed_until=0;s.save_path="res://reports/industry-v1/missing/invalid.json"
	s.industry.auto_feed()
	check(s.builds.states.trough==before_feed and s.animals.states["test:chicken"].fed_until==0,"failed automatic feeding rolls back food and animal")
	s.save_path=old_path
	s.animals.states["test:chicken"].x+=600
	# Force a partial pickup and failed second pickup to exercise metadata conservation.
	var saved_slots: Array=s.inventory.slots.duplicate(true)
	for i in 40:s.inventory.slots[i]={"item_id":"stone","count":int(s.database.item("stone").max_stack)}
	var food_limit: int=int(s.database.item("roasted_carrot").max_stack)
	s.inventory.slots[8]={"item_id":"roasted_carrot","count":food_limit-1,"spoilage":.4}
	var drop_row := {"id":"test:food","item_id":"roasted_carrot","count":3,"x":w.player.position.x,"y":w.player.position.y,"instance":{"item_id":"roasted_carrot","count":3,"spoilage":.4}}
	s.loose[drop_row.id]=drop_row;var drop: Node2D=w.stream.create_item_drop(drop_row)
	check(s.pickup(drop),"partially full inventory takes available food quantity")
	check(s.loose[drop_row.id].count==2 and s.loose[drop_row.id].instance.count==2 and s.loose[drop_row.id].instance.spoilage==.4,"partial pickup preserves remainder quantity and freshness")
	s.inventory.slots[9]={};s.save_path="res://reports/industry-v1/missing/invalid.json"
	check(not s.pickup(drop) and s.inventory.slots[9].is_empty() and s.loose[drop_row.id].count==2,"pickup save failure restores loose food and inventory")
	s.save_path=old_path;Fresh.advance(s.database,s.loose[drop_row.id].instance,360)
	check(s.pickup(drop) and is_equal_approx(s.inventory.slots[9].spoilage,.5),"aged dropped food returns without resetting freshness")
	s.inventory.slots.assign(saved_slots)
	var carpet: Dictionary=s.builds.candidate("wool_carpet",w.player.position+Vector2(0,160),false,false,0)
	check(s.builds.reason(carpet)=="需要已有地板","carpet rejects natural ground")
	var floor_row: Dictionary=s.builds.candidate("wood_floor",Vector2(carpet.x,carpet.y),false,false,0);s.builds.states["floor"]=floor_row
	check(s.builds.occupant(carpet).is_empty(),"carpet overlay never conflicts with base floor")
	s.builds.states["carpet"]=carpet
	check(s.builds.protected_reason("floor")=="请先拆除地毯","base floor protected against floating carpet")
	s.inventory.equipment.main_hand=s.inventory.instance("copper_axe")
	var held_before: Dictionary=s.inventory.equipment.main_hand.duplicate(true)
	s.inventory.slots[0]={"item_id":"silver_lantern","count":1}
	check(not s.inventory.equip(0),"silver lantern does not equip")
	check(s.inventory.use_slot(0),"silver lantern uses original inventory light action")
	check(s.lantern.visible and s.lamp_slot().fuel==3600 and s.inventory.equipment.main_hand==held_before,"silver light starts full without replacing held tool")
	s.burn_lantern(1800)
	w.item_ui.body_ui._process(0)
	check(is_equal_approx(w.item_ui.body_ui.fuel.value,50),"silver fuel HUD uses its own lifetime")
	check(w.item_ui.body_ui.lamp_icon.texture==s.texture("silver_lantern","icon"),"fuel HUD shows active silver icon")
	s.inventory.use_slot(0);check(not s.lantern.visible,"second use switches silver light off")
	s.inventory.use_slot(0);check(s.lantern.visible and s.lamp_slot().fuel==1800,"using again preserves fuel")
	s.lamp_slot().fuel=.1
	s.burn_lantern(.2)
	check(s.inventory.slots[0].is_empty() and s.inventory.equipment.main_hand==held_before and not s.lantern.visible,"expired silver light removes only its inventory item")
	check(cmd("oven","start",3,"",1,{"wild_carrot":3}).is_empty(),"fallback job stored for separate process restore")
	if "formal" in OS.get_cmdline_user_args():
		w.environment_view.preview=false;w.environment_view.simulation.paused=false
		var elapsed: float=s.builds.states.oven.machine.jobs[3].elapsed
		w.environment_view.advance_gameplay(.1)
		check(s.builds.states.oven.machine.jobs[3].elapsed>elapsed,"ordinary world clock advances industrial jobs without preview flag")
		elapsed=s.builds.states.oven.machine.jobs[3].elapsed
		w.environment_view.simulation.paused=true;w.environment_view.advance_gameplay(.1)
		check(s.builds.states.oven.machine.jobs[3].elapsed==elapsed,"paused world does not advance industrial jobs")
	# Save known state for a separate-process restore, without touching player saves.
	s.builds.states.fridge.contents[0].spoilage=.5;s.inventory.slots[39]={"item_id":"roasted_carrot","count":2,"spoilage":1.0}
	check(s.save_state(),"atomic fixture snapshot saves")
	var seen := {};check(s.builds.validate(s.builds.serialize(),seen),"complete building snapshot validates")
	if "window" in OS.get_cmdline_user_args():
		s.industry_ui.open("oven");await frames(8)
		var oven_size: Vector2=s.industry_ui.panel.size
		check(s.industry_ui.visible and s.industry_ui.slot_buttons.size()==4,"oven opens four row UI")
		for i in range(1,4):check(s.industry_ui.slot_buttons[i].global_position.y>s.industry_ui.slot_buttons[i-1].global_position.y,"oven rows vertically ordered "+str(i))
		root.get_texture().get_image().save_png(OUT+"oven-window.png")
		s.industry_ui.slot_buttons[0].pressed.emit();await frames(8)
		check(s.industry_ui.ingredient_window.visible and s.industry_ui.panel.size==oven_size,"plus opens separate ingredient window without expanding oven")
		var before_cancel: Array=s.inventory.slots.duplicate(true)
		root.get_texture().get_image().save_png(OUT+"oven-ingredients.png")
		s.industry_ui.ingredient_window.hide();await frames()
		check(s.inventory.slots==before_cancel and s.industry_ui.selected_slot==-1,"cancel ingredient window consumes nothing")
		s.industry_ui.slot_buttons[1].pressed.emit();await frames()
		s.industry_ui.ingredient_choices[0].select(s.industry_ui.ingredient_ids.find("wild_carrot")+1)
		s.industry_ui.cook.pressed.emit();await frames()
		check(not s.industry_ui.ingredient_window.visible and not s.builds.states.oven.machine.jobs[1].is_empty(),"ingredient confirmation starts selected slot and closes popup")
		s.industry_ui.close_panel();s.storage_ui.open("cabinet");await frames(8);root.get_texture().get_image().save_png(OUT+"cabinet-window.png")
		s.storage_ui.close_panel();w.item_ui.toggle_craft();await frames(8);root.get_texture().get_image().save_png(OUT+"craft-window.png")
		w.item_ui.close_panels();w.player.set_process(false)
		var contact := Image.create(1440,800,false,Image.FORMAT_RGBA8)
		var tool_ids := ["copper_axe","copper_pickaxe","copper_shovel","copper_hammer","fishing_rod"]
		for column in tool_ids.size():
			s.inventory.equipment.main_hand=s.inventory.instance(tool_ids[column])
			for direction in 4:
				w.player.facing=["front","back","left","right"][direction];w.player.action="";w.player.update_animation();await frames(3)
				var config: Dictionary=w.player.held_tool.definitions["tool:"+tool_ids[column]]
				var tex: Texture2D=load(config.texture)
				check(tex.get_image().get_pixel(int(config.grip_px[0]),int(config.grip_px[1])).a>.9,"hand anchor touches tool "+tool_ids[column]+str(direction))
				contact.blit_rect(root.get_texture().get_image(),Rect2i(520,220,240,200),Vector2i(column*240,direction*200))
		contact.save_png(OUT+"tools-contact.png")
	await finish()
