extends SceneTree
const OUT := "res://reports/ores-v06/"
var world: Node
func _initialize() -> void:call_deferred("run")
func frames(n: int=3) -> void:
	for i in n:await process_frame
func shot(name_text: String) -> void:
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+name_text+".png")
func run() -> void:
	Engine.max_fps=60;Engine.set_meta("integration_seed",271828)
	DisplayServer.window_set_title("矿石造型验证 · 自动关闭")
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	world.player.set_physics_process(false);world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	var service: Node=world.item_service
	var p: Vector2=world.generator.spawn
	for room in world.generator.rooms:
		if preload("res://scripts/harvest_distribution.gd").dirt_region(world.generator,room.p):p=room.p;break
	world.player.position=p+Vector2(0,130);world.player.reset_physics_interpolation();world.player.camera.reset_smoothing();world.stream.update_target(world.player.position)
	var deadline := Time.get_ticks_msec()+25000
	while not world.stream.viewport_ready(world.player.position,Vector2(root.size)/2) and Time.get_ticks_msec()<deadline:await process_frame
	for node in get_nodes_in_group("world_interactables"):
		if node.position.distance_to(p)<500:node.queue_free()
	await frames()
	var kinds: Array=["stone_outcrop","flint_outcrop","copper_outcrop","silver_outcrop","gold_outcrop"]
	for i in kinds.size():
		var node: Node2D=service.create_harvest("capture:"+str(i),{"kind":kinds[i],"x":p.x-300+i*150,"y":p.y-25})
		var label := Label.new();label.text=node.definition.name+" · "+str(int(node.definition.hits))+"次";label.position=Vector2(-40,12);label.add_theme_font_size_override("font_size",13);label.add_theme_color_override("font_color",Color("fff5da"));label.add_theme_color_override("font_shadow_color",Color("413b2e"));label.add_theme_constant_override("shadow_outline_size",3);node.add_child(label)
	await frames(8);await shot("five-mines-dirt")
	service.inventory.slots[0]=service.inventory.instance("stone_pickaxe");service.inventory.use_slot(0)
	for pair in [["stone",5],["flint",3],["copper_ore",4],["silver_ore",3],["gold_ore",2]]:service.inventory.add(pair[0],pair[1])
	world.item_ui.toggle_bag();await frames(5);await shot("raw-metal-inventory");world.item_ui.close_panels()
	for kind in ["silver_outcrop","gold_outcrop"]:
		var target: Node2D=service.create_harvest("capture:hit:"+kind,{"kind":kind,"x":p.x+50,"y":p.y+12})
		world.player.position=p;world.player.reset_physics_interpolation();world.player.camera.reset_smoothing()
		world.player.action="mine";world.player.facing="right";world.player.action_target=target;world.player.action_clock=.55
		service.resource_hits[str(target.resource_id)]=1;target.refresh_stage();world.player.update_animation();await frames(7);await shot(kind+"-mining")
		world.player.cancel_action();target.queue_free();await frames()
	print("ORE_CAPTURE native dirt gallery, raw inventory, silver/gold contact frames saved")
	world.queue_free();await frames(8);quit()
