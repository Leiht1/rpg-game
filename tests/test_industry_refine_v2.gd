extends SceneTree
const OUT="res://reports/industry-refine-v2/"
var w: Node
var s: Node
var checks: Array=[]
var notices: Array=[]
var events: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func different(a: Color,b: Color) -> bool:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>.025
func frames(n: int=3) -> void:
	for i in n:await process_frame
func machine(id: String) -> Dictionary:return s.builds.states[id].machine
func act(id: String,action: String,index: int=0,key: String="",count: int=1,materials: Dictionary={}) -> String:
	return s.industry.act(id,action,index,key,count,materials)
func stock() -> void:
	for i in 40:s.inventory.slots[i]={}
	for id in ["wood","stone","plant_fiber","branch","flint","copper_ore","silver_ore","gold_ore","copper_ingot","silver_ingot","copper_plate","copper_parts","wool","wild_carrot","potato","cabbage"]:s.inventory.add(id,40)
func build(id: String,kind: String,at: Vector2) -> void:
	var row: Dictionary=s.builds.candidate(kind,at,false,false,0);s.builds.states[id]=row;s.builds.install(w.stream.chunk_at(at))
	s.builds.visuals[id].body.collision_layer=0
func fresh(id: String) -> void:machine(id).assign(s.industry.initial(s.builds.states[id].kind))
func shot(label: String) -> void:
	await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+label+".png")
