extends SceneTree
const Gen=preload("res://scripts/world_generator.gd")
const Dist=preload("res://scripts/harvest_distribution.gd")
const Service=preload("res://scripts/item_service.gd")
const OUT="res://reports/broadleaf-v1/"
var checks: Array=[]
var samples: Array=[]
var counts: Array=[]
var world: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func capture(name_value: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_value+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT));Engine.max_fps=60
	var config: Dictionary=preload("res://scripts/harvest_node.gd").configuration()
	check(config.version=="harvest-resources-2.1.0" and config.resources.broadleaf_clump.hits==1 and config.resources.broadleaf_clump.drops.broad_leaf==4,"explicit version and one-dig/four-leaf definition")
	var b:=preload("res://scripts/body_state.gd").new()
	b.advance(20,8,true,false);check(is_equal_approx(b.stamina,60),"twenty seconds running spends 40 stamina")
	b.stamina=0;b.exhausted=true;b.advance(20,8,false,false)
	check(b.stamina>=20 and b.stamina<=31,"twenty seconds rest recovers slowly")
	b.stamina=100;b.exhausted=false
	for i in 40:b.spend_labor("mine")
	check(is_equal_approx(b.stamina,0) and not b.can_labor("mine"),"full stamina supports 40 mining hits")
	var inv:=ItemInventory.new(ItemDatabase.new());inv.body=b;inv.add("wildflower",3);b.hunger=50;b.health=75
	check(inv.use_slot(8) and b.hunger==51 and b.health==75 and inv.count_item("wildflower")==2,"wildflower consumes one and restores exactly one hunger only")
	b.hunger=100;check(not inv.use_slot(8) and inv.count_item("wildflower")==2,"full hunger never wastes wildflowers")
	for seed_value in [271828,447349832]:
		var gen:=Gen.new(seed_value,1024);var layer:=Service.new()
		layer.world={"generator":gen,"Gen":Gen};layer.patch_noise.seed=seed_value^87361;layer.patch_noise.frequency=1.0/float(layer.rules.noise_scale);layer.patch_noise.fractal_octaves=2;layer.prepare_navigation()
		var coords: Array[Vector2i]=[]
		for room in gen.rooms:
			if not Dist.grass_region(gen,room.p):continue
			var center:=Vector2i(room.p/Gen.CHUNK_PX)
			for y in range(-2,3):
				for x in range(-2,3):
					var c:=center+Vector2i(x,y)
					if not coords.has(c):coords.append(c)
		var found: Array=[]
		var verified:=0
		for coord in coords:
			var rows:=Dist.broadleaf_candidates(layer,coord,[])
			found.append_array(rows)
			for row in rows:
				check(Dist.grass_region(gen,Vector2(row.x,row.y)),"plant restricted to grass interior "+str(seed_value)+row.id)
			if not rows.is_empty() and verified<4:
				var actual:=Dist.build(layer,coord)
				check(actual==Service.build_distribution(gen,layer.rules,layer.reachable,coord).harvest,"same-seed worker result "+str(seed_value)+str(coord))
				for row in actual:
					if row.kind=="broadleaf_clump":samples.append({"seed":seed_value,"row":row,"coord":[coord.x,coord.y]})
				verified+=1
		check(not found.is_empty() and found.size()<coords.size()*.7,"few clumps per grass-region sample "+str(seed_value))
		var spaced:=true
		for row in found:
			for other in found:
				if row.id!=other.id and Vector2(row.x,row.y).distance_to(Vector2(other.x,other.y))<259.999:spaced=false
		check(spaced,"cross-chunk 260 spacing "+str(seed_value))
		counts.append({"seed":seed_value,"sample_chunks":coords.size(),"clumps_before_existing_harvest_exclusion":found.size()})
		layer.free()
	check(not samples.is_empty(),"actual complete world generation contains reachable clumps")
	Engine.set_meta("integration_seed",271828);world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	world.environment_view.simulation.paused=true;world.environment_view.simulation.set_time(10)
	var s: Node=world.item_service;var p: Node=world.player;var ui: Control=world.item_ui
	p.automated=true;p.set_physics_process(false)
	for resolution in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,900)]:
		root.size=resolution;root.content_scale_size=resolution;ui.fit_core_ui();await frames(5)
		check(is_equal_approx(ui.body_ui.hud.get_global_rect().end.y,ui.dock.get_global_rect().end.y),"body HUD bottom aligns with hotbar "+str(resolution))
		check(not ui.body_ui.hud.get_global_rect().intersects(ui.dock.get_global_rect()),"aligned HUD avoids dock "+str(resolution))
		check(ui.dock.get_global_rect().end.x<=resolution.x-15,"dock remains within screen "+str(resolution))
		check(ui.body_ui.summary.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER,"body status centered "+str(resolution))
		await capture("hud-"+str(resolution.x))
	root.size=Vector2i(1280,720);root.content_scale_size=root.size;ui.fit_core_ui()
	var p0: Vector2=p.position
	# Find a real generated plant near the first seed's meadow sample, load its chunk.
	var natural: Dictionary={}
	for sample in samples:
		if sample.seed==271828:natural=sample.row;break
	check(not natural.is_empty(),"first seed has a real sample for scene integration")
	if not natural.is_empty():
		p0=Vector2(natural.x,natural.y)+Vector2(0,44);p.position=p0;p.reset_physics_interpolation();p.camera.reset_smoothing()
		world.stream.update_target(p0)
		var deadline:=Time.get_ticks_msec()+20000
		while not world.stream.viewport_ready(p0,root.get_visible_rect().size/(2.0*p.camera.zoom)) and Time.get_ticks_msec()<deadline:await process_frame
		await frames(10)
	var plant: Node2D=s.create_harvest("broadleaf:test:one",{"kind":"broadleaf_clump","x":p0.x+35,"y":p0.y})
	await frames()
	check(plant.sprite.texture!=null and plant.soil==null,"surface plant has intact art and no buried soil veil")
	check(not preload("res://scripts/world_interaction.gd").allowed(s.inventory,"dig"),"unarmed dig cannot harvest")
	check(not s.harvest_hit(plant,"dig"),"unarmed authoritative attempt produces nothing")
	s.inventory.add("simple_shovel",1)
	for i in 40:
		if s.inventory.slots[i].get("item_id","")=="simple_shovel":s.inventory.equip(i);break
	await frames();await capture("grass-contact")
	var shape: Transform2D=plant.sprite.transform
	p.facing="right";p.action="dig";p.action_target=plant;p.action_clock=.5;p.update_animation();await frames();await capture("dig-contact")
	check(plant.sprite.transform==shape,"dig contact never shifts plant root")
	var before: int=s.inventory.count_item("broad_leaf");var old_stamina: float=s.body.stamina
	p.cancel_action()
	var pointer:=InputEventMouseMotion.new();pointer.position=root.get_canvas_transform()*(plant.position+Vector2(0,-8));pointer.global_position=pointer.position;root.push_input(pointer,true);await frames()
	check(p.selected_target()==plant,"actual selector targets new plant")
	p.set_physics_process(true);Input.action_press("interact");p.try_interact()
	await create_timer(.9).timeout
	Input.action_release("interact");p.set_physics_process(false)
	check(s.consumed.has("broadleaf:test:one") and int(s.resource_hits.get("broadleaf:test:one",0))==1,"one native shovel action completes plant at authoritative hit")
	check(s.body.stamina==old_stamina-1.5,"plant uses current 1.5-point digging cost")
	var rewards: Array=s.loose.values().filter(func(row):return str(row.id).begins_with("broadleaf:test:one:loot:"))
	check(rewards.size()==1 and rewards[0].item_id=="broad_leaf" and int(rewards[0].count)==4,"exact four broad leaves in original world-drop path")
	check(not s.harvest_hit(plant,"dig") and s.loose.values().filter(func(row):return str(row.id).begins_with("broadleaf:test:one:loot:")).size()==1,"completed plant cannot duplicate rewards")
	p.cancel_action();await create_timer(.8).timeout
	for drop in world.stream.drops.duplicate():
		if is_instance_valid(drop) and str(drop.get_meta("drop_id","")).begins_with("broadleaf:test:one:loot:"):
			drop.set_meta("airborne",false);s.pickup(drop)
	check(s.inventory.count_item("broad_leaf")==before+4,"original pickup puts all four leaves in inventory")
	var fiber_before: int=s.inventory.count_item("plant_fiber")
	check(s.start_craft("hand_leaf_fiber",2).is_empty(),"four dug leaves start existing two-batch fiber recipe")
	s.advance_craft(1.5)
	check(s.inventory.count_item("broad_leaf")==before and s.inventory.count_item("plant_fiber")==fiber_before+6,"existing timed recipe converts four leaves to six fibers")
	check(s.create_harvest("broadleaf:test:one",{"kind":"broadleaf_clump","x":p0.x+35,"y":p0.y})==null,"consumed plant does not respawn on chunk reload")
	await frames();await capture("after-dig")
	# Previous official harvest save upgrades without reroll/reset of player state.
	s.save_path="user://broadleaf-upgrade-test.json";world.persistent_world=true
	var save: Dictionary=s.snapshot();save.harvest_version="harvest-resources-2.0.0"
	var file:=FileAccess.open(s.save_path,FileAccess.WRITE);file.store_string(JSON.stringify(save));file.close()
	s.load_state();check(s.writable and s.consumed.has("broadleaf:test:one") and s.inventory.count_item("plant_fiber")==fiber_before+6,"2.0 save retains inventory and harvest history after 2.1 upgrade")
	world.persistent_world=false;s.dirty=false;DirAccess.remove_absolute(s.save_path)
	var failed:=checks.filter(func(row):return not row.pass).size()
	var mode:="headless" if DisplayServer.get_name()=="headless" else "window"
	FileAccess.open(OUT+mode+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failed,"counts":counts,"samples":samples},"  "))
	print("BROADLEAF ",mode,": ",checks.size()," checks; ",failed," failures; ",counts)
	world.queue_free();await frames(5);quit(0 if failed==0 else 1)

