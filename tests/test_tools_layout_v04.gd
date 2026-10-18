extends SceneTree
const OUT := "res://reports/equipment-panel-v04/"
var checks: Array=[]
var world: Node
var ui: Control
var service: Node
var pointer := Vector2.ZERO
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func motion(at: Vector2,held: bool=false) -> void:
	var e := InputEventMouseMotion.new()
	e.position=at; e.global_position=at; e.relative=at-pointer; pointer=at
	e.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(e,true); await frames()
func mouse(at: Vector2,pressed: bool,code: int=MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.position=at; e.global_position=at; e.pressed=pressed; e.button_index=code
	e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed and code==MOUSE_BUTTON_LEFT else 0
	root.push_input(e,true); await frames()
func click(at: Vector2,code: int=MOUSE_BUTTON_LEFT) -> void:
	await motion(at); await mouse(at,true,code); await mouse(at,false,code)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func has_state_text(node: Node) -> bool:
	if node is Label and (node.text.contains("未装备") or node.text.contains("主手") or node.text.contains("石斧") or node.text.contains("石镐")): return true
	for child in node.get_children():
		if has_state_text(child): return true
	return false
func run() -> void:
	Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(world)
	while not world.started: await process_frame
	world.player.automated=true
	service=world.item_service;ui=world.item_ui
	world.environment_view.simulation.set_time(10);world.environment_view.simulation.paused=true
	var preview_mode: bool=world.tools_preview
	check(not world.persistent_world,"fixture and tool preview never write formal state")
	check(service.tools_preview==preview_mode,"world and ItemService agree on candidate preview state")
	if not preview_mode:
		for id in ["stone_axe","stone_pickaxe","simple_shovel"]: service.inventory.add(id,1)
	ui.toggle_bag(); await frames(6)
	check(ui.cells.size()==43,"all original slots and three equipment slots retained")
	check(ui.cells[41].global_position.y<ui.cells[40].global_position.y and ui.cells[40].global_position.y<ui.cells[42].global_position.y,"equipment top to bottom head weapon outfit")
	check(is_equal_approx(ui.cells[41].global_position.x,ui.cells[40].global_position.x) and is_equal_approx(ui.cells[40].global_position.x,ui.cells[42].global_position.x),"three equipment cells aligned vertically")
	var portrait: Control=ui.bag.find_child("CharacterPortrait",true,false)
	var section: Control=ui.bag.find_child("EquipmentSection",true,false)
	var title: Control=ui.bag.find_child("EquipmentTitle",true,false)
	check(section is PanelContainer,"equipment area has a separate full border")
	check(is_equal_approx(ui.cells[41].global_position.y,ui.cells[8].global_position.y),"head cell top aligns with first bag cell")
	check(is_equal_approx(title.get_global_rect().get_center().x,portrait.get_global_rect().get_center().x) and title.get_global_rect().end.y<=portrait.global_position.y,"equipment title centered above character portrait")
	for index in [41,40,42]:
		var label: Control=ui.cells[index].get_parent().get_child(1)
		check(label is Label and label.global_position.y>=ui.cells[index].get_global_rect().end.y,"slot label under cell "+str(index))
	check(ui.cells[40].get_global_rect().end.x<portrait.global_position.x,"equipment cells sit to left of character portrait")
	check(service.inventory.slot_key(40)=="main_hand" and service.inventory.slot_key(41)=="head" and service.inventory.slot_key(42)=="outfit","visual reorder keeps logical slot identities unchanged")
	check(service.inventory.equipment_slots[0].name=="武器" and service.inventory.equipment_slots[2].name=="服装","visible slot names use weapon and outfit")
	check(not has_state_text(ui.bag),"no unequipped or item-content labels in bag")
	check(not "equipped_badge" in world.player and not "hand_badge" in ui,"HUD and actor equipment text removed")
	check(ui.bag.get_global_rect().end.y<ui.dock.get_global_rect().position.y,"bag leaves original bottom hotbar visible")
	for i in 3:
		var id: String=["stone_axe","stone_pickaxe","simple_shovel"][i]
		check(service.texture(id,"icon")!=null,"approved icon available "+id)
		check(service.texture(id,"world")!=null,"approved world art available "+id)
		check(str(service.database.item(id).icon).begins_with("res://assets/tools/v04/"),"approved formal item art definition "+id)
		check(service.inventory.slots[8+i].item_id==id,"three debug tools occupy original bag cells "+id)
	check(ui.preview_actor.has_node("Visual/ArmLBehind"),"portrait uses corrected rear arm hierarchy")
	world.player.facing="right";world.player.moving=true;world.player.gait_distance=32
	world.player.update_animation();await frames(4)
	var source_arm: Sprite2D=world.player.character.get_node("Visual/ArmLBehind")
	var preview_arm: Sprite2D=ui.preview_actor.get_node("Visual/ArmLBehind")
	check(preview_arm.texture==load("res://assets/hero/cartoon/art/front_arm.png") and ui.preview_actor.get_node("Visual").scale.x==1,"portrait stays front-facing while world faces right")
	world.player.input_override=Vector2.RIGHT
	for i in 6:
		await physics_frame
		await frames(1)
		var drive: RemoteTransform2D=world.player.character.get_node("Visual/Pelvis/ArmL/RearVisualDrive")
		check(source_arm.global_transform.is_equal_approx(drive.global_transform),"native rear arm follows movement without manual sync "+str(i))
	world.player.input_override=Vector2.ZERO
	world.player.moving=false;world.player.facing="front";world.player.update_animation()
	await frames(3)
	if preview_mode:
		await shot("candidate-bag")
		await click(ui.cells[8].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
		await click(ui.equip_button.get_global_rect().get_center())
		check(service.inventory.has_capability("chop") and ui.cells[40].icon.texture!=null,"right click equips illustrated axe into weapon cell")
		check(not has_state_text(ui.bag),"equipped item still adds no persistent content label")
		await shot("candidate-equipped")
		await motion(ui.cells[40].get_global_rect().get_center())
		await create_timer(.22).timeout
		check(is_instance_valid(ui.hover_card),"illustrated equipment retains hover card")
		await shot("candidate-hover")
		ui.hide_item_hover()
		var start: Vector2=ui.cells[9].get_global_rect().get_center()
		var end: Vector2=ui.cells[40].get_global_rect().get_center()
		await motion(start);await mouse(start,true);await motion(start+Vector2(20,0),true)
		check(root.gui_is_dragging(),"native illustrated tool drag begins")
		await motion(end,true);await mouse(end,false)
		check(service.inventory.has_capability("mine") and service.inventory.slots[9].item_id=="stone_axe","reordered weapon cell supports native drag swap")
		await click(ui.cells[40].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
		await click(ui.equip_button.get_global_rect().get_center())
		check(service.inventory.get_slot(40).is_empty(),"right click unequips from reordered weapon cell")
		ui.close_panels()
		check(service.discard(8,1),"illustrated tool can use original discard path")
		await create_timer(.55).timeout
		var found := false
		for drop in world.stream.drops:
			if is_instance_valid(drop) and drop.get_meta("item_id","")=="stone_pickaxe":
				found=true
				check(drop.has_method("animate_drop") and drop.get_meta("instance",{}).item_id=="stone_pickaxe","world tool art uses animated drop and preserves instance")
		check(found,"world tool exists after landing")
		await shot("candidate-ground")
	else: await shot("formal-layout")
	var failed := 0
	for row in checks:
		if not row.pass: failed+=1
	var mode := "candidate" if preview_mode else "formal"
	var file := FileAccess.open(OUT+mode+"-tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"count":checks.size(),"failures":failed},"  "));file.close()
	print("TOOLS_LAYOUT ",mode," ",checks.size()," checks; ",failed," failures")
	world.queue_free();await frames(6)
	quit(0 if failed==0 else 1)
