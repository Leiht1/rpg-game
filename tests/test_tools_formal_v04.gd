extends SceneTree
const OUT := "res://reports/tools-formal-v04/"
const Interaction = preload("res://scripts/world_interaction.gd")
var checks: Array=[]
var failures: Array=[]
var world: Node
var ui: Control
var service: Node
var pointer := Vector2.ZERO
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: failures.append(label); push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func mouse(at: Vector2, pressed: bool, code: int=MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.position=at; e.global_position=at; e.pressed=pressed; e.button_index=code
	e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed and code==MOUSE_BUTTON_LEFT else 0
	root.push_input(e,true)
	await frames()
func motion(at: Vector2, held: bool=false) -> void:
	var e := InputEventMouseMotion.new()
	e.position=at; e.global_position=at; e.relative=at-pointer; pointer=at
	e.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(e,true)
	await frames()
func click(at: Vector2, code: int=MOUSE_BUTTON_LEFT) -> void:
	await motion(at); await mouse(at,true,code); await mouse(at,false,code)
func key(code: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode=code; e.keycode=code; e.pressed=true
	root.push_input(e,true); await frames()
	e=InputEventKey.new(); e.physical_keycode=code; e.keycode=code
	root.push_input(e,true); await frames()
func drag(a: int,b: int) -> void:
	var start: Vector2=ui.cells[a].get_global_rect().get_center()
	await motion(start); await mouse(start,true); await motion(start+Vector2(20,0),true)
	check(root.gui_is_dragging(),"native drag begins %d"%a)
	var end: Vector2=ui.cells[b].get_global_rect().get_center()
	await motion(end,true); await mouse(end,false)
func shot(name_text: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_text+".png")
func equip_id(id: String) -> bool:
	for i in 40:
		if service.inventory.slots[i].get("item_id","")==id: return service.inventory.equip(i)
	return false
func run() -> void:
	Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	world.player.automated=true;world.player.set_physics_process(false)
	service=world.item_service;ui=world.item_ui
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	for id in ["stone_axe","stone_pickaxe","simple_shovel"]:service.inventory.add(id,1)
	check(not world.tools_preview,"verification uses normal formal entry")
	var view := SubViewport.new();view.size=Vector2i(256,256);view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var review_actor: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate()
	review_actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	review_actor.scale=Vector2.ONE*2
	view.add_child(review_actor);review_actor.get_node("AnimationPlayer").stop()
	var board := Image.create(768,1024,false,Image.FORMAT_RGBA8);board.fill(Color("f3ead4"))
	for col in 3:
		var id: String=["stone_axe","stone_pickaxe","simple_shovel"][col]
		equip_id(id)
		check(service.texture(id,"icon")!=null and service.texture(id,"world")!=null,"formal icon and world PNG "+id)
		for row in 4:
			world.player.facing=["front","right","left","back"][row]
			world.player.action="";world.player.moving=false;world.player.idle_clock=.2
			world.player.update_animation()
			await frames()
			var held: Sprite2D=world.player.character.get_node("Visual/Pelvis/ArmR/HeldTool")
			check(held.visible and held.get_meta("item_id")==id,"correct formal held tool "+id+" "+world.player.facing)
			var pin: Vector2=-held.offset
			var grip_alpha: Color=held.texture.get_image().get_pixel(roundi(pin.x),roundi(pin.y))
			check(grip_alpha.a>.9,"grip registered on opaque shaft "+id+" "+world.player.facing)
			check(held.get_index()<held.get_parent().get_node("Sprite").get_index(),"tool shaft behind hand "+id+" "+world.player.facing)
			check(not world.player.character.get_node("Visual/Pelvis/ArmR/Grip/Axe").visible,"legacy axe hidden "+id+" "+world.player.facing)
			var before_rotation: float=held.get_parent().rotation
			for repeat in 12: world.player.update_animation()
			check(is_equal_approx(before_rotation,held.get_parent().rotation),"held stance never accumulates drift "+id+" "+world.player.facing)
			ui.sync_portrait(world.player.character,review_actor)
			await RenderingServer.frame_post_draw
			board.blend_rect(view.get_texture().get_image(),Rect2i(0,0,256,256),Vector2i(col*256,row*256))
			world.player.moving=true;world.player.gait_distance=32;world.player.update_animation()
			check(held.visible,"walking retains equipped tool "+id+" "+world.player.facing)
			world.player.action="pickup";world.player.action_clock=.4;world.player.update_animation()
			check(not held.visible,"pickup frees the hand "+id+" "+world.player.facing)
			world.player.cancel_action();world.player.moving=false;world.player.update_animation()
			check(held.visible,"tool returns after pickup "+id+" "+world.player.facing)
			check(service.inventory.has_capability({"stone_axe":"chop","stone_pickaxe":"mine","simple_shovel":"dig"}[id]),"capability unchanged "+id+" "+world.player.facing)
		world.player.facing="front";world.player.update_animation()
		ui.toggle_bag();await frames(5)
		var twin: Sprite2D=ui.preview_actor.get_node("Visual/Pelvis/ArmR/HeldTool")
		var held: Sprite2D=world.player.character.get_node("Visual/Pelvis/ArmR/HeldTool")
		check(twin.visible and twin.texture==held.texture and twin.offset==held.offset and twin.centered==held.centered,"live bag preview matches held registration "+id)
		check(twin.get_index()<twin.get_parent().get_node("Sprite").get_index(),"portrait hand occludes shaft "+id)
		await shot(id+"-bag")
		ui.close_panels()
	board.save_png(OUT+"native-held-four-directions.png")
	service.inventory.unequip(40);world.player.update_animation()
	check(not world.player.character.get_node("Visual/Pelvis/ArmR/HeldTool").visible,"unequip clears visible held tool")
	# Restore on the same atomic inventory snapshot must immediately restore the held art.
	equip_id("stone_pickaxe")
	world.persistent_world=true;service.save_path="user://test-tools-formal-v04.json";service.save_state()
	service.inventory.equipment={};service.inventory.changed.emit();service.load_state()
	check(world.player.character.get_node("Visual/Pelvis/ArmR/HeldTool").visible and service.inventory.has_capability("mine"),"save restore immediately restores held tool and capability")
	world.persistent_world=false;DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
	ui.close_panels();world.player.cancel_action();world.player.set_physics_process(true)
	# Real E mining and pickup use the existing action path with the new held art.
	var ore: Node2D=service.debug_ore();check(ore!=null,"clear formal ore point available")
	if ore!=null:
		var id: String=ore.get_meta("ore_id")
		world.player.position=ore.position+Vector2(0,30);world.player.reset_physics_interpolation();world.player.camera.reset_smoothing()
		await frames(8);await motion(root.get_canvas_transform()*(ore.position+Vector2(0,-8)));await key(KEY_E)
		check(world.player.action=="mine" and world.player.character.get_node("Visual/Pelvis/ArmR/HeldTool").visible,"actual E mining holds the pickaxe")
		await create_timer(.85).timeout
		check(service.consumed.has(id) and service.loose.has(id+":drop"),"actual mining creates existing material exactly once")
		await shot("formal-mining")
	var file := FileAccess.open(OUT+"tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"count":checks.size(),"failures":failures,"checks":checks},"  "));file.close()
	print("FORMAL_TOOLS ",checks.size()," checks; ",failures.size()," failures")
	view.queue_free();world.queue_free();await frames(8)
	quit(0 if failures.is_empty() else 1)
