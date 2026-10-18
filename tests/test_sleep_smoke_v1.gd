extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var formal := "--formal" in OS.get_cmdline_user_args()
	Engine.set_meta("sleep_preview",not formal)
	var world: Node=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	var ok := true
	if formal:
		var s=world.item_service;var v=world.environment_view
		v.set_process(false);v.simulation.paused=false
		ok=not s.craft_book.recipes.bench_sleeping_bag.default_unlocked and not s.camps.build_book.recipes.build_wood_bed.default_unlocked and preload("res://scripts/sleep_controller.gd").art_path("wood_bed").is_empty()
		s.body.energy=0
		ok=ok and v.try_start_sleep(true)
		v.advance_gameplay(1.5)
		ok=ok and s.body.sleeping and s.body.sleep_forced and world.player.animation_player.current_animation=="sleep/breathe"
		ok=ok and is_equal_approx(v.simulation.time_scale,1.0)
	print("SLEEP SMOKE ","FORMAL " if formal else "", "PASS" if ok else "FAIL")
	world.item_service.dirty=false;world.queue_free()
	for i in 4: await process_frame
	quit(0 if ok else 1)
