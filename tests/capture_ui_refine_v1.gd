extends SceneTree
## Rendered evidence with direct original Control callbacks; native input has headless tests.
const OUT := "res://reports/ui-rework-v1/"
var world: Node
var ui: Control
var service: Node
func _initialize() -> void:call_deferred("run")
func frames(n: int=5) -> void:
	for i in n:await process_frame
func shot(id: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+id+".png")
func run() -> void:
	Engine.max_fps=60;Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	ui=world.item_ui;service=world.item_service;world.player.automated=true
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	for pair in [["wild_berry",18],["branch",27],["plant_fiber",34],["stone",12],["flint",9],["wood",7],["broad_leaf",8],["wild_carrot",6],["bone_fragment",3],["relic_fragment",4],["stone_axe",1],["stone_pickaxe",1],["simple_shovel",1]]:service.inventory.add(pair[0],pair[1])
	service.inventory.move_slot(8,0);service.inventory.move_slot(18,1);service.inventory.move_slot(19,2);service.inventory.use_slot(2)
	ui.toggle_bag();await shot("inventory-1280")
	# Same official tooltip factory, kept stable while a human may be moving the desktop pointer.
	var card: Control=ui.make_item_card(10);ui.add_child(card);card.z_index=20;ui.ignore_card_mouse(card)
	card.position=Vector2(620,245);await shot("tooltip-1280");card.queue_free()
	ui.close_panels();await shot("hud-selected")
	ui.toggle_craft();ui.craft_panel.choose_category("工具");ui.craft_panel.select_recipe("hand_stone_axe")
	var saved: Array=service.inventory.slots.duplicate(true)
	for i in 40:service.inventory.slots[i]={}
	service.inventory.changed.emit();await shot("craft-insufficient")
	service.inventory.restore(saved);ui.craft_panel.quantity.value=1;ui.craft_panel.once.pressed.emit();await create_timer(1.65).timeout;await shot("craft-success")
	ui.craft_panel.choose_category("野外用品");ui.craft_panel.select_recipe("hand_supply_pouch");await shot("craft-five-materials")
	for dimensions in [Vector2i(960,540),Vector2i(1600,900)]:
		root.content_scale_size=dimensions;await frames()
		ui.close_panels();ui.toggle_bag();await shot("inventory-"+str(dimensions.x))
		ui.toggle_craft();ui.craft_panel.choose_category("工具");ui.craft_panel.select_recipe("hand_stone_axe");await shot("craft-"+str(dimensions.x))
	service.dirty=false;world.queue_free();await frames()
	print("UI REFINE rendered captures complete at 1280x720 and logical 960x540 / 1600x900")
	quit()
