extends SceneTree
var world: Node

func _initialize() -> void: call_deferred("run")

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/items-v03/"+label+".png")

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	world=load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	var ticks := 0
	while not world.started and ticks < 1800:
		ticks+=1
		await process_frame
	world.environment_view.simulation.set_time(10)
	var service: Node = world.item_service
	for i in 12:
		var id: String = service.database.ids()[i]
		var p: Vector2=world.player.position+Vector2((i%6-2.5)*65,90+(i/6)*66)
		world.stream.create_item_drop({"id":"gallery:%d"%i,"item_id":id,"count":1,"x":p.x,"y":p.y,"natural":true})
	await capture("world-candidates")
	for id in service.database.ids(): service.inventory.add(id,5)
	await key(KEY_B)
	assert(world.item_ui.bag.visible and world.player.input_blocked)
	for cell in world.item_ui.cells:
		assert(cell.size.x<=52 and cell.size.y<=52)
		assert(not "caption" in cell)
	await capture("bag-empty-hotbar")
	var baseline: Array[Rect2]=[]
	for cell in world.item_ui.cells: baseline.append(cell.get_global_rect())
	var layout_checks := 0
	for index in [0,1,7,8,9,15,39]:
		world.item_ui.cells[index].hovered=true
		world.item_ui.cells[index].refresh()
		await process_frame
		await process_frame
		for i in 40:
			assert(world.item_ui.cells[i].get_global_rect()==baseline[i])
			layout_checks+=1
		world.item_ui.cells[index].hovered=false
		world.item_ui.cells[index].refresh()
	print("ITEM_LAYOUT ",layout_checks," unchanged cell rectangles across hotbar and bag hover states")
	world.item_ui.show_item_hover(8)
	world.item_ui._process(0.14)
	assert(not is_instance_valid(world.item_ui.hover_card))
	world.item_ui._process(0.02)
	assert(is_instance_valid(world.item_ui.hover_card))
	await capture("item-hover-card")
	var first_cell: Control=world.item_ui.cells[8]
	var target: Control=world.item_ui.cells[0]
	var data := {"inventory":service.inventory,"slot":8}
	assert(target._can_drop_data(Vector2.ZERO,data))
	target._drop_data(Vector2.ZERO,data)
	assert(service.inventory.slots[0].item_id=="wild_berry" and service.inventory.slots[8].is_empty())
	var right := InputEventMouseButton.new()
	right.button_index=MOUSE_BUTTON_RIGHT
	right.pressed=true
	target.on_input(right)
	assert(service.inventory.slots[0].count==4)
	await key(KEY_1)
	assert(service.inventory.slots[0].count==3)
	var repeat := InputEventKey.new()
	repeat.physical_keycode=KEY_1; repeat.pressed=true; repeat.echo=true
	Input.parse_input_event(repeat)
	await process_frame
	assert(service.inventory.slots[0].count==3)
	await key(KEY_2)
	assert(service.inventory.slots[1].is_empty())
	assert(service.inventory.move_slot(12,1))
	await key(KEY_2)
	assert(service.inventory.slots[1].item_id=="wood" and service.inventory.slots[1].count==5)
	await capture("bag-drag-and-eat")
	await key(KEY_F6)
	await capture("catalog")
	await key(KEY_ESCAPE)
	assert(not world.player.input_blocked)
	await capture("hotbar")
	world.item_ui.bag_button.pressed.emit()
	await process_frame
	assert(world.item_ui.bag.visible and world.player.input_blocked)
	assert(world.item_ui.bag_button.size.x<=52 and world.item_ui.bag_button.size.y<=52)
	assert(absf(world.item_ui.bag_button.get_global_rect().get_center().y-world.item_ui.cells[7].get_global_rect().get_center().y)<1)
	world.item_ui.bag_button.pressed.emit()
	await process_frame
	assert(not world.item_ui.bag.visible and not world.player.input_blocked)
	assert(world.item_ui.bag_button.size==world.item_ui.cells[0].size)
	assert(world.item_ui.map_button.size==world.item_ui.cells[0].size)
	assert(absf(world.item_ui.map_button.get_global_rect().get_center().y-world.item_ui.cells[7].get_global_rect().get_center().y)<1)
	for state in ["font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		assert(world.item_ui.bag_button.get_theme_color(state)==world.item_ui.bag_button.get_theme_color("font_color"))
		var close: Button=world.item_ui.bag.get_child(0).get_child(0).get_child(1)
		assert(close.get_theme_color(state)==close.get_theme_color("font_color"))
	world.item_ui.map_button.pressed.emit()
	await process_frame
	assert(world.map_view.visible and world.player.input_blocked and not world.item_ui.bag.visible)
	var nav_position: Vector2=world.item_ui.map_button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position=nav_position
	root.push_input(motion,true)
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.position=nav_position;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed
		root.push_input(click,true)
		await process_frame
	assert(not world.map_view.visible and not world.player.input_blocked)
	await capture("navigation-icons")
	print("ITEM_NAV: two 52px aligned icon buttons; map GUI click opens/closes; all text interaction states retain dark color")
	var pickup_position: Vector2=world.player.position+Vector2(18,0)
	var pickup: Node2D=world.stream.create_item_drop({"id":"capture:pickup","item_id":"brown_mushroom","count":1,"x":pickup_position.x,"y":pickup_position.y})
	world.player.try_interact()
	assert(world.player.action=="pickup")
	for i in 45: await physics_frame
	assert(not is_instance_valid(pickup))
	assert(service.inventory.slots[9].item_id=="brown_mushroom" and service.inventory.slots[9].count==6 and service.inventory.slots[8].is_empty())
	assert(service.inventory.slots[0].count==3)
	print("ITEMS_UI: B open, initially empty hotbar, drag, right-click consume, F6 catalog, Escape close verified")
	world.queue_free()
	await process_frame
	quit()