func finish() -> void:
	var failed: int=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+("restart.json" if "read" in OS.get_cmdline_user_args() else "window.json"),FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks},"  "))
	print("INDUSTRY REFINE V2: ",checks.size()," checks; ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.free();await process_frame;quit(0 if failed==0 else 1)
func run() -> void:
	Engine.set_meta("integration_seed",271828);DirAccess.make_dir_recursive_absolute(OUT)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;s.set_process(false);w.set_process(false);w.player.set_physics_process(false);w.environment_view.set_process(false);w.environment_view.simulation.paused=true
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	s.save_path=OUT+"isolated-save.json"
	if "read" in OS.get_cmdline_user_args():
		w.persistent_world=true;s.load_state();await frames()
		check(s.writable,"new process snapshot accepted")
		check(machine("furnace").version==2 and not machine("furnace").enabled,"new process retains manual off state")
		check(machine("furnace").completed.size()==1 and machine("furnace").queue.size()==1,"new process retains independent output and queue")
		check(machine("furnace").fuel==500 and machine("oven").fuel==700,"new process retains per-facility fuel")
		check(machine("oven").enabled and machine("oven").completed.size()==2,"new process retains oven switch and products")
		check(machine("legacy").legacy_queue.size()==7 and machine("legacy").legacy_fuel==400,"new process retains old paid overflow")
		check(machine("metal").completed[0].output.durability==250,"new process retains unique legacy crafted tool")
		check(s.builds.visuals.furnace.get_node("IndustryEffects").puffs.is_empty(),"restart does not replay completion smoke")
		await finish();return
	check(s.database.errors.is_empty() and s.craft_book.errors.is_empty(),"updated definitions valid")
	var at: Vector2=w.player.position+Vector2(65,0)
	for entry in [["furnace","stone_furnace"],["oven","copper_oven"],["metal","metal_workbench"],["lamp","copper_lamp"]]:build(entry[0],entry[1],at)
	await frames();stock();s.notice.connect(func(v):notices.append(v));s.item_obtained.connect(func(id,n):events.append([id,n]))
	check(s.industry.rules.max_fuel==2000 and s.industry.rules.queue_limit==5 and s.industry.rules.completed_limit==6,"requested capacities configured")
	check(not machine("furnace").enabled and not machine("oven").enabled,"new burners start off")
	check(act("furnace","ignite").length()>0,"empty burner cannot ignite")
	check(act("furnace","start",0,"smelt_copper").is_empty(),"ore paid once into active slot")
	check(act("furnace","fuel",0,"wood").is_empty(),"fuel added")
	s.industry.advance(5,2);check(machine("furnace").fuel==120 and machine("furnace").jobs[0].elapsed==0,"off preserves fuel and work")
	check(act("furnace","ignite").is_empty(),"manual ignition accepted")
	s.industry.advance(24,9.6)
	check(machine("furnace").completed.size()==1 and machine("furnace").jobs[0].is_empty(),"completed ingot moves out and frees processing slot")
	check(s.builds.visuals.furnace.get_node("IndustryEffects").puffs.size()==4,"one actual completion emits four bounded chimney puffs")
	s.industry.advance(5,2);check(machine("furnace").fuel==91,"ignited empty furnace continues burning")
	act("furnace","extinguish");s.industry.advance(5,2);check(machine("furnace").fuel==91,"extinguish stops fuel use")
	machine("furnace").fuel=2000;var inventory: Array=s.inventory.slots.duplicate(true)
	check(not act("furnace","fuel",0,"wood").is_empty() and s.inventory.slots==inventory,"fuel cap rejects without consuming item")
	fresh("furnace");machine("furnace").fuel=2000;act("furnace","ignite")
	for i in 6:check(act("furnace","start",0,"smelt_copper").is_empty(),"one active plus five queue accepts task "+str(i))
	inventory=s.inventory.slots.duplicate(true)
	check(machine("furnace").queue.size()==5 and not act("furnace","start",0,"smelt_copper").is_empty() and s.inventory.slots==inventory,"sixth waiting task rejected without material loss")
	s.industry.advance(145,58);check(machine("furnace").completed.size()==6 and machine("furnace").queue.is_empty(),"queue auto-processes up to six stored products")
	act("furnace","start",0,"smelt_gold");s.industry.advance(41,16.4)
	check(machine("furnace").completed.size()==6 and machine("furnace").jobs[0].elapsed==0,"full product tray pauses new processing")
	var copper: int=s.inventory.count_item("copper_ingot");var obtained: int=events.size()
	check(act("furnace","claim_all").is_empty() and s.inventory.count_item("copper_ingot")==copper+6 and events.size()==obtained+6,"single action collects all six products")
	check(machine("furnace").completed.is_empty(),"claimed tray empty")
	s.industry.advance(40,16);check(machine("furnace").completed.size()==1,"processing resumes after claiming")
	w.persistent_world=true;s.save_path=OUT+"missing/save.json";inventory=s.inventory.slots.duplicate(true)
	check(not act("furnace","claim_all").is_empty() and machine("furnace").completed.size()==1 and s.inventory.slots==inventory,"failed bulk claim saves roll back all outputs and inventory")
	w.persistent_world=false;s.save_path=OUT+"isolated-save.json"
	for i in 40:s.inventory.slots[i]={"item_id":"stone","count":99}
	check(not act("furnace","claim_all").is_empty() and machine("furnace").completed.size()==1,"full bag keeps unclaimed product")
	stock();check(act("furnace","claim_all").is_empty(),"bulk claim retries safely after space available")
	check(not act("furnace","claim_all").is_empty(),"repeated claim cannot duplicate product")
	machine("furnace").completed=[{"recipe":"smelt_copper","elapsed":24.0,"ready":true,"output":{"item_id":"copper_ingot","count":1}},{"recipe":"smelt_gold","elapsed":40.0,"ready":true,"output":{"item_id":"gold_ingot","count":1}}]
	for i in 40:s.inventory.slots[i]={"item_id":"stone","count":99}
	s.inventory.slots[8]={"item_id":"copper_ingot","count":98}
	check(act("furnace","claim_all").is_empty() and s.inventory.slots[8].count==99 and machine("furnace").completed.size()==1 and machine("furnace").completed[0].output.item_id=="gold_ingot","partial-capacity bulk claim keeps every unclaimed output")
	stock();act("furnace","claim_all")
	fresh("oven");act("oven","fuel",0,"wood",10);act("oven","ignite")
	for i in 4:check(act("oven","start",i,"",1,{"wild_carrot":1}).is_empty(),"oven slot starts "+str(i))
	s.industry.advance(12,4.8)
	check(machine("oven").completed.size()==4 and machine("oven").fuel==1188,"four oven slots burn one shared fuel supply")
	for i in 4:act("oven","start",i,"",1,{"wild_carrot":1})
	s.industry.advance(12,4.8);check(machine("oven").completed.size()==6,"simultaneous oven completion respects six product cap")
	var oven_snapshot: Dictionary=JSON.parse_string(JSON.stringify(s.builds.states.oven))
	if not s.industry.valid(oven_snapshot):
		print("OVEN VALIDATION DIAGNOSTIC ",JSON.stringify(oven_snapshot))
		for j in oven_snapshot.machine.jobs:print("ACTIVE ",s.industry.valid_job("copper_oven",j))
		for j in oven_snapshot.machine.completed:print("COMPLETE ",s.industry.valid_job("copper_oven",j,true))
	check(s.industry.valid(oven_snapshot),"oven blocked completions remain valid persisted state")
	act("oven","claim_all");s.industry.advance(.1,.04);check(machine("oven").completed.size()==2,"blocked oven products finish only after tray freed")
	act("oven","extinguish");var fuel_before: float=machine("oven").fuel;s.industry.advance(3,1.2);check(machine("oven").fuel==fuel_before,"oven off stops fuel consumption")
	await frames();var fx: Node=s.builds.visuals.oven.get_node("IndustryEffects")
	check(not fx.glass.visible,"oven off glass dark")
	act("oven","ignite");await frames();check(fx.glass.visible,"oven ignited glass lit")
	var phase: float=fx.phase;await frames(8);check(fx.phase>phase,"glass glow phase animates")
	await ui_checks()
	await craft_checks()
	await carpet_checks()
	await effect_checks()
	await compatibility_checks(at)
	await construction_checks()
	await finish()
func ui_checks() -> void:
	stock();fresh("furnace")
	var ui: Node=s.industry_ui;ui.open("furnace")
	var bounds: Rect2=ui.panel.get_global_rect();await frames(12)
	check(bounds==ui.panel.get_global_rect(),"first visible frame and settled furnace panel have identical bounds")
	check(ui.fuel_bar.max_value==2000 and not ui.fuel_bar.show_percentage and ui.separator.visible,"fuel uses unlabeled bar with separator")
	check(ui.recipe_buttons.size()==3 and ui.fuel_buttons.size()==4,"ore and fuel cards replace dropdowns")
	check(not ui.fuel_window.visible and not ui.amount.is_visible_in_tree(),"fuel materials and quantity are absent from main screen")
	check(ui.switches.get_parent()==ui.fuel_section and ui.switches.get_index()==ui.fuel_bar.get_parent().get_index()+1,"ignite and extinguish directly below fuel progress")
	for card in ui.recipe_buttons.values():check(not card.text.contains(".0"),"ore materials have integer quantities")
	ui.recipe_buttons.smelt_copper.pressed.emit();check(ui.selected_recipe=="smelt_copper","ore click selects")
	ui.recipe_buttons.smelt_copper.pressed.emit();check(ui.selected_recipe.is_empty(),"second ore click deselects")
	ui.recipe_buttons.smelt_copper.pressed.emit();ui.start.pressed.emit();ui.add.pressed.emit();await frames()
	check(ui.fuel_window.visible,"add fuel opens second level popup")
	check(ui.fuel_window.find_children("*","OptionButton",true,false).is_empty() and ui.fuel_window.get_theme_stylebox("panel") is StyleBoxEmpty,"fuel popup uses paper cards with no native black dropdown")
	var before_cancel: Array=s.inventory.slots.duplicate(true);ui.fuel_window.hide();check(s.inventory.slots==before_cancel,"cancel fuel popup consumes nothing")
	ui.add.pressed.emit();await frames();ui.fuel_buttons.wood.pressed.emit();await shot("fuel-selection")
	# GLES native child windows have no readable viewport texture. Render the same paper subtree.
	var popup_view := SubViewport.new();popup_view.size=ui.fuel_window.size;popup_view.world_2d=World2D.new();popup_view.transparent_bg=true;popup_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(popup_view)
	var paper: Control=ui.fuel_window.get_child(0).duplicate();paper.theme=ui.theme;paper.position=Vector2.ZERO;paper.size=Vector2(popup_view.size);popup_view.add_child(paper)
	await frames();await RenderingServer.frame_post_draw;popup_view.get_texture().get_image().save_png(OUT+"fuel-popup-paper.png");popup_view.free()
	check(ui.fuel_window.transparent and ui.fuel_window.transparent_bg,"secondary fuel window has no opaque black background")
	ui.fuel_confirm.pressed.emit();ui.ignite.pressed.emit();await frames()
	check(not ui.fuel_window.visible,"fuel confirmation closes secondary popup")
	check(machine("furnace").enabled and machine("furnace").fuel==120,"native UI fuel and ignition callbacks work")
	check(ui.slot_buttons[0].get_theme_constant("icon_max_width")==56,"ingot progress icon enlarged")
	check(ui.panel.get_global_rect()==bounds,"selection enqueue and fuel do not move furnace panel")
	check(ui.column.get_combined_minimum_size().y<=ui.column.size.y,"furnace contents fit fixed panel")
	await shot("furnace-window")
	ui.queue_button.pressed.emit();await frames();check(ui.tray.visible,"queue button opens separate view");ui.tray.hide()
	s.industry.advance(24,9.6);ui.refresh();ui.completed_button.pressed.emit();await frames();check(ui.tray_rows.get_child_count()==1,"completed button shows actual output")
	ui.tray.hide();ui.claim_all.pressed.emit();check(machine("furnace").completed.is_empty(),"UI one-click claim works")
	ui.extinguish.pressed.emit();await frames();check(not s.builds.visuals.furnace.get_node("IndustryEffects").flame.visible,"furnace flame extinguishes")
	ui.close_panel();ui.open("oven");bounds=ui.panel.get_global_rect();await frames(10)
	check(ui.panel.get_global_rect()==bounds,"oven opens without layout jump")
	check(ui.column.get_combined_minimum_size().y<=ui.column.size.y,"oven controls fit fixed panel")
	ui.slot_buttons[0].pressed.emit();await frames();check(ui.ingredient_window.visible,"oven ingredient popup remains independent")
	ui.ingredient_window.hide();await shot("oven-window");ui.close_panel()
func craft_checks() -> void:
	stock();var metal: Array=[]
	for r in s.craft_book.available("全部","metal_workbench"):
		if r.conditions==["metal_workbench"]:metal.append(r.recipe_id)
	check(metal.size()==9,"all nine metal outputs registered as craft recipes")
	check(not s.craft_book.available().any(func(r):return r.conditions==["metal_workbench"]),"hand recipes cannot expose metal processing")
	check(not s.craft_book.available("全部",true).any(func(r):return r.conditions==["metal_workbench"]),"ordinary workbench cannot expose metal processing")
	s.builds.visuals.metal.perform_interaction("open",w.player);await frames()
	check(w.item_ui.craft_panel.visible and w.item_ui.craft_panel.mode_title.text=="金属加工台制作","metal interaction uses original craft UI")
	for id in metal:
		var row: Dictionary=s.craft_book.recipe(id);var before: int=s.inventory.count_item(row.output_id)
		check(s.start_craft(id,1).is_empty(),"start real metal crafting "+id)
		s.advance_craft(1.5);check(s.inventory.count_item(row.output_id)==before+int(row.output_count),"craft output enters original inventory "+id)
	var inventory: Array=s.inventory.slots.duplicate(true);s.start_craft("metal_copper_plate",1);s.cancel_craft();check(s.inventory.slots==inventory,"cancelled metal craft consumes nothing")
	w.persistent_world=true;s.save_path=OUT+"missing/craft.json";var before_failed: Array=s.inventory.slots.duplicate(true);var event_count: int=events.size()
	s.start_craft("metal_copper_plate",1);s.advance_craft(1.5)
	check(s.inventory.slots==before_failed and events.size()==event_count,"failed metal craft save rolls back inputs output and obtained event")
	w.persistent_world=false;s.save_path=OUT+"isolated-save.json"
	s.craft_station_id="";check(not s.start_craft("metal_copper_plate",1).is_empty(),"metal crafting rechecks real station")
	w.item_ui.close_panels()
	var image: Texture2D=load("res://assets/industry/v1/metal_workbench.png")
	var profile: Dictionary=s.builds.volume_profile("metal_workbench")
	var painted: Vector2=Vector2(image.get_image().get_used_rect().size)
	var expected_width: float=painted.x*minf(profile.width/painted.x,profile.max_height/painted.y)
	check(is_equal_approx(s.builds.visuals.metal.industry_rect(image).size.x,expected_width),"metal painted width follows approved current volume profile")
	check(s.industry.rules.copper_lamp_radius==300,"copper standing lamp radius increased from 210 to 300")
	w.environment_view._process(0)
	var radii: PackedFloat32Array=w.environment_view.material_effect.get_shader_parameter("camp_radii")
	var expected_radius: float=300*root.get_canvas_transform().get_scale().x
	check(radii.has(expected_radius),"actual lighting shader receives enlarged copper lamp radius")
func carpet_checks() -> void:
	var at: Vector2=w.player.position+Vector2(40,0);build("floor","wood_floor",at);build("carpet","wool_carpet",at);await frames()
	check(s.builds.visuals.floor.z_index<s.builds.visuals.carpet.z_index and s.builds.visuals.carpet.z_index<0,"floor below carpet below every actor")
	var view := SubViewport.new();view.size=Vector2i(320,320);view.transparent_bg=true;view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	s.inventory.equipment.clear();w.player.facing="front";w.player.action="";w.player.update_animation()
	var actor: Node2D=w.player.character.duplicate();actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;actor.position=Vector2(32,32);actor.scale=Vector2.ONE*2;view.add_child(actor);actor.get_node("AnimationPlayer").stop()
	var carpet: Node2D=s.builds.visuals.carpet;var previous: Node=carpet.get_parent();var previous_position: Vector2=carpet.position
	carpet.reparent(view,false);carpet.position=Vector2(160,270);carpet.scale=Vector2.ONE*2;carpet.hide();await frames();await RenderingServer.frame_post_draw;var bare: Image=view.get_texture().get_image()
	carpet.show();await frames();await RenderingServer.frame_post_draw;var fixed: Image=view.get_texture().get_image()
	carpet.z_index=1;await frames();await RenderingServer.frame_post_draw;var old: Image=view.get_texture().get_image()
	var samples := 0;var wrong := 0;var reproduced := 0
	for y in range(230,270):
		for x in range(100,220):
			var color: Color=bare.get_pixel(x,y)
			if color.a<.99:continue
			samples+=1
			if different(color,fixed.get_pixel(x,y)):wrong+=1
			if different(color,old.get_pixel(x,y)):reproduced+=1
	check(samples>20 and wrong==0 and reproduced>0,"GPU actor feet remain visible on upper carpet; old overlap reproduced")
	fixed.save_png(OUT+"carpet-feet.png");carpet.z_index=-1;carpet.scale=Vector2.ONE;carpet.reparent(previous,false);carpet.position=previous_position;view.free()
func compatibility_checks(at: Vector2) -> void:
	var old: Dictionary=s.builds.candidate("stone_furnace",at,false,false,0)
	var job := {"recipe":"smelt_copper","elapsed":0.0,"ready":false,"output":{"item_id":"copper_ingot","count":1}}
	old.machine={"version":1,"fuel":2400.0,"jobs":[job.duplicate(true)],"queue":[],"feed":{},"enabled":true}
	for i in 12:old.machine.queue.append(job.duplicate(true))
	check(s.industry.valid(old),"old machine v1 is accepted")
	check(old.machine.version==2 and old.machine.queue.size()==5 and old.machine.legacy_queue.size()==7,"old paid tasks migrate without loss")
	check(old.machine.fuel==2000 and old.machine.legacy_fuel==400 and not old.machine.enabled,"old excess fuel retained and burner safely off")
	s.builds.states.legacy=old
	var malformed: Dictionary=old.duplicate(true);malformed.machine.fuel=2001;check(not s.industry.valid(malformed),"new over-cap fuel rejected")
	malformed=old.duplicate(true);malformed.machine.completed=[job];check(not s.industry.valid(malformed),"unfinished outputs cannot enter completed tray")
	var tool: Dictionary=s.inventory.instance("copper_axe")
	machine("metal").completed=[{"recipe":"metal_copper_axe","elapsed":15.0,"ready":true,"output":tool}]
	check(not s.builds.protected_reason("metal").is_empty(),"completed product prevents demolition")
	w.item_ui.toggle_craft("metal");await frames();check(w.item_ui.craft_panel.legacy_jobs.visible,"old paid metal outputs remain reachable from craft screen")
	w.item_ui.craft_panel.choose_category("金属加工");await shot("metal-crafting-window")
	w.item_ui.craft_panel.legacy_jobs.pressed.emit();await frames();check(s.industry_ui.visible and s.industry_ui.current=="metal","legacy queue button opens original paid-task collection")
	s.industry_ui.close_panel()
	machine("furnace").fuel=500;machine("furnace").enabled=false;machine("furnace").completed=[{"recipe":"smelt_copper","elapsed":24.0,"ready":true,"output":{"item_id":"copper_ingot","count":1}}];machine("furnace").queue=[job.duplicate(true)]
	machine("oven").fuel=700;machine("oven").enabled=true
	w.persistent_world=true;check(s.save_state(),"new machine state saves atomically");w.persistent_world=false
func effect_checks() -> void:
	var view := SubViewport.new();view.size=Vector2i(320,320);view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var bg := ColorRect.new();bg.color=Color("8aa956");bg.size=Vector2(320,320);view.add_child(bg)
	for id in ["furnace","oven"]:
		var node: Node2D=s.builds.visuals[id];var parent: Node=node.get_parent();var previous: Vector2=node.position
		var fx: Node=node.get_node("IndustryEffects");fx.set_process(false);fx.puffs.clear();machine(id).fuel=500;machine(id).enabled=false
		node.reparent(view,false);node.position=Vector2(160,270);node.scale=Vector2.ONE*2;fx.phase=0;fx.update_effect(0)
		await frames();await RenderingServer.frame_post_draw;var off: Image=view.get_texture().get_image()
		machine(id).enabled=true;fx.update_effect(0);await frames();await RenderingServer.frame_post_draw;var on: Image=view.get_texture().get_image()
		fx.phase=.71;fx.update_effect(0);await frames();await RenderingServer.frame_post_draw;var changed: Image=view.get_texture().get_image()
		var lit := 0;var animated := 0
		for y in 320:
			for x in 320:
				if different(off.get_pixel(x,y),on.get_pixel(x,y)):lit+=1
				if different(on.get_pixel(x,y),changed.get_pixel(x,y)):animated+=1
		check(lit>0 and animated>0,"GPU actual ignition and motion "+id)
		if id=="furnace":
			fx.on_finished(id);fx.update_effect(.5);fx.phase=.71;fx.update_effect(0);await frames();await RenderingServer.frame_post_draw;var smoke: Image=view.get_texture().get_image();var pixels := 0
			var chimney: Vector2=node.position+fx.chimney*node.scale
			for y in range(maxi(0,int(chimney.y)-45),mini(320,int(chimney.y)+15)):
				for x in range(maxi(0,int(chimney.x)-20),mini(320,int(chimney.x)+20)):
					if different(changed.get_pixel(x,y),smoke.get_pixel(x,y)):pixels+=1
			check(pixels>0,"GPU small smoke appears at chimney")
			smoke.save_png(OUT+"furnace-burning-smoke.png")
		else:
			var yellow_pixels := 0
			for y in range(193,229):
				for x in range(124,196):
					var c := on.get_pixel(x,y)
					if c.r>.78 and c.g>.65 and c.b<.65:yellow_pixels+=1
			check(yellow_pixels>200,"GPU glass emits bright fluorescent yellow, not brown tint")
			on.save_png(OUT+"oven-glass-lit.png");off.save_png(OUT+"oven-glass-off.png")
		node.scale=Vector2.ONE;node.reparent(parent,false);node.position=previous;fx.set_process(true)
	view.free()
func construction_checks() -> void:
	# Exercise the real placement transaction on a loaded, otherwise clear floor site.
	s.builds.states.clear();s.builds.refresh_all();s.camps.states.clear();s.camps.rebuild();await frames(8);stock()
	var origin: Vector2=w.player.position;var row := {}
	for y in range(-3,4):
		for x in range(-3,4):
			var candidate: Dictionary=s.builds.candidate("wood_floor",origin+Vector2(x*96,y*64),false,false,0);w.player.position=Vector2(candidate.x,candidate.y)+Vector2(110,70)
			if s.builds.reason(candidate).is_empty():row=candidate;break
		if not row.is_empty():break
	check(not row.is_empty(),"construction test finds valid site")
	if row.is_empty():return
	var before: int=notices.size();check(s.builds.place(row,s.inventory.slots.duplicate(true)).is_empty(),"real build succeeds")
	check(notices.size()==before+1 and notices.back()=="消耗：木材 ×4","successful construction announces exact integer materials")
	before=notices.size();s.builds.place(row,s.inventory.slots.duplicate(true));check(notices.size()==before,"rejected construction emits no consumption notice")
