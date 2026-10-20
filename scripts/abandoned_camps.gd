extends RefCounted
## A new-world-only batch. Existing item snapshots never receive retroactive ruins.
const Grid = preload("res://scripts/camp_grid.gd")
const TEMPLATES = [
	[["wood_chest",-78,-18],["workbench",74,-26],["straw_mat",-54,86]],
	[["wood_chest",76,10],["wood_bed",-70,-18],["stone_path",48,96]],
	[["wood_chest",-70,72],["workbench",68,56],["straw_mat",-60,-22],["wood_floor",48,-32]]
]
const LOOT = ["wood","stone","plant_fiber","flint","potato","cabbage","copper_ore","silver_ore"]

static func template_rows(service: Node, center: Vector2, variant: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for part in TEMPLATES[variant]:
		var row: Dictionary=service.builds.candidate(part[0],center+Vector2(part[1],part[2]),false,false,0)
		row.abandoned=true
		if row.kind=="wood_chest":
			for i in 3:
				var id: String=LOOT[rng.randi_range(0,LOOT.size()-1)]
				row.contents[i]={"item_id":id,"count":rng.randi_range(2,5) if id in ["wood","stone","plant_fiber"] else 1}
		result.append(row)
	# Broken northern fence and one side; south/east stay open for access.
	for offset in [Vector2(-144,-96),Vector2(-48,-96),Vector2(144,-96),Vector2(-192,-32)]:
		if rng.randf()<.15: continue
		var row: Dictionary=service.builds.candidate("wood_fence",center+offset,offset.x==-192,false,0)
		row.abandoned=true
		result.append(row)
	return result

static func site_clear(service: Node, center: Vector2) -> bool:
	if center.distance_to(service.world.generator.spawn)<1800: return false
	var props: Array[Dictionary]=service.nearby_props(center)
	# Sample the whole camp and its open approach, not merely each building root.
	for y in range(-128,161,32):
		for x in range(-224,225,32):
			if not service.ground_clear(center+Vector2(x,y),24,props): return false
	return service.has_approach(center+Vector2(0,160),props)

static func resources_clear(service: Node, rows: Array[Dictionary]) -> bool:
	var chunks := {}
	for row in rows:
		for offset in [Vector2(-80,-80),Vector2(80,-80),Vector2(-80,80),Vector2(80,80)]:
			chunks[service.world.stream.chunk_at(Vector2(row.x,row.y)+offset)]=true
	for coord in chunks:
		var packet: Dictionary=service.chunk_distribution(coord)
		var resources: Array=packet.accepted.duplicate()
		resources.append_array(preload("res://scripts/harvest_distribution.gd").build(service,coord))
		for resource in resources:
			for row in rows:
				if Vector2(row.x,row.y).distance_to(Vector2(resource.x,resource.y))<80: return false
	return true

static func generate(service: Node) -> void:
	if service.builds.abandoned_version!=0: return
	var rng := RandomNumberGenerator.new()
	rng.seed=service.world.world_seed ^ 7182351
	var centers: Array[Vector2]=[]
	for attempt in 2400:
		if centers.size()>=(5 if service.world.map_cells>1024 else 3): break
		var center := Vector2(rng.randf_range(600,service.world.generator.extent-600),rng.randf_range(600,service.world.generator.extent-600))
		center=(center/Grid.STEP).floor()*Grid.STEP
		if centers.any(func(p):return p.distance_to(center)<3500): continue
		if not site_clear(service,center): continue
		var rows := template_rows(service,center,centers.size()%3,rng)
		if not resources_clear(service,rows): continue
		for i in rows.size(): service.builds.states["abandoned:v1:%d:%d"%[centers.size(),i]]=rows[i]
		centers.append(center)
	service.builds.abandoned_version=1
	service.dirty=true
