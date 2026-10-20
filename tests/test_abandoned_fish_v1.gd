extends SceneTree
const OUT="res://reports/abandoned-fish-v1/"
const SAVE=OUT+"isolated-save.json"
const Ruins=preload("res://scripts/abandoned_camps.gd")
const Fresh=preload("res://scripts/food_freshness.gd")
var checks: Array=[]
var w: Node
var s: Node
var events: Array=[]
var original_files: Dictionary={}
func files() -> Dictionary:
	var result := {}
	for name in DirAccess.get_files_at("user://"):
		if name.ends_with(".json") or name.ends_with(".tmp"): result[name]=FileAccess.get_sha256("user://"+name)
	return result
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func _initialize() -> void: call_deferred("run")
func frames(n: int=3) -> void:
	for i in n: await process_frame
func write(value: Dictionary) -> void:
	var file := FileAccess.open(SAVE,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func travel(at: Vector2) -> void:
	w.player.position=at;w.player.camera.reset_smoothing();w.stream.update_target(at)
	while not w.stream.viewport_ready(at,Vector2(640,360)): await process_frame
	await frames(8)
func run() -> void:
	original_files=files()
	var args := OS.get_cmdline_user_args()
	Engine.set_meta("integration_seed",int(args[args.size()-1]) if "sites" in args else 271828)
	w=load("res://scenes/abandoned_fish_preview.tscn").instantiate() if "preview" in args else load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(w)
	while not w.started: await process_frame
	w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
	s=w.item_service;s.set_process(false);s.animals.set_process(false)
	await travel(w.player.position)
	if "preview" in args:
		check(not w.persistent_world,"preview disables all player save IO")
		check(s.inventory.count_item("lake_fish")==12 and s.inventory.count_item("cabbage")==12,"preview provides fish and cabbage")
		check(s.inventory.count_item("stone_hammer")==1 and s.inventory.count_item("fishing_rod")==1,"preview provides hammer and rod")
		var row: Dictionary=s.builds.states.get("abandoned:v1:0:0",{})
		check(not row.is_empty() and w.player.position.distance_to(Vector2(row.x,row.y))<100,"preview starts beside generated camp")
		check(s.save_state(),"preview save remains no-op")
		await finish([]);return
	s.save_path=SAVE;w.persistent_world=true
	s.item_obtained.connect(func(id,count):events.append([id,count]))
	if "read" in args:
		s.save_path=OUT+"restart-save.json";s.load_state()
		check(s.writable,"fresh process restores actual snapshot")
		check(not s.builds.states.has("abandoned:v1:0:0"),"fresh process chest stays demolished")
		check(not s.loose.has("abandoned:v1:0:0:contents:0"),"fresh process picked contents stay removed")
		check(s.camps.known("vegetable_fish_soup"),"fresh process retains discovery")
		check(s.inventory.slots.any(func(v):return v.get("item_id","")=="lake_fish" and v.has("spoilage")),"fresh process retains fish freshness")
		await finish([]);return
	check(s.database.errors.is_empty(),"item database validates")
	var groups := {}
	for id in s.builds.states:
		var row: Dictionary=s.builds.states[id]
		if not row.get("abandoned",false): continue
		var group: String=str(id).get_slice(":",2)
		if not groups.has(group): groups[group]=[]
		groups[group].append(id)
	check(groups.size()==3,"new world generates three grouped camps")
	var summaries := []
	for group in groups:
		var ids: Array=groups[group]
		check(ids.size()>=5,"multiple structures in camp "+group)
		var kinds := {};var center := Vector2.ZERO
		for id in ids:
			var row: Dictionary=s.builds.states[id];kinds[row.kind]=true
			center+=Vector2(row.x,row.y)
			check(w.generator.can_walk(Vector2(row.x,row.y),20),"dry land "+id)
		center/=ids.size()
		check(center.distance_to(w.generator.spawn)>1600,"spawn clearance "+group)
		check(kinds.has("wood_chest") and kinds.has("wood_fence") and kinds.size()>=3,"living camp and broken enclosure "+group)
		summaries.append({"group":group,"x":center.x,"y":center.y,"kinds":kinds.keys()})
	check(s.builds.validate(s.builds.serialize(),{}),"generated buildings and loot validate")
	if "sites" in args:
		for group in groups:
			var rows: Array[Dictionary]=[]
			for id in groups[group]:rows.append(s.builds.states[id])
			var chest_row: Dictionary=rows[0]
			var offset: Vector2=Vector2(-78,-18) if group=="0" else Vector2(76,10) if group=="1" else Vector2(-70,72)
			check(Ruins.site_clear(s,Vector2(chest_row.x,chest_row.y)-offset),"entire site clear and connected "+group)
			check(Ruins.resources_clear(s,rows),"resource and mineral clearance "+group)
		await finish(summaries);return
	check(s.save_state(),"generated camp snapshot saves")
	var generated: Dictionary= s.builds.states.duplicate(true)
	Ruins.generate(s);check(generated==s.builds.states,"generation cannot duplicate")
	var chest_id := "abandoned:v1:0:0"
	if not s.builds.states.has(chest_id): await finish(summaries);return
	var chest: Dictionary=s.builds.states[chest_id].duplicate(true)
	await travel(Vector2(chest.x,chest.y)+Vector2(0,52))
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		w.get_viewport().get_texture().get_image().save_png(OUT+"camp-window.png")
	var target: Node2D=s.builds.visuals.get(chest_id)
	check(is_instance_valid(target),"stream installs camp")
	check(preload("res://scripts/world_interaction.gd").action_for(target)=="","no functional interaction without hammer")
	check(not target.perform_interaction("open",w.player),"abandoned chest direct interaction refused")
	check(not s.builds.set_chest_open(chest_id,true).is_empty(),"abandoned chest service refuses open")
	check(not s.builds.transfer(chest_id,0,8,chest.contents[0],{}).is_empty(),"abandoned storage direct transfer refused")
	for id in generated:
		if generated[id].kind=="workbench":check(not s.workbench_valid(id),"abandoned workbench unavailable")
		if generated[id].kind in ["wood_bed","straw_mat"]:check(not s.sleep.available(id),"abandoned sleep facility unavailable")
	s.inventory.equipment.main_hand=s.inventory.instance("stone_hammer")
	check(preload("res://scripts/world_interaction.gd").action_for(target)=="demolish","hammer selects demolition")
	for i in 2:check(s.builds.strike(chest_id,target),"chest demolition hit "+str(i))
	var before: Dictionary= s.snapshot().duplicate(true)
	s.save_path="res://reports/abandoned-fish-v1/missing/sub/save.json"
	check(not s.builds.strike(chest_id,target),"final demolition save failure")
	check(s.snapshot()==before,"failed demolition restores building contents durability and loose")
	s.save_path=SAVE
	check(s.builds.strike(chest_id,target),"last chest hit commits")
	check(not s.builds.states.has(chest_id),"chest removed")
	check(s.loose[chest_id+":refund:wood"].count==5 and s.loose[chest_id+":refund:plant_fiber"].count==2,"original 50 percent chest refund")
	for i in 3:
		var drop_id := chest_id+":contents:"+str(i)
		check(s.loose.has(drop_id) and s.loose[drop_id].instance==chest.contents[i],"contents preserved "+str(i))
	await create_timer(.7).timeout
	var drop: Node2D
	for node in w.stream.drops:
		if is_instance_valid(node) and node.get_meta("drop_id","")==chest_id+":contents:0":drop=node;break
	check(is_instance_valid(drop),"contents use real drop node")
	before=s.snapshot().duplicate(true);var event_count := events.size()
	s.save_path="res://reports/abandoned-fish-v1/missing/sub/save.json"
	check(not s.pickup(drop),"pickup save failure refused")
	check(s.snapshot()==before and events.size()==event_count,"pickup rollback and no obtained event")
	s.save_path=SAVE
	var pickup_slots: Array=s.inventory.slots.duplicate(true)
	for i in 40:s.inventory.slots[i]={"item_id":"wood","count":99}
	check(not s.pickup(drop) and s.loose.has(chest_id+":contents:0") and events.size()==event_count,"full bag leaves contents on ground")
	s.inventory.slots=pickup_slots
	check(s.pickup(drop),"contents can be picked up")
	check(events.size()==event_count+1,"pickup obtained once")
	check(s.save_state(),"demolition and pickup snapshot saved")
	s.load_state();check(s.writable and not s.builds.states.has(chest_id) and not s.loose.has(chest_id+":contents:0"),"reload never restores demolished chest or picked loot")
	# A non-storage facility follows precisely the original material return.
	var bench_id := "abandoned:v1:0:1"
	var bench: Dictionary=s.builds.states[bench_id]
	await travel(Vector2(bench.x,bench.y)+Vector2(0,52))
	target=s.builds.visuals[bench_id]
	for i in int(s.builds.definitions.workbench.hits):check(s.builds.strike(bench_id,target),"nonstorage demolition "+str(i))
	check(s.loose[bench_id+":refund:wood"].count==6 and s.loose[bench_id+":refund:stone"].count==4,"nonstorage original refund")
	# Existing fish stacks missing spoilage normalize safely, in inventory/storage/loose.
	var legacy := {"item_id":"lake_fish","count":2}
	check(Fresh.normalize(s.database,legacy) and legacy.spoilage==0,"legacy fish fresh migration")
	var invalid := {"item_id":"lake_fish","count":1,"spoilage":-1}
	check(not Fresh.normalize(s.database,invalid),"invalid freshness refused")
	s.inventory.add("lake_fish",3)
	var fish_slot := -1
	for i in 40:
		if s.inventory.slots[i].get("item_id","")=="lake_fish":fish_slot=i;break
	check(fish_slot>=0 and s.inventory.slots[fish_slot].has("spoilage"),"fish acquisition creates freshness")
	check(not s.inventory.use_slot(fish_slot),"raw fish cannot be eaten")
	Fresh.advance(s.database,legacy,3600)
	check(Fresh.rotten(legacy),"fish rots after 2.5 game days")
	check(s.stack_texture(legacy,"icon")!=s.texture("lake_fish","icon"),"reused rotten appearance present")
	var cold := {"item_id":"lake_fish","count":1,"spoilage":0.0}
	Fresh.advance(s.database,cold,3600,true);check(cold.spoilage<1,"fridge slows fish decay")
	var sample: Dictionary=s.inventory.slots[fish_slot].duplicate(true)
	sample.count=2;sample.spoilage=.4;s.inventory.slots[fish_slot]=sample
	var split: int=s.inventory.split_slot(fish_slot,1)
	check(split>=0 and s.inventory.slots[split].spoilage==.4,"split preserves fish freshness")
	check(s.inventory.organized_bag_slots().any(func(v):return v.get("item_id","")=="lake_fish" and v.spoilage==.4 and v.count==2),"organize merges only matching freshness")
	var fridge: Dictionary=s.builds.candidate("refrigerator",w.player.position+Vector2(45,0),false,false,0)
	s.builds.states.fridge=fridge
	check(s.builds.transfer("fridge",0,fish_slot,{},s.inventory.slots[fish_slot].duplicate(true)).is_empty(),"raw fish accepted by real fridge transfer")
	s.loose["decay-fish"]={"id":"decay-fish","item_id":"lake_fish","count":1,"instance":{"item_id":"lake_fish","count":1,"spoilage":.4},"x":w.player.position.x,"y":w.player.position.y,"mode":"pickup"}
	s.industry.advance(1,1440)
	check(s.builds.states.fridge.contents[0].spoilage>.4 and s.builds.states.fridge.contents[0].spoilage<1,"real storage decay advances at chilled rate")
	check(is_equal_approx(s.loose["decay-fish"].instance.spoilage,.8),"real loose fish decay advances")
	check(is_equal_approx(s.inventory.slots[split].spoilage,.8),"real inventory fish decay advances")
	check(s.builds.transfer("fridge",0,fish_slot,s.builds.states.fridge.contents[0].duplicate(true),{}).is_empty(),"fish taken back with remaining freshness")
	s.builds.states.erase("fridge")
	var material := {"item_id":"wood","count":1};Fresh.advance(s.database,material,10000)
	check(not material.has("spoilage"),"unrelated material does not rot")
	await travel(w.generator.spawn)
	s.camps.states.test={"x":w.player.position.x+20,"y":w.player.position.y,"fuel":500.0,"lit":true,"recipe":"","elapsed":0.0,"ready":false}
	s.camps.rebuild()
	s.inventory.add("cabbage",1)
	for recipe in ["roast_fish","vegetable_fish_soup"]:
		var spec: Dictionary=s.camps.rules.recipes[recipe]
		var materials := {}
		for key in spec.materials:materials[key]=int(spec.materials[key])
		check(s.camps.match_materials(materials)==recipe,"exact fish recipe "+recipe)
		before=s.snapshot().duplicate(true)
		s.save_path="res://reports/abandoned-fish-v1/missing/sub/save.json"
		check(not s.camps.act("test","experiment",recipe,materials).is_empty() and before==s.snapshot(),"cook start rollback "+recipe)
		s.save_path=SAVE
		check(s.camps.act("test","experiment",recipe,materials).is_empty(),"cook starts "+recipe)
		s.camps.advance(float(spec.seconds)+.1)
		check(s.camps.states.test.ready,"cook completes "+recipe)
		check(s.camps.known(recipe),"recipe discovered "+recipe)
		s.save_state();s.load_state()
		check(s.writable and s.camps.states.test.ready,"ready meal survives reload "+recipe)
		before=s.snapshot().duplicate(true);event_count=events.size()
		s.save_path="res://reports/abandoned-fish-v1/missing/sub/save.json"
		check(not s.camps.act("test","claim").is_empty() and before==s.snapshot() and event_count==events.size(),"claim rollback "+recipe)
		s.save_path=SAVE
		var slots_before: Array=s.inventory.slots.duplicate(true)
		for i in 40:s.inventory.slots[i]={"item_id":"wood","count":99}
		check(not s.camps.act("test","claim").is_empty() and s.camps.states.test.ready and event_count==events.size(),"full bag preserves meal and sends no event "+recipe)
		s.inventory.slots=slots_before
		check(s.camps.act("test","claim").is_empty(),"claim cooked fish "+recipe)
		check(events.size()==event_count+1 and events.back()==[spec.output,1],"meal obtained event "+recipe)
		check(not s.camps.act("test","claim").is_empty(),"duplicate claim refused "+recipe)
		for i in 40:
			if s.inventory.slots[i].get("item_id","")!=spec.output:continue
			s.body.hunger=40
			check(s.inventory.use_slot(i),"meal edible "+recipe)
			check(s.body.hunger==40+s.database.item(spec.output).effects.hunger,"conservative hunger gain "+recipe)
	check(s.camps.match_materials({"brown_mushroom":1})=="roast_mushroom","existing recipe intact")
	s.inventory.add("lake_fish",1)
	s.save_path=OUT+"restart-save.json";check(s.save_state(),"snapshot for independent process")
	s.save_path=SAVE
	var saved: Dictionary= s.snapshot().duplicate(true)
	saved.buildings.erase("abandoned_version")
	for row in saved.buildings.objects.values():row.erase("abandoned")
	write(saved);s.load_state()
	check(s.writable and s.builds.abandoned_version==0,"old building snapshot compatible, no camp injection")
	await finish(summaries)
func finish(summaries: Array) -> void:
	w.persistent_world=false;w.free();await process_frame
	check(files()==original_files,"all real player save hashes unchanged")
	var failed := checks.filter(func(c):return not c.pass)
	var args := OS.get_cmdline_user_args()
	var suffix: String= "preview" if "preview" in args else "read" if "read" in args else "sites-"+args[args.size()-1] if "sites" in args else "headless" if DisplayServer.get_name()=="headless" else "window"
	var file := FileAccess.open(OUT+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"count":checks.size(),"failed":failed.size(),"camps":summaries},"\t"));file.close()
	print("ABANDONED FISH V1: ",checks.size()," checks, ",failed.size()," failed")
	quit(0 if failed.is_empty() else 1)


