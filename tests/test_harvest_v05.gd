extends SceneTree
const OUT := "res://reports/harvest-v05/"
const Interaction = preload("res://scripts/world_interaction.gd")
const Config = preload("res://scripts/harvest_node.gd")
var checks: Array=[]
var failures: Array=[]
var world: Node
var service: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: failures.append(label);push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func shot(name_text: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_text+".png")
func equip(id: String) -> void:
	world.player.cancel_action()
	for i in 40:
		if service.inventory.slots[i].get("item_id","")==id:
			service.inventory.equip(i);return
func key_e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode=KEY_E;event.keycode=KEY_E;event.pressed=true
	root.push_input(event,true)
	await frames(2)
	event=InputEventKey.new();event.physical_keycode=KEY_E;event.keycode=KEY_E
	root.push_input(event,true)
	await frames(1)
func point(node: Node2D) -> void:
	var event := InputEventMouseMotion.new()
	event.position=root.get_canvas_transform()*(node.position+Vector2(0,-10));event.global_position=event.position
	root.push_input(event,true)
	await frames(3)
func animate_sheet() -> void:
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1080,1200)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var bg := ColorRect.new();bg.color=Color("e8e1c7");bg.size=Vector2(1080,1200);viewport.add_child(bg)
	var row := 0
	for action in ["mine","dig"]:
		var inv := ItemInventory.new(service.database)
		inv.add("stone_pickaxe" if action=="mine" else "simple_shovel",1);inv.equip(8)
		for facing in ["front","back","right","left"]:
			var view: String="side" if facing in ["right","left"] else facing
			var times: Array=[0,.32,.55,.72,1.1] if action=="mine" else [0,.24,.43,.68,1.10]
			for col in 5:
				var rig: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate()
				viewport.add_child(rig)
				rig.position=Vector2(35+210*col,32+145*row);rig.scale=Vector2.ONE*1.0
				var player: AnimationPlayer=rig.get_node("AnimationPlayer")
				player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				player.add_animation_library("harvest",load("res://assets/hero/cartoon/harvest_actions.tres"))
				player.play("harvest/"+view+"_"+action);player.seek(times[col],true)
				var held := preload("res://scripts/held_tool.gd").new();held.apply(rig,inv,facing,action)
				if facing=="left":rig.get_node("Visual").scale.x=-1;rig.get_node("Visual").position.x=128
				var label := Label.new();label.text="%s %s %.2fs"%[action,facing,times[col]];label.position=Vector2(12+210*col,12+145*row);label.add_theme_color_override("font_color",Color("493d30"));viewport.add_child(label)
				check(rig.get_node("Visual/ArmLBehind").show_behind_parent,"left arm stays behind "+action+facing+str(col))
			row+=1
	await frames(5);await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUT+"native-actions.png")
	viewport.queue_free();await frames()
func reload_chunk(c: Vector2i) -> void:
	var packet: Dictionary=world.generator.build_chunk(c)
	var stamps: Array[Dictionary]=[]
	packet["ground_stamps"]=stamps
	world.stream.install_chunk(packet)

func isolated() -> void:
	var db := ItemDatabase.new()
	check(db.errors.is_empty() and db.ids().size()==preload("res://tests/current_test_contract.gd").item_count(),"unique database: existing 15 plus bone/relic/pouch")
	for id in ["stone","flint","wild_carrot","bone_fragment","relic_fragment","supply_pouch"]:
		check(ResourceLoader.exists(db.item(id).icon) and ResourceLoader.exists(db.item(id).world_visual),"six real inventory/drop visuals "+id)
	var inv := ItemInventory.new(db)
	inv.add("supply_pouch",1)
	check(inv.use_slot(8),"pouch opens through existing use_slot")
	check(inv.slots[8].item_id=="wild_carrot" and inv.slots[8].count==2 and inv.slots[9].item_id=="flint" and inv.slots[10].item_id=="relic_fragment","pouch fixed rewards correct")
	check(inv.use_slot(8) and inv.slots[8].count==1,"root food keeps existing eat behavior")
	check(not inv.use_slot(10),"relic material cannot be consumed")
	for i in range(8,40): inv.slots[i]={"item_id":"wood","count":99}
	inv.slots[8]={"item_id":"supply_pouch","count":1}
	var original: Array=inv.slots.duplicate(true)
	check(not inv.use_slot(8) and inv.slots==original,"full bag pouch transaction rolls back all rewards and source")
