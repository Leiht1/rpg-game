extends SceneTree
var checks: Array=[]
var w
var s
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks.append({"pass":ok,"label":label})
	if not ok:push_error(label)
func run() -> void:
	var login=root.get_node("Network")
	var original_profile: Dictionary=login.profile.duplicate(true)
	login.profile={"role":"player"}
	Engine.set_meta("integration_seed",98171023)
	w=load("res://tests/world_clean_camp_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;w.environment_view.set_process(false);w.set_process(false);w.player.set_physics_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	for i in 40:s.inventory.slots[i]={}
	var row: Dictionary={}
	s.inventory.equipment.main_hand=s.inventory.instance("stone_pickaxe")
	for y in range(-4,5):
		for x in range(-4,5):
			var at: Vector2=w.generator.spawn+Vector2(x*96,y*64);w.player.position=at+Vector2(70,50)
			var candidate: Dictionary=s.builds.candidate("tilled_soil",at,false,true,0)
			if s.builds.reason(candidate).is_empty():row=candidate;break
		if not row.is_empty():break
	check(not row.is_empty(),"legal plot")
	if row.is_empty():quit(1);return
	check(s.builds.place(row,s.inventory.slots.duplicate(true)).is_empty(),"till")
	await process_frame
	var id: String=s.builds.states.keys()[0];var target: Node2D=s.builds.visuals[id];w.player.position=target.position+Vector2(0,40)
	await physics_frame
	s.inventory.add("broad_leaf_seed",3)
	check(s.planting.interact(id,target,"broad_leaf_seed"),"sow broad leaf")
	check(s.inventory.count_item("broad_leaf_seed")==2,"one seed consumed")
	var spec: Dictionary=s.planting.rules.crops.broad_leaf
	for stage in 3:
		s.builds.states[id].growth_minutes=[0.0,float(spec.stage_minutes),float(spec.minutes)][stage]
		check(s.planting.stage(s.builds.states[id])==stage,"growth stage "+str(stage))
		check(ResourceLoader.exists(s.planting.art("broad_leaf_"+str(stage))),"stage art "+str(stage))
	check(s.builds.validate(JSON.parse_string(JSON.stringify(s.builds.serialize())),{}),"crop persistence roundtrip")
	var ready: Dictionary=s.builds.states[id].duplicate(true)
	# Only one free slot: broad leaves fit but fiber/seeds do not; no partial rewards.
	for i in 40:s.inventory.slots[i]={"item_id":"stone","count":99}
	s.inventory.slots[39]={}
	var slots: Array=s.inventory.slots.duplicate(true)
	check(not s.planting.interact(id,target) and s.inventory.slots==slots and s.builds.states[id]==ready,"full bag atomically rejects dual products and seeds")
	for i in 40:s.inventory.slots[i]={}
	slots=s.inventory.slots.duplicate(true)
	var old_path: String=s.save_path;s.save_path="user://missing-leaf-folder/no.json";w.persistent_world=true
	check(not s.planting.interact(id,target) and s.inventory.slots==slots and s.builds.states[id]==ready,"save failure restores all rewards and mature crop")
	w.persistent_world=false;s.save_path=old_path
	check(s.planting.interact(id,target),"harvest broad leaf")
	check(s.inventory.count_item("broad_leaf")==4 and s.inventory.count_item("plant_fiber")==4 and s.inventory.count_item("broad_leaf_seed")==2,"equal leaf fiber and sustainable seeds")
	check(s.builds.states[id].roots and not s.planting.interact(id,target),"roots prevent duplicate harvest")
	# Existing natural-source path deterministically grants the fourth seed.
	var source:=""
	for i in 100:
		var value:="leaf-seed-check-"+str(i)
		if posmod(value.hash(),s.planting.rules.crops.size())==3:source=value;break
	var drop:=Node2D.new();drop.position=w.player.position;w.object_root.add_child(drop)
	for key in {"drop_id":source,"item_id":"plant_fiber","count":1,"natural":true,"mode":"harvest"}:drop.set_meta(key,{"drop_id":source,"item_id":"plant_fiber","count":1,"natural":true,"mode":"harvest"}[key])
	check(s.pickup(drop) and s.inventory.count_item("broad_leaf_seed")==4,"new seed uses original natural gathering")
	# Preview never changes inventory or resource counters, and rejection restores visuals.
	var preview=load("res://scripts/network_interaction_preview.gd").new()
	var sample:=Node2D.new();sample.add_to_group("drops");w.object_root.add_child(sample)
	var before: Array=s.inventory.slots.duplicate(true)
	preview.begin("pickup",sample,"pickup",w.player)
	check(not sample.visible and sample.get_meta("network_pending",false) and s.inventory.slots==before,"pickup pending feedback has no inventory mutation")
	preview.finish("pickup")
	check(sample.visible and sample.modulate==Color.WHITE and not sample.has_meta("network_pending"),"rejected pickup restores full visibility")
	var tree: Node2D
	for candidate in w.object_root.get_children():
		if candidate.is_in_group("trees") and candidate.has_method("hit"):tree=candidate;break
	var hits: Dictionary=w.stream.tree_hits.duplicate(true)
	preview.begin("tree",tree,"chop",w.player)
	check(tree.get_meta("network_preview_hits",0)==1 and w.stream.tree_hits==hits,"chop feedback does not grant authoritative hit")
	preview.finish("tree")
	check(tree.get_meta("network_preview_hits",0)==0,"rejected chop removes preview receipt")
	var network=root.get_node("Network")
	var old_profile: Dictionary=original_profile
	network.profile={"role":"player","nickname":"admin"}
	check(not preload("res://scripts/debug_access.gd").allowed(),"ordinary account cannot obtain debug access by nickname")
	var f4:=InputEventKey.new();f4.pressed=true;f4.physical_keycode=KEY_F4
	w.environment_view.panel.hide();w.environment_view._input(f4)
	check(not w.environment_view.panel.visible,"ordinary account F4 does not open environment tools")
	var f6:=InputEventKey.new();f6.pressed=true;f6.physical_keycode=KEY_F6
	w.item_ui.catalog.hide();w.item_ui._input(f6)
	check(not w.item_ui.catalog.visible,"ordinary account F6 does not open catalog tools")
	check(w.item_ui.catalog.find_child("SpawnAnimal",true,false)==null and w.item_ui.catalog.find_child("SpawnBoar",true,false)==null,"ordinary account has no debug action buttons")
	network.profile={"role":"admin"}
	check(preload("res://scripts/debug_access.gd").allowed(),"authenticated administrator retains debug access")
	w.environment_view._input(f4)
	check(w.environment_view.panel.visible,"administrator F4 opens tools")
	w.environment_view.panel.hide();w.item_ui._input(f6)
	check(w.item_ui.catalog.visible,"administrator F6 opens tools")
	w.item_ui.close_panels();network.profile=old_profile
	var controller=load("res://scripts/network_game_world.gd").new()
	var owned_nodes: Array=[]
	for property in controller.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value=controller.get(property.name)
			if value is Node and value.get_parent()==null:owned_nodes.append(value)
	var network_player=load("res://scripts/network_game_player.gd").new()
	for property in network_player.get_property_list():
		if int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value=network_player.get(property.name)
			if value is Node and value.get_parent()==null:owned_nodes.append(value)
	owned_nodes.append(network_player)
	controller.object_root=w.object_root;controller.player=network_player;controller.item_service=s;controller.requesting=true
	sample.set_meta("drop_id","queue-feedback-check")
	controller.enqueue("interact",[{"drop_id":"queue-feedback-check"}])
	check(controller.commands.size()==1 and sample.get_meta("network_pending",false) and s.inventory.slots==before,"queued interaction provides feedback during an in-flight snapshot")
	controller.interaction_preview.clear();controller.free()
	for value in owned_nodes:
		if is_instance_valid(value):value.free()
	var ore=s.create_ore("ore:preview-check",{"x":w.player.position.x+32,"y":w.player.position.y})
	var resource_hits: Dictionary=s.resource_hits.duplicate(true)
	var children_before: int=ore.get_child_count()
	preview.begin("ore",ore,"mine",w.player)
	check(ore.get_child_count()>children_before and s.resource_hits==resource_hits and not ore.get_meta("spent",false),"mine feedback starts immediately without mining or depletion")
	preview.finish("ore");ore.queue_free()
	# Actual plot visuals, three different stages, original soil and character at normal zoom.
	var ids: Array=[]
	for i in 3:
		var entry: Dictionary=row.duplicate(true);entry.x+=float((i-1)*96);entry.crop="broad_leaf";entry.growth_minutes=[0.0,float(spec.stage_minutes),float(spec.minutes)][i];entry.roots=false
		ids.append("leaf-"+str(i));s.builds.states[ids[-1]]=entry
	s.builds.states.erase(id);s.builds.refresh_all()
	for prop in w.object_root.get_children():
		if prop.is_in_group("trees") and prop.position.distance_to(Vector2(row.x,row.y))<450:prop.hide()
	w.player.position=Vector2(row.x,row.y)+Vector2(0,90);w.player.reset_physics_interpolation();w.player.camera.reset_smoothing()
	w.item_ui.message_time=0;w.item_ui.message.hide();w.item_ui.obtained.hide();w.item_ui.guide.hide()
	for i in 8:await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/online-leaf-v1/crop-native.png")
	FileAccess.open("res://reports/online-leaf-v1/checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	var failed:=checks.filter(func(c):return not c.pass).size();print("LEAF_CHECKS ",checks.size()," FAILED ",failed)
	w.queue_free();await process_frame;quit(1 if failed else 0)
