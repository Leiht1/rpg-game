extends SceneTree
var failures := 0
func _initialize() -> void:run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("CHECK ",ok," ",label)
	if not ok:failures+=1
func run() -> void:
	var w=load("res://scripts/network_game_host_world.gd").new()
	w.bootstrap={"id":"restore-batch-test","seed":271828,"map_cells":128}
	root.add_child(w);current_scene=w
	while not w.started:await process_frame
	w.set_process(false);w.item_service.set_process(false);w.environment_view.set_process(false);w.player.set_physics_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	w.stream.set_process(false)
	var s=w.item_service
	s.builds.states.clear();s.builds.refresh_all()
	await process_frame
	for x in range(-5,6):
		for y in range(-5,6):
			var row=s.builds.candidate("wood_floor",w.player.position+Vector2(x*96,y*64),false,false,0)
			s.builds.states[str(x)+":"+str(y)]=row
	s.builds.refresh_all();await process_frame
	for i in 4:
		var old=s.builds.visuals.values().duplicate()
		var before: int=w.object_root.get_child_count()
		var snap=s.snapshot()
		for row in snap.buildings.objects.values():row.hits=(i+1)%2
		s.load_state("",false,snap)
		check(s.writable,"validated restore")
		check(w.object_root.get_child_count()-before<=s.builds.visuals.size(),"each visible building instantiated at most once")
		for node in old:check(node.body.collision_layer==0,"retired collider disabled immediately")
		check(s.builds.states==snap.buildings.objects,"restored building state exact")
		await process_frame
	var snap=s.snapshot();snap.buildings.objects={}
	s.load_state("",false,snap)
	check(s.writable and s.builds.visuals.is_empty(),"deletion restore removes all building visuals")
	await process_frame
	print("FAILURES ",failures)
	quit(1 if failures else 0)