func run() -> void:
	Engine.max_fps=60
	isolated()
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	service=world.item_service
	world.player.automated=true
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	for id in ["stone_axe","stone_pickaxe","simple_shovel"]:service.inventory.add(id,1)
	await animate_sheet()
	var total := 0
	var kinds := {}
	var samples: Array=[]
	# Loaded worker distributions provide real formal resources, no debug placement.
	for coord in world.stream.loaded:
		var packet: Dictionary=service.chunk_cache.get(coord,{})
		for row in packet.get("harvest",[]):
			total+=1;kinds[row.kind]=int(kinds.get(row.kind,0))+1
			check(world.generator.can_walk(Vector2(row.x,row.y),52) and service.ecology(Vector2(row.x,row.y)).shore<=.08,"formal candidate dry/shore clearance "+row.id)
	check(total>0,"formal loaded chunks naturally contain harvestable resources")
	var coord: Vector2i=world.stream.chunk_at(world.generator.spawn)
	var first: Dictionary=service.build_distribution(world.generator,service.rules,service.reachable,coord)
	var second: Dictionary=service.build_distribution(world.generator,service.rules,service.reachable,coord)
	check(first.harvest==second.harvest and first.accepted==second.accepted,"same Seed worker distributions identical")
	check(first.accepted==service.chunk_distribution(coord).accepted,"old natural distribution preserved by extra layer")
	# Sample additional formal chunks around actual biome nodes, bounded to this layer.
	for room in world.generator.rooms:
		if samples.size()>=18:break
		var p: Vector2=room.p
		var c: Vector2i=world.stream.chunk_at(p)
		var packet: Dictionary=service.build_distribution(world.generator,service.rules,service.reachable,c)
		samples.append({"coord":str(c),"count":packet.harvest.size()})
		for row in packet.harvest:kinds[row.kind]=int(kinds.get(row.kind,0))+1
	# Five explicit fixture targets on clear ground exercise all definitions even if rare.
	var base: Vector2=world.generator.spawn
	world.player.set_physics_process(false)
	for node in get_nodes_in_group("world_interactables"):node.queue_free()
	for drop in world.stream.drops.duplicate():
		if is_instance_valid(drop) and drop.position.distance_to(base)<150:world.stream.drops.erase(drop);drop.queue_free()
	await frames(3)
	var serial := 0
	for kind in Config.configuration().resources:
		serial+=1
		service.body.stamina=100;service.body.exhausted=false;service.body.energy=100
		var id: String="test:harvest:"+str(kind)
		var row := {"kind":kind,"x":base.x+30,"y":base.y+12}
		service.ore_nodes[id]=row
		var node: Node2D=service.create_harvest(id,row)
		world.player.position=base+Vector2(-8,12)
		world.player.reset_physics_interpolation();world.player.camera.reset_smoothing()
		await frames(5)
		var action: String=node.definition.action
		if int(node.definition.hits)==1:
			var single_expected: Dictionary=node.definition.drops.duplicate(true)
			for reward in single_expected:single_expected[reward]=int(single_expected[reward])
			equip("simple_shovel");await point(node)
			world.player.set_physics_process(true);await key_e();await create_timer(1.3).timeout;world.player.set_physics_process(false)
			check(service.consumed.has(id) and int(service.resource_hits.get(id,0))==1,"single-hit resource commits exactly once "+kind)
			var single_rewards := {}
			for loot in service.loose.values():
				if str(loot.id).begins_with(id+":loot:"):single_rewards[loot.item_id]=int(single_rewards.get(loot.item_id,0))+int(loot.count)
			check(single_rewards==single_expected,"single-hit resource yields one exact batch "+kind)
			world.player.cancel_action()
			continue
		for wrong in ["stone_axe","simple_shovel" if action=="mine" else "stone_pickaxe"]:
			equip(wrong)
			check(not Interaction.execute(world.stream,world.player,node) and not service.resource_hits.has(id),"wrong capability rejects "+kind+" "+wrong)
		service.inventory.unequip(40)
		check(not Interaction.execute(world.stream,world.player,node),"empty hand rejects "+kind)
		equip("stone_pickaxe" if action=="mine" else "simple_shovel")
		await point(node)
		check(world.player.selected_target()==node,"stable explicit E target "+kind)
		world.player.set_physics_process(true)
		await frames(6);await key_e()
		check(world.player.action==action and world.player.action_target==node,"native E starts dedicated action "+kind)
		await key_e();await key_e()
		world.player.input_override=Vector2.LEFT
		var before: Vector2=world.player.position
		await create_timer(.72).timeout
		world.player.input_override=Vector2.ZERO
		check(int(service.resource_hits.get(id,0))==1,"repeated E commits once "+kind)
		check(world.player.position.distance_to(before)<.1,"action locks movement and facing "+kind)
		check(node.position==Vector2(row.x,row.y) and node.rotation==0 and node.scale==Vector2.ONE,"resource remains anchored "+kind)
		check(float(node.hit_material.get_shader_parameter("damage_amount"))==1.0,"damage/reveal shader advances without swapping the anchored body "+kind)
		await shot(kind+"-hit")
		await create_timer(.60).timeout
		# Real unload/reinstall of a partial target, using the same chunk machinery.
		world.player.set_physics_process(false)
		var c: Vector2i=world.stream.chunk_at(node.position)
		world.stream.unload_chunk(c);await frames(3)
		reload_chunk(c);await frames(3)
		node=null
		for candidate in get_nodes_in_group("world_interactables"):
			if candidate.get_meta("ore_id","")==id:node=candidate;break
		check(node!=null and node.get_meta("progress","").begins_with("1/"),"partial progress survives actual chunk unload/reinstall "+kind)
		world.player.cancel_action();await point(node)
		# Switching the equipped tool interrupts pending work before impact.
		world.player.try_interact();service.inventory.unequip(40)
		check(world.player.action.is_empty() and int(service.resource_hits[id])==1,"unequip cancels pending hit "+kind)
		equip("stone_pickaxe" if action=="mine" else "simple_shovel")
		world.player.try_interact()
		world.player.position=base+Vector2(-180,0)
		world.player._physics_process(.1)
		check(world.player.action.is_empty() and int(service.resource_hits[id])==1,"leaving reach interrupts before impact "+kind)
		world.player.position=before
		# Complete remaining real actions with native input and clock.
		for hit in range(1,int(node.definition.hits)):
			await point(node);world.player.set_physics_process(true);await key_e();await create_timer(1.30).timeout;world.player.set_physics_process(false)
		check(service.consumed.has(id),"resource finishes after configured hit count "+kind)
		var expected: Dictionary=Config.configuration().resources[kind].drops
		if kind=="stone_outcrop":
			expected=expected.duplicate()
			expected.stone=12+int(abs(id.hash())%5)
			if abs((id+":flint").hash())%10<3:expected.flint=1
		for reward in expected: expected[reward]=int(expected[reward])
		var found := {}
		for loot in service.loose.values():
			if str(loot.id).begins_with(id+":loot:"):found[loot.item_id]=int(found.get(loot.item_id,0))+int(loot.count)
		check(found==expected,"exactly one configured reward batch "+kind)
		# Completed target cannot return after a second real chunk cycle.
		world.stream.unload_chunk(c);await frames(3);reload_chunk(c);await frames(3)
		var revived := false
		for candidate in get_nodes_in_group("world_interactables"):
			if candidate.get_meta("ore_id","")==id:revived=true
		check(not revived,"completed target never respawns "+kind)
		for drop in world.stream.drops.duplicate():
			if not is_instance_valid(drop) or not str(drop.get_meta("drop_id","")).begins_with(id+":loot:"):continue
			world.player.position=drop.position+Vector2(-22,0)
			world.player.reset_physics_interpolation();world.player.camera.reset_smoothing();await frames(3);await point(drop)
			var drop_id: String=drop.get_meta("drop_id","")
			world.player.set_physics_process(true);await key_e();await create_timer(.8).timeout;world.player.set_physics_process(false)
			check(not service.loose.has(drop_id),"reward uses original E pickup "+kind)
		world.player.position=base+Vector2(-8,12);world.player.cancel_action()
	# Isolated disk save, never touches the user's world files.
	world.persistent_world=true;service.save_path="user://test-harvest-v05-isolated.json"
	service.save_state()
	var stored: Dictionary=service.resource_hits.duplicate(true)
	service.resource_hits={};service.consumed={};service.load_state()
	var hit_equal: bool=true
	for id in stored: hit_equal=hit_equal and int(service.resource_hits.get(id,-1))==int(stored[id])
	check(hit_equal and service.consumed.has("test:harvest:buried_supply"),"atomic file reload preserves hits and depleted nodes")
	world.persistent_world=false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
	# Existing tool-specific chop and normal pickup through shared interaction.
	world.player.position=world.generator.spawn;equip("stone_axe")
	var tree: Node2D
	for candidate in get_nodes_in_group("trees"):
		var approach: Vector2=candidate.position+Vector2(45,12)
		if world.stream.tree_in_reach(approach,candidate):tree=candidate;world.player.position=approach;break
	if tree:
		var tree_id: String=tree.get_meta("prop_id");var old_hits: int=world.stream.tree_hits.get(tree_id,0)
		check(Interaction.execute(world.stream,world.player,tree) and int(world.stream.tree_hits.get(tree_id,0))==old_hits+1,"existing axe tree hit/drop path still works")
	world.player.cancel_action();world.item_ui.toggle_bag();await frames(5)
	check(world.item_ui.preview_actor.get_node("AnimationPlayer").current_animation=="front_breathe","bag preview remains fixed front idle")
	await shot("backpack-items")
	world.item_ui.close_panels()
	var file := FileAccess.open(OUT+"tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"count":checks.size(),"natural_loaded":total,"sampled_kinds":kinds,"sample_chunks":samples},"  "));file.close()
	print("HARVEST_V05 ",checks.size()," checks; ",failures.size()," failures")
	world.queue_free();await frames(8);quit(0 if failures.is_empty() else 1)



