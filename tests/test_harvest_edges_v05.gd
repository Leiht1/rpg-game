extends SceneTree
const OUT := "res://reports/harvest-v05/"
var world: Node
var service: Node
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func equip(id: String) -> void:
	world.player.cancel_action()
	service.inventory.equipment.main_hand=service.inventory.instance(id)
	service.inventory.changed.emit()
func write_data(data: Dictionary) -> void:
	var f := FileAccess.open(service.save_path,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	service=world.item_service
	world.player.automated=true;world.player.set_physics_process(false)
	var p: Vector2=world.generator.spawn
	for node in get_nodes_in_group("world_interactables"):node.queue_free()
	await frames()
	var a: Node2D=service.create_harvest("edge:a",{"kind":"stone_outcrop","x":p.x+34,"y":p.y})
	var b: Node2D=service.create_harvest("edge:b",{"kind":"flint_outcrop","x":p.x+35,"y":p.y+35})
	equip("stone_pickaxe");world.player.position=p
	world.player.action="mine";world.player.action_target=a;world.player.action_clock=0;world.player.facing="right"
	world.player.try_interact();world.player._physics_process(.56)
	check(int(service.resource_hits.get("edge:a",0))==1 and not service.resource_hits.has("edge:b"),"nearby second target cannot steal locked hit")
	world.player._physics_process(.12)
	check(int(service.resource_hits.get("edge:a",0))==1,"same action cannot submit a second hit")
	world.player.cancel_action();world.player.action="mine";world.player.action_target=b
	b.queue_free();await frames();world.player._physics_process(.6)
	check(world.player.action.is_empty() and not service.resource_hits.has("edge:b"),"target removed before impact cancels safely")
	# A committed target may disappear while recovery finishes.
	world.player.action="mine";world.player.action_target=a;world.player.action_clock=.56;world.player.action_committed=true
	a.queue_free();await frames();world.player._physics_process(.7)
	check(world.player.action.is_empty(),"target removed after impact allows safe recovery end")
	for facing in ["front","back","right","left"]:
		for action in ["mine","dig"]:
			var view: String="side" if facing in ["left","right"] else facing
			var clip: Animation=world.player.animation_player.get_animation("harvest/"+view+"_"+action)
			check(clip!=null and clip.get_track_count()>20,"dedicated native directional body clip "+facing+action)
	# Resource visuals and effects belong to chunk lifetime, including completed ones.
	var node: Node2D=service.create_harvest("edge:complete",{"kind":"buried_root","x":p.x+28,"y":p.y+16})
	service.resource_hits["edge:complete"]=2;node.feedback(p,true)
	var chunk: Vector2i=world.stream.chunk_at(node.position)
	world.stream.unload_chunk(chunk);await frames()
	var packet: Dictionary=world.generator.build_chunk(chunk);var stamps: Array[Dictionary]=[];packet["ground_stamps"]=stamps;world.stream.install_chunk(packet)
	check(not is_instance_valid(node),"chunk unload releases finished resource and transient soil effects")
	# Pickup capacity behavior reuses original service without losing the remainder.
	var saved_slots: Array=service.inventory.slots.duplicate(true)
	for i in range(8,40):service.inventory.slots[i]={"item_id":"stone","count":99}
	var entry := {"id":"edge:drop","item_id":"stone","count":5,"x":p.x,"y":p.y}
	service.loose[entry.id]=entry
	var drop: Node2D=world.stream.create_item_drop(entry)
	check(not service.pickup(drop) and int(drop.get_meta("count"))==5 and service.loose.has(entry.id),"full bag keeps all ground rewards")
	service.inventory.slots[8].count=97
	check(service.pickup(drop) and int(drop.get_meta("count"))==3 and int(service.loose[entry.id].count)==3,"partial pickup leaves persisted remainder")
	service.inventory.slots=saved_slots
	# Real file compatibility/unknown-version protection using an isolated path.
	world.persistent_world=true;service.save_path="user://test-harvest-v05-edge.json"
	var snapshot: Dictionary=service.snapshot()
	snapshot.erase("harvest_version");snapshot.erase("resource_hits")
	write_data(snapshot);service.load_state()
	check(service.writable and service.resource_hits.is_empty() and service.loose.has("edge:drop"),"legacy save missing harvest fields keeps inventory/drop edits")
	snapshot["harvest_version"]="unknown-future-layer";write_data(snapshot)
	var bytes_before := FileAccess.get_file_as_bytes(service.save_path)
	service.load_state();service.save_state()
	check(not service.writable and FileAccess.get_file_as_bytes(service.save_path)==bytes_before,"unknown harvest version is protected from overwrite")
	world.persistent_world=false;DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
	var failed := checks.filter(func(row):return not row.pass)
	var f := FileAccess.open(OUT+"edge-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":checks.size(),"failures":failed,"checks":checks},"  "));f.close()
	print("HARVEST_EDGE ",checks.size()," checks; ",failed.size()," failures")
	world.queue_free();await frames(8);quit(0 if failed.is_empty() else 1)
