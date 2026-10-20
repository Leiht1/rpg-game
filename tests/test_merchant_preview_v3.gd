extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.max_fps=60
	var world=load("res://scripts/merchant_preview.gd").new();root.add_child(world)
	for i in 120:await process_frame
	var service=world.item_service
	var required := {}
	for id in service.merchant.rules.products:
		for material in service.merchant.price(id):required[material]=required.get(material,0)+service.merchant.price(id)[material]
	var funded := true
	for id in required:funded=funded and service.inventory.count_item(id)>=required[id]
	var ok: bool=funded and not world.persistent_world and service.inventory.count_item("solar_flashlight")==0 and world.player.position.distance_to(service.merchant.actor.position)<78
	print("MERCHANT PREVIEW actual startup materials, no free torch, isolated world, nearby merchant: ",ok)
	world.queue_free()
	for i in 5:await process_frame
	quit(0 if ok else 1)
