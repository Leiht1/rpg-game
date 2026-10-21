extends SceneTree
var world: Node
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var baseline: int=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for i in 20:
		var temporary=preload("res://scripts/item_service.gd").new()
		temporary.free()
	var workers_clean: bool=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline
	world=preload("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(world)
	while not world.started:await process_frame
	for i in 5:await process_frame
	world.item_service.dirty=false
	world.queue_free()
	for i in 8:await process_frame
	print("RUNTIME_EXIT_ORPHANS_BEGIN")
	Node.print_orphan_nodes()
	print("RUNTIME_EXIT_ORPHANS_END")
	var world_clean: bool=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline
	print("RUNTIME_EXIT 2 checks; ",0 if workers_clean and world_clean else 1," failures")
	quit(0 if workers_clean and world_clean else 1)
