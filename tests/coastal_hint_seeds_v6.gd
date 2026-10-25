extends "res://tests/mine_route_hint_seeds_v5.gd"
func run() -> void:
	var results: Array=[];var resolved: Array=[]
	for seed_value in [271828,314159,161803]:
		var service:=ServiceSample.new();var world:=WorldSample.new();world.world_seed=seed_value;world.generator=load("res://scripts/world_generator.gd").new(seed_value,1024);service.world=world
		var gen=world.generator;var site:=Vector2.INF
		for point in gen.region_cores:
			if gen.can_walk(point,24) and gen.biome(point)=="岩石区":site=point;break
		if site==Vector2.INF:
			for i in 1024:
				var point:=Vector2(float(i%32)+.5,float(i/32)+.5)*float(gen.extent)/32
				if gen.can_walk(point,24) and gen.biome(point)=="岩石区":site=point;break
		check(site!=Vector2.INF,"seed "+str(seed_value)+" starts at a real rocky area")
		service.chapter.mine.state.site={"x":site.x,"y":site.y};var before: Dictionary=service.chapter.mine.state.duplicate(true)
		var hint: Dictionary=preload("res://scripts/mine_route_hint.gd").new().resolve(service)
		var again: Dictionary=preload("res://scripts/mine_route_hint.gd").new().resolve(service)
		check(hint==again,"seed "+str(seed_value)+" independent readers agree")
		check(hint.terrain=="sea_eroded_ruins_plateau" and not hint.target_generated,"seed "+str(seed_value)+" future special terrain only")
		check(hint.requirements.different_rock_region_from_mine and hint.requirements.near_outer_sea and hint.requirements.connected_to_ordinary_rock,"seed "+str(seed_value)+" correct terrain contract")
		if hint.direction_resolved:
			var center:=Vector2(hint.search_area.center.x,hint.search_area.center.y)
			check(gen.can_walk(center,24) and gen.biome(center)=="岩石区","seed "+str(seed_value)+" selected coast sector is existing rocky land")
			check(hint.connected_rock_region!=hint.source_rock_region,"seed "+str(seed_value)+" rock component differs from mine")
			check(gen.coast_distance(center)>=180 and gen.coast_distance(center)<=900,"seed "+str(seed_value)+" actual outer sea proximity")
			var bearing:=Vector2(hint.bearing.x,hint.bearing.y);var forward:=Vector2(hint.paper_forward.x,hint.paper_forward.y)
			check(bearing.rotated(hint.north_rotation).distance_to(forward)<.0001,"seed "+str(seed_value)+" painted compass agrees with route frame")
			resolved.append(hint)
		else:check(not hint.has("search_area") and not hint.has("bearing"),"seed "+str(seed_value)+" unavailable direction is not fabricated")
		check(service.chapter.mine.state==before,"seed "+str(seed_value)+" no progress mutation")
		results.append(hint);service.free();world.free()
	check(resolved.size()>=2,"multiple actual worlds resolve distinct coast sectors")
	if resolved.size()>=2:check(resolved[0].search_area!=resolved[1].search_area,"different seeds do not share a fictitious fixed map location")
	FileAccess.open("res://reports/coastal-route-v6/seed-hints.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "));FileAccess.open("res://reports/coastal-route-v6/seed-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));var failed: int=checks.filter(func(row):return not row.pass).size();print("COASTAL ROUTE SEEDS ",checks.size()," checks ",failed," failures");quit(1 if failed else 0)
