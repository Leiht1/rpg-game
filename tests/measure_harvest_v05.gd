extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	var world: Node=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	world.player.set_physics_process(false)
	var service: Node=world.item_service
	var rows: Array=[]
	for offset in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1)]:
		var c: Vector2i=world.stream.chunk_at(world.generator.spawn)+offset
		var result: Dictionary=service.build_distribution(world.generator,service.rules,service.reachable,c)
		rows.append({"chunk":str(c),"harvest_ms":result.harvest_ms,"all_resource_ms":result.ms,"new_nodes":result.harvest.size()})
	var slot := 8
	service.inventory.slots[slot]={"item_id":"supply_pouch","count":1}
	var message: String=world.item_ui.use_failure(slot)
	var ok: bool=message=="背包空间不足，补给包保持原样"
	var f := FileAccess.open("res://reports/harvest-v05/timing.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"generation_samples":rows,"pouch_capacity_message":ok,"note":"Three resource-layer worker samples, not an FPS benchmark; terrain/scenery costs excluded."},"  "));f.close()
	print("HARVEST_TIMING ",JSON.stringify(rows)," message=",ok)
	world.queue_free();for i in 5:await process_frame
	quit(0 if ok else 1)
