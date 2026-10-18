extends SceneTree
const OUT := "res://reports/portrait-front-v04/"
var world: Node
var ui: Control
var checks: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func equip(id: String) -> void:
	for i in 40:
		if world.item_service.inventory.slots[i].get("item_id","")==id:
			world.item_service.inventory.equip(i);return
func run() -> void:
	Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	world.player.automated=true;world.player.set_physics_process(false)
	ui=world.item_ui;ui.toggle_bag()
	for id in ["stone_axe","stone_pickaxe","simple_shovel"]:world.item_service.inventory.add(id,1)
	for id in ["stone_axe","stone_pickaxe","simple_shovel"]:
		equip(id)
		for facing in ["front","right","left","back"]:
			world.player.facing=facing;world.player.moving=true;world.player.gait_distance=32;world.player.update_animation()
			await frames(3)
			var portrait: Node2D=ui.preview_actor
			var visual: Node2D=portrait.get_node("Visual")
			check(portrait.get_node("AnimationPlayer").current_animation=="front_breathe","front idle independent of world walk "+id+" "+facing)
			check(visual.scale==Vector2.ONE and visual.position==Vector2.ZERO,"portrait never mirrors/turns "+id+" "+facing)
			check(portrait.get_node("Visual/Pelvis/Head/Sprite").texture==load("res://assets/hero/cartoon/art/front_head.png"),"front head stays visible "+id+" "+facing)
			var tool: Sprite2D=portrait.get_node("Visual/Pelvis/ArmR/HeldTool")
			check(tool.visible and tool.get_meta("item_id")==id,"equipped tool updates in front portrait "+id+" "+facing)
			check(tool.get_index()<tool.get_parent().get_node("Sprite").get_index(),"front hand covers shaft "+id+" "+facing)
			var expected: String=("side" if facing in ["left","right"] else facing)+"_walk"
			check(world.player.animation_player.current_animation==expected,"world retains own view/animation "+id+" "+facing)
		world.item_service.inventory.unequip(40);await frames(2)
		check(not ui.preview_actor.get_node("Visual/Pelvis/ArmR/HeldTool").visible,"unequip clears fixed-front tool "+id)
	# Backpack movement remains real, with the display never turning or walking.
	equip("simple_shovel");world.player.cancel_action();world.player.set_physics_process(true)
	var start: Vector2=world.player.position
	world.player.input_override=Vector2.LEFT
	await create_timer(.22).timeout
	world.player.input_override=Vector2.ZERO
	check(world.player.position.x<start.x-10,"open bag still permits actual left movement")
	check(world.player.facing=="left" and ui.preview_actor.get_node("Visual").scale.x==1 and ui.preview_actor.get_node("AnimationPlayer").current_animation=="front_breathe","actual left movement cannot turn portrait")
	# A world interaction does not force the equipment display into that action.
	world.player.set_physics_process(false);world.player.action="pickup";world.player.action_clock=.3;world.player.update_animation();await frames(3)
	check(ui.preview_actor.get_node("AnimationPlayer").current_animation=="front_breathe" and ui.preview_actor.get_node("Visual/Pelvis/ArmR/HeldTool").visible,"portrait remains equipment idle during world pickup")
	world.player.cancel_action();world.player.update_animation()
	ui.close_panels();ui.toggle_bag();await frames(3)
	check(ui.preview_actor.get_node("AnimationPlayer").current_animation=="front_breathe","reopening bag preserves front view")
	check(not world.player.input_blocked,"fixed portrait does not block bag movement")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"front-shovel-world-left.png")
	var failed := 0
	for row in checks:
		if not row.pass:failed+=1
	var file := FileAccess.open(OUT+"tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"count":checks.size(),"failures":failed,"checks":checks},"  "));file.close()
	print("FRONT_PORTRAIT ",checks.size()," checks; ",failed," failures")
	world.queue_free();await frames(6)
	quit(0 if failed==0 else 1)
