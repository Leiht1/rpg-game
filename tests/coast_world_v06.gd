extends "res://tests/capture_world_v06.gd"
func run()->void:
	Engine.set_meta("world_v06_seed",447349832)
	w=load("res://prototypes/world-v06/world.gd").new();root.add_child(w)
	w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	var start:=Vector2.ZERO;var direction:=Vector2.ZERO
	for y in range(20,490):
		if start!=Vector2.ZERO:break
		for x in range(20,490):
			var p:Vector2=Vector2(x,y)*w.generator.extent/512.
			var coast:float=w.generator.coast_distance(p)
			if coast<65. or coast>95. or not w.generator.can_walk(p,30):continue
			var props_clear:=true;var coord:=Vector2i(p/1152.)
			for cy in range(coord.y-1,coord.y+2):
				for cx in range(coord.x-1,coord.x+2):
					for prop in w.generator.props_for_chunk(Vector2i(cx,cy)):
						if prop.kind<4 and prop.position.distance_to(p)<220:props_clear=false
			if not props_clear:continue
			start=p
			direction=-Vector2(w.generator.coast_distance(p+Vector2(8,0))-w.generator.coast_distance(p-Vector2(8,0)),w.generator.coast_distance(p+Vector2(0,8))-w.generator.coast_distance(p-Vector2(0,8))).normalized()
			break
	check(start!=Vector2.ZERO,"found unobstructed coast probe")
	w.player.position=start;w.player.camera.reset_smoothing();await settle()
	w.player.input_override=direction
	for i in 150:await physics_frame
	w.player.input_override=Vector2.ZERO
	var moved:float=w.player.position.distance_to(start)
	check(moved>20 and moved<200,"normal physics stops at ocean",moved)
	check(w.generator.can_walk(w.player.position,10),"feet remain on dry side")
	check(not w.generator.can_walk(start+direction*300,10),"ocean target is impassable")
	await shot("coast-collision")
	var mismatches:=0
	for y in 128:
		for x in 128:
			var p:Vector2=(Vector2(x,y)+Vector2.ONE*.5)*w.generator.extent/128.
			if w.generator.can_walk(p,0)!=(w.generator.sample(p).z<=.56):mismatches+=1
	check(mismatches==0,"land ocean water source matches collision classification",mismatches)
	var failures:=0
	for item in checks:
		if not item.pass:failures+=1
	FileAccess.open("res://reports/world-v06/coast-runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"seed":447349832,"distance":moved,"start":str(start),"end":str(w.player.position)},"  "))
	w.queue_free();await process_frame
	print("COAST FAILURES ",failures);quit(1 if failures else 0)
