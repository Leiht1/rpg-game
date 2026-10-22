extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	var world=load("res://scripts/network_game_host_world.gd").new()
	world.bootstrap={"id":"snapshot-performance-isolated","seed":271828,"map_cells":1536}
	root.add_child(world);current_scene=world
	while not world.started:await process_frame
	await create_timer(.5).timeout
	world.set_meta("network_game",true)
	var service=world.item_service
	var snapshot:Dictionary=service.snapshot()
	print("BUILDINGS ",snapshot.buildings.objects.size())
	for i in 4:
		var clock:=Time.get_ticks_usec()
		service.load_state("",false,snapshot)
		print("SNAPSHOT_MS ",(Time.get_ticks_usec()-clock)/1000.0)
		assert(service.writable)
		await process_frame
	var buildings=service.builds
	var first:Dictionary=buildings.candidate("wood_chest",world.player.position,false,true,0)
	var second:Dictionary=buildings.candidate("wood_chest",world.player.position+Vector2(120,0),false,true,0)
	first.contents[0]={"item_id":"wood","count":2}
	var data:Dictionary={"version":1,"grid_version":1,"abandoned_version":1,"objects":{"a":first,"b":second}}
	assert(buildings.validate(data.duplicate(true),{}))
	var restored:Dictionary=data.duplicate(true)
	assert(buildings.validate(restored,{}))
	assert(restored.objects.a.contents[0].count==2 and restored.objects.b.contents[0].is_empty())
	restored.objects.b.contents[0]={"item_id":"stone","count":3}
	assert(buildings.validate(restored,{}) and restored.objects.a.contents[0].item_id=="wood" and restored.objects.b.contents[0].item_id=="stone")
	restored.objects.b.contents[0]=false
	assert(not buildings.validate(restored,{}))
	restored.objects.b.contents[0]={"item_id":"wood","count":999999}
	assert(not buildings.validate(restored,{}))
	restored=data.duplicate(true)
	var tool:Dictionary=service.inventory.instance("stone_axe")
	restored.objects.a.contents[0]=tool.duplicate(true);restored.objects.b.contents[0]=tool.duplicate(true)
	assert(not buildings.validate(restored,{}))
	print("SNAPSHOT_VALIDATION_PASS 11")
	quit()
