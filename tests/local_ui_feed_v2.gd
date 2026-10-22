extends Node
class LocalWorld extends "res://scripts/world.gd":
	func load_world_identity(_path: String=WORLD_ID_PATH) -> void:
		persistent_world=false;world_seed=271828;map_cells=1536;world_id="local-ui-feed-v2-test"
	func parse_arguments() -> void:pass
const OUT="res://reports/.tmp/local-ui-feed-v2/"
var checks:=0
func verify(ok: bool, text: String) -> void:
	if not ok:print("LOCAL_TEST_FAIL ",text);get_tree().quit(1)
	assert(ok,text);checks+=1
func frames(n: int=4) -> void:
	for i in n:await get_tree().process_frame
func key(code: int) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);await frames();event.pressed=false;Input.parse_input_event(event);await frames()
func click(at: Vector2) -> void:
	var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	get_viewport().push_input(event,true);await frames();event.pressed=false;get_viewport().push_input(event,true);await frames()
func shot(label: String) -> void:
	await get_tree().create_timer(.25).timeout
	get_viewport().get_texture().get_image().save_png(OUT+label+".png")
func _ready() -> void:run.call_deferred()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var world:=LocalWorld.new();add_child(world)
	while not world.started:await get_tree().process_frame
	var ui=world.item_ui;var service=world.item_service;var inv=service.inventory;var animals=service.animals
	service.guide_stage=2
	var menu=load("res://scripts/world_menu.gd").new()
	menu.world_provider=func():return world
	menu.return_action=func():pass
	add_child(menu)
	await get_tree().create_timer(.3).timeout
	verify(not world.hint.visible,"operation paragraph removed")
	for prop in world.object_root.get_children():
		if prop.get("kind") is int:verify(prop.kind!=6,"no flower decorations installed")
	var seen:=0
	var base:=Vector2i(world.generator.spawn/world.Gen.CHUNK_PX)
	for y in range(-3,4):
		for x in range(-3,4):
			for row in world.generator.props_for_chunk(base+Vector2i(x,y)):
				verify(row.kind!=6,"generator excludes only flower kind")
				if row.kind in [4,5]:seen+=1
	verify(seen>0,"other decorative grass retained")
	await key(KEY_M);verify(world.map_view.visible,"M opens map")
	await shot("map")
	await click(menu.trigger.get_global_rect().get_center())
	verify(not world.map_view.visible and not menu.overlay.visible,"mouse Esc closes map without menu")
	await key(KEY_M);await key(KEY_ESCAPE);verify(not world.map_view.visible and not menu.overlay.visible,"keyboard Esc closes map")
	await key(KEY_M);var zoom: float=world.map_view.zoom
	var wheel:=InputEventMouseButton.new();wheel.position=world.map_view.map_rect.get_center();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
	get_viewport().push_input(wheel,true);await frames();verify(world.map_view.zoom>zoom,"map wheel preserved")
	await click(world.map_view.recenter.get_global_rect().get_center());verify(world.map_view.center.distance_to(world.player.position)<1,"recenter remains clickable")
	await click(menu.trigger.get_global_rect().get_center())
	ui.guide.open_letter();await shot("guide")
	var words=ui.guide.page.get_child(2)
	verify(words.text.contains("鼠标右键可使用物品，装备道具") and words.text.contains("可投放"),"guide has both mouse descriptions")
	verify(words.position.y+words.get_minimum_size().y<ui.guide.page.size.y-20,"guide text within paper")
	ui.guide.close_letter();await frames()
	animals.set_physics_process(false)
	for actor in animals.visuals.values():actor.set_physics_process(false)
	var p: Vector2=world.player.position
	var id:="local-feed:sheep"
	animals.states[id]=animals.make_row("sheep",p+Vector2(42,0))
	animals.sync_visuals();await frames()
	var animal: Node2D=animals.visuals[id];animal.set_physics_process(false)
	verify(animals.caption(id)=="","no food means no feeding hint")
	inv.add("broad_leaf",3);inv.add("wild_carrot",2);inv.add("carrot_seed",2);inv.add("wild_carrot",2)
	verify(animals.caption(id)=="E 投喂","food enables E hint")
	verify(animals.food_slots(id).size()==2,"one square per suitable food type")
	ui.update_target_tip(animal,3.0);verify(ui.target_tip.visible,"feed hint stays visible")
	world.player.facing="right"
	var motion:=InputEventMouseMotion.new();motion.position=get_viewport().get_canvas_transform()*animal.position
	get_viewport().push_input(motion,true);await frames()
	verify(world.player.selected_target()==animal,"real interaction target")
	await key(KEY_E);verify(ui.feed_ui.visible and world.player.input_blocked,"E opens small food UI")
	verify(ui.feed_ui.grid.get_child_count()==2 and ui.feed_ui.panel.size.x<280 and ui.feed_ui.panel.size.y<110,"compact squares only")
	var button=ui.feed_ui.grid.get_child(0)
	verify(button.icon!=null and not button.tooltip_text.is_empty(),"food icon and hover metadata")
	var card=button._make_custom_tooltip("");verify(card is PanelContainer,"same full item tooltip");card.free()
	await shot("feed-choices")
	var before: int=inv.count_item("broad_leaf");var trust: int=animals.states[id].trust
	await click(button.get_global_rect().get_center())
	verify(not ui.feed_ui.visible and world.player.action=="feed","click enters existing feed gesture")
	verify(inv.count_item("broad_leaf")==before,"no early debit before contact")
	await get_tree().create_timer(1.1).timeout
	verify(inv.count_item("broad_leaf")==before-1 and animals.states[id].trust==trust+1,"one real food and trust commit")
	animals.interact(id,animal);await frames();verify(ui.feed_ui.visible,"can inspect foods during cooldown")
	ui.feed_ui.grid.get_child(0).pressed.emit();await frames()
	verify(inv.count_item("broad_leaf")==before-1 and ui.message.text.contains("刚吃过"),"cooldown gives brief reason, no debit")
	animals.states[id].feed_at=-100000.0
	animals.interact(id,animal);await frames();await key(KEY_ESCAPE)
	verify(not ui.feed_ui.visible and not menu.overlay.visible,"Esc dismisses food picker only")
	animals.interact(id,animal);await frames();world.player.position+=Vector2(200,0);await frames()
	verify(not ui.feed_ui.visible,"range loss closes picker")
	world.player.position=p
	inv.equipment.main_hand=inv.instance("shears")
	verify(animals.caption(id)=="E 剪毛","shears retain priority")
	inv.equipment.clear()
	animals.states["local-feed:chicken"]=animals.make_row("chicken",p+Vector2(-80,0))
	verify(animals.food_slots("local-feed:chicken").size()==1,"chicken filters seeds, not sheep food")
	animals.interact(id,animal);await frames()
	var index: int=animals.food_slots(id)[0]
	var expected: Dictionary=inv.slots[index].duplicate(true)
	inv.slots[index]={"item_id":"plant_fiber","count":2}
	ui.feed_ui.choose(index,expected);await frames()
	verify(world.player.action!="feed" and inv.slots[index].item_id=="plant_fiber","changed source cannot feed wrong item")
	inv.slots[index]=expected
	var slots: Array[Dictionary]=inv.slots.duplicate(true)
	for i in 40:
		if inv.slots[i].get("item_id","") in animals.rules.sheep.foods:inv.slots[i]={}
	inv.changed.emit();animals.states[id].tamed=true;animals.states[id].trust=5
	var mode: String=animals.states[id].mode
	verify(animals.interact(id,animal) and animals.states[id].mode!=mode,"no food retains follow/stay")
	inv.slots=slots
	print("LOCAL_UI_FEED_V2_PASS checks=",checks)
	world.queue_free();menu.queue_free();await frames(12);get_tree().quit()
