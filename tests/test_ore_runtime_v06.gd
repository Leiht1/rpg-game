extends SceneTree
const OUT := "res://reports/ores-v06/"
var world: Node
var service: Node
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func frames(n: int=3) -> void:
	for i in n:await process_frame
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func point(node: Node2D) -> void:
	var e := InputEventMouseMotion.new();e.position=root.get_canvas_transform()*(node.position+Vector2(0,-12));e.global_position=e.position;root.push_input(e,true);await frames(3)
func key(code: int,pressed: bool) -> void:
	var e := InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed;Input.parse_input_event(e);await frames(2)
func shot(name_text: String) -> void:
	if DisplayServer.get_name()=="headless": await frames(2);return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+name_text+".png")
func run() -> void:
	Engine.max_fps=60;Engine.time_scale=4.0 if DisplayServer.get_name()=="headless" else 1.0;Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	service=world.item_service;world.player.automated=true;world.player.set_physics_process(false)
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	check(service.database.errors.is_empty() and service.database.ids().size()==21,"21 stable item definitions including three raw metal ores")
	for id in ["copper_ore","silver_ore","gold_ore"]:check(service.texture(id,"icon")!=null and service.texture(id,"world")!=null,"real metal icon/drop visual "+id)
	check(get_nodes_in_group("rocks").is_empty(),"formal loaded world contains no old scenery rocks")
	var bad_loose := false
	for drop in world.stream.drops:
		if drop.get_meta("natural",false) and drop.get_meta("item_id","")=="stone":bad_loose=true
	check(not bad_loose,"formal loaded world contains no generated loose stone")
	# Upgrade a genuine isolated version1 snapshot, without resetting any old belongings.
	service.inventory.add("stone_pickaxe",1);service.inventory.move_slot(8,0);service.inventory.use_slot(0)
	service.resource_hits["harvest:1:preserve-buried"]=1;service.consumed["harvest:1:old-mined"]=true
	var instance: Dictionary=service.inventory.equipment.main_hand.duplicate(true)
	world.persistent_world=true;service.save_path="user://test-ore-upgrade-v06.json"
	var legacy: Dictionary=service.snapshot();legacy.harvest_version="harvest-resources-1.0.0";legacy.erase("props_version")
	var file := FileAccess.open(service.save_path,FileAccess.WRITE);file.store_string(JSON.stringify(legacy));file.close()
	service.load_state()
	check(service.writable and service.inventory.equipment.main_hand.instance_id==instance.instance_id and service.inventory.get_slot(0).instance_id==instance.instance_id,"old save upgrades without losing equipped tool/hotbar reference")
	check(int(service.resource_hits["harvest:1:preserve-buried"])==1 and service.consumed.has("harvest:1:old-mined"),"old buried progress and consumed history retained")
	service.save_state();var upgraded=JSON.parse_string(FileAccess.get_file_as_string(service.save_path))
	check(upgraded.harvest_version==world.item_service.HARVEST_VERSION and upgraded.props_version==world.Gen.PROP_VERSION,"next atomic write records upgraded resource/prop policy")
	world.persistent_world=false;DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
	# Find actual dry dirt, then wait for its original streamed world to load.
	var p: Vector2=world.generator.spawn
	var found := false
	for room in world.generator.rooms:
		if not preload("res://scripts/harvest_distribution.gd").dirt_region(world.generator,room.p):continue
		for offset in [Vector2.ZERO,Vector2(150,0),Vector2(-150,0),Vector2(0,150)]:
			var candidate: Vector2=room.p+offset
			if service.ground_clear(candidate,65,service.nearby_props(candidate),false):p=candidate;found=true;break
		if found:break
	check(found,"actual brown dirt region found for native mine/visual checks")
	world.player.position=p;world.player.reset_physics_interpolation();world.player.camera.reset_smoothing();world.stream.update_target(p)
	var deadline := Time.get_ticks_msec()+30000
	while not world.stream.viewport_ready(p,Vector2(root.size)/(world.player.camera.zoom*2)) and Time.get_ticks_msec()<deadline:await process_frame
	check(world.stream.has_ground(p),"actual dirt terrain loaded")
	var ids: Array=["stone_outcrop","flint_outcrop","copper_outcrop","silver_outcrop","gold_outcrop"]
	var expected_hits: Array=[5,7,9,12,16]
	for index in ids.size():
		var kind: String=ids[index]
		world.player.cancel_action()
		for node in get_nodes_in_group("world_interactables"):
			if node.position.distance_to(p)<220:node.queue_free()
		for drop in world.stream.drops.duplicate():
			if is_instance_valid(drop) and drop.position.distance_to(p)<200:world.stream.drops.erase(drop);drop.queue_free()
		await frames(3)
		var id := "native:ore:"+kind
		var target: Node2D=service.create_harvest(id,{"kind":kind,"x":p.x+50,"y":p.y+12})
		world.player.position=p;world.player.reset_physics_interpolation();world.player.camera.reset_smoothing();await frames(8)
		check(int(target.definition.hits)==expected_hits[index],"quality-scaled hit count "+kind)
		var original: Texture2D=target.sprite.texture
		var transform: Transform2D=target.sprite.transform
		await point(target)
		check(world.player.selected_target()==target,"E selects mineable large outcrop "+kind)
		world.player.set_physics_process(true);await key(KEY_E,true)
		await create_timer(.65).timeout
		check(int(service.resource_hits.get(id,0))==1 and target.sprite.texture==original and target.sprite.transform==transform,"one native impact keeps fixed large body "+kind)
		check(world.player.held_tool.strike_layer.visible,"side tool remains drawn in front of large mine "+kind)
		await shot(kind+"-mining")
		deadline=Time.get_ticks_msec()+25000
		while not service.consumed.has(id) and Time.get_ticks_msec()<deadline:await process_frame
		await key(KEY_E,false);await create_timer(.75).timeout;world.player.set_physics_process(false)
		check(service.consumed.has(id) and int(service.resource_hits.get(id,0))==expected_hits[index],"held E completes exactly configured hits "+kind)
		var expected: Dictionary=preload("res://scripts/harvest_node.gd").configuration().resources[kind].drops
		var rewards := {}
		for row in service.loose.values():
			if str(row.id).begins_with(id+":loot:"):rewards[row.item_id]=int(row.count)
		for item in expected:expected[item]=int(expected[item])
		check(rewards==expected,"one exact configured reward batch "+kind)
		for drop in world.stream.drops.duplicate():
			if not is_instance_valid(drop) or not str(drop.get_meta("drop_id","")).begins_with(id+":loot:"):continue
			var drop_id: String=drop.get_meta("drop_id")
			world.player.position=drop.position+Vector2(-24,0);world.player.reset_physics_interpolation();world.player.camera.reset_smoothing();await frames(5);await point(drop)
			world.player.set_physics_process(true);await key(KEY_E,true);await key(KEY_E,false);await create_timer(.85).timeout;world.player.set_physics_process(false)
			check(not service.loose.has(drop_id),"existing E picks mined material into original inventory "+kind+drop_id)
	# Three raw materials persist with the same equipped instance, no inventory reset.
	world.player.cancel_action();world.persistent_world=true;service.save_path="user://test-ore-inventory-v06.json";service.save_state()
	service.inventory.slots.clear();for i in 40:service.inventory.slots.append({})
	service.load_state()
	for id in ["copper_ore","silver_ore","gold_ore"]:check(service.inventory.slots.any(func(row):return row.get("item_id","")==id),"new ore inventory persists "+id)
	world.persistent_world=false;DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
	# Fixed full-body gallery on actual dirt, then native bag showing all raw ores.
	world.player.position=p+Vector2(0,130);world.player.reset_physics_interpolation();world.player.camera.reset_smoothing()
	for node in get_nodes_in_group("world_interactables"):
		if node.position.distance_to(p)<500:node.queue_free()
	await frames()
	for i in ids.size():
		var node: Node2D=service.create_harvest("gallery:ore:"+str(i),{"kind":ids[i],"x":p.x-300+i*150,"y":p.y-25})
		var label := Label.new();label.text=node.definition.name+" · "+str(int(node.definition.hits))+"次";label.position=Vector2(-40,12);label.add_theme_font_size_override("font_size",13);label.add_theme_color_override("font_color",Color("fff5da"));label.add_theme_color_override("font_shadow_color",Color("413b2e"));label.add_theme_constant_override("shadow_outline_size",3);node.add_child(label)
	await frames(12);await shot("five-mines-dirt")
	world.item_ui.toggle_bag();await frames(6);await shot("raw-metal-inventory")
	var failed := checks.filter(func(row):return not row.pass)
	file=FileAccess.open(OUT+"runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify({"count":checks.size(),"failures":failed,"checks":checks,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"time_scale":Engine.time_scale},"  "));file.close()
	print("ORE_RUNTIME ",checks.size()," checks; ",failed.size()," failures")
	world.queue_free();await frames(8);quit(0 if failed.is_empty() else 1)



