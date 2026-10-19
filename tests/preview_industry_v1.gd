extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.set_meta("industry_preview",true);Engine.set_meta("integration_seed",271828)
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	var s=w.item_service;var p: Vector2=w.player.position
	while not w.stream.viewport_ready(p,Vector2(640,360)):await process_frame
	# Only this disposable fixture is arranged; player files are never loaded or saved.
	for n in get_nodes_in_group("trees")+get_nodes_in_group("world_interactables")+w.stream.drops:
		if is_instance_valid(n) and n.position.distance_to(p)<420:
			n.hide();n.set_meta("spent",true);n.set_meta("collected",true)
			for body in n.find_children("*","CollisionObject2D",true,false):body.collision_layer=0
	var kinds=["stone_furnace","metal_workbench","copper_oven","copper_lamp","reinforced_cabinet","feed_trough","refrigerator"]
	for i in kinds.size():
		var at: Vector2=p+Vector2(-240+(i%4)*160,-90 if i<4 else 110)
		add_build(s,kinds[i],kinds[i],at)
	var floor_at: Vector2=p+Vector2(240,110)
	add_build(s,"floor","wood_floor",floor_at);add_build(s,"wool_carpet","wool_carpet",floor_at)
	for id in ["wood","stone","flint","plant_fiber","branch","copper_ore","silver_ore","gold_ore","copper_ingot","silver_ingot","copper_plate","copper_parts","metal_connector","wool","wild_carrot","potato","cabbage","wild_berry","broad_leaf","egg"]:
		if not s.database.item(id).is_empty():s.inventory.add(id,40)
	for i in 6:s.inventory.slots[i]=s.inventory.instance(["copper_axe","copper_pickaxe","copper_shovel","copper_hammer","silver_lantern","fishing_rod"][i])
	s.inventory.slots[6]={"item_id":"roasted_carrot","count":2,"spoilage":1.0}
	s.inventory.slots[7]={"item_id":"egg_vegetable_bake","count":1,"spoilage":0.0}
	s.builds.states.refrigerator.contents[0]={"item_id":"roasted_carrot","count":3,"spoilage":.3}
	s.builds.states.reinforced_cabinet.contents[0]={"item_id":"gold_ingot","count":4}
	s.builds.states.feed_trough.machine.feed={"wild_berry":8,"broad_leaf":8}
	s.builds.states.copper_oven.machine.fuel=600
	s.builds.states.stone_furnace.machine.fuel=600
	s.inventory.changed.emit();w.title.text="工业与营地生活 V1 · 候选预览"
	w.player.camera.reset_smoothing()
	if "capture" in OS.get_cmdline_user_args():
		for i in 20:await process_frame
		root.get_texture().get_image().save_png("res://reports/industry-v1/scene-preview.png")
		w.free();quit()
func add_build(s: Node,id: String,kind: String,at: Vector2) -> void:
	var row: Dictionary=s.builds.candidate(kind,at,false,false,0)
	s.builds.states[id]=row;s.builds.install(s.world.stream.chunk_at(Vector2(row.x,row.y)))
