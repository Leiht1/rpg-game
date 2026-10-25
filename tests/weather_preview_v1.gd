extends SceneTree
var w: Node
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.set_meta("weather_preview",true);Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	var s=w.item_service;var b=s.builds;var env=w.environment_view.simulation
	b.states.clear();b.refresh_all();s.camps.states.clear();s.camps.rebuild()
	s.guide_stage=2;s.body.energy=45
	for i in 40:s.inventory.slots[i]={}
	for id in ["wood","plant_fiber","broad_leaf","stone","flint"]:s.inventory.add(id,90)
	s.inventory.slots[0]=s.inventory.instance("rain_umbrella");s.inventory.slots[1]=s.inventory.instance("stone_hammer");s.inventory.slots[2]=s.inventory.instance("stone_axe");s.inventory.equip(0)
	var site: Dictionary={}
	for yy in range(-3,4):
		for xx in range(-3,4):
			var at: Vector2=w.generator.spawn+Vector2(xx*96,yy*64);w.player.position=at+Vector2(0,120)
			var row: Dictionary=b.candidate("rain_shelter",at,false,true,0)
			if b.reason(row).is_empty():site=row;break
		if not site.is_empty():break
	if not site.is_empty():
		b.place(site,s.inventory.slots.duplicate(true))
		var at:=Vector2(site.x,site.y)
		var bed: Dictionary=b.candidate("wood_bed",at,false,true,0);w.player.position=at+Vector2(0,75)
		b.place(bed,s.inventory.slots.duplicate(true))
		var fire_at: Vector2=at+Vector2(180,30)
		s.camps.states["weather-preview:fire"]={"x":fire_at.x,"y":fire_at.y,"lit":true,"fuel":1200.0,"hits":0,"recipe":"","elapsed":0.0,"ready":false};s.camps.rebuild()
		w.player.position=at+Vector2(0,60)
	env.minute=1080;env.force_weather(2)
	w.player.reset_physics_interpolation();w.player.update_animation();w.item_ui.body_ui.refresh()
	if "--smoke" in OS.get_cmdline_user_args():
		await create_timer(1.0).timeout
		assert(not w.persistent_world and s.inventory.equipment.main_hand.item_id=="rain_umbrella" and not site.is_empty())
		print("WEATHER PREVIEW isolated entry passed")
		quit()
