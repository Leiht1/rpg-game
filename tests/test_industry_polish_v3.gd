extends "res://tests/test_industry_refine_v2.gd"
const REVIEW_OUT="res://reports/industry-polish-v3/"
func shot(label: String) -> void:
	await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(REVIEW_OUT+label+".png")
func finish() -> void:
	var failed: int=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(REVIEW_OUT+"window.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks},"  "))
	print("INDUSTRY POLISH V3: ",checks.size()," checks; ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.free();await process_frame;quit(0 if failed==0 else 1)
func green(bar: ProgressBar) -> bool:
	var color: Color=bar.get_theme_stylebox("fill").bg_color
	return color.g>color.r+.12 and color.g>color.b+.15
func gray(bar: ProgressBar) -> bool:
	var color: Color=bar.get_theme_stylebox("fill").bg_color
	return maxf(color.r,maxf(color.g,color.b))-minf(color.r,minf(color.g,color.b))<.06
func orange(bar: ProgressBar) -> bool:
	var color: Color=bar.get_theme_stylebox("fill").bg_color
	return color.r>color.g+.20 and color.g>color.b+.20
func run() -> void:
	DirAccess.make_dir_recursive_absolute(REVIEW_OUT);Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;s.set_process(false);w.set_process(false);w.player.set_physics_process(false);w.environment_view.set_process(false);w.environment_view.simulation.paused=true
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	var at: Vector2=w.player.position+Vector2(65,0)
	for entry in [["furnace","stone_furnace"],["oven","copper_oven"],["metal","metal_workbench"],["bench","workbench"],["lamp","copper_lamp"]]:build(entry[0],entry[1],at)
	await frames();stock()
	check(s.craft_book.errors.is_empty() and s.camps.build_book.errors.is_empty(),"recipe definitions valid")
	var metal: Array=s.craft_book.available("全部","metal_workbench")
	check(metal.size()==9 and metal.all(func(r):return r.conditions==["metal_workbench"]),"metal building exposes only its own nine products")
	var ordinary: Array=s.craft_book.available("全部","workbench")
	check(ordinary.any(func(r):return r.recipe_id=="workbench_shears") and ordinary.any(func(r):return r.conditions.is_empty()),"ordinary workbench keeps its original hand and bench recipes")
	check(not ordinary.any(func(r):return r.conditions==["metal_workbench"]),"ordinary building has no metal-exclusive products")
	s.builds.visuals.metal.perform_interaction("open",w.player);await frames()
	check(w.item_ui.craft_panel.recipe_buttons.size()==9,"metal UI all category contains no ordinary recipes")
	check(not s.craft_check("hand_stone_axe",1).is_empty(),"service also rejects hand recipes at metal station")
	check(not s.craft_check("workbench_shears",1).is_empty(),"service rejects ordinary bench recipes at metal station")
	check(s.craft_check("metal_copper_plate",1).is_empty(),"metal recipe remains craftable at its own station")
	var types := {"metal_copper_plate":"材料加工","metal_copper_parts":"材料加工","metal_metal_connector":"材料加工","metal_copper_axe":"工具","metal_copper_pickaxe":"工具","metal_copper_shovel":"工具","metal_copper_hammer":"工具","metal_fishing_rod":"工具","metal_silver_lantern":"野外用品"}
	for id in types:check(s.craft_book.recipe(id).category==types[id],"metal product type "+id)
	check(s.craft_book.categories("metal_workbench")==["全部","材料加工","工具","野外用品"],"metal categories follow product types")
	check(green(w.item_ui.craft_panel.progress) and green(w.camp_ui.progress),"crafting and campfire production bars are green")
	w.item_ui.craft_panel.choose_category("工具");await shot("metal-tools-only");w.item_ui.close_panels()
	var building_types := {"wood_chest":"生活","reinforced_cabinet":"生活","copper_oven":"生活","camp_torch":"生活","stone_furnace":"科技","metal_workbench":"科技","workbench":"科技"}
	for r in s.camps.build_book.recipes.values():
		if building_types.has(r.output_id):check(r.category==building_types[r.output_id],"construction type "+str(r.output_id))
	var categories: Array=s.camps.build_book.categories()
	check(not categories.has("设施") and not categories.has("照明") and not categories.has("加工"),"obsolete construction categories removed")
	w.item_ui.toggle_build();w.item_ui.craft_panel.choose_category("生活");await shot("build-life-category");w.item_ui.close_panels()
	for id in ["furnace","oven"]:
		s.industry_ui.open(id);await frames()
		for bar in s.industry_ui.bars:check(green(bar),"green process progress "+id)
		machine(id).fuel=500;s.industry_ui.refresh();check(gray(s.industry_ui.fuel_bar),"unlit fuel bar gray "+id)
		check(act(id,"ignite").is_empty(),"ignite "+id);s.industry_ui.refresh();check(orange(s.industry_ui.fuel_bar),"lit fuel bar flame orange "+id)
		if id=="furnace":
			act(id,"start",0,"smelt_copper");s.industry.advance(5,2);s.industry_ui.refresh();await shot("furnace-green-and-orange")
		act(id,"extinguish");s.industry_ui.refresh();check(gray(s.industry_ui.fuel_bar),"extinguished fuel returns gray "+id);s.industry_ui.close_panel()
	s.camps.states.fire={"x":at.x,"y":at.y,"fuel":100.0,"lit":false,"recipe":"","elapsed":0.0,"ready":false};s.camps.rebuild();s.camps.install(w.stream.chunk_at(at));await frames()
	var fire: Node=s.camps.visuals.fire;fire._process(0);check(gray(fire.fuel_bar),"world campfire unlit fuel gray")
	s.camps.states.fire.lit=true;fire._process(0);check(orange(fire.fuel_bar),"world campfire burning fuel orange")
	s.inventory.slots[8]={"item_id":"field_lantern","count":1};s.toggle_lantern(8);w.item_ui.body_ui._process(0)
	check(orange(w.item_ui.body_ui.fuel),"lantern fuel uses active flame color")
	s.toggle_lantern(8);w.item_ui.body_ui._process(0);check(gray(w.item_ui.body_ui.fuel),"switched-off lantern fuel style returns gray")
	w.environment_view._process(0)
	var strengths: PackedFloat32Array=w.environment_view.material_effect.get_shader_parameter("camp_strengths")
	check(strengths.has(1.35) and strengths.has(1.0),"actual shader receives brighter copper intensity while other lights retain 1")
	await brightness_check()
	await smoke_check()
	await finish()
func brightness_check() -> void:
	var view := SubViewport.new();view.size=Vector2i(720,720);view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var bg := ColorRect.new();bg.color=Color(.38,.46,.32);bg.size=Vector2(720,720);view.add_child(bg)
	var effect := ColorRect.new();effect.size=bg.size;var mat := ShaderMaterial.new();mat.shader=load("res://scripts/world_environment.gdshader");effect.material=mat;view.add_child(effect)
	mat.set_shader_parameter("brightness",.25);mat.set_shader_parameter("camp_count",1)
	var centers := PackedVector2Array();centers.resize(32);centers[0]=Vector2(.5,.5)
	var radii := PackedFloat32Array();radii.resize(32);radii[0]=300
	var strengths := PackedFloat32Array();strengths.resize(32);strengths[0]=1
	mat.set_shader_parameter("camp_centers",centers);mat.set_shader_parameter("camp_radii",radii);mat.set_shader_parameter("camp_strengths",strengths)
	await frames();await RenderingServer.frame_post_draw;var old: Image=view.get_texture().get_image()
	strengths[0]=1.35;mat.set_shader_parameter("camp_strengths",strengths)
	await frames();await RenderingServer.frame_post_draw;var current: Image=view.get_texture().get_image()
	var a: Color=old.get_pixel(360,360);var b: Color=current.get_pixel(360,360)
	check(b.r>a.r+.02 and b.g>a.g+.02,"GPU night-time center actually brighter")
	check(not different(old.get_pixel(20,20),current.get_pixel(20,20)),"GPU outside lamp radius unchanged")
	current.save_png(REVIEW_OUT+"lamp-brightness-controlled.png");view.free()
func smoke_check() -> void:
	for id in s.builds.visuals:s.builds.visuals[id].visible=id=="furnace"
	for node in s.camps.visuals.values():
		node.hide()
		for collider in node.find_children("*","CollisionObject2D",true,false):collider.collision_layer=0
	w.item_ui.close_panels();var fx: Node=s.builds.visuals.furnace.get_node("IndustryEffects");fx.set_process(false);fx.puffs.clear();fx.update_effect(0)
	await frames();await RenderingServer.frame_post_draw;var before: Image=root.get_texture().get_image()
	check(act("furnace","ignite").is_empty(),"resume furnace for actual completion")
	s.industry.advance(19,7.6)
	check(machine("furnace").completed.size()==1 and fx.puffs.size()==4,"actual completed ingot emits chimney burst once")
	fx.update_effect(.45);await frames();await RenderingServer.frame_post_draw;var after: Image=root.get_texture().get_image()
	var chimney: Vector2=root.get_canvas_transform()*fx.to_global(fx.chimney)
	var bounds := Rect2i(Vector2i(chimney)-Vector2i(18,50),Vector2i(36,57)).intersection(Rect2i(Vector2i.ZERO,after.get_size()))
	var pixels := 0
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			if different(before.get_pixel(x,y),after.get_pixel(x,y)):pixels+=1
	check(pixels>12,"real default-window chimney smoke visibly changes native pixels")
	after.save_png(REVIEW_OUT+"furnace-completion-smoke.png")
	fx.update_effect(1.1);check(not fx.puffs.is_empty(),"smoke lasts beyond former 1.5 seconds")
	fx.update_effect(2);check(fx.puffs.is_empty(),"completion smoke finishes without permanent smoke")
