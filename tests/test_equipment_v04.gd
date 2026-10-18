extends SceneTree
const OUT := "res://reports/equipment-v04/"
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
func isolated_checks() -> void:
	var db := ItemDatabase.new()
	check(db.errors.is_empty() and db.ids().size()==15,"database keeps 12 items and adds three tools")
	var inv := ItemInventory.new(db)
	check(inv.add("stone_axe",2)==0,"tools fit as independent instances")
	var first: Dictionary=inv.slots[8].duplicate(true)
	check(inv.slots[8].instance_id!=inv.slots[9].instance_id,"two identical tools have different instance IDs")
	check(not inv.has_capability("chop"),"bag tools do not grant capabilities")
	check(inv.move_slot(8,0) and not inv.has_capability("chop"),"hotbar tool does not grant capabilities")
	check(inv.equip(0) and inv.get_slot(40)==first and inv.slots[0].is_empty(),"equip moves whole instance from hotbar")
	check(inv.has_capability("chop") and not inv.has_capability("mine") and not inv.has_capability("dig"),"axe grants only chop")
	inv.add("stone_pickaxe",1)
	check(inv.equip(8) and inv.slots[8]==first and inv.has_capability("mine") and not inv.has_capability("chop"),"occupied equipment swaps into source cell")
	var before: Array=inv.slots.duplicate(true)
	check(not inv.move_slot(40,41) and inv.slots==before and inv.has_capability("mine"),"wrong equipment slot rejects without mutation")
	for i in range(8,40):
		if inv.slots[i].is_empty(): inv.slots[i]={"item_id":"wood","count":99}
	var held: Dictionary=inv.get_slot(40).duplicate(true)
	check(not inv.unequip(40) and inv.get_slot(40)==held,"full bag unequip leaves equipment untouched")
	inv.slots[12]={}
	check(inv.unequip(40) and inv.slots[12]==held and not inv.has_capability("mine"),"unequip moves instance to first bag vacancy")
	inv.equip(12)
	var restored := ItemInventory.new(db)
	check(restored.restore(inv.slots) and restored.restore_equipment(inv.equipment) and restored.has_capability("mine"),"inventory and equipment round trip")
	check(restored.get_slot(40)==held,"instance state and identity survive restoration")
	var duplicate := inv.equipment.duplicate(true)
	restored.slots[12]=held.duplicate(true)
	check(not restored.restore_equipment(duplicate),"duplicate bag/equipment instance rejects restore")
	var legacy := ItemInventory.new(db)
	check(legacy.restore(inv.slots) and legacy.restore_equipment({}) and legacy.equipment.is_empty(),"legacy save without equipment remains compatible")
	check(legacy.restore_equipment({"unknown":{"item_id":"removed_item","count":1},"head":held}) and legacy.equipment.is_empty() and legacy.quarantined_equipment.size()==2,"unknown and illegal equipment preserved in quarantine without capabilities")
	for cap in ["pickup","open","talk","inspect"]: check(Interaction.allowed(null,cap),"basic interaction ungated "+cap)
	check(not Interaction.allowed(null,"chop") and not Interaction.allowed(null,"mine"),"empty hand cannot perform tool actions")
	inv.slots[12]={}
	inv.add("simple_shovel",1); inv.equip(12)
	check(inv.has_capability("dig") and not inv.has_capability("chop") and not inv.has_capability("mine"),"shovel grants only dig")
	# Future equipment must use the same data-driven slots and capabilities.
	var weapon := db.item("stone_axe")
	weapon.item_id="test_sword"; weapon.equipment_type="weapon"; weapon.capabilities=["attack"]
	db.definitions.test_sword=weapon
	var future := ItemInventory.new(db)
	future.add("test_sword",1); future.equip(8)
	check(future.has_capability("attack") and not future.has_capability("chop") and not future.has_capability("mine"),"future weapon does not gain gathering permissions")
	for pair in [["head","headwear",41],["outfit","outfit",42]]:
		var row := weapon.duplicate(true)
		row.item_id="test_"+pair[0]; row.equip_slot=pair[0]; row.equipment_type=pair[1]; row.capabilities=[]
		db.definitions[row.item_id]=row
		future.add(row.item_id,1)
		check(future.equip(8) and future.get_slot(pair[2]).item_id==row.item_id,"data-driven slot accepts "+pair[0])
