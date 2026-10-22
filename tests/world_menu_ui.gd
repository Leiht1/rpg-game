extends SceneTree
class Fixture extends Node:
	var title:=Label.new()
	var player={"input_blocked":false}
	var item_service={"body":Body.new(),"expansion_ui":null,"industry_ui":null,"planting_ui":null,"storage_ui":null,"merchant":{"ui":null}}
	var item_ui=UI.new()
	var map_view:=Control.new()
	var camp_ui=null
	func _input(event):
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
			for page in [item_ui.modal,map_view,item_ui.bag,item_ui.catalog,item_ui.craft_panel]:
				if page.visible:page.hide();get_viewport().set_input_as_handled();return
class Body extends RefCounted:
	func sleep_active():return false
class UI extends RefCounted:
	var bag:=Control.new()
	var catalog:=Control.new()
	var craft_panel:=Control.new()
	var modal:=Control.new()
	var body_ui=null
	func update_input_block():pass
func _initialize() -> void:run.call_deferred()
func esc(echo_value:bool=false):
	var event:=InputEventKey.new();event.physical_keycode=KEY_ESCAPE;event.pressed=true;event.echo=echo_value
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	assert(load("res://scripts/launcher.gd") != null)
	assert(load("res://scripts/network_game_world.gd") != null)
	var world:=Fixture.new();root.add_child(world)
	world.add_child(world.title)
	for page in [world.item_ui.bag,world.item_ui.catalog,world.item_ui.craft_panel,world.item_ui.modal,world.map_view]:world.add_child(page);page.hide()
	var simulation=load("res://scripts/world_environment.gd").new();world.add_child(simulation)
	var dial=load("res://scripts/environment_dial.gd").new();world.add_child(dial);dial.position=Vector2(20,16);dial.simulation=simulation
	var menu=load("res://scripts/world_menu.gd").new()
	menu.world_provider=func():return world
	var calls:=[0];menu.return_action=func():calls[0]+=1
	root.add_child(menu);await process_frame;menu._process(0)
	assert(not world.title.visible)
	assert(menu.trigger.size==Vector2(44,24))
	var rect:Rect2=menu.trigger.get_global_rect()
	assert(rect.end.distance_to(Vector2(90,86)) > 68)
	assert(not menu.overlay.visible)
	menu.trigger.pressed.emit();assert(menu.overlay.visible)
	assert(world.get_meta("world_menu_open"))
	assert(menu.panel.get_theme_stylebox("panel") is StyleBoxTexture)
	assert(menu.panel.get_child_count()==2)
	await create_timer(.2).timeout
	assert(menu.panel.size.y < 100 and menu.panel.size.x < 240)
	assert((menu.panel.get_global_rect().get_center()-root.get_visible_rect().get_center()).length()<1)
	await esc();assert(not menu.overlay.visible)
	for page in [world.item_ui.bag,world.map_view,world.item_ui.catalog,world.item_ui.craft_panel,world.item_ui.modal]:
		page.show();await esc();assert(not page.visible and not menu.overlay.visible)
		await esc();assert(menu.overlay.visible);await esc();assert(not menu.overlay.visible)
	# Even a page that fails to consume its close key must not open the menu in the same event.
	world.item_ui.bag.show()
	var key:=InputEventKey.new();key.physical_keycode=KEY_ESCAPE;key.pressed=true
	menu._input(key);world.item_ui.bag.hide();menu._unhandled_input(key);assert(not menu.overlay.visible)
	await esc();assert(menu.overlay.visible)
	await esc(true);assert(menu.overlay.visible)
	menu.back.pressed.emit();assert(calls[0]==0 and menu.confirmation.visible)
	await create_timer(.1).timeout
	assert((menu.panel.get_global_rect().get_center()-root.get_visible_rect().get_center()).length()<1)
	DirAccess.make_dir_recursive_absolute("res://reports/.tmp/world-menu-confirm")
	root.get_texture().get_image().save_png("res://reports/.tmp/world-menu-confirm/confirmation.png")
	menu.confirmation.get_child(1).get_child(1).pressed.emit()
	assert(calls[0]==0 and menu.back.visible and menu.overlay.visible)
	menu.back.pressed.emit();await esc();assert(calls[0]==0 and not menu.confirmation.visible and menu.overlay.visible)
	menu.back.pressed.emit();menu.confirmation.get_child(1).get_child(0).pressed.emit();assert(calls[0]==1)
	await create_timer(.2).timeout
	DirAccess.make_dir_recursive_absolute("res://reports/.tmp/world-menu-v2")
	root.get_texture().get_image().save_png("res://reports/.tmp/world-menu-v2/menu.png")
	menu.queue_free();world.queue_free();await process_frame
	print("WORLD_MENU_UI_V2_PASS")
	quit()
