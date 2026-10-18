extends SceneTree
const OUT := "res://reports/harvest-fix-v051/"
var checks: Array=[]
var world: Node
var service: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func inventory_checks() -> void:
	var db := ItemDatabase.new()
	var inv := ItemInventory.new(db)
	for pair in [["stone_axe",0],["stone_pickaxe",1],["simple_shovel",2]]:
		inv.add(pair[0],1)
		for i in range(8,40):
			if inv.slots[i].get("item_id","")==pair[0]:inv.move_slot(i,pair[1]);break
	for repeat in 4:
		for pair in [["stone_axe",0],["stone_pickaxe",1],["simple_shovel",2]]:
			check(inv.use_slot(pair[1]),"hotkey equips "+pair[0]+str(repeat))
			check(inv.get_slot(pair[1]).item_id==pair[0] and inv.equipment.main_hand.item_id==pair[0],"hotbar icon remains same equipped instance "+pair[0]+str(repeat))
			var ids := {}
			for slot in inv.slots+inv.equipment.values():
				if slot.has("instance_id"):ids[slot.instance_id]=int(ids.get(slot.instance_id,0))+1
			check(ids.size()==3 and ids.values().all(func(n):return n==1),"exactly three single-owned tool instances "+str(repeat)+pair[0])
	var restored := ItemInventory.new(db)
	check(restored.restore(inv.slots) and restored.restore_equipment(inv.equipment),"aliased tools pass duplicate-safe restore")
	restored.restore_hotbar_links(inv.hotbar_equipment)
	check(restored.get_slot(2).item_id=="simple_shovel" and restored.use_slot(0) and restored.get_slot(2).item_id=="simple_shovel","hotbar links restore and previous tool returns to own key")
	check(restored.move_slot(0,5) and restored.get_slot(0).is_empty() and restored.get_slot(5).item_id=="stone_axe","active alias moves to empty hotbar without cloning")
	check(restored.move_slot(5,8) and restored.equipment.main_hand.is_empty() and restored.get_slot(5).is_empty() and restored.slots[8].item_id=="stone_axe","drag active alias to bag unequips single instance")
	# An unbound worn item returns to the bag when a bound hotkey tool replaces it.
	var other := ItemInventory.new(db);other.add("stone_axe",1);other.equip(8);other.add("stone_pickaxe",1);other.move_slot(8,1)
	check(other.use_slot(1) and other.get_slot(1).item_id=="stone_pickaxe" and other.slots[8].item_id=="stone_axe","unbound previous equipment returns to free bag slot")
func key(code: int,pressed: bool) -> void:
	var e := InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e);await frames(2)