func run() -> void:
	Engine.max_fps=60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	isolated_checks()
	Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(world)
	while not world.started: await process_frame
	world.player.automated=true
	service=world.item_service; ui=world.item_ui
	world.environment_view.simulation.set_time(10)
	world.environment_view.simulation.paused=true
	service.inventory.add("stone_axe",1); service.inventory.add("stone_pickaxe",1); service.inventory.add("simple_shovel",1)
	service.inventory.add("wild_berry",3)
	await key(KEY_B)
	check(ui.bag.visible and ui.cells.size()==43,"one bag window displays 32 bag cells and three equipment cells")
	check(ui.cells[8].global_position.x<ui.cells[40].global_position.x,"bag left and equipment right")
	check(ui.preview_actor!=null and ui.preview_view.size==Vector2i(156,228),"live original-rig character preview exists")
	await click(ui.cells[8].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(ui.equip_button.visible and ui.equip_button.text=="装备","right click tool offers equip")
	await click(ui.equip_button.get_global_rect().get_center())
	check(service.inventory.has_capability("chop") and service.inventory.slots[8].is_empty(),"native menu equips axe")
	await frames()
	check(not "equipped_summary" in ui and not "equipped_badge" in world.player,"equipment content text removed; hover cards retained")
	await shot("bag-equipped-axe")
	await drag(9,40)
	check(service.inventory.has_capability("mine") and service.inventory.slots[9].item_id=="stone_axe","native drag exchanges pickaxe and axe")
	await drag(40,41)
	check(service.inventory.has_capability("mine") and service.inventory.get_slot(41).is_empty(),"native wrong-slot drop rejected")
	await drag(40,8)
	check(not service.inventory.has_capability("mine") and service.inventory.slots[8].item_id=="stone_pickaxe","native drag unequips into bag")
	await drag(9,40)
	await click(ui.cells[40].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(ui.equip_button.text=="卸下" and not ui.destroy_button.visible,"equipment menu offers unequip without destroy")
	await click(ui.equip_button.get_global_rect().get_center())
	check(service.inventory.get_slot(40).is_empty(),"native menu unequips")
	equip_id("stone_axe")
	ui.show_item_hover(40); await create_timer(.2).timeout
	check(is_instance_valid(ui.hover_card),"equipped item supports hover card")
	await shot("equipment-hover")
	ui.close_panels()
	# Real existing tree, with original collision and original hit/drop behavior.
	var tree: Node2D
	var approach := Vector2.ZERO
	for node in get_nodes_in_group("trees"):
		for offset in [Vector2(0,48),Vector2(48,0),Vector2(-48,0)]:
			var place: Vector2=node.position+offset
			if world.generator.can_walk(place,12) and world.stream.tree_in_reach(place,node): tree=node; approach=place; break
		if tree!=null: break
	check(tree!=null,"reachable original tree found")
	if tree!=null:
		world.player.position=approach
		world.player.reset_physics_interpolation()
		world.player.camera.reset_smoothing()
		await frames(10)
		var id: String=tree.get_meta("prop_id")
		var hits: int=int(world.stream.tree_hits.get(id,0))
		service.inventory.unequip(40)
		check(not Interaction.execute(world.stream,world.player,tree) and int(world.stream.tree_hits.get(id,0))==hits,"empty hand leaves tree unmodified")
		equip_id("stone_pickaxe")
		check(service.inventory.has_capability("mine"),"pickaxe equipped for negative tree case")
		check(not Interaction.execute(world.stream,world.player,tree) and int(world.stream.tree_hits.get(id,0))==hits,"pickaxe cannot chop tree")
		# Drop lies off-facing; pointer still chooses it ahead of a pointed tree.
		var dpos: Vector2=approach+Vector2(0,16)
		var entry := {"id":"test:pickup","item_id":"branch","count":1,"x":dpos.x,"y":dpos.y}
		service.loose[entry.id]=entry
		var drop: Node2D=world.stream.create_item_drop(entry)
		check(world.stream.interaction_target(approach,"back",dpos)==drop,"mouse target wins within range")
		check(world.stream.interaction_target(approach,"back",tree.position+Vector2(0,-25))==tree,"mouse explicitly selects tree over nearby pickup")
		check(world.stream.interaction_target(approach,"back")==drop,"unusable tree does not permanently steal fallback pickup")
		check(Interaction.execute(world.stream,world.player,drop),"pickaxe still permits ordinary pickup")
		equip_id("stone_axe")
		check(service.inventory.has_capability("chop"),"axe equipped for real tree")
		var cursor: Vector2=root.get_canvas_transform()*(tree.position+Vector2(0,-25))
		await motion(cursor)
		await key(KEY_E)
		check(world.player.action=="chop","E starts original axe chop")
		await create_timer(.9).timeout
		check(int(world.stream.tree_hits.get(id,0))==hits+1,"one real axe action commits one hit")
		await key(KEY_E); await create_timer(.9).timeout
		check(world.stream.harvested.has(id) or int(world.stream.tree_hits.get(id,0))==hits+2,"second axe hit preserves tree hit/drop behavior")
	# Ore test uses a clear loaded spot, independent of landscape rocks.
	world.player.cancel_action()
	world.player.position=world.generator.spawn
	world.player.reset_physics_interpolation(); world.player.camera.reset_smoothing()
	await frames(12)
	var ore: Node2D=service.debug_ore()
	check(ore!=null,"F6 developer ore can be placed on clear loaded ground")
	if ore!=null:
		var ore_id: String=ore.get_meta("ore_id")
		service.inventory.unequip(40)
		check(not Interaction.execute(world.stream,world.player,ore) and not service.consumed.has(ore_id),"empty hand cannot mine or remove ore")
		equip_id("stone_axe")
		check(not Interaction.execute(world.stream,world.player,ore) and not service.consumed.has(ore_id),"axe cannot mine")
		equip_id("stone_pickaxe")
		world.player.position=ore.position+Vector2(0,30)
		world.player.reset_physics_interpolation(); world.player.camera.reset_smoothing()
		await frames(8)
		await motion(root.get_canvas_transform()*(ore.position+Vector2(0,-8)))
		await frames(12); await shot("ore-selected")
		await key(KEY_E)
		check(world.player.action=="mine","E starts pickaxe mining")
		await create_timer(.85).timeout
		check(service.consumed.has(ore_id) and service.loose.has(ore_id+":drop") and service.loose[ore_id+":drop"].count==3,"ore consumes once and creates three existing flint materials")
		var drop: Node2D
		for node in world.stream.drops:
			if is_instance_valid(node) and node.get_meta("drop_id","")==ore_id+":drop": drop=node
		check(drop!=null,"mined material remains a world pickup")
		if drop!=null:
			await motion(root.get_canvas_transform()*drop.position)
			await key(KEY_E); await create_timer(.85).timeout
			check(not service.loose.has(ore_id+":drop"),"E pickup works with equipped pickaxe")
		await shot("mining-complete")
	# Atomic real file round trip in an isolated fixture path.
	world.player.cancel_action()
	service.inventory.get_slot(40).state["test_mark"]="kept"
	var expected: Dictionary=service.inventory.get_slot(40).duplicate(true)
	world.persistent_world=true
	service.save_path="user://test-equipment-v04-isolated.json"
	service.save_state()
	service.inventory.equipment={}; service.ore_nodes={}
	service.load_state()
	check(service.inventory.get_slot(40).instance_id==expected.instance_id and service.inventory.get_slot(40).item_id==expected.item_id and service.inventory.get_slot(40).state==expected.state and int(service.inventory.get_slot(40).count)==int(expected.count) and service.inventory.has_capability("mine"),"atomic save reload restores same equipment instance and capabilities")
	check(not service.ore_nodes.is_empty(),"ore state survives same snapshot reload")
	world.persistent_world=false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.save_path))
	ui.toggle_bag(); await frames(5)
	check(not world.player.input_blocked,"ordinary equipment bag still permits movement")
	var before_pos: Vector2=world.player.position
	world.player.input_override=Vector2.RIGHT
	await create_timer(.2).timeout
	world.player.input_override=Vector2.ZERO
	check(world.player.position.distance_to(before_pos)>10,"movement through open equipment bag")
	ui.toggle_map(); await frames(4)
	check(world.map_view.visible and not ui.bag.visible and world.map_view.get_parent().layer==10,"map still covers equipment bag and HUD")
	await key(KEY_ESCAPE)
	check(not world.map_view.visible,"Esc closes map")
	ui.toggle_bag(); await frames(4); await shot("bag-equipped-pickaxe")
	check(ui.bag.get_global_rect().end.y<ui.dock.get_global_rect().position.y,"equipment bag leaves bottom hotbar visible")
	# Switching the formal main hand during an action must cancel the action.
	world.player.action="mine"
	world.player.action_target=service.debug_ore()
	service.inventory.unequip(40)
	check(world.player.action.is_empty(),"removing tool cancels pending tool action before impact")
	# Tool drops carry the existing instance state rather than minting a new copy.
	ui.close_panels()
	var tool_index := -1
	for i in 40:
		if service.inventory.slots[i].get("item_id","")=="stone_pickaxe": tool_index=i; break
	if tool_index>=0:
		var tool_instance: Dictionary=service.inventory.slots[tool_index].duplicate(true)
		check(service.discard(tool_index,1),"tool uses existing world discard path")
		await create_timer(.5).timeout
		var tool_drop: Node2D
		for node in world.stream.drops:
			if is_instance_valid(node) and node.get_meta("instance",{}).get("instance_id","")==tool_instance.instance_id: tool_drop=node; break
		check(tool_drop!=null and service.inventory.slots[tool_index].is_empty(),"world tool drop retains identity without bag copy")
		if tool_drop!=null:
			check(service.pickup(tool_drop),"dropped tool can be picked up empty-handed")
			var found := 0
			for slot in service.inventory.slots:
				if slot.get("instance_id","")==tool_instance.instance_id:
					found+=1
					check(slot.state==tool_instance.state,"tool instance state survives drop and pickup")
			check(found==1,"exactly one instance exists after tool drop and pickup")
	else: check(false,"tool available for discard identity check")
	ui.toggle_bag()
	# Only registered, rig-compatible approved assets can appear on the preview.
	var head_row: Dictionary=service.database.item("stone_axe")
	head_row.item_id="qa_head"; head_row.equip_slot="head"; head_row.equipment_type="headwear"; head_row.visual_id="qa_existing_head"; head_row.capabilities=[]
	service.database.definitions.qa_head=head_row
	world.player.appearance.registry.qa_existing_head={"front":[{"parent":"Visual/Pelvis/Head","texture":"res://assets/hero/cartoon/art/front_head.png","position":[0,0],"scale":.25}]}
	world.player.facing="front"
	service.inventory.add("qa_head",1)
	equip_id("qa_head")
	await frames(4)
	var world_parts: Array=world.player.character.find_children("EquipmentVisual*","Sprite2D",true,false)
	var preview_parts: Array=ui.preview_actor.find_children("EquipmentVisual*","Sprite2D",true,false)
	check(world_parts.size()==1 and preview_parts.size()==1 and world_parts[0].texture==preview_parts[0].texture,"registered head appearance updates world and portrait together")
	service.inventory.unequip(41)
	await frames(4)
	check(world.player.character.find_children("EquipmentVisual*","Sprite2D",true,false).is_empty() and ui.preview_actor.find_children("EquipmentVisual*","Sprite2D",true,false).is_empty(),"unequip clears both world and portrait appearance")
	for i in 40:
		if service.inventory.slots[i].get("item_id","")=="qa_head": service.inventory.slots[i]={}
	service.database.definitions.erase("qa_head")
	world.player.appearance.registry.erase("qa_existing_head")
	var report := {"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"count":checks.size()}
	var file := FileAccess.open(OUT+"tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")); file.close()
	print("EQUIPMENT_V04 ",checks.size()," checks; ",failures.size()," failures")
	world.queue_free(); await frames(8)
	quit(0 if failures.is_empty() else 1)
