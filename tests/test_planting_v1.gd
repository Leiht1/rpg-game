extends SceneTree
const OUT="res://reports/planting-formal-v1/"
const Interaction=preload("res://scripts/world_interaction.gd")
var checks=[]
var w
var s
var b
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func equip(id: String) -> void:
	s.inventory.equipment.main_hand=s.inventory.instance(id)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Engine.set_meta("integration_seed",98171023)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started: await process_frame
	s=w.item_service;b=s.builds
	w.environment_view.set_process(false);w.set_process(false);w.player.set_physics_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)): await process_frame
	check(not Engine.get_meta("planting_preview",false),"full cycle runs without planting preview metadata")
	for crop in s.planting.rules.crops:
		var spec: Dictionary=s.planting.rules.crops[crop]
		check(s.inventory.count_item(spec.seed)==0,"formal startup does not inject test seeds "+crop)
		for stage_index in 3:
			var path: String=s.planting.art(crop+"_"+str(stage_index))
			check(path.begins_with("res://assets/planting/v3/") and ResourceLoader.exists(path),"formal crop stage resource "+crop+str(stage_index))
	for item in ["carrot_seed","potato_seed","cabbage_seed","potato","cabbage"]:
		var definition: Dictionary=s.database.item(item)
		check(definition.icon.begins_with("res://assets/planting/v3/") and definition.world_visual==definition.icon and s.texture(item,"icon")!=null,"formal item metadata and usable texture "+item)
	for i in 40: s.inventory.slots[i]={}
	var events=[];s.item_obtained.connect(func(id,count):events.append([id,count]))
	check(s.database.errors.is_empty(),"item definitions valid and unique")
	check(s.camps.build_book.recipes.build_tilled_soil.default_unlocked,"formal building menu enabled without preview switch")
	var row={}
	equip("stone_pickaxe")
	for y in range(-4,5):
		for x in range(-4,5):
			var at: Vector2=w.generator.spawn+Vector2(x*96,y*64)
			w.player.position=at+Vector2(70,50)
			var candidate: Dictionary=b.candidate("tilled_soil",at,false,true,0)
			if b.reason(candidate).is_empty(): row=candidate;break
		if not row.is_empty(): break
	check(not row.is_empty(),"legal plot location found")
	if row.is_empty(): await finish();return
	equip("simple_shovel");check(b.reason(row).contains("石镐"),"shovel cannot till")
	equip("stone_pickaxe");var durability: int=s.inventory.equipment.main_hand.durability
	var till_path: String=s.save_path;s.save_path="user://missing-planting-folder/no-save.json";w.persistent_world=true
	check(not b.place(row,s.inventory.slots.duplicate(true)).is_empty() and b.states.is_empty() and s.inventory.equipment.main_hand.durability==durability,"failed till save restores plot and pickaxe durability")
	w.persistent_world=false;s.save_path=till_path
	check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"pickaxe tills using building transaction")
	check(s.inventory.equipment.main_hand.durability==durability-1,"tilling costs one pickaxe durability")
	await frames()
	var id: String=b.states.keys()[0];var node: Node2D=b.visuals[id]
	w.player.position=node.position+Vector2(0,40);await physics_frame
	check(not b.reason(row).is_empty(),"occupied plot cannot be built twice")
	check(not b.place(b.candidate("tilled_soil",Vector2.ZERO,false,true,0),s.inventory.slots.duplicate(true)).is_empty(),"invalid location rejected")
	check(not s.planting.interact(id,node),"missing seed cannot sow")
	w.camp_ui.begin_build("build_tilled_soil");await frames()
	check(w.camp_ui.placing and is_instance_valid(w.camp_ui.ghost) and w.camp_ui.ghost_build.states.preview.kind=="tilled_soil","original building preview supports tilling")
	w.camp_ui.cancel_placement();w.item_ui.update_input_block()
	s.inventory.slots[0]={"item_id":"carrot_seed","count":3};w.item_ui.message.text="seed-selection-test"
	var seed_key := InputEventKey.new();seed_key.pressed=true;seed_key.physical_keycode=KEY_1;seed_key.keycode=KEY_1
	w.item_ui._input(seed_key)
	check(s.inventory.selected==0 and s.inventory.slots[0].count==3 and w.item_ui.message.text=="seed-selection-test","number key selects seeds without consuming or showing use failure")
	for crop in s.planting.rules.crops:
		var spec: Dictionary=s.planting.rules.crops[crop]
		s.inventory.slots[0]={"item_id":spec.seed,"count":3};s.inventory.selected=0
		check(s.planting.interact(id,node,str(spec.seed)),"sow "+crop)
		check(s.inventory.slots[0].count==2 and b.states[id].crop==crop,"consume exactly one seed "+crop)
		check(not s.planting.interact(id,node),"growing plot rejects second sow "+crop)
		check(Interaction.action_for(node)=="","immature crop has no hint or action "+crop)
		s.planting.advance(spec.stage_minutes)
		check(s.planting.stage(b.states[id])==1,"middle stage uses configured time "+crop)
		check(s.planting.valid(b.states[id]),"crop state validates "+crop)
		var saved: Dictionary=JSON.parse_string(JSON.stringify(b.serialize()))
		check(b.validate(saved,{}),"JSON roundtrip accepted "+crop)
		b.states=saved.objects
		s.planting.advance(spec.minutes-spec.stage_minutes)
		check(s.planting.stage(b.states[id])==2 and Interaction.action_for(node)=="pickup","mature crop pickup "+crop)
		var before: int=s.inventory.count_item(spec.produce)
		check(s.planting.interact(id,node),"harvest "+crop)
		check(s.inventory.count_item(spec.produce)==before+spec.yield_count and s.inventory.count_item(spec.seed)==4,"produce and sustainable seeds "+crop)
		check(b.states[id].roots and b.states[id].crop.is_empty(),"harvest leaves roots "+crop)
		check(not s.planting.interact(id,node),"wrong tool cannot clear or duplicate harvest "+crop)
		equip("simple_shovel");var tool_before: int=s.inventory.equipment.main_hand.durability
		check(s.planting.interact(id,node),"shovel clears roots "+crop)
		check(not b.states[id].roots and s.inventory.equipment.main_hand.durability==tool_before-1,"clear restores idle plot and costs durability "+crop)
		equip("stone_pickaxe")
	# Same step as body/time, pause and debug clock changes never age crops.
	s.inventory.slots[0]={"item_id":"carrot_seed","count":3};s.planting.interact(id,node,"carrot_seed")
	var sim=w.environment_view.simulation;sim.paused=true
	w.environment_view.advance_gameplay(2)
	check(b.states[id].growth_minutes==0,"paused simulation does not grow")
	sim.paused=false
	w.environment_view.advance_gameplay(1)
	check(is_equal_approx(b.states[id].growth_minutes,1440.0/(sim.day_length_minutes*60.0)),"growth follows real gameplay minutes")
	# Full bag must retain ripe crop; save failure must restore both sides.
	b.states[id].growth_minutes=360.0
	var slots: Array=s.inventory.slots.duplicate(true)
	for i in 40: s.inventory.slots[i]={"item_id":"stone","count":99}
	check(not s.planting.interact(id,node) and s.planting.stage(b.states[id])==2,"full bag does not lose crop")
	s.inventory.slots=slots
	var old_path: String=s.save_path;s.save_path="user://missing-planting-folder/no-save.json";w.persistent_world=true
	check(not s.planting.interact(id,node) and s.planting.stage(b.states[id])==2 and s.inventory.slots==slots,"failed harvest save rolls back rewards and crop")
	var crop_before: Dictionary=b.states[id].duplicate(true)
	b.states[id].crop="";b.states[id].growth_minutes=0.0
	check(not s.planting.interact(id,node,"carrot_seed") and b.states[id].crop.is_empty() and s.inventory.slots==slots,"failed sow save restores seed and idle state")
	b.states[id].roots=true;equip("simple_shovel")
	var held_before: Dictionary=s.inventory.equipment.duplicate(true)
	check(not s.planting.interact(id,node) and b.states[id].roots and s.inventory.equipment==held_before,"failed clear save restores roots and shovel durability")
	b.states[id]=crop_before
	w.persistent_world=false;s.save_path=old_path
	# Stream visuals may disappear, persistent states continue and reinstall unchanged.
	var coord: Vector2i=w.stream.chunk_at(node.position);var state_before: Dictionary=b.states.duplicate(true)
	b.unload(coord);await frames();b.install(coord);await frames();node=b.visuals[id]
	check(b.states==state_before and s.planting.stage(b.states[id])==2,"chunk unload/reinstall preserves mature state")
	equip("stone_pickaxe");w.player.facing="back";w.player.position=node.position+Vector2(0,32)
	check(w.player.selected_target()==node,"mature plot selected by original E targeting")
	w.player.try_interact()
	check(w.player.action=="pickup" and w.player.harvesting,"mature crop starts original character pickup action")
	w.player._physics_process(.55)
	check(b.states[id].roots,"pickup action commits harvest at existing animation point")
	w.player.cancel_action();equip("simple_shovel");w.player.try_interact()
	check(w.player.action=="dig" and not w.player.hold_chop,"root cleaning starts dig without held-key repeat")
	w.player._physics_process(.7)
	check(not b.states[id].roots,"dig action clears roots at existing animation point")
	w.player.cancel_action()
	# All four states are ordinary hammer-demolishable buildings, without crop rewards.
	for state in ["idle","growing","mature","roots"]:
		var r: Dictionary=row.duplicate(true);r.crop="";r.growth_minutes=0.0;r.roots=false
		if state in ["growing","mature"]:r.crop="carrot";r.growth_minutes=360.0 if state=="mature" else 1.0
		if state=="roots":r.roots=true
		b.states={id:r};b.refresh_all();await frames();node=b.visuals[id];w.player.position=node.position+Vector2(0,40);await physics_frame
		equip("stone_hammer");var event_count: int=events.size()
		check(b.strike(id,node) and not b.states.has(id) and event_count==events.size(),"hammer removes "+state+" plot without harvest")
		await frames()
	# Natural harvesting emits the shared event and grants a deterministic one-time seed reward.
	var drop=Node2D.new();drop.position=w.player.position;w.object_root.add_child(drop)
	for key in {"drop_id":"planting-test-wild","item_id":"wild_carrot","count":1,"natural":true,"mode":"harvest"}:drop.set_meta(key,{"drop_id":"planting-test-wild","item_id":"wild_carrot","count":1,"natural":true,"mode":"harvest"}[key])
	var count_events: int=events.size();check(s.pickup(drop),"wild harvest obtains seeds")
	check(events.size()==count_events+2 and s.consumed.has("planting-test-wild:planting-seeds-v1"),"natural produce and seeds share obtained queue")
	# Existing crafting and cooking events are connected to the same FIFO.
	for material in ["branch","flint","plant_fiber"]:s.inventory.add(material,10)
	var craft_events: int=events.size()
	check(s.start_craft("hand_stone_axe",1).is_empty(),"existing crafting still starts")
	s.advance_craft(1.5)
	check(events.size()==craft_events+1 and events[-1]==["stone_axe",1],"crafting uses unified obtained event")
	s.camps.states["toast-test"]={"x":w.player.position.x,"y":w.player.position.y,"fuel":10.0,"lit":true,"recipe":"roast_carrot","elapsed":12.0,"ready":true}
	var cooking_events: int=events.size()
	check(s.camps.act("toast-test","claim").is_empty() and events.size()==cooking_events+1 and events[-1]==["roasted_carrot",1],"cooking claim uses same obtained event")
	check(not s.camps.act("toast-test","claim").is_empty() and events.size()==cooking_events+1,"cooking repeat claim has no extra reward")
	await frames(5)
	var toast=s.world.item_ui.obtained
	check(toast is CanvasLayer and toast.layer==100,"obtained UI above ordinary panels")
	# Logical viewport coordinates also apply in headless mode.
	check(is_equal_approx(toast.card.position.x,(root.get_visible_rect().size.x-toast.card.size.x)*.5) and toast.card.position.y+toast.card.size.y<w.item_ui.dock.position.y,"obtained UI centered above hotbar")
	check(toast.pending.size()>1,"multiple rewards retained in FIFO")
	var first_entry: Dictionary=toast.pending[0].duplicate(true)
	toast.remaining=0;toast._process(0)
	check(toast.caption.text.contains(s.database.item(first_entry.id).name) and toast.caption.text.contains(str(first_entry.count)) and toast.icon.texture!=null,"FIFO displays correct next icon name and count")
	w.item_ui.toggle_bag();await frames()
	check(w.item_ui.bag.visible and toast.card.visible and toast.layer>w.ui.layer,"reward remains above open backpack")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"toast-over-bag.png")
	w.item_ui.toggle_bag()
	# Visual specimen field: independent blocks and nine different stage drawings.
	b.states.clear()
	var sample_origin: Dictionary=b.candidate("tilled_soil",w.player.position,false,true,0)
	var center := Vector2(sample_origin.x,sample_origin.y)
	for tree in get_nodes_in_group("trees"):tree.hide()
	for drop_node in w.stream.drops:
		if is_instance_valid(drop_node):drop_node.hide()
	for crop_index in 3:
		for stage_index in 3:
			var crop: String=["carrot","potato","cabbage"][crop_index]
			var at: Vector2=center+Vector2((crop_index-1)*96,(stage_index-1)*64)
			var sample: Dictionary=b.candidate("tilled_soil",at,false,true,0)
			sample.crop=crop;sample.growth_minutes=[0.0,s.planting.rules.crops[crop].stage_minutes,s.planting.rules.crops[crop].minutes][stage_index]
			b.states["sample-%d-%d"%[crop_index,stage_index]]=sample
	for sample_index in 2:
		var sample: Dictionary=b.candidate("tilled_soil",center+Vector2(192,-64+sample_index*64),false,true,0)
		sample.roots=sample_index==1;b.states["extra-"+str(sample_index)]=sample
	check(b.states["sample-1-0"].x-b.states["sample-0-0"].x==96 and b.states["sample-0-1"].y-b.states["sample-0-0"].y==64,"visual crop field uses exact floor spacing in both directions")
	b.refresh_all();w.player.position=center+Vector2(320,130);w.item_ui.message.text="";await frames(12)
	if DisplayServer.get_name()!="headless":
		await process_frame;await RenderingServer.frame_post_draw
		var screenshot: Image=root.get_texture().get_image()
		screenshot.save_png(OUT+"window.png")
		var white := 0
		for y in range(170,240):
			for x in range(350,620):
				var color := screenshot.get_pixel(x,y)
				if color.r>.98 and color.g>.98 and color.b>.98:white+=1
		check(white<20,"rendered crop region has no released-texture white squares")
	await finish()
func finish() -> void:
	var failed=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+("headless" if DisplayServer.get_name()=="headless" else "window")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("PLANTING V1 ",checks.size()," checks; ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames();quit(0 if failed==0 else 1)
