extends SceneTree
const Grid = preload("res://scripts/camp_grid.gd")
const OUT := "res://reports/camp-build-fix-v1/after/"
var checks: Array=[]
var world: Node
var s: Node
var b: RefCounted
func _initialize() -> void: call_deferred("run")
func check(ok: bool, name_value: String) -> void:
	checks.append({"name":name_value,"pass":ok})
	if not ok: push_error(name_value)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func shot(name_value: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_value+".png")
func stock() -> void:
	for i in 40: s.inventory.slots[i]={}
	for id in ["stone","wood","plant_fiber","flint"]: s.inventory.add(id,90)
func find_site(kind: String) -> Dictionary:
	var origin: Vector2=world.generator.spawn
	for y in range(-4,5):
		for x in range(-4,5):
			var at: Vector2=origin+Vector2(x*96,y*64)
			world.player.position=at+Vector2(0,80)
			var row: Dictionary=b.candidate(kind,at,false,true,0)
			if b.reason(row).is_empty(): return row
	return {}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	if not "--formal" in OS.get_cmdline_user_args(): Engine.set_meta("camp_build_preview",true)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	world.environment_view.simulation.paused=true;world.player.set_physics_process(false)
	while not world.stream.viewport_ready(world.player.position,Vector2(640,360)): await process_frame
	s=world.item_service;b=s.builds
	await frames()
	if "--restart-read" in OS.get_cmdline_user_args():
		world.persistent_world=true;s.save_path=OUT+"restart.json";s.load_state();await frames()
		check(s.writable and b.states.size()==39,"fresh process loads all39 camp instances")
		check(b.states.get("show:h:1:4",{}).get("open",false),"fresh process restores gate open")
		check(b.states.get("show:h:0:0",{}).get("hits")==2,"fresh process restores wall damage")
		check(b.states.get("show:wood_chest",{}).get("contents",[{}])[0].get("durability")==73,"fresh process first chest tool73")
		check(b.states.get("show:second_chest",{}).get("contents",[{}])[0].get("durability")==41,"fresh process independent second chest tool41")
		check(s.loose.values().any(func(v): return v.get("origin","")=="demolition"),"fresh process restores ground demolition materials")
		var count: int=b.visuals.size();s.load_state();await frames();check(b.visuals.size()==count,"repeated full snapshot load does not duplicate instances")
		world.persistent_world=false;finish();return
	if "--formal" in OS.get_cmdline_user_args():
		check(not Engine.get_meta("camp_build_preview",false) and s.camps.build_book.available().size()==10 and s.craft_book.recipe("hand_stone_hammer").default_unlocked,"formal startup exposes ten buildings and hammer without preview")
		check(s.database.item("stone_hammer").icon.begins_with("res://assets/buildings/v1/") and FileAccess.file_exists("res://assets/buildings/v1/provenance.json"),"formal startup uses approved asset paths")
	check(s.database.errors.is_empty() and s.craft_book.errors.is_empty() and s.camps.build_book.errors.is_empty(),"all item craft building data validates")
	check(b.definitions.size()==9 and s.camps.build_book.recipes.size()==10,"nine new buildings and existing campfire")
	for id in ["stone_axe","stone_pickaxe","simple_shovel","stone_hammer"]:
		var item: Dictionary=s.inventory.instance(id)
		check(item.durability==100,"initial durability "+id)
		item.durability=null;check(s.inventory.normalize_durability(item) and item.durability==100,"legacy null migrates "+id)
		item.durability=73;s.inventory.equipment.main_hand=item
		s.inventory.hotbar_equipment={"0":item.instance_id}
		var ability: String=s.database.item(id).capabilities[0]
		check(s.inventory.wear_held(str(item.instance_id),ability) and item.durability==72,"instance loses one "+id)
		check(not s.inventory.wear_held("wrong",ability) and item.durability==72,"wrong instance no wear "+id)
		item.durability=1;s.inventory.wear_held(str(item.instance_id),ability)
		check(s.inventory.equipment.is_empty() and s.inventory.hotbar_equipment.is_empty(),"last use removes tool and hotbar alias "+id)
	var invalid: Dictionary=s.inventory.instance("stone_axe");invalid.durability=101
	check(not s.inventory.normalize_durability(invalid),"invalid durability rejected")
	var graph := {}
	var center := Vector2i(5,5)
	for mask in range(1,16):
		graph.clear()
		if mask&1: graph.a={"gx":5,"gy":4,"vertical":true,"layer":"edge"}
		if mask&2: graph.b={"gx":5,"gy":5,"vertical":false,"layer":"edge"}
		if mask&4: graph.c={"gx":5,"gy":5,"vertical":true,"layer":"edge"}
		if mask&8: graph.d={"gx":4,"gy":5,"vertical":false,"layer":"edge"}
		check(Grid.connections(graph,center)==mask,"endpoint graph all connection masks "+str(mask))
	stock()
	var row := find_site("stone_wall")
	check(not row.is_empty(),"find legal real terrain building site")
	if row.is_empty(): finish();return
	var stone: int=s.inventory.count_item("stone")
	var old: Array=s.inventory.slots.duplicate(true)
	check(b.place(row,old).is_empty() and s.inventory.count_item("stone")==stone-6,"wall place debit exactly six")
	var id: String=b.occupant(row)
	check(not id.is_empty(),"stable building instance ID")
	check(not b.place(row,s.inventory.slots.duplicate(true)).is_empty() and s.inventory.count_item("stone")==stone-6,"duplicate occupancy no debit")
	var gate: Dictionary=row.duplicate(true);gate.kind="stone_gate"
	check(b.cost(gate)=={"wood":6,"plant_fiber":3},"door replacement only positive delta")
	check(b.place(gate,s.inventory.slots.duplicate(true)).is_empty() and b.occupant(gate)==id,"door replacement preserves instance")
	await frames()
	world.player.position=Vector2(row.x,row.y)+Vector2(0,90)
	var ray := PhysicsRayQueryParameters2D.create(Vector2(row.x,row.y)+Vector2(0,20),Vector2(row.x,row.y)-Vector2(0,20))
	check(not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"closed gate collision blocks channel")
	check(b.toggle(id).is_empty() and b.states[id].open,"gate opens")
	await create_timer(.3).timeout
	check(world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),"open gate moves leaf collision clear of channel")
	world.player.position=Vector2(row.x,row.y)
	check(not b.toggle(id).is_empty() and b.states[id].open,"gate cannot close on actor")
	world.player.position=Vector2(row.x,row.y)+Vector2(0,90)
	check(b.toggle(id).is_empty() and not b.states[id].open,"gate closes from safe position")
	var protected: Dictionary= s.inventory.instance("stone_hammer");s.inventory.equipment.main_hand=protected
	b.states[id].contents[0]={"item_id":"wood","count":1}
	check(not b.strike(id,b.visuals[id]) and protected.durability==100,"protected content consumes no hammer wear")
	b.states[id].contents[0]={}
	for i in 3: check(b.strike(id,b.visuals[id]),"effective demolition hit "+str(i+1))
	check(b.states.has(id) and b.states[id].hits==3 and protected.durability==97,"partial damage persists per hit")
	protected.durability=1
	check(b.strike(id,b.visuals[id]) and not b.states.has(id) and s.inventory.equipment.is_empty(),"last durability completes demolition then breaks hammer")
	check(s.loose.get(id+":refund:stone",{}).get("count")==3 and s.loose.get(id+":refund:wood",{}).get("count")==3 and s.loose.get(id+":refund:plant_fiber",{}).get("count")==1,"door refunds floor fifty percent as real world entries")
	await frames()
	check(not b.strike(id,null),"repeat demolition cannot refund twice")
	stock()
	var paint_row := find_site("stone_wall")
	var paint_point := Vector2(paint_row.x,paint_row.y)
	world.player.position=paint_point+Vector2(96,100)
	var before_count: int=b.states.size();var before_stone: int=s.inventory.count_item("stone")
	world.camp_ui.begin_build("build_stone_wall")
	world.camp_ui.paint_at(paint_point);world.camp_ui.paint_at(paint_point+Vector2(192,0))
	var placed: int=b.states.size()-before_count
	check(placed>=1 and s.inventory.count_item("stone")==before_stone-placed*6,"native continuous stroke independently debits successful segments")
	var paint_slots: Array=s.inventory.slots.duplicate(true)
	world.camp_ui.paint_at(paint_point)
	check(s.inventory.slots==paint_slots,"continuous stroke revisits do not duplicate debit")
	world.camp_ui.cancel_placement();check(s.inventory.slots==paint_slots,"cancel stroke keeps only committed segments")
	# Keep other tests independent of the walls just placed through the native controller.
	b.states.clear();b.refresh_all();await frames()
	stock()
	var floor_row := find_site("wood_floor");var floor_at := Vector2(floor_row.x,floor_row.y)
	world.player.position=floor_at+Vector2(96,80)
	var before_wood: int=s.inventory.count_item("wood")
	world.camp_ui.begin_build("build_wood_floor");world.camp_ui.paint_at(floor_at);world.camp_ui.paint_at(floor_at+Vector2(192,0))
	check(b.states.size()>=1 and s.inventory.count_item("wood")==before_wood-b.states.size()*4,"native floor stroke debits four per successful cell")
	world.camp_ui.cancel_placement();b.states.clear();b.refresh_all();await frames()
	stock()
	for slot in s.inventory.slots:
		if slot.get("item_id","")=="stone": slot.count=7
	var limited := find_site("stone_wall");var limited_at := Vector2(limited.x,limited.y)
	world.player.position=limited_at+Vector2(96,90)
	world.camp_ui.begin_build("build_stone_wall");world.camp_ui.paint_at(limited_at);world.camp_ui.paint_at(limited_at+Vector2(192,0))
	check(b.states.size()==1 and s.inventory.count_item("stone")==1,"material shortage retains first segment without overspending")
	world.camp_ui.cancel_placement();b.states.clear();b.refresh_all();await frames()
	stock();var chest := find_site("wood_chest")
	check(not chest.is_empty(),"find chest site")
	check(b.place(chest,s.inventory.slots.duplicate(true)).is_empty(),"place functional chest")
	var cid: String=b.states.keys()[-1]
	var tool: Dictionary=s.inventory.instance("stone_axe");tool.durability=73;s.inventory.slots[20]=tool
	check(b.transfer(cid,0,20,{},tool.duplicate(true)).is_empty() and s.inventory.slots[20].is_empty() and b.states[cid].contents[0].durability==73,"chest stores same tool instance durability")
	check(not b.protected_reason(cid).is_empty(),"nonempty chest protected")
	var protection_hammer: Dictionary=s.inventory.instance("stone_hammer");s.inventory.equipment.main_hand=protection_hammer
	check(not b.strike(cid,b.visuals[cid]) and protection_hammer.durability==100,"nonempty real chest rejects hit before durability")
	s.inventory.equipment.erase("main_hand")
	check(b.transfer(cid,0,21,tool.duplicate(true),{}).is_empty() and s.inventory.slots[21].durability==73,"chest retrieves tool without reset")
	check(not b.transfer(cid,0,21,{},{}).is_empty(),"stale transfer snapshot rejected")
	s.inventory.equip(21)
	check(b.transfer(cid,3,40,{},tool.duplicate(true)).is_empty() and s.inventory.get_slot(40).is_empty() and b.states[cid].contents[3].durability==73,"equipped tool directly enters chest without reset")
	check(b.transfer(cid,3,40,tool.duplicate(true),{}).is_empty() and s.inventory.get_slot(40).durability==73,"chest tool directly equips without reset")
	s.inventory.hotbar_equipment={"0":tool.instance_id}
	check(b.transfer(cid,3,0,{},tool.duplicate(true)).is_empty() and s.inventory.hotbar_equipment.is_empty() and s.inventory.equipment.is_empty(),"equipped hotbar alias moves actual instance into chest and clears link")
	check(b.transfer(cid,3,21,tool.duplicate(true),{}).is_empty() and s.inventory.slots[21].durability==73,"hotbar to chest to bag keeps durability73")
	s.inventory.slots[22]={"item_id":"wood","count":4};b.states[cid].contents[1]={"item_id":"wood","count":7}
	check(b.transfer(cid,1,22,{"item_id":"wood","count":7},{"item_id":"wood","count":4}).is_empty() and b.states[cid].contents[1].count==11,"chest merges stacks")
	var data: Dictionary=b.serialize()
	check(b.validate(data.duplicate(true),{}),"building snapshot validation")
	var bad: Dictionary=data.duplicate(true);bad.version=2
	check(not b.validate(bad,{}),"unknown building version protected")
	bad=data.duplicate(true);bad.objects.values()[0].contents[0]=tool;bad.objects.values()[0].contents[2]=tool
	check(not b.validate(bad,{}),"duplicate chest tool instance rejected")
	check(b.chest_edit(cid,1,{"item_id":"wood","count":11},"split",-1,3).is_empty() and b.states[cid].contents[0].count==3 and b.states[cid].contents[1].count==8,"chest split preserves total")
	check(b.chest_edit(cid,0,{"item_id":"wood","count":3},"move",1).is_empty() and b.states[cid].contents[1].count==11 and b.states[cid].contents[0].is_empty(),"chest internal drag merges")
	check(not b.chest_edit(cid,1,{"item_id":"wood","count":11},"split",-1,11).is_empty(),"chest full stack split rejected")
	var failed_row := find_site("stone_path")
	# Failed disk commit must preserve both sides, with no published visual or debit.
	var old_path: String=s.save_path
	s.save_path="user://missing-camp-directory/not-a-save.json";world.persistent_world=true
	var slots_before: Array=s.inventory.slots.duplicate(true)
	check(not b.chest_edit(cid,1,{"item_id":"wood","count":11},"destroy").is_empty() and b.states[cid].contents[1].count==11,"failed chest save rolls back contents")
	var count_before: int=b.states.size()
	check(not b.place(failed_row,s.inventory.slots.duplicate(true)).is_empty() and b.states.size()==count_before and s.inventory.slots==slots_before,"failed placement save rolls back occupancy and all materials")
	world.persistent_world=false;s.save_path=old_path
	var costs := {"stone":0,"wood":0,"plant_fiber":0,"flint":0}
	for pair in [["stone_wall",23],["stone_gate",1],["wood_chest",1],["workbench",1]]:
		for material in b.definitions[pair[0]].cost: costs[material]+=int(b.definitions[pair[0]].cost[material])*pair[1]
	for material in s.camps.build_book.recipe("hand_simple_campfire").materials: costs[material]+=int(s.camps.build_book.recipe("hand_simple_campfire").materials[material])
	check(costs=={"stone":158,"wood":32,"plant_fiber":11,"flint":1},"standard 6x6 camp material balance")
	var before: Dictionary=b.serialize()
	var coord: Vector2i=world.stream.chunk_at(Vector2(chest.x,chest.y))
	b.unload(coord);await frames();b.install(coord)
	check(b.serialize()==before and b.visuals.has(cid),"unload reload retains stable chest contents")
	# Exercise actual original snapshot write + read in a report-only file.
	var original_path: String=s.save_path
	s.save_path=OUT+"roundtrip.json";world.persistent_world=true
	check(s.save_state(),"atomic snapshot write")
	b.states={};s.inventory.slots[21]={};s.load_state()
	check(b.serialize()==before and s.inventory.slots[21].get("durability")==73,"atomic snapshot reload restores buildings and durability")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(s.save_path));saved.buildings.version=99
	FileAccess.open(OUT+"unknown.json",FileAccess.WRITE).store_string(JSON.stringify(saved));s.load_state(OUT+"unknown.json")
	check(not s.writable,"unknown future building version protects source")
	s.writable=true;world.persistent_world=false;s.save_path=original_path
	var camp_at: Vector2=Vector2(chest.x,chest.y)+Vector2(0,160)
	s.camps.states["camp-test:protected"]={"x":camp_at.x,"y":camp_at.y,"fuel":10.0,"lit":true,"recipe":"","elapsed":0.0,"ready":false}
	s.camps.rebuild();s.camps.install(world.stream.chunk_at(camp_at));await frames()
	var camp_hammer: Dictionary=s.inventory.instance("stone_hammer");s.inventory.equipment.main_hand=camp_hammer
	check(not b.strike("camp-test:protected",s.camps.visuals["camp-test:protected"]) and camp_hammer.durability==100,"fuelled campfire protects hammer durability")
	var protected_camp: Dictionary=s.camps.states["camp-test:protected"]
	protected_camp.fuel=0.0;protected_camp.lit=false;protected_camp.recipe="roast_carrot"
	check(not b.strike("camp-test:protected",s.camps.visuals["camp-test:protected"]) and camp_hammer.durability==100,"paused cooking campfire protects hammer durability")
	protected_camp.ready=true;protected_camp.elapsed=s.camps.rules.recipes.roast_carrot.seconds
	check(not b.strike("camp-test:protected",s.camps.visuals["camp-test:protected"]) and camp_hammer.durability==100,"ready cooking campfire protects hammer durability")
	s.camps.visuals["camp-test:protected"].queue_free();s.camps.visuals.erase("camp-test:protected");s.camps.states.erase("camp-test:protected");s.camps.rebuild();s.inventory.equipment.erase("main_hand")
	# Real native ore completion executes its final one-durability action before break.
	var ore_at: Vector2=Vector2(chest.x,chest.y)+Vector2(160,0)
	world.player.position=ore_at+Vector2(75,0)
	var ore: Node2D=s.create_harvest("camp-test:ore",{"x":ore_at.x,"y":ore_at.y,"kind":"stone_outcrop"})
	await frames()
	s.resource_hits["camp-test:ore"]=4
	var pick: Dictionary=s.inventory.instance("stone_pickaxe");pick.durability=1;s.inventory.equipment.main_hand=pick
	check(s.harvest_hit(ore,"mine") and s.consumed.has("camp-test:ore") and s.inventory.equipment.is_empty(),"native final mine yields before tool break")
	var ore_count := 0
	for entry in s.loose.values():
		if str(entry.id).begins_with("camp-test:ore:") and entry.item_id=="stone": ore_count+=int(entry.count)
	check(ore_count>=12 and ore_count<=16,"native complete stone outcrop yield 12 to16")
	check(not s.harvest_hit(ore,"mine"),"completed ore cannot duplicate rewards")
	var root_at := ore_at+Vector2(120,0);world.player.position=root_at+Vector2(50,0)
	var root_node: Node2D=s.create_harvest("camp-test:root",{"x":root_at.x,"y":root_at.y,"kind":"buried_root"});await frames()
	s.resource_hits["camp-test:root"]=int(root_node.definition.hits)-1
	var shovel: Dictionary=s.inventory.instance("simple_shovel");shovel.durability=1;s.inventory.equipment.main_hand=shovel
	check(s.harvest_hit(root_node,"dig") and s.consumed.has("camp-test:root") and s.inventory.equipment.is_empty(),"native final dig yields before shovel break")
	var all_trees: Array=get_nodes_in_group("trees")
	if not all_trees.is_empty():
		var tree: Node2D=all_trees[0];var tree_id: String=tree.get_meta("prop_id")
		world.stream.tree_hits[tree_id]=tree.required_hits-1
		var axe: Dictionary=s.inventory.instance("stone_axe");axe.durability=1;s.inventory.equipment.main_hand=axe
		world.stream.chop_tree(tree)
		check(world.stream.harvested.has(tree_id) and s.inventory.equipment.is_empty(),"native final chop yields before axe break")
		var drop: Dictionary=s.loose.get(tree_id+":hit%d"%tree.required_hits,{})
		check(int(drop.get("count",0))>=4 and int(drop.get("count",0))<=6,"native tree batch yields4 to6 wood")
	var successes := 0
	for i in 10000:
		if abs((str(i)+":flint").hash())%10<3: successes+=1
	check(successes>=2800 and successes<=3200,"deterministic flint approximately30percent sample")
	stock();s.inventory.slots[21]=tool;s.inventory.changed.emit()
	var stored_tool: Dictionary=s.inventory.instance("stone_pickaxe");stored_tool.durability=41;b.states[cid].contents[0]=stored_tool
	var held_tool: Dictionary=s.inventory.instance("stone_hammer");held_tool.durability=25;s.inventory.equipment.main_hand=held_tool;s.inventory.changed.emit()
	check(world.item_ui.cells[21].durability_bar.visible and world.item_ui.cells[21].durability_bar.value==73,"bag cell exact live durability73")
	var equipment_index := -1
	for i in range(40,43):
		if s.inventory.slot_key(i)=="main_hand": equipment_index=i
	check(world.item_ui.cells[equipment_index].durability_bar.value==25,"equipped cell exact live durability25")
	world.player.position=Vector2(chest.x,chest.y)+Vector2(0,80);world.player.camera.force_update_scroll()
	s.storage_ui.open(cid)
	for size_value in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=size_value;await frames(8)
		check(s.storage_ui.panel.size==Vector2(1030,600),"storage fixed logic canvas "+str(size_value.x))
		await shot("storage-"+str(size_value.x))
	check(s.storage_ui.cells[0].bar.value==41,"storage cell exact live durability41")
	s.storage_ui.split(1);s.storage_ui.amount.text="0";s.storage_ui.amount.text_changed.emit("0")
	check(s.storage_ui.split_confirm.disabled,"storage quantity rejects zero")
	s.storage_ui.amount.text="3";s.storage_ui.amount.text_changed.emit("3")
	check(not s.storage_ui.split_confirm.disabled,"storage quantity accepts legal partial stack")
	await shot("storage-split");s.storage_ui.quantity.hide()
	s.storage_ui.close_panel();world.item_ui.toggle_bag()
	for size_value in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=size_value;await frames(8);world.item_ui.show_item_hover(21);world.item_ui.hover_wait=0;await frames(3);await shot("durability-"+str(size_value.x))
	world.item_ui.close_panels();world.item_ui.toggle_build();await frames()
	for size_value in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=size_value;await frames(8);await shot("build-menu-"+str(size_value.x))
	world.item_ui.close_panels()
	# Same real world/renderer; authored structural arrangement for visual inspection.
	var anchor: Vector2=Vector2(chest.x,chest.y).snapped(Grid.STEP)
	b.states.clear()
	for y in 4:
		for x in 4:
			var tile: Dictionary=b.candidate("wood_floor" if x<2 else "stone_path",anchor+Vector2(x*96+48,y*64+32),false,true,0)
			b.states["show:tile:%d:%d"%[x,y]]=tile
	for x in 4:
		for y in [0,4]:
			var r: Dictionary=b.candidate("stone_gate" if x==1 and y==4 else "stone_wall",anchor+Vector2(x*96+48,y*64),false,true,0)
			b.states["show:h:%d:%d"%[x,y]]=r
	for y in 4:
		for x in [0,4]:
			b.states["show:v:%d:%d"%[x,y]]=b.candidate("stone_wall",anchor+Vector2(x*96,y*64+32),true,true,0)
	for x in 2:
		b.states["show:fence:"+str(x)]=b.candidate("wood_fence",anchor+Vector2(96*x+48,128),false,true,0)
	b.states["show:cross"]=b.candidate("wood_fence",anchor+Vector2(96,96),true,true,0)
	for data_row in [["wood_chest",Vector2(285,58)],["workbench",Vector2(280,158)],["camp_torch",Vector2(330,218)]]:
		b.states["show:"+data_row[0]]=b.candidate(data_row[0],anchor+data_row[1],false,true,0)
	var closed_gate: Dictionary=b.states["show:h:1:4"]
	check(Grid.swing(b.states,closed_gate)==-1,"south gate inward resolves toward enclosed camp")
	closed_gate.inward=false;check(Grid.swing(b.states,closed_gate)==1,"south gate outward resolves away from camp")
	closed_gate.inward=true;closed_gate.swing=Grid.swing(b.states,closed_gate)
	b.refresh_all();await frames()
	world.player.position=anchor+Vector2(180,196);world.player.camera.force_update_scroll();root.size=Vector2i(1280,720)
	await frames(8);await shot("camp-candidate-day")
	for size_value in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=size_value;await frames(5);await shot("connections-"+str(size_value.x))
	root.size=Vector2i(1280,720)
	check(b.visuals.size()==b.states.size(),"all authored showcase modules install once")
	var gate_id := "show:h:1:4"
	world.player.position=anchor+Vector2(144,336)
	check(b.toggle(gate_id).is_empty(),"showcase single gate opens")
	await frames(35);await shot("camp-candidate-gate-open")
	world.environment_view.simulation.minute=0
	await shot("camp-candidate-night")
	b.states["show:h:0:0"].hits=2
	var first_tool: Dictionary=s.inventory.instance("stone_axe");first_tool.durability=73;b.states["show:wood_chest"].contents[0]=first_tool
	var second_tool: Dictionary=s.inventory.instance("stone_pickaxe");second_tool.durability=41
	b.states["show:second_chest"]=b.candidate("wood_chest",anchor+Vector2(220,220),false,false,1)
	b.states["show:second_chest"].contents[0]=second_tool
	world.persistent_world=true;s.save_path=OUT+"restart.json"
	check(s.save_state(),"write complete camp for separate process restart")
	world.persistent_world=false
	await repair_checks(anchor)
	finish()
