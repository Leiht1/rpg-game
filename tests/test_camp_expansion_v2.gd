extends SceneTree
const OUT="res://reports/camp-expansion-v2/"
const SAVE=OUT+"isolated-save.json"
const Fresh=preload("res://scripts/food_freshness.gd")
var w: Node
var s: Node
var checks: Array=[]
var original: Dictionary={}
var events: Array=[]
var home := Vector2.ZERO
var ids := {}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
	print("CHECK ",ok," ",label)
func files() -> Dictionary:
	var result := {}
	for n in DirAccess.get_files_at("user://"):
		if n.ends_with(".json") or n.ends_with(".tmp"):result[n]=FileAccess.get_sha256("user://"+n)
	return result
func frames(n: int=3) -> void:
	for i in n:await process_frame
func near(id: String) -> void:
	var row: Dictionary=s.builds.states[id]
	w.player.position=Vector2(row.x,row.y)+Vector2(0,70);w.player.camera.reset_smoothing();w.stream.update_target(w.player.position)
	await frames(4)
func legal(kind: String) -> Dictionary:
	for y in range(-400,401,32):
		for x in range(-500,501,32):
			var p := home+Vector2(x,y)
			w.player.position=p+Vector2(0,72)
			if not w.generator.can_walk(w.player.position,12):continue
			var row: Dictionary=s.builds.candidate(kind,p,false,false,0)
			if s.builds.reason(row).is_empty():return row
	return {}
func fill() -> void:
	for i in 40:s.inventory.slots[i]={}
	s.inventory.equipment={};s.inventory.hotbar_equipment={}
	for id in ["wood","stone","flint","plant_fiber","copper_parts","copper_plate","metal_connector","silver_ingot"]:s.inventory.add(id,99)
