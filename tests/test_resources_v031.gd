extends SceneTree
const Gen = preload("res://scripts/world_generator.gd")
var world: Node
var checks := 0
var failures: Array[String] = []
var stats: Array = []

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/resources-v031"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--restart-phase="): await restart_run(arg.get_slice("=",1)); return
	for seed_value in [271828,447349832,1671081329]:
		Engine.set_meta("integration_seed",seed_value)
		world=load("res://tests/world_v06_formal_fixture.gd").new()
		root.add_child(world)
		world.stream.set_process(false)
		world.player.input_blocked=true
		var service: Node = world.item_service
		check(not service.preview,"formal logic enabled without art preview")
		var gen: WildGenerator = world.generator
		var before := gen.props_for_chunk(world.stream.chunk_at(gen.spawn))
		var terrain := gen.sample(gen.spawn+Vector2(200,90))
		var coords: Array[Vector2i] = []
		for p in [gen.spawn]+Array(gen.region_cores):
			var c: Vector2i = world.stream.chunk_at(p)
			for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN]:
				if not coords.has(c+offset): coords.append(c+offset)
		var all: Array = []
		var ids := {}
		var distribution := {}
		var empty := 0
		var timing: Array[float] = []
		for c in coords:
			var rows: Array = service.entries(c)
			timing.append(service.generation_ms)
			if rows.is_empty(): empty+=1
			check(rows==service.entries(c),"cached repeat %s/%s"%[seed_value,c])
			for row in rows:
				check(not ids.has(row.id),"unique world ID")
				ids[row.id]=true
				var p := Vector2(row.x,row.y)
				check(world.stream.chunk_at(p)==c,"world ownership by position")
				check(gen.can_walk(p,24) and gen.sample(p).z<=.32,"walkable dry land")
				check(service.ground_clear(p,float(service.rules.resources[row.item_id].ground_radius),service.nearby_props(p)),"root and footprint clearance")
				check(service.has_approach(p,service.nearby_props(p)),"reachable approach")
				check(row.item_id!="pine_cone","no cones without conifers")
				if row.item_id=="wild_apple": check(not str(row.source_id).is_empty(),"fallen apple has source tree")
				var eco: Dictionary = row.ecology
				var biome: String = eco.keys()[0]
				for key in eco:
					if float(eco[key])>float(eco[biome]): biome=key
				if not distribution.has(biome): distribution[biome]={}
				distribution[biome][row.item_id]=int(distribution[biome].get(row.item_id,0))+1
				all.append(row)
		var spacing_valid := true
		for i in all.size():
			for j in range(i+1,all.size()):
				var a: Dictionary = all[i]; var b: Dictionary = all[j]
				if Vector2(a.x,a.y).distance_to(Vector2(b.x,b.y))<maxf(float(a.spacing),float(b.spacing)): spacing_valid=false
		check(spacing_valid,"all cross-boundary resource spacing")
		var first: Array = service.entries(coords[0])
		service.raw_cells.clear(); service.chunk_cache.clear(); service.prop_cache.clear()
		service.entries(coords.back())
		check(first==service.entries(coords[0]),"cold regeneration independent of load order")
		var worker: Dictionary=service.build_distribution(Gen.new(seed_value,1024,gen.plan_snapshot()),service.rules,service.reachable,coords[0])
		check(worker.accepted==service.chunk_distribution(coords[0]).accepted,"terrain worker and direct resource layer identical")
		check(before==gen.props_for_chunk(world.stream.chunk_at(gen.spawn)) and terrain==gen.sample(gen.spawn+Vector2(200,90)),"original terrain and props unchanged")
		check(gen.plan_snapshot().field.get_data()==Gen.new(seed_value,1024).field.get_data(),"mainland field unchanged")
		check(empty>0 and all.size()>0,"sparse chunks and resources coexist")
		var spawn_visible := 0
		var rect := Rect2(gen.spawn-Vector2(640,360),Vector2(1280,720))
		var c: Vector2i = world.stream.chunk_at(gen.spawn)
		for y in range(c.y-1,c.y+2):
			for x in range(c.x-1,c.x+2):
				for row in service.entries(Vector2i(x,y)):
					if rect.has_point(Vector2(row.x,row.y)): spawn_visible+=1
		stats.append({"seed":seed_value,"chunks":coords.size(),"resources":all.size(),"empty_chunks":empty,"by_ecology":distribution,"navigation_ms":service.navigation_ms,"generation_max_ms":timing.max(),"spawn_visible":spawn_visible})
		if seed_value==271828: await state_checks(service,c)
		service.dirty=false
		world.queue_free()
		await process_frame
	var file := FileAccess.open("res://reports/resources-v031/tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"samples":stats},"\t"))
	file.close()
	print("RESOURCES_TEST ",checks," checks / ",failures.size()," failures; ",JSON.stringify(stats))
	quit(0 if failures.is_empty() else 1)

func state_checks(service: Node, c: Vector2i) -> void:
	var rows: Array = service.entries(c)
	if rows.is_empty():
		for offset in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]:
			rows=service.entries(c+offset)
			if not rows.is_empty(): break
	check(not rows.is_empty(),"spawn neighborhood has natural resources")
	if rows.is_empty(): return
	var row: Dictionary = rows[0].duplicate(true)
	var owner: Vector2i = world.stream.chunk_at(Vector2(row.x,row.y))
	var drop: Node2D = world.stream.create_item_drop(row)
	check(drop!=null and drop.visible,"formal resource visible without pending art")
	var initial: int = service.entries(owner).size()
	check(service.pickup(drop),"natural pickup commits")
	await process_frame
	check(service.entries(owner).size()==initial-1,"harvested filter stable")
	service.install_chunk(owner)
	var live := 0
	for node in world.stream.drops:
		if node.get_meta("drop_id")==row.id: live+=1
	check(live==0,"reinstall does not duplicate consumed resource")
	# Partial natural pickup: remaining quantity becomes a separate loose edit.
	service.inventory=ItemInventory.new(service.database)
	service.inventory.add("stone",32*99)
	service.inventory.slots[8].count=98
	var p: Vector2 = world.player.position+Vector2(20,0)
	var partial := {"id":"natural:031:test:partial","item_id":"stone","count":3,"x":p.x,"y":p.y,"natural":true}
	drop=world.stream.create_item_drop(partial)
	check(service.pickup(drop) and int(drop.get_meta("count"))==2,"partial pickup preserves remainder")
	check(service.inventory.slots[8].count==99 and service.consumed.has(partial.id) and service.loose[partial.id].count==2,"partial pickup quantity conservation")
	check(not service.pickup(drop) and not drop.get_meta("collected",false),"full bag preserves resource and no success state")
	# Remove visible drops, reinstall only state, without generating ground packets.
	for node in world.stream.drops.duplicate(): node.queue_free()
	world.stream.drops.clear()
	await process_frame
	service.install_chunk(world.stream.chunk_at(p))
	var found := 0
	for node in world.stream.drops:
		if node.get_meta("drop_id")==partial.id: found+=1; check(int(node.get_meta("count"))==2,"partial remainder survives reload")
	check(found==1,"partial remainder installed exactly once")
	# Save path is test-only, never the user's world.
	service.save_path="user://resource-v031-test.json"
	world.persistent_world=true
	service.save_state()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(service.snapshot()))
	service.consumed={}; service.loose={}
	service.inventory=ItemInventory.new(service.database)
	service.load_state()
	check(JSON.parse_string(JSON.stringify(service.snapshot()))==saved,"restart snapshot restores inventory and world edits")
	# Migrate 0.3.0 inventory/tree/loose state while retaining original file.
	var legacy: Dictionary = saved.duplicate(true)
	legacy.resource_version=service.LEGACY_RESOURCE_VERSION
	var file := FileAccess.open("user://resource-v030-test.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy)); file.close()
	service.load_state("user://resource-v030-test.json",true)
	check(JSON.parse_string(JSON.stringify(service.inventory.slots))==saved.slots and service.loose==saved.loose,"legacy bag and loose edits migrate")
	check(JSON.parse_string(FileAccess.get_file_as_string("user://resource-v030-test.json")).resource_version==service.LEGACY_RESOURCE_VERSION,"legacy original preserved")
	for path in ["user://resource-v031-test.json","user://resource-v030-test.json"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	world.persistent_world=false
	# Discard validates real ground packets; a bare loaded marker is insufficient.
	var drop_coord: Vector2i=world.stream.chunk_at(world.player.position)
	if not world.stream.has_ground(world.player.position):
		var packet: Dictionary=world.generator.build_chunk(drop_coord)
		var stamps: Array[Dictionary]=[];packet["ground_stamps"]=stamps
		world.stream.install_chunk(packet)
	check(service.discard(8,1),"player drop API")
	var player_id := ""
	for id in service.loose:
		if str(id).begins_with("player:"): player_id=id
	check(not player_id.is_empty() and service.loose[player_id].origin=="player","player drop namespace separate")
	service.inventory=ItemInventory.new(service.database)
	await create_timer(.8).timeout
	for node in world.stream.drops:
		if node.get_meta("drop_id")==player_id: check(service.pickup(node),"player drop can be picked back up"); break
	check(not service.loose.has(player_id),"player drop conserved through pickup")

func restart_run(phase: String) -> void:
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(world)
	world.stream.set_process(false)
	world.player.input_blocked=true
	var service: Node=world.item_service
	service.save_path="user://resources-v031-process-test.json"
	world.persistent_world=true
	if phase=="write":
		var c: Vector2i=world.stream.chunk_at(world.generator.spawn)
		var rows: Array=service.entries(c)
		if rows.is_empty(): rows=service.entries(c+Vector2i.RIGHT)
		check(not rows.is_empty(),"restart fixture resource exists")
		if not rows.is_empty():
			var row: Dictionary=rows[0]
			check(service.pickup(world.stream.create_item_drop(row)),"restart harvest before exit")
			service.loose["player:restart"]={"id":"player:restart","item_id":"branch","count":2,"x":row.x+100,"y":row.y,"origin":"player"}
			world.stream.harvested["fixture:tree"]=true
			service.save_state()
			FileAccess.open("res://reports/resources-v031/restart-fixture.json",FileAccess.WRITE).store_string(JSON.stringify({"resource":row,"snapshot":service.snapshot()}))
	else:
		var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/resources-v031/restart-fixture.json"))
		service.load_state()
		check(JSON.parse_string(JSON.stringify(service.snapshot()))==fixture.snapshot,"fresh process inventory/world snapshot restored")
		var row: Dictionary=fixture.resource
		var c: Vector2i=world.stream.chunk_at(Vector2(row.x,row.y))
		var restored := false
		for entry in service.entries(c):
			if entry.id==row.id: restored=true
		check(not restored,"fresh process harvested resource stays absent")
		check(service.loose.has("player:restart") and int(service.loose["player:restart"].count)==2,"fresh process player drop retained")
		check(world.stream.harvested.has("fixture:tree"),"fresh process tree edit retained")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
	world.persistent_world=false
	service.dirty=false
	world.queue_free()
	await process_frame
	FileAccess.open("res://reports/resources-v031/restart-"+phase+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
	print("RESTART_",phase," ",checks," checks / ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
