extends SceneTree
var checks := 0
var failures: Array[String] = []
var world: Node

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := ItemDatabase.new()
	check(db.errors.is_empty(),"database validation")
	check(db.ids().size()==12,"12 definitions")
	for id in db.ids():
		var definition := db.item(id)
		check(not str(definition.name).is_empty() and not str(definition.description).is_empty(),"name description "+id)
		var copy := db.item(id)
		copy.name="changed"
		check(db.item(id).name!=copy.name,"definition copy "+id)
	var bag := ItemInventory.new(db)
	check(bag.add("wood",100)==0,"add split")
	for i in 8: check(bag.slots[i].is_empty(),"pickup leaves hotbar empty %d"%i)
	check(bag.slots[8].count==99 and bag.slots[9].count==1,"stack limit")
	check(bag.move_slot(9,0),"explicit hotbar drag")
	check(bag.slots[9].is_empty() and bag.slots[0].count==1,"move not duplicate")
	check(bag.add("wood",1)==0 and bag.slots[0].count==2 and bag.slots[9].is_empty(),"acquisition merges into existing hotbar first")
	check(bag.move_slot(0,9) and bag.slots[9].count==2,"merge across panels")
	check(not bag.move_slot(9,8),"full target stack no-op")
	check(bag.add("wild_berry",2)==0,"food add")
	check(bag.use_slot(10) and bag.slots[10].count==1,"food consumes once")
	check(bag.use_slot(10) and bag.slots[10].is_empty(),"food empties slot")
	check(not bag.use_slot(8),"material no direct use")
	check(not bag.move_slot(-1,0) and not bag.move_slot(40,0),"invalid move safe")
	check(bag.add("unknown",2)==2,"unknown rejected")
	var restored := ItemInventory.new(db)
	check(restored.restore(bag.slots) and restored.slots==bag.slots,"inventory roundtrip")
	var invalid := bag.slots.duplicate(true)
	invalid[8].count=1000
	check(not restored.restore(invalid) and restored.slots==bag.slots,"corrupt inventory rejected atomically")
	var full := ItemInventory.new(db)
	check(full.add("stone",32*99)==0,"fill bag")
	check(full.capacity("stone")==0 and full.add("stone",1)==1,"empty hotbar not pickup capacity")
	full.slots[0]={"item_id":"stone","count":98}
	check(full.capacity("stone")==1 and full.add("stone",2)==1 and full.slots[0].count==99,"full bag still fills existing hotbar up to limit")
	check(full.slots[1].is_empty(),"overflow never opens new hotbar stack")
	world=load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	world.item_service.preview=true
	var service: Node = world.item_service
	world.persistent_world=false
	for i in 12:
		var id: String = db.ids()[i]
		check(service.texture(id,"icon")!=null and service.texture(id,"world")!=null,"two real visuals "+id)
	var c: Vector2i = world.stream.chunk_at(world.player.position)
	var first: Array = service.entries(c)
	check(first==service.entries(c),"resource reproducibility")
	var neighboring: Array = service.entries(c+Vector2i.RIGHT)
	check(first==service.entries(c),"independent load order")
	if not first.is_empty():
		service.consumed[first[0].id]=true
		var remaining: Array = service.entries(c)
		check(remaining.size()==first.size()-1,"harvested resource excluded after regeneration")
		service.consumed.erase(first[0].id)
	for entry in first+neighboring:
		check(world.generator.can_walk(Vector2(entry.x,entry.y),18),"resource on dry ground")
	var entry := {"id":"test:berry","item_id":"wild_berry","count":2,"x":world.player.position.x+20,"y":world.player.position.y}
	service.loose[entry.id]=entry
	var drop: Node2D = world.stream.create_item_drop(entry)
	check(service.pickup(drop),"pickup to bag")
	check(service.consumed.has(entry.id) and not service.loose.has(entry.id),"world removal committed")
	for i in 8: check(service.inventory.slots[i].is_empty(),"world pickup leaves hotbar empty %d"%i)
	check(service.inventory.slots[8].count==2,"picked count")
	await process_frame
	entry={"id":"test:reload","item_id":"wood","count":1,"x":world.player.position.x+22,"y":world.player.position.y}
	service.loose[entry.id]=entry
	drop=world.stream.create_item_drop(entry)
	check(world.stream.create_item_drop(entry)==drop,"duplicate install returns one drop")
	world.stream.drops.erase(drop)
	drop.queue_free()
	await process_frame
	service.install_chunk(c)
	var reloaded := 0
	for node in world.stream.drops:
		if node.get_meta("drop_id","")==entry.id: reloaded+=1
	check(reloaded==1,"loose drop restored once on chunk reload")
	service.inventory=full
	entry={"id":"test:full","item_id":"stone","count":1,"x":world.player.position.x,"y":world.player.position.y}
	service.loose[entry.id]=entry
	drop=world.stream.create_item_drop(entry)
	check(not service.pickup(drop) and not drop.get_meta("collected",false) and service.loose.has(entry.id),"full bag preserves world drop")
	service.inventory=restored
	var test_path := "user://items-v03-test-only.json"
	service.save_path=test_path
	world.persistent_world=true
	world.stream.harvested["test:tree"]=true
	world.stream.tree_hits["test:partial_tree"]=1
	service.save_state()
	check(FileAccess.file_exists(test_path),"atomic file written")
	var saved: Dictionary=service.snapshot().duplicate(true)
	service.inventory.slots[8]={}
	service.consumed={}
	service.load_state()
	check(service.inventory.slots==saved.slots and service.consumed==saved.consumed,"file inventory and edits restore")
	check(service.loose==JSON.parse_string(JSON.stringify(saved.loose)) and world.stream.harvested.has("test:tree") and int(world.stream.tree_hits["test:partial_tree"])==1,"drops and tree edits saved together")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	world.persistent_world=false
	service.dirty=false
	world.queue_free()
	await process_frame
	var file := FileAccess.open("res://reports/items-v03/tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failures},"\t"))
	file.close()
	print("ITEMS_TEST ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