func capture(name_value: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_value+".png")
func run() -> void:
	original=files();Engine.set_meta("integration_seed",271828);Engine.set_meta("camp_expansion_preview",true)
	if "preview" in OS.get_cmdline_user_args():
		w=load("res://scenes/camp_expansion_preview.tscn").instantiate();root.add_child(w)
		while not w.started or w.volume_label==null:await process_frame
		s=w.item_service
		check(not w.persistent_world,"candidate preview disables all player save IO")
		check(w.demonstration_ids.size()==26,"preview places all twenty-six registered buildings")
		check(s.builds.validate(s.builds.serialize(),{}),"preview building records validate")
		check(s.inventory.count_item("carrot_seed")==6,"preview crop supplies")
		await frames(25);await capture("overview")
		w.environment_view.set_process(false);w.player.set_physics_process(false);s.set_process(false);s.animals.set_process(false)
		for demo_id in w.demonstration_ids:
			var row: Dictionary=s.builds.states[demo_id];var node: Node2D=s.builds.visuals[demo_id]
			if row.kind in s.expansion.KINDS:
				await near(demo_id)
				check(node.shape.shape.size==s.builds.footprint_rect(row).size,"candidate "+row.kind+" collider matches its individual base")
				check(node.perform_interaction("open",w.player) and s.expansion_ui.visible,"candidate "+row.kind+" opens through world interaction")
				await frames(8);await capture(row.kind+"-ui");s.expansion_ui.close_panel()
			if row.kind in ["wood_bed","straw_mat"]:
				await near(demo_id);s.body.energy=70
				check(s.sleep.start(demo_id).is_empty() and s.body.sleep_active(),row.kind+" still accepts sleep in candidate camp")
				s.sleep.interrupt();check(not s.body.sleep_active() and s.builds.states[demo_id].sleep_state=="PLACED",row.kind+" wakes with original lifecycle")
		w.item_ui.toggle_build();w.item_ui.craft_panel.select_recipe("build_advanced_smokehouse");await frames(8)
		check(w.item_ui.craft_panel.recipe_buttons.has("build_advanced_smokehouse"),"V panel contains candidate smokehouse from start")
		await capture("build-list");w.item_ui.close_panels()
		await finish("preview");return
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;w.set_process(false);w.environment_view.set_process(false);w.player.set_physics_process(false);s.set_process(false);s.animals.set_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	home=w.player.position
	s.item_obtained.connect(func(id,count):events.append([id,count]))
	s.save_path=SAVE;w.persistent_world=true
	if "read" in OS.get_cmdline_user_args():
		s.load_state()
		check(s.writable,"independent process restores expansion snapshot")
		check(s.builds.states.restart_compost.expansion.job.ready,"independent process retains ready fertilizer")
		check(s.builds.states.restart_smoker.expansion.job.minutes==20,"independent process retains smoked fish partial progress")
		check(s.builds.states.restart_supply.expansion.fuel_items.wood==4,"independent process retains actual fuel stock")
		check(s.builds.states.restart_plot.fertilized,"independent process retains seasonal fertilizer flag")
		check(s.inventory.slots.any(func(v):return v.get("item_id","")=="smoked_fish" and v.spoilage==.3),"independent process retains smoked fish freshness")
		await finish("read");return
	check(s.database.errors.is_empty() and s.camps.build_book.errors.is_empty(),"items and build recipes validate")
	var before_old: Dictionary=s.builds.serialize()
	check(s.builds.validate(before_old,{}),"existing building snapshot remains valid without expansion fields")
	fill()
	for kind in s.expansion.KINDS:
		var recipe: Dictionary=s.camps.build_book.recipe("build_"+kind)
		check(recipe.default_unlocked and recipe.conditions.is_empty(),kind+" has no unlock or facility prerequisites")
		check(s.camps.build_book.available().any(func(r):return r.output_id==kind),kind+" visible from preview start without resources gate")
		check(recipe.materials==s.builds.definitions[kind].cost,kind+" build cost has one consistent value")
		var row := legal(kind)
		check(not row.is_empty(),kind+" legal site exists")
		if row.is_empty():continue
		var slots: Array=s.inventory.slots.duplicate(true);var buildings: Dictionary=s.builds.states.duplicate(true)
		s.inventory.slots[8].count-=1
		check(s.builds.place(row,slots).begins_with("背包已变化") and s.builds.states==buildings,kind+" real inventory change prevents placement")
		s.inventory.slots=slots.duplicate(true)
		var blocked: Dictionary=row.duplicate(true);blocked.x=w.player.position.x;blocked.y=w.player.position.y
		check(not s.builds.place(blocked,slots).is_empty() and s.inventory.slots==slots and s.builds.states==buildings,kind+" invalid position consumes nothing")
		w.camp_ui.begin_build("build_"+kind);w.camp_ui.cancel_placement()
		check(s.inventory.slots==slots and s.builds.states==buildings,kind+" entering/cancelling placement costs nothing")
		s.save_path=OUT+"missing/save.json"
		check(s.builds.place(row,slots).begins_with("保存失败"),kind+" placement reaches atomic save failure")
		check(s.inventory.slots==slots and s.builds.states==buildings,kind+" placement rolls back building and materials")
		s.save_path=SAVE
		check(s.builds.place(row,slots).is_empty(),kind+" legal placement commits")
		for key in recipe.materials:check(s.inventory.count_item(key)==99-int(recipe.materials[key]),kind+" pays "+key)
		for id in s.builds.states:
			if s.builds.states[id].kind==kind:ids[kind]=id
		fill();await frames(3)
	check(ids.size()==4,"all four functional buildings placed through original V transaction")
	if ids.size()!=4:await finish("failed-sites");return
	var bench: String=ids.precision_repair_bench
	await near(bench)
	for tool in s.expansion.rules.repairs:
		fill();var value: Dictionary=s.inventory.instance(tool);value.durability=1;s.inventory.slots[0]=value
		var before: Array=s.inventory.slots.duplicate(true)
		s.save_path=OUT+"missing/save.json"
		check(s.expansion.act(bench,"repair",0,value.duplicate(true)).begins_with("保存失败"),tool+" repair save failure")
		check(s.inventory.slots==before,tool+" repair restores exact instance and payment")
		s.save_path=SAVE;var identity: String=value.instance_id
		check(s.expansion.act(bench,"repair",0,s.inventory.slots[0].duplicate(true)).is_empty(),tool+" repair succeeds")
		check(s.inventory.slots[0].durability==s.database.item(tool).durability and s.inventory.slots[0].instance_id==identity,tool+" restored to max with same instance")
		for key in s.expansion.repair_cost(value):check(s.inventory.count_item(key)==98,tool+" repair material consumed")
		check(not s.expansion.act(bench,"repair",0,s.inventory.slots[0].duplicate(true)).is_empty(),tool+" full tool rejects repair")
		var craft: Dictionary={}
		for r in s.craft_book.recipes.values():
			if r.output_id==tool:craft=r.materials
		check(not craft.is_empty() and craft!=s.expansion.repair_cost(value),tool+" repair uses less than complete recipe")
	fill();var vanished: Dictionary=s.inventory.instance("fishing_rod");vanished.durability=1
	check(not s.expansion.act(bench,"repair",0,vanished).is_empty(),"missing destroyed instance cannot be recreated")
	var held: Dictionary=s.inventory.instance("copper_axe");held.durability=4;s.inventory.equipment.main_hand=held;s.inventory.hotbar_equipment["0"]=held.instance_id
	check(s.expansion.act(bench,"repair",0,held.duplicate(true)).is_empty(),"equipped hotbar alias repairs original instance")
	check(s.inventory.equipment.main_hand.durability==250 and s.inventory.slots[0].is_empty(),"repair creates no duplicate equipped tool")
	s.inventory.equipment.main_hand.durability=4
	s.expansion_ui.open(bench);await frames(5);await capture("repair-ui")
	var repair_button: Button=s.expansion_ui.choices.get_child(0)
	Input.warp_mouse(repair_button.get_global_rect().get_center());await frames(2)
	var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.position=repair_button.get_global_rect().get_center();click.pressed=true;Input.parse_input_event(click);await frames(2)
	click=click.duplicate();click.pressed=false;Input.parse_input_event(click);await frames(3)
	if DisplayServer.get_name()!="headless":check(s.inventory.equipment.main_hand.durability==250,"native repair panel mouse click repairs selected instance")
	s.expansion_ui.close_panel()
	fill();var box: String=ids.fuel_supply_box
	await near(box)
	var deposit_slots: Array=s.inventory.slots.duplicate(true);s.save_path=OUT+"missing/save.json"
	check(s.expansion.act(box,"deposit",-1,{},"wood",4).begins_with("保存失败") and s.inventory.slots==deposit_slots and s.builds.states[box].expansion.fuel_items.is_empty(),"fuel deposit save failure rolls back both sides")
	s.save_path=SAVE
	check(not s.expansion.act(box,"deposit",-1,{},"stone",1).is_empty(),"supplier rejects noncombustible material")
	check(s.expansion.act(box,"deposit",-1,{},"wood",4).is_empty(),"fuel supply stores real wood")
	check(s.inventory.count_item("wood")==95 and s.builds.states[box].expansion.fuel_items.wood==4,"fuel transfer conserves inventory")
	var p: Vector2=Vector2(s.builds.states[box].x,s.builds.states[box].y)
	for pair in [["test_furnace","stone_furnace",Vector2(110,0)],["test_oven","copper_oven",Vector2(-110,0)],["distant_oven","copper_oven",Vector2(400,0)],["other_machine","metal_workbench",Vector2(0,110)]]:
		s.builds.states[pair[0]]=s.builds.candidate(pair[1],p+pair[2],false,false,0)
	var buildings_before: Dictionary=s.builds.states.duplicate(true)
	s.save_path=OUT+"missing/save.json";s.expansion.supply()
	check(s.builds.states==buildings_before,"automatic supply save failure rolls back all suppliers and recipients")
	s.save_path=SAVE;s.expansion.supply()
	check(s.builds.states.test_furnace.machine.fuel==120 and s.builds.states.test_oven.machine.fuel==120,"nearby furnace and oven each receive paid fuel")
	check(not s.builds.states.test_furnace.machine.enabled and not s.builds.states.test_oven.machine.enabled,"supply never ignites either machine")
	check(s.builds.states.distant_oven.machine.fuel==0 and s.builds.states.other_machine.machine.fuel==0,"range and station whitelist enforced")
	check(s.builds.states[box].expansion.fuel_items.wood==2,"each recipient consumes one actual stored item")
	s.builds.states.test_furnace.machine.fuel=5;s.builds.states.test_furnace.machine.enabled=true
	s.industry.advance(.1,.1)
	check(s.builds.states.test_furnace.machine.enabled and s.builds.states.test_furnace.machine.fuel>120,"fuel supply preserves an already burning machine through low fuel")
	await near(box)
	var inv_before: Array=s.inventory.slots.duplicate(true);buildings_before=s.builds.states.duplicate(true)
	s.save_path=OUT+"missing/save.json"
	check(not s.expansion.act(box,"withdraw",-1,{},"wood",1).is_empty() and s.inventory.slots==inv_before and s.builds.states==buildings_before,"fuel withdrawal rejection changes nothing")
	s.save_path=SAVE
	check(not s.expansion.act(box,"withdraw",-1,{},"wood",1).is_empty(),"deposited fuel cannot be reclaimed")
	for id in ["test_furnace","test_oven","distant_oven","other_machine"]:s.builds.states.erase(id)
	fill();var compost: String=ids.compost_bin;await near(compost)
	s.inventory.slots[0]={"item_id":"lake_fish","count":3,"spoilage":1.0}
	check(s.expansion.compost_allowed(s.inventory.slots[0]),"rotten fish accepted")
	check(not s.expansion.compost_allowed({"item_id":"lake_fish","count":3,"spoilage":.9}),"fresh fish rejected by composter")
	check(s.expansion.compost_allowed({"item_id":"roasted_fish","count":3,"spoilage":1.0}),"rotten cooked food accepted")
	check(not s.expansion.compost_allowed({"item_id":"stone","count":3}),"inorganic items rejected")
	inv_before=s.inventory.slots.duplicate(true);buildings_before=s.builds.states.duplicate(true);s.save_path=OUT+"missing/save.json"
	check(s.expansion.act(compost,"process",0,s.inventory.slots[0].duplicate(true)).begins_with("保存失败") and inv_before==s.inventory.slots and buildings_before==s.builds.states,"compost input and process roll back on save failure")
	s.save_path=SAVE
	check(s.expansion.act(compost,"process",0,s.inventory.slots[0].duplicate(true)).is_empty() and s.inventory.slots[0].is_empty(),"three rotten fish start one batch")
	s.expansion.advance(719);check(not s.builds.states[compost].expansion.job.ready,"compost not ready before twelve normal game hours")
	check(not s.builds.protected_reason(compost).is_empty(),"in-progress process cannot be demolished")
	s.expansion.advance(1);check(s.builds.states[compost].expansion.job.ready,"compost becomes fertilizer after normal gameplay time")
	var event_count := events.size();s.save_path=OUT+"missing/save.json"
	check(s.expansion.act(compost,"claim").begins_with("保存失败") and s.builds.states[compost].expansion.job.ready and events.size()==event_count,"fertilizer claim failure preserves output and no false event")
	s.save_path=SAVE
	check(s.expansion.act(compost,"claim").is_empty() and s.inventory.count_item("compost_fertilizer")==1,"fertilizer enters original inventory")
	check(events.size()==event_count+1 and events.back()==["compost_fertilizer",1],"fertilizer uses obtained queue only after commit")
	check(not s.expansion.act(compost,"claim").is_empty(),"fertilizer duplicate claim refused")
	var plot: Dictionary=s.builds.candidate("tilled_soil",p+Vector2(0,160),false,false,0);plot.crop="carrot"
	s.builds.states["test_plot"]=plot;s.builds.install(w.stream.chunk_at(Vector2(plot.x,plot.y)));await near("test_plot")
	inv_before=s.inventory.slots.duplicate(true);s.save_path=OUT+"missing/save.json"
	check(s.expansion.act("test_plot","fertilize").begins_with("保存失败") and not s.builds.states.test_plot.get("fertilized",false) and s.inventory.slots==inv_before,"fertilizer effect and item roll back")
	s.save_path=SAVE
	check(s.expansion.act("test_plot","fertilize").is_empty(),"fertilizer applies to current growing crop")
	check(not s.expansion.act("test_plot","fertilize").is_empty(),"same crop cannot stack fertilizer")
	s.planting.advance(100);check(s.builds.states.test_plot.growth_minutes==125,"fertilized crop grows 25 percent faster")
	s.builds.states.test_plot.growth_minutes=2880
	w.player.position=Vector2(plot.x,plot.y)+Vector2(0,35);await frames(3)
	var crop_before: int=s.inventory.count_item("wild_carrot")
	check(s.planting.interact("test_plot",s.builds.visuals.test_plot) and s.inventory.count_item("wild_carrot")==crop_before+4 and not s.builds.states.test_plot.has("fertilized"),"harvest retains original yield and clears seasonal fertilizer")
	fill();var smoker: String=ids.advanced_smokehouse;await near(smoker)
	s.inventory.slots[0]={"item_id":"roasted_fish","count":2,"spoilage":1.0}
	check(not s.expansion.act(smoker,"process").is_empty(),"smokehouse rejects rotten fish")
	s.inventory.slots[0].spoilage=.2;inv_before=s.inventory.slots.duplicate(true);buildings_before=s.builds.states.duplicate(true);s.save_path=OUT+"missing/save.json"
	check(s.expansion.act(smoker,"process").begins_with("保存失败") and s.inventory.slots==inv_before and s.builds.states==buildings_before,"smokehouse roasted fish and wood roll back")
	s.save_path=SAVE
	check(s.expansion.act(smoker,"process").is_empty() and s.inventory.count_item("roasted_fish")==1 and s.inventory.count_item("wood")==98,"smoking consumes exactly one non-rotten roasted fish and one wood")
	s.expansion.advance(119);check(not s.builds.states[smoker].expansion.job.ready,"smoked fish waits for normal two game hours")
	s.expansion.advance(1);check(s.builds.states[smoker].expansion.job.ready,"smokehouse produces smoked fish")
	var preserved: Array=s.inventory.slots.duplicate(true)
	for i in 40:s.inventory.slots[i]={"item_id":"wood","count":99}
	check(not s.expansion.act(smoker,"claim").is_empty() and s.builds.states[smoker].expansion.job.ready,"full inventory preserves smoked fish")
	s.inventory.slots=preserved;event_count=events.size()
	s.save_path=OUT+"missing/save.json"
	check(s.expansion.act(smoker,"claim").begins_with("保存失败") and s.inventory.slots==preserved and s.builds.states[smoker].expansion.job.ready and events.size()==event_count,"smoked fish claim save failure rolls back without notification")
	s.save_path=SAVE
	check(s.expansion.act(smoker,"claim").is_empty() and s.inventory.count_item("smoked_fish")==1,"smoked fish claims into original inventory")
	check(events.size()==event_count+1 and events.back()==["smoked_fish",1],"smoked fish sends one obtained event")
	var smoked := {"item_id":"smoked_fish","count":1,"spoilage":0.0};var roasted := {"item_id":"roasted_fish","count":1,"spoilage":0.0}
	Fresh.advance(s.database,smoked,3600);Fresh.advance(s.database,roasted,3600)
	check(Fresh.rotten(roasted) and not Fresh.rotten(smoked),"smoked fish lasts longer than roasted fish")
	var chilled := {"item_id":"smoked_fish","count":1,"spoilage":0.0};Fresh.advance(s.database,chilled,8*1440,true)
	check(not Fresh.rotten(chilled),"smoked fish chilled shelf life exceeds ambient thirty days")
	Fresh.advance(s.database,smoked,30*1440);check(Fresh.rotten(smoked) and Fresh.effects(s.database,smoked).health==-5,"smoked fish retains existing rotten food effects")
	for diagnostic_id in s.builds.states:
		var diagnostic: Dictionary=s.builds.serialize();diagnostic.objects={diagnostic_id:s.builds.states[diagnostic_id].duplicate(true)}
		if not s.builds.validate(diagnostic,{}):print("INVALID ROW ",diagnostic_id," ",diagnostic.objects)
	check(s.builds.validate(s.builds.serialize(),{}),"all new live building states validate")
	var damaged: Dictionary=s.builds.serialize();damaged.objects[smoker].expansion.job={"minutes":NAN,"ready":true,"output":{"item_id":"smoked_fish","count":1}}
	check(not s.builds.validate(damaged,{}),"invalid process state rejected")
	for kind in ["wood_fence","fence_gate","stone_wall","stone_gate","wood_bed","straw_mat","sleeping_bag"]:
		check(s.builds.volume_profile(kind).is_empty(),kind+" connection or sleep geometry unchanged")
	for kind in s.builds.volume_profiles:
		var row: Dictionary=s.builds.candidate(kind,home,false,false,0)
		var node := preload("res://scripts/camp_building.gd").new();node.manager=s.builds;node.building_id="volume-test";s.builds.states["volume-test"]=row
		var def: Dictionary=s.builds.definitions[kind]
		var image: Texture2D=preload("res://scripts/candidate_art.gd").texture(def.art) if str(def.get("art","")).begins_with("res://prototypes/") else load(def.art) if def.has("art") else load("res://assets/buildings/signpost_v1/signpost.png") if kind=="signpost" else node.texture(int(def.frame))
		check(image!=null and node.volume_rect(image,s.builds.volume_profile(kind)).size.x<=float(s.builds.volume_profiles[kind].width)+.01,kind+" visible bounds obey independent profile")
		node.free();s.builds.states.erase("volume-test")
	check(s.builds.volume_profiles.wood_chest.width<80 and s.builds.volume_profiles.wool_carpet.width>96,"chest shrinks and carpet expands")
	Engine.set_meta("camp_expansion_preview",false)
	check(not s.builds.volume_profile("wood_chest").is_empty(),"formal mode uses approved volume profile")
	check(s.camps.build_book.available().filter(func(r):return r.output_id in s.expansion.KINDS).size()==4,"four approved facilities available in ordinary entry")
	Engine.set_meta("camp_expansion_preview",true)
	# Stable restart fixture stored in this report only.
	for id in ["restart_compost","restart_smoker","restart_supply","restart_plot"]:
		var kind := "compost_bin" if id=="restart_compost" else "advanced_smokehouse" if id=="restart_smoker" else "fuel_supply_box" if id=="restart_supply" else "tilled_soil"
		s.builds.states[id]=s.builds.candidate(kind,home+Vector2(800+ids.size()*96,500),false,false,0)
	s.builds.states.restart_compost.expansion.job={"minutes":720.0,"ready":true,"output":{"item_id":"compost_fertilizer","count":1}}
	s.builds.states.restart_smoker.expansion.job={"minutes":20.0,"ready":false,"output":{"item_id":"smoked_fish","count":1,"spoilage":0.0}}
	s.builds.states.restart_supply.expansion.fuel_items={"wood":4}
	s.builds.states.restart_plot.crop="carrot";s.builds.states.restart_plot.fertilized=true
	s.inventory.slots[0]={"item_id":"smoked_fish","count":1,"spoilage":.3}
	check(s.save_state(),"isolated restart snapshot saves")
	s.load_state();check(s.writable and s.builds.states.restart_supply.expansion.fuel_items.wood==4,"same-process snapshot round trip")
	await finish("headless" if DisplayServer.get_name()=="headless" else "window")
func finish(suffix: String) -> void:
	w.persistent_world=false;w.free();await frames(2)
	check(files()==original,"all actual player save hashes unchanged")
	var failed := checks.filter(func(c):return not c.pass)
	var file := FileAccess.open(OUT+suffix+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"));file.close()
	print("CAMP EXPANSION V2: ",checks.size()," checks, ",failed.size()," failed")
	quit(0 if failed.is_empty() else 1)
