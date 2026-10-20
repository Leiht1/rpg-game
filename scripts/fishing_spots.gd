extends RefCounted
## Candidate positions only. Population selection and persistence live in fishing_population.gd.
var generator: WildGenerator

func candidates(source: WildGenerator) -> Array[Dictionary]:
	generator=source
	var result: Array[Dictionary]=[]
	# Sample lake banks; active counts are selected by the population manager.
	for lake_index in generator.lakes.size():
		var lake: Vector4=generator.lakes[lake_index]
		var center := Vector2(lake.x,lake.y)
		for step in 32:
			var angle := float(step)*TAU/32.0
			var outward := Vector2.from_angle(angle)
			var previous_water := false
			for radius in range(80,2200,8):
				var point := center+outward*float(radius)
				var is_water := generator.sample(point).z>.56
				if previous_water and not is_water:
					var stand := point+outward*40
					if not generator.can_walk(stand,20): break
					var water := Vector2.ZERO
					var found_water := false
					# Search around the local shoreline, then test the whole effect footprint.
					# Centre-only tests fail on coves, tips and irregular shallow edges.
					for depth in range(64,121,8):
						for tangent in [0,-16,16,-32,32]:
							var candidate := point-outward*depth+outward.orthogonal()*float(tangent)
							if stand.distance_to(candidate)<172 and fish_water_clearance(candidate):
								water=candidate;found_water=true;break
						if found_water: break
					if not found_water: break
					var separate := true
					for old in result:
						if old.water.distance_to(water)<180: separate=false
					if separate:
						result.append({"stand":stand,"water":water,"lake":lake_index,"id":"lake-%d-%d"%[lake_index,step]})
					break
				previous_water=is_water

	append_coast_candidates(result)
	return result

func fish_water_clearance(at: Vector2) -> bool:
	# Includes the largest 52x16 ripple, offset secondary ring, splash and margin.
	for y in range(-24,25,8):
		for x in range(-60,61,8):
			if generator.sample(at+Vector2(x,y)).z<.8: return false
	return true

func append_coast_candidates(result: Array[Dictionary]) -> void:
	# Detect the actual irregular continent contour, rather than the map rectangle.
	var step := generator.extent/96.0
	for y in 96:
		for x in 96:
			var a := Vector2(x,y)*step
			var da: float=generator.coast_distance(a)
			for axis in [Vector2.RIGHT,Vector2.DOWN]:
				var b: Vector2=a+axis*step
				if (da>0)==(generator.coast_distance(b)>0): continue
				var land := a if da>0 else b
				var sea := b if da>0 else a
				for iteration in 12:
					var middle := (land+sea)*.5
					if generator.coast_distance(middle)>0: land=middle
					else: sea=middle
				var edge := (land+sea)*.5
				var inward := Vector2(generator.coast_distance(edge+Vector2(16,0))-generator.coast_distance(edge-Vector2(16,0)),generator.coast_distance(edge+Vector2(0,16))-generator.coast_distance(edge-Vector2(0,16))).normalized()
				if inward.length_squared()<.9: continue
				var stand := edge+inward*56
				if not generator.can_walk(stand,20): continue
				for depth in [72,80,88,96,104,112]:
					var water := edge-inward*float(depth)
					if stand.distance_to(water)>=172 or not fish_water_clearance(water): continue
					var separate := true
					for old in result:
						if old.water.distance_to(water)<180: separate=false;break
					if separate: result.append({"stand":stand,"water":water,"lake":-1,"id":"coast-%d-%d-%d"%[x,y,int(axis.y)]})
					break
