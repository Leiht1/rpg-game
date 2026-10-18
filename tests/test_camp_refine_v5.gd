extends SceneTree
const OUT := "res://reports/camp-refine-v5/"
var world: Node
var service: Node
var checks: Array=[]
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=3):
	for i in n: await process_frame
func shot(label: String):
	if "--capture" not in OS.get_cmdline_user_args(): return
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func empty_inventory():
	world.item_ui.close_panels();world.item_ui.message_time=0;world.item_ui.message.hide();world.player.cancel_action()
	for i in 40: service.inventory.slots[i]={}
	service.inventory.equipment.clear();service.inventory.hotbar_equipment.clear();service.inventory.changed.emit()
func point(node: Node2D):
	var event := InputEventMouseMotion.new();event.position=root.get_canvas_transform()*(node.position+Vector2(0,-10));event.global_position=event.position;root.push_input(event,true);await frames()
func run():
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	world.player.set_physics_process(false);world.player.camera.position_smoothing_enabled=false;world.environment_view.simulation.paused=true;service=world.item_service
	while not world.stream.viewport_ready(world.player.position,Vector2(640,360)): await process_frame
	await menu_checks()
	await back_pose_checks()
	await real_back_actions()
	var failed: Array=checks.filter(func(v): return not v.pass)
	FileAccess.open(OUT+("window-tests.json" if "--capture" in OS.get_cmdline_user_args() else "tests.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"  "))
	print("REFINE V5: %d checks, %d failed"%[checks.size(),failed.size()])
	world.persistent_world=false;world.free();await process_frame;quit(0 if failed.is_empty() else 1)
func menu_checks():
	for tool in ["stone_axe","stone_pickaxe","simple_shovel","stone_hammer"]:
		empty_inventory();var inv: ItemInventory=service.inventory
		inv.slots[0]=inv.instance(tool);var id: String=inv.slots[0].instance_id
		check(inv.equip(0),"equip from hotbar "+tool)
		world.item_ui.open_item_menu(0,Vector2(600,420))
		check(world.item_ui.equip_button.text=="卸下","equipped alias menu says unequip "+tool)
		check(world.item_ui.equipped_action_index(0)>=40,"alias resolves real equipment slot "+tool)
		await shot("hotbar-unequip-"+tool)
		world.item_ui.equip_button.pressed.emit()
		check(inv.equipment.get("main_hand",{}).is_empty() and inv.slots[0].get("instance_id")==id,"menu unequips same instance to its hotbar "+tool)
		check(not inv.hotbar_equipment.has("0") and inv.slots[0].durability==100,"unequip removes alias and retains durability "+tool)
		world.item_ui.open_item_menu(0,Vector2(600,420));check(world.item_ui.equip_button.text=="装备","unequipped hotbar says equip "+tool)
		world.item_ui.equip_button.pressed.emit();check(inv.equipment.main_hand.instance_id==id and inv.slots[0].is_empty(),"menu equips physical hotbar item again "+tool)
	empty_inventory();var inv: ItemInventory=service.inventory
	inv.slots[0]=inv.instance("stone_axe");inv.equip(0)
	for i in range(8,40): inv.slots[i]={"item_id":"wood","count":99}
	world.item_ui.open_item_menu(0,Vector2(600,420));world.item_ui.equip_button.pressed.emit()
	check(inv.slots[0].get("item_id")=="stone_axe" and inv.equipment.get("main_hand",{}).is_empty(),"full bag still unequips into original hotbar")
	empty_inventory();inv.slots[0]=inv.instance("stone_axe");var first: String=inv.slots[0].instance_id;inv.equip(0)
	world.item_ui.open_item_menu(0,Vector2(600,420))
	inv.slots[1]=inv.instance("stone_pickaxe");inv.equip(1)
	world.item_ui.equip_button.pressed.emit()
	check(inv.equipment.main_hand.item_id=="stone_pickaxe" and inv.slots[0].instance_id==first,"stale unequip label cannot equip returned former item")
	empty_inventory();inv.slots[8]=inv.instance("stone_axe");inv.equip(8)
	for i in range(8,40): inv.slots[i]={"item_id":"wood","count":99}
	var equipment_index := -1
	for i in inv.equipment_slots.size():
		if inv.equipment_slots[i].id=="main_hand": equipment_index=40+i
	world.item_ui.open_item_menu(equipment_index,Vector2(600,420));world.item_ui.equip_button.pressed.emit()
	check(inv.equipment.get("main_hand",{}).get("item_id")=="stone_axe","unbound equipped item stays when bag full")
	empty_inventory()
func back_pose_checks():
	var player: Node=world.player;var animation: AnimationPlayer=player.animation_player
	var reference: Array=[]
	service.inventory.equipment.main_hand=service.inventory.instance("stone_hammer")
	player.facing="back";player.action="demolish";player.action_clock=.55;player.update_animation()
	for path in ["Visual/Pelvis","Visual/Pelvis/ArmR","Visual/Pelvis/ArmL","Visual/Pelvis/Head","Visual/LegL","Visual/LegR"]:
		reference.append(player.character.get_node(path).transform)
	check(animation.current_animation=="harvest/back_mine","hammer reference is existing native back clip")
	for row in [["mine","stone_pickaxe",.55],["chop","stone_axe",.36],["dig","simple_shovel",.68]]:
		service.inventory.equipment.main_hand=service.inventory.instance(row[1])
		player.action=row[0];player.facing="back";player.action_clock=row[2];player.update_animation()
		check(animation.current_animation=="harvest/back_mine","back action shares hammer native clip "+row[0])
		var at := 0
		for path in ["Visual/Pelvis","Visual/Pelvis/ArmR","Visual/Pelvis/ArmL","Visual/Pelvis/Head","Visual/LegL","Visual/LegR"]:
			check(player.character.get_node(path).transform.is_equal_approx(reference[at]),"shared back contact pose "+row[0]+path);at+=1
		check(player.character.get_node("Visual/Pelvis/ArmR/HeldTool").get_meta("item_id")==row[1],"correct held tool on shared pose "+row[0])
		await shot("back-contact-"+row[0])
		for view in ["front","right","left"]:
			player.facing=view;player.update_animation()
			var direction := "front" if view=="front" else "side"
			check(animation.current_animation==("harvest/" if row[0]!="chop" else "")+direction+"_"+row[0],"existing other view retained "+row[0]+view)
	check(is_equal_approx(animation.get_animation("back_chop").length,.82),"original chop end time unchanged")
	check(is_equal_approx(animation.get_animation("harvest/back_dig").length,1.25),"original digging end time unchanged")
	player.cancel_action()
func real_back_actions():
	var player: Node=world.player
	empty_inventory()
	var tree: Node2D
	for node in get_nodes_in_group("trees"):
		var at: Vector2=node.position+Vector2(0,48)
		if world.generator.can_walk(at,12) and world.stream.tree_in_reach(at,node): tree=node;break
	check(tree!=null,"original tree approachable from south")
	if tree!=null:
		service.inventory.equipment.main_hand=service.inventory.instance("stone_axe");player.position=tree.position+Vector2(0,48);player.reset_physics_interpolation();player.camera.reset_smoothing();player.camera.force_update_scroll();await frames(8);await point(tree)
		player.try_interact();check(player.action=="chop" and player.facing=="back","original E chop chooses back toward northern tree")
		if player.action=="chop":
			var id: String=tree.get_meta("prop_id");var before: int=world.stream.tree_hits.get(id,0)
			player.action_clock=.35;player._physics_process(.02)
			check(int(world.stream.tree_hits.get(id,0))==before+1 or world.stream.harvested.has(id),"back chop commits original hit once")
			check(service.inventory.equipment.main_hand.durability==99,"back chop costs original one durability")
		player.cancel_action()
	var spawn: Vector2=world.generator.spawn
	for node in get_nodes_in_group("world_interactables"): node.queue_free()
	for drop in world.stream.drops.duplicate():
		if is_instance_valid(drop):world.stream.drops.erase(drop);drop.queue_free()
	await frames()
	for row in [["mine","stone_pickaxe","stone_outcrop",.55],["dig","simple_shovel","buried_bone",.68]]:
		var id: String="back-v5:"+row[0]
		var target: Node2D=service.create_harvest(id,{"kind":row[2],"x":spawn.x,"y":spawn.y-45})
		service.inventory.equipment.main_hand=service.inventory.instance(row[1]);player.position=spawn;player.reset_physics_interpolation();player.camera.reset_smoothing();player.camera.force_update_scroll();await frames(8);await point(target)
		player.try_interact();check(player.action==row[0] and player.facing=="back","original E starts northern target "+row[0])
		if player.action==row[0]:
			player.action_clock=float(row[3])-.01;player._physics_process(.02)
			check(service.resource_hits.get(id,0)==1,"back action commits original contact "+row[0])
			player._physics_process(.02);check(service.resource_hits.get(id,0)==1,"back action no duplicate hit "+row[0])
			check(service.inventory.equipment.main_hand.durability==99,"back action original durability "+row[0])
		await shot("back-real-"+row[0]);player.cancel_action();target.queue_free();await frames()
