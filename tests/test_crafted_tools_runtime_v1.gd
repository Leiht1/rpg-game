extends SceneTree
const OUT := "res://reports/crafting-progress-v1/"
const Interaction = preload("res://scripts/world_interaction.gd")
var checks: Array=[]
var world: Node
var service: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func key(pressed: bool) -> void:
	var event := InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=pressed
	Input.parse_input_event(event);await frames(2)
func point(target: Node2D) -> void:
	var event := InputEventMouseMotion.new();event.position=root.get_canvas_transform()*(target.position+Vector2(0,-10));event.global_position=event.position
	root.push_input(event,true);await frames(3)
func equip(id: String) -> void:
	world.player.cancel_action()
	for i in 40:
		if service.inventory.slots[i].get("item_id","")==id:
			service.inventory.equip(i);return
func run() -> void:
	Engine.max_fps=60;Engine.time_scale=3.0;Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	service=world.item_service;world.player.automated=true;world.player.set_physics_process(false)
	var identities := {}
	for pair in [["hand_stone_axe","stone_axe"],["hand_stone_pickaxe","stone_pickaxe"],["hand_simple_shovel","simple_shovel"]]:
		var recipe: Dictionary=service.craft_book.recipe(pair[0])
		for id in recipe.materials:service.inventory.add(str(id),int(recipe.materials[id]))
		check(service.start_craft(pair[0],1).is_empty(),"start actual timed tool "+pair[1])
		var deadline := Time.get_ticks_msec()+5000
		while not service.craft_job.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
		check(service.craft_job.is_empty() and service.inventory.count_item(pair[1])==1,"timed tool reaches original inventory "+pair[1])
		for row in service.inventory.slots:
			if row.get("item_id","")==pair[1]:identities[pair[1]]=row.instance_id
	check(identities.values().size()==3 and identities.values()[0]!=identities.values()[1] and identities.values()[1]!=identities.values()[2],"crafted tools are distinct native instances")
	var tree: Node2D
	var approach := Vector2.ZERO
	for node in get_nodes_in_group("trees"):
		for offset in [Vector2(0,48),Vector2(48,0),Vector2(-48,0)]:
			var at: Vector2=node.position+offset
			if world.generator.can_walk(at,12) and world.stream.tree_in_reach(at,node):tree=node;approach=at;break
		if tree!=null:break
	check(tree!=null,"reachable original tree exists")
	if tree!=null:
		equip("stone_axe");world.player.position=approach;world.player.reset_physics_interpolation();world.player.camera.reset_smoothing();await frames(8)
		var id: String=tree.get_meta("prop_id");var before: int=int(world.stream.tree_hits.get(id,0))
		await point(tree);world.player.set_physics_process(true);await key(true);await key(false);await create_timer(.95).timeout
		check(service.inventory.has_capability("chop") and (int(world.stream.tree_hits.get(id,0))==before+1 or world.stream.harvested.has(id)),"crafted equipped axe commits native E chop")
		world.player.set_physics_process(false);world.player.cancel_action()
	var p: Vector2=world.generator.spawn
	for node in get_nodes_in_group("world_interactables"):node.queue_free()
	for drop in world.stream.drops.duplicate():
		if is_instance_valid(drop):world.stream.drops.erase(drop);drop.queue_free()
	await frames()
	for pair in [["stone_outcrop","stone_pickaxe","mine"],["buried_bone","simple_shovel","dig"]]:
		var id: String="crafted-tool:"+pair[2]
		var target: Node2D=service.create_harvest(id,{"kind":pair[0],"x":p.x+50,"y":p.y+12})
		equip(pair[1]);world.player.position=p;world.player.reset_physics_interpolation();world.player.camera.reset_smoothing();await frames(8)
		await point(target)
		check(world.player.selected_target()==target,"crafted tool selects original target "+pair[2])
		var hits: int=target.definition.hits
		world.player.set_physics_process(true);await key(true)
		var deadline := Time.get_ticks_msec()+12000
		while not service.consumed.has(id) and Time.get_ticks_msec()<deadline:await process_frame
		await key(false);await create_timer(.8).timeout;world.player.set_physics_process(false);world.player.cancel_action()
		check(service.consumed.has(id) and int(service.resource_hits.get(id,0))==hits,"crafted tool completes configured native hits "+pair[2])
		var rewards := {}
		for row in service.loose.values():
			if str(row.id).begins_with(id+":loot:"):rewards[row.item_id]=int(row.count)
		check(not rewards.is_empty(),"native resource rewards created exactly after completion "+pair[2])
		for drop in world.stream.drops.duplicate():
			if is_instance_valid(drop) and str(drop.get_meta("drop_id","")).begins_with(id):
				world.stream.drops.erase(drop)
				drop.queue_free()
		await frames()
	# Ordinary E pickup remains available with a crafted tool equipped.
	var entry := {"id":"crafted-tool:pickup","item_id":"branch","count":1,"x":p.x+12,"y":p.y+12,"origin":"player","mode":"pickup"}
	service.loose[entry.id]=entry
	var drop: Node2D=world.stream.create_item_drop(entry)
	world.player.position=p;world.player.reset_physics_interpolation();world.player.camera.reset_smoothing();await frames(8);await point(drop)
	var before: int=service.inventory.count_item("branch")
	world.player.set_physics_process(true);await key(true);await key(false);await create_timer(.8).timeout
	check(service.inventory.count_item("branch")==before+1 and not service.loose.has(entry.id),"crafted tool does not block ordinary E pickup")
	var failed := checks.filter(func(row):return not row.pass).size()
	FileAccess.open(OUT+"crafted-tools-runtime.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("CRAFTED TOOLS: ",checks.size()," checks; ",failed," failures; headless time_scale=3")
	service.dirty=false;world.queue_free();await frames(6);quit(0 if failed==0 else 1)
