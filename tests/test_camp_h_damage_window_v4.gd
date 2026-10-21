extends "res://tests/test_camp_build_v4.gd"
func run() -> void:
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	world.player.set_physics_process(false);world.environment_view.simulation.paused=true
	s=world.item_service;b=s.builds
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"restart.json"))
	var r: Dictionary=saved.buildings.objects["show:h:0:0"]
	var anchor := Vector2(r.x-48,r.y)
	await h_and_damage_checks(anchor)
	var failed: Array=checks.filter(func(v): return not v.pass)
	FileAccess.open(OUT+"h-damage-window-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"  "))
	print("H/DAMAGE WINDOW: %d checks, %d failed"%[checks.size(),failed.size()])
	world.persistent_world=false;world.free();await frames(6);quit(0 if failed.is_empty() else 1)
