extends "res://tests/test_camp_door_v3.gd"
func run() -> void:
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	world.player.set_physics_process(false);s=world.item_service;b=s.builds
	var at: Vector2=world.generator.spawn.snapped(Vector2(96,64))+Vector2(0,32)
	var row: Dictionary=b.candidate("fence_gate",at,true,true,0)
	b.states={"corner":row,"neighbor":b.candidate("wood_fence",at+Vector2(48,-32),false,true,0)}
	b.refresh_all();world.player.position=at+Vector2(-30,0);await sync_physics()
	world.persistent_world=true;s.save_path="res://reports/camp-door-v3/intentionally-missing/items.json"
	check(not b.toggle("corner").is_empty() and not row.open and not row.has("hinge_end"),"failed save rolls back open swing and absent legacy hinge field")
	check(is_equal_approx(b.visuals.corner.gate_angle,PI*.5),"failed save does not move visual or collider hinge")
	world.persistent_world=false
	check(b.toggle("corner").is_empty() and row.open and row.hinge_end==0,"retry after failed save keeps clear original hinge beside connected wall")
	await create_timer(.3).timeout
	check(b.toggle("corner").is_empty(),"alternate hinge closes before obstacle test")
	await create_timer(.3).timeout
	world.player.position=at+Vector2(80,0)
	var obstacles: Array=[]
	for side in [-1,1]:
		var obstacle := StaticBody2D.new();var collision := CollisionShape2D.new();var shape := RectangleShape2D.new();shape.size=Vector2(40,128);collision.shape=shape;obstacle.add_child(collision);obstacle.position=at+Vector2(32*side,0);world.object_root.add_child(obstacle);obstacles.append(obstacle)
	await sync_physics()
	for hinge in [0,1]:
		for swing in [-1,1]: check(b.gate_blocked("corner",swing,hinge),"real obstacles block hinge %d swing %d"%[hinge,swing])
	check(not b.toggle("corner").is_empty() and not row.open,"all four actual paths blocked refuses opening")
	for obstacle in obstacles: obstacle.queue_free()
	await sync_physics()
	check(b.toggle("corner").is_empty() and row.open,"removing actual obstacles restores operation")
	var failed: Array=checks.filter(func(v): return not v.pass)
	FileAccess.open("res://reports/camp-door-v3/hinge-transaction-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"  "))
	print("HINGE TRANSACTION: %d checks, %d failed"%[checks.size(),failed.size()])
	world.persistent_world=false;world.free();await frames(6);quit(0 if failed.is_empty() else 1)