func finish() -> void:
	var failed: Array=checks.filter(func(r): return not r.pass)
	var result_name := "restart-tests.json" if "--restart-read" in OS.get_cmdline_user_args() else "formal-window-tests.json" if "--formal" in OS.get_cmdline_user_args() and "--capture" in OS.get_cmdline_user_args() else "formal-tests.json" if "--formal" in OS.get_cmdline_user_args() else "window-tests.json" if "--capture" in OS.get_cmdline_user_args() else "tests.json"
	FileAccess.open(OUT+result_name,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"  "))
	print("CAMP BUILD V1: %d checks, %d failed"%[checks.size(),failed.size()])
	world.persistent_world=false;world.free();await process_frame;quit(0 if failed.is_empty() else 1)


func repair_checks(anchor: Vector2) -> void:
	const Interaction = preload("res://scripts/world_interaction.gd")
	world.environment_view.simulation.minute=720
	world.item_ui.close_panels();world.camp_ui.close_panel();s.storage_ui.close_panel()
	s.inventory.equipment.clear();s.inventory.hotbar_equipment.clear();stock()
	b.states.clear();b.refresh_all();await sync_physics()
	# A deliberately clear part of the same real world, without authoring a second map.
	var center: Vector2=anchor+Vector2(144,160)
	for gate_kind in ["stone_gate","fence_gate"]:
		for vertical in [false,true]:
			for swing_value in [-1,1]:
				var row: Dictionary=b.candidate(gate_kind,center,vertical,true,0)
				row.swing=swing_value;b.states={"test:gate":row};b.refresh_all();await sync_physics()
				var node: Node2D=b.visuals["test:gate"]
				var at := Vector2(row.x,row.y)
				var safe := Vector2(32*swing_value,0) if vertical else Vector2(0,-32*swing_value)
				world.player.position=at+safe;await sync_physics()
				var label_value := "%s vertical=%s swing=%s"%[gate_kind,vertical,swing_value]
				check(Interaction.in_reach(world.stream,world.player.position,node),"door reachable side one "+label_value)
				check(Interaction.execute(world.stream,world.player,node) and row.open,"opens from normal nearby position "+label_value)
				check(not b.toggle("test:gate").is_empty() and row.open,"animation repeat guarded "+label_value)
				await create_timer(.1).timeout
				var during: PackedVector2Array=node.leaf_points(node.gate_angle)
				check(node.leaf.polygon[1].distance_to(during[1])<4.01,"mid animation visual and collision tip agree "+label_value)
				await shot("door-"+gate_kind+"-"+str(vertical)+"-"+str(swing_value)+"-mid")
				await create_timer(.3).timeout
				check(Interaction.execute(world.stream,world.player,node) and not row.open,"same standing position closes "+label_value)
				await create_timer(.3).timeout
				var safe_other := Vector2(-32*swing_value,80) if vertical else Vector2(80,32*swing_value)
				world.player.position=at+safe_other;await sync_physics()
				check(Interaction.in_reach(world.stream,world.player.position,node),"door reachable side two "+label_value)
				check(Interaction.execute(world.stream,world.player,node) and row.open,"opens side two outside leaf path "+label_value)
				await create_timer(.3).timeout
				var points: PackedVector2Array=node.leaf_points((PI*.5 if vertical else 0.0)+PI*.25*swing_value)
				world.player.position=at+points[0].lerp(points[1],.6);await sync_physics()
				check(not b.toggle("test:gate").is_empty() and row.open,"real swept path blocks closing "+label_value)
				world.player.position=at+safe_other;await sync_physics()
				check(b.toggle("test:gate").is_empty(),"closes when path clear on side two "+label_value)
				await create_timer(.3).timeout
				check(node.leaf.polygon.size()==4 and node.leaf.polygon[0].distance_to(node.leaf_points(node.gate_angle)[0])<4.01,"closed collision follows hinge angle "+label_value)
				var obstacle := StaticBody2D.new();var shape_node := CollisionShape2D.new();var box := RectangleShape2D.new();box.size=Vector2(12,12);shape_node.shape=box;obstacle.add_child(shape_node);obstacle.position=at+points[0].lerp(points[1],.65);world.object_root.add_child(obstacle);await sync_physics()
				check(not b.toggle("test:gate").is_empty() and not row.open,"actual external obstacle blocks swing "+label_value)
				obstacle.queue_free();await sync_physics()
				check(b.toggle("test:gate").is_empty(),"obstacle removal permits opening "+label_value)
				await create_timer(.3).timeout
				world.player.position=at+safe;world.player.camera.force_update_scroll();await sync_physics()
				await shot("door-"+gate_kind+"-"+str(vertical)+"-"+str(swing_value)+"-open")
				check(node.gate_parts.size()==24 and node.y_sort_enabled,"leaf strips independently Y sorted "+label_value)
				check(node.gate_parts[0].position.distance_to(node.gate_parts[-1].position)>50,"sort follows actual rotated leaf contacts "+label_value)
	b.states.clear()
	for i in 3:
		b.states["wall"+str(i)]=b.candidate("stone_wall",anchor+Vector2(48+i*96,0),false,true,0)
	b.refresh_all();await sync_physics()
	check(not b.visuals.wall0.needs_joint(Grid.ends(b.states.wall0)[1]),"horizontal wall middle no repeated end post")
	check(b.visuals.wall0.needs_joint(Grid.ends(b.states.wall0)[0]),"horizontal exposed end keeps end post")
	var wall: Node2D=b.visuals.wall0
	check(Interaction.action_for(wall).is_empty(),"structure no inspect without hammer")
	s.inventory.equipment.main_hand=s.inventory.instance("stone_hammer")
	check(Interaction.action_for(wall)=="demolish","structure shows E only with equipped hammer")
	s.inventory.equipment.clear()
	for kind in ["wood_floor","stone_path","camp_torch","wood_chest","workbench"]:
		var recipe_id := ""
		for recipe in s.camps.build_book.recipes.values():
			if recipe.output_id==kind: recipe_id=recipe.recipe_id
		check(not recipe_id.is_empty(),"existing recipe retained "+kind)
		stock();world.player.position=center;world.player.camera.force_update_scroll()
		world.camp_ui.begin_build(recipe_id)
		world.item_ui.drag_pointer=Vector2(640,360)
		await sync_physics()
		world.item_ui.update_input_block()
		check(not world.player.input_blocked and world.camp_ui.placing,"movement allowed while placing "+kind)
		check(world.camp_ui.ghost.preview and world.camp_ui.ghost.scale==Vector2.ONE,"preview uses same unscaled runtime renderer "+kind)
		check(not world.camp_ui.ghost.is_in_group("world_interactables") and world.camp_ui.ghost.get_child_count()==0,"preview has no world collision or interactions "+kind)
		world.player.automated=true;world.player.input_override=Vector2.RIGHT;world.player.cancel_action()
		while not world.stream.viewport_ready(world.player.position,Vector2(root.size)/2.0): await frames()
		var before_move: Vector2=world.player.position
		world.player.set_physics_process(true)
		for i in 6: await physics_frame
		world.player.set_physics_process(false);world.player.input_override=Vector2.ZERO;world.player.automated=false
		check(world.player.position.distance_to(before_move)>0,"actual physics moves during build "+kind)
		for size_value in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
			root.size=size_value;await sync_physics();await shot("preview-"+kind+"-"+str(size_value.x))
		world.camp_ui.cancel_placement();world.item_ui.update_input_block()
	check(not b.serialize().is_empty(),"unchanged building snapshot schema available")


func sync_physics() -> void:
	await physics_frame
	await physics_frame
	await process_frame