func run() -> void:
	Engine.max_fps=60
	inventory_checks()
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	service=world.item_service;world.player.automated=true;world.player.set_physics_process(false)
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	var p: Vector2=world.generator.spawn
	for node in get_nodes_in_group("world_interactables"):node.queue_free()
	for drop in world.stream.drops.duplicate():
		if is_instance_valid(drop) and drop.position.distance_to(p)<160:world.stream.drops.erase(drop);drop.queue_free()
	await frames()
	for kind in preload("res://scripts/harvest_node.gd").configuration().resources:
		for drop in world.stream.drops.duplicate():
			if is_instance_valid(drop) and drop.position.distance_to(p)<160:world.stream.drops.erase(drop);drop.queue_free()
		await frames()
		var id: String="followup:"+str(kind)
		var row := {"kind":kind,"x":p.x+34,"y":p.y+12}
		var node: Node2D=service.create_harvest(id,row)
		var texture: Texture2D=node.sprite.texture
		var transform: Transform2D=node.sprite.transform
		for hits in range(int(node.definition.hits)+1):
			service.resource_hits[id]=hits;node.refresh_stage()
			check(node.sprite.texture==texture and node.sprite.transform==transform,"no stage translation or silhouette swap "+kind+str(hits))
		service.resource_hits.erase(id);node.refresh_stage()
		if kind not in ["stone_outcrop","buried_bone"]:node.queue_free();await frames();continue
		var action: String=node.definition.action
		service.inventory.equipment.main_hand=service.inventory.instance("stone_pickaxe" if action=="mine" else "simple_shovel");service.inventory.changed.emit()
		world.player.position=p+Vector2(-8,12);world.player.reset_physics_interpolation();world.player.camera.reset_smoothing();await frames(8)
		var motion := InputEventMouseMotion.new();motion.position=root.get_canvas_transform()*(node.position+Vector2(0,-10));motion.global_position=motion.position;root.push_input(motion,true);await frames()
		world.player.set_physics_process(true)
		await key(KEY_E,true)
		await create_timer(1.40).timeout
		check(int(service.resource_hits.get(id,0))==1 and world.player.action==action,"held E begins second native cycle "+action)
		await key(KEY_E,false)
		await create_timer(1.28).timeout
		check(int(service.resource_hits.get(id,0))==2 and world.player.action.is_empty(),"release finishes current cycle and stops "+action)
		# Hold again to complete exactly once, never advance to a different object.
		await key(KEY_E,true);await create_timer(1.8).timeout;await key(KEY_E,false)
		check(service.consumed.has(id) and int(service.resource_hits[id])==int(node.definition.hits) if is_instance_valid(node) else service.consumed.has(id),"held E completes resource once "+action)
		world.player.set_physics_process(false);world.player.cancel_action()
	# Native keyboard equips physical hotbar tools and leaves current icon visible.
	for pair in [["stone_axe",0],["stone_pickaxe",1],["simple_shovel",2]]:service.inventory.slots[pair[1]]=service.inventory.instance(pair[0])
	service.inventory.equipment={};service.inventory.hotbar_equipment={};service.inventory.changed.emit()
	for code in [KEY_1,KEY_2,KEY_3,KEY_1]:
		await key(code,true);await key(code,false)
		var index: int=code-KEY_1
		check(service.inventory.get_slot(index).get("instance_id","")==service.inventory.equipment.main_hand.instance_id and world.item_ui.cells[index].icon.texture!=null,"native number key switches and retains icon "+str(code))
	# Real disk round trip includes references and no second physical item.
	world.persistent_world=true;service.save_path="user://test-harvest-followup.json";service.save_state()
	service.inventory.hotbar_equipment={};service.load_state()
	check(service.writable and service.inventory.get_slot(0).item_id=="stone_axe" and service.inventory.slots[0].is_empty(),"disk restore keeps active shortcut reference without duplicate")
	world.persistent_world=false;DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
	# Grounded contact and immutable silhouettes at all stages, in actual game terrain.
	world.player.position=p;world.player.reset_physics_interpolation();world.player.camera.reset_smoothing()
	for node in get_nodes_in_group("world_interactables"):node.queue_free()
	await frames()
	var col := 0
	for kind in preload("res://scripts/harvest_node.gd").configuration().resources:
		for phase in 3:
			var id: String="gallery:"+str(kind)+str(phase)
			var node: Node2D=service.create_harvest(id,{"kind":kind,"x":p.x-250+col*115,"y":p.y-90+phase*80})
			service.resource_hits[id]=roundi(float(phase)*float(node.definition.hits)/2);node.refresh_stage()
		col+=1
	await frames(10);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"grounded-stages.png")
	world.item_ui.toggle_bag();await frames(5);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"hotbar-equipped.png")
	var failed := checks.filter(func(row):return not row.pass)
	var f := FileAccess.open(OUT+"tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":checks.size(),"checks":checks,"failures":failed},"  "));f.close()
	print("HARVEST_FOLLOWUP ",checks.size()," checks; ",failed.size()," failures")
	world.queue_free();await frames(8);quit(0 if failed.is_empty() else 1)

