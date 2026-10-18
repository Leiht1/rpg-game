extends SceneTree
const OUT := "res://reports/camp-effects-v11/"
var checks: Array=[]
var world: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=3) -> void:
	for i in n: await process_frame
func run() -> void:
	Engine.max_fps=60;Engine.set_meta("integration_seed",271828)
	world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	var size := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width",1280),ProjectSettings.get_setting("display/window/size/viewport_height",720))
	check(root.content_scale_size==size,"only configured default viewport; no resolution switching")
	world.player.set_physics_process(false);world.environment_view.simulation.paused=true
	world.player.camera.position_smoothing_enabled=false
	while not world.stream.viewport_ready(world.player.position,Vector2(size)*.5): await process_frame
	var s = world.item_service;var b = s.builds;var p = world.player
	var origin: Vector2=world.generator.spawn
	b.states["fx:torch"]=b.candidate("camp_torch",origin+Vector2(-70,0),false,true,0)
	b.refresh_all();await frames()
	var torch = b.visuals["fx:torch"]
	check(torch.torch_flame!=null and torch.torch_flame.texture.resource_path=="res://assets/buildings/v1/frame-15.png","torch retains approved PNG with local flame shader")
	var pose: Transform2D=torch.torch_flame.transform
	torch._process(.2)
	check(torch.torch_flame.transform==pose and torch.torch_flame.material.get_shader_parameter("phase")>0,"torch animates shader phase without whole-object motion")
	var preview: Node2D=load("res://scripts/camp_building.gd").new();preview.manager=b;preview.building_id="fx:torch";preview.preview=true;world.object_root.add_child(preview)
	check(preview.torch_flame!=null and preview.torch_flame.transform==pose,"placement preview shares animated torch geometry")
	preview.queue_free()
	# Compare isolated real GPU pixels, without changing the app window resolution.
	var viewport := SubViewport.new();viewport.size=Vector2i(128,160);viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var sprite := Sprite2D.new();sprite.texture=torch.torch_flame.texture;sprite.scale=torch.torch_flame.scale;sprite.position=Vector2(64,80)
	sprite.material=torch.torch_flame.material.duplicate();viewport.add_child(sprite)
	sprite.material.set_shader_parameter("phase",0.0);await frames();await RenderingServer.frame_post_draw
	var first: Image=viewport.get_texture().get_image();first.save_png(OUT+"torch-phase-a.png")
	sprite.material.set_shader_parameter("phase",.37);await frames();await RenderingServer.frame_post_draw
	var second: Image=viewport.get_texture().get_image();second.save_png(OUT+"torch-phase-b.png")
	var fixed_changed := 0;var flame_changed := 0;var fixed_samples := 0
	# Original torch spans y34..126. The cup/shaft below y64 must be identical.
	for y in range(34,127):
		for x in range(44,85):
			var changed: bool=first.get_pixel(x,y)!=second.get_pixel(x,y)
			if y>=65:
				if first.get_pixel(x,y).a>.05: fixed_samples+=1
				if changed: fixed_changed+=1
			elif changed: flame_changed+=1
	check(fixed_samples>100 and fixed_changed==0,"GPU cup rope and shaft pixels fixed")
	check(flame_changed>0,"GPU upper flame visibly moves")
	FileAccess.open(OUT+"torch-pixels.json",FileAccess.WRITE).store_string(JSON.stringify({"fixed_samples":fixed_samples,"fixed_changed":fixed_changed,"flame_changed":flame_changed}))
	viewport.queue_free()
	var camp_at: Vector2=origin+Vector2(70,0)
	s.camps.states["fx:camp"]={"x":camp_at.x,"y":camp_at.y,"fuel":600.0,"lit":true,"recipe":"","elapsed":0.0,"ready":false}
	s.camps.rebuild();s.camps.install(world.stream.chunk_at(camp_at));await frames()
	var camp = s.camps.visuals["fx:camp"];camp._process(0)
	check(camp.fuel_bar.position==Vector2(-36,6) and camp.fuel_bar.size.x==72,"fuel bar six units closer with width preserved")
	var old_camp: Node2D=load("res://reports/camp-effects-v11/baseline/scripts/campfire.gd").new()
	old_camp.manager=s.camps;old_camp.camp_id="fx:camp";old_camp.position=Vector2(-10000,-10000);world.object_root.add_child(old_camp);await frames()
	var old_height: float=old_camp.fuel_bar.size.y*old_camp.fuel_bar.scale.y
	var new_height: float=camp.fuel_bar.size.y*camp.fuel_bar.scale.y
	check(is_equal_approx(new_height,old_height*.5),"fuel bar rendered height exactly half actual previous control")
	FileAccess.open(OUT+"fuel-bar-measurement.json",FileAccess.WRITE).store_string(JSON.stringify({"old_control_height":old_camp.fuel_bar.size.y,"new_control_height":camp.fuel_bar.size.y,"old_display_height":old_height,"new_display_height":new_height,"old_y":old_camp.fuel_bar.position.y,"new_y":camp.fuel_bar.position.y}))
	old_camp.queue_free()
	check(camp.fuel_bar.value==600 and camp.fuel_bar.max_value==1200,"fuel values and capacity unchanged")
	check(s.camps.rules.light_radius==250,"camp light radius 200 to 250")
	world.environment_view.simulation.set_time(0);world.environment_view._process(0)
	var radii: PackedFloat32Array=world.environment_view.material_effect.get_shader_parameter("camp_radii")
	check(radii.has(250.0*root.get_canvas_transform().get_scale().x),"actual environment shader receives expanded camp radius")
	if DisplayServer.get_name()!="headless":
		await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"night-torch-camp.png")
	s.camps.advance(1,1,1);camp._process(0)
	check(s.camps.states["fx:camp"].fuel==598 and camp.fuel_bar.value==598,"existing storm fuel consumption still updates moved bar")
	world.environment_view.simulation.set_time(12);world.environment_view._process(0)
	# Actual demolition settlement for free, edge and floor structures, plus the campfire.
	s.inventory.equipment.main_hand=s.inventory.instance("stone_hammer")
	for spec in [["workbench",false],["stone_wall",false],["wood_fence",true],["wood_floor",false],["campfire",false]]:
		var kind: String=spec[0];var id := "fx:demolition:"+kind
		var center: Vector2=origin
		var target: Node2D
		var cost: Dictionary
		if kind=="campfire":
			s.camps.states[id]={"x":center.x,"y":center.y,"fuel":0.0,"lit":false,"recipe":"","elapsed":0.0,"ready":false,"hits":2}
			s.camps.rebuild();s.camps.install(world.stream.chunk_at(center));target=s.camps.visuals[id];cost={"wood":4,"stone":6,"flint":1}
		else:
			var row: Dictionary=b.candidate(kind,center,bool(spec[1]),true,0);row.hits=int(b.definitions[kind].hits)-1
			b.states[id]=row;b.refresh_all();await frames();target=b.visuals[id];center=Vector2(row.x,row.y);cost=b.definitions[kind].cost
		p.position=center+Vector2(30,25);p.reset_physics_interpolation();await physics_frame;await physics_frame
		var old_wear: int=s.inventory.equipment.main_hand.durability
		check(b.strike(id,target),"real last strike commits "+kind)
		var refunds: Array=s.loose.values().filter(func(r):return str(r.id).begins_with(id+":refund:"))
		check(not refunds.is_empty() and refunds.all(func(r):return Vector2(r.x,r.y)==center),"refunds anchored at original building center "+kind)
		check(refunds.all(func(r):return int(r.count)==floori(float(cost[r.item_id])*.5) and not r.has("drop_animation")),"original refunds with no persisted animation flag "+kind)
		var drops: Array=world.stream.drops.filter(func(n):return is_instance_valid(n) and str(n.get_meta("drop_id","")).begins_with(id+":refund:"))
		check(drops.size()==refunds.size() and drops.all(func(n):return n.get_meta("airborne",false) and n.position==center and n.visual.position!=Vector2.ZERO),"new refund nodes animate without moving landing roots "+kind)
		check(not s.pickup(drops[0]),"airborne refund cannot be picked early "+kind)
		check(s.inventory.equipment.main_hand.durability==old_wear-1,"single original tool wear "+kind)
		await create_timer(.48).timeout
		check(drops.all(func(n):return not n.get_meta("airborne",false) and n.visual.position.is_equal_approx(Vector2.ZERO) and n.position==center),"refund flight settles at same center "+kind)
		var entry: Dictionary=refunds[0].duplicate(true);var old: Node2D=drops[0];world.stream.drops.erase(old);old.queue_free();await frames()
		var restored: Node2D=world.stream.create_item_drop(entry)
		check(not restored.get_meta("airborne",false) and restored.visual.position==Vector2.ZERO,"restored settled refund does not replay flight "+kind)
		check(s.pickup(restored),"settled centered refund remains collectible "+kind)
	# A failed demolition save must not create animated reward nodes or consume wear.
	var fail_id := "fx:rollback"
	var row: Dictionary=b.candidate("wood_floor",origin,false,true,0);row.hits=1;b.states[fail_id]=row;b.refresh_all();await frames()
	p.position=Vector2(row.x,row.y)+Vector2(30,25);await physics_frame;await physics_frame
	var loose_before: Dictionary=s.loose.duplicate(true);var wear_before: int=s.inventory.equipment.main_hand.durability
	world.persistent_world=true;s.save_path=OUT+"missing/save.json"
	check(not b.strike(fail_id,b.visuals[fail_id]) and b.states.has(fail_id) and b.states[fail_id].hits==1,"save failure restores building damage")
	check(s.loose==loose_before and s.inventory.equipment.main_hand.durability==wear_before,"save failure restores loot and tool wear")
	world.persistent_world=false
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("CAMP EFFECTS V11: ",checks.size()," checks; ",failed," failures")
	s.dirty=false;world.queue_free();await frames(6);quit(0 if failed==0 else 1)
