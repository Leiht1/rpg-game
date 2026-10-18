extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var w: Node=load("res://prototypes/sleep-v1/preview_world.gd").new();root.add_child(w)
	while not w.sleep_samples_ready: await process_frame
	var ok: bool=not w.persistent_world and w.environment_view.save_path.is_empty() and absf(w.item_service.body.energy-25)<.1 and w.item_service.inventory.count_item("sleeping_bag")==3 and w.item_service.builds.states.values().any(func(r):return r.kind=="workbench") and w.item_service.builds.states.values().any(func(r):return r.kind=="wood_bed" and r.vertical)
	print("Preview status: persistent=",w.persistent_world," env_path=",w.environment_view.save_path," energy=",w.item_service.body.energy," samples=",w.item_service.builds.states.values().map(func(r):return [r.kind,r.vertical]))
	print("SLEEP PREVIEW ENTRY: ","PASS" if ok else "FAIL")
	w.item_service.dirty=false;w.queue_free()
	for i in 6: await process_frame
	quit(0 if ok else 1)
