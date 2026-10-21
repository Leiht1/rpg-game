extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var world=load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(world)
	while not world.started:await process_frame
	var card:=Panel.new()
	world.item_ui.add_child(card)
	world.item_ui.hover_card=card
	world.item_ui.hide_item_hover()
	assert(world.item_ui.hover_card==null)
	card.free()
	await create_timer(.2).timeout
	world.persistent_world=false
	world.free()
	await process_frame
	print("FREED_HOVER_TIMER_PASS")
	quit()
