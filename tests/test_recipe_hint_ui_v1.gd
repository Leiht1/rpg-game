extends SceneTree
const OUT := "res://reports/ui-hints-v1/"
var world: Node
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func frames(n: int=3) -> void:
	for i in n:await process_frame
func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func shot(id: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+id+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.max_fps=60;Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	world.player.automated=true;world.player.set_physics_process(false)
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	var ui: Control=world.item_ui
	ui.toggle_craft();await frames(5)
	var panel_rect: Rect2=ui.craft_panel.panel.get_global_rect()
	for id in ui.craft_panel.recipe_buttons:
		var entry: Button=ui.craft_panel.recipe_buttons[id]
		check(entry.modulate==Color.WHITE,"insufficient recipe retains light card "+id)
		check(entry.get_tooltip().is_empty(),"recipe has no duplicate native tooltip "+id)
	ui.craft_panel.select_recipe("hand_stone_pickaxe");await frames(3)
	var chosen: Button=ui.craft_panel.recipe_buttons.hand_stone_pickaxe
	check(chosen.button_pressed and chosen.text.contains("已选"),"selected recipe has explicit visible marker")
	check(not ui.craft_panel.recipe_buttons.hand_stone_axe.button_pressed and not ui.craft_panel.recipe_buttons.hand_stone_axe.text.contains("已选"),"previous recipe clears selected state")
	check(chosen.get_theme_stylebox("pressed").texture.resource_path.ends_with("slot_selected.png"),"selected card uses separately painted golden rim")
	var normal: StyleBox=chosen.get_theme_stylebox("normal")
	var selected: StyleBox=chosen.get_theme_stylebox("pressed")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:check(normal.get_content_margin(side)==selected.get_content_margin(side),"recipe state margins stable "+str(side))
	var motion := InputEventMouseMotion.new();motion.position=chosen.get_global_rect().get_center();motion.global_position=motion.position;root.push_input(motion,true)
	await create_timer(.8).timeout
	check(chosen.get_tooltip().is_empty() and ui.craft_panel.panel.get_global_rect()==panel_rect,"hover keeps tooltip empty and frame fixed")
	await shot("recipes")
	ui.close_panels();ui.set_process(false)
	var target := Node2D.new();world.add_child(target);target.position=world.player.position+Vector2(20,5)
	target.set_meta("display_name","半埋根茎");target.set_meta("interaction_action","dig")
	ui.update_target_tip(target,0)
	check(ui.target_tip.visible,"world target hint is shown through existing logic")
	check(ui.target_tip.get_theme_stylebox("panel").texture.resource_path.ends_with("hints_v1/target_hint.png"),"world hint references new single-sheet image")
	var item_card: Control=ui.make_item_card(8)
	check(ui.target_tip.get_theme_stylebox("panel").texture!=item_card.get_theme_stylebox("panel").texture,"world hint is distinct from existing item hover note")
	item_card.free()
	await frames(5);await shot("target-hint")
	check(ui.target_tip.size.y<45,"single-layer hint stays compact around one text line")
	var failed := checks.filter(func(row):return not row.pass).size()
	var mode := "headless" if DisplayServer.get_name()=="headless" else "window"
	FileAccess.open(OUT+mode+".json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("RECIPE/HINT UI ",mode,": ",checks.size()," checks; ",failed," failures")
	world.item_service.dirty=false;world.queue_free();await frames(5);quit(0 if failed==0 else 1)
