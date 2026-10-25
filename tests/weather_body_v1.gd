extends "res://tests/sleep_v8_fixture.gd"
const Exposure=preload("res://scripts/weather_exposure.gd")
const Body=preload("res://scripts/body_state.gd")
const Config=preload("res://scripts/weather_body_rules.gd")
func condition(rain: float=0.0, temperature: float=22.0) -> Dictionary:
	return {"rain":rain,"storm":0.0,"ambient":temperature,"warmth":2.0,"heat":0.0,"umbrella":false,"shelter":false}
func advance_model(model: RefCounted, minutes: float) -> void:
	model.rules=model.rules.duplicate(true);model.rules.energy_per_hour=0;model.rules.hunger_per_day=0
	model.advance(minutes*2.5,minutes,false,false)
func capture_weather(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await frames(4);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/weather-v1/"+label+".png")
func run() -> void:
	Engine.set_meta("weather_preview",true);Engine.set_meta("integration_seed",271828)
	var m=Body.new();m.exposure=condition();advance_model(m,120)
	check(m.wetness==0 and m.cold_level==0,"clear dry comfortable")
	m.exposure=condition(1,16);advance_model(m,2)
	check(m.wetness>0 and m.wetness<2 and m.health==100,"brief rain no severe harm")
	advance_model(m,118);check(m.wetness>60,"exposure gradually wets")
	var wet: float=m.wetness;m.exposure.umbrella=true;advance_model(m,10);check(m.wetness<wet,"umbrella prevents wetting and allows slow drying")
	m.exposure.umbrella=false;m.exposure=condition();wet=m.wetness;advance_model(m,10);check(m.wetness<wet,"rain stops gradual drying")
	var cold=Body.new();cold.wetness=100;cold.exposure=condition(1,0)
	var seen: Array=[0]
	for i in 240:
		advance_model(cold,1)
		if not seen.has(cold.cold_level):seen.append(cold.cold_level)
	check(seen==[0,1,2,3],"all four thermal states crossed smoothly")
	check(cold.health<100 and cold.health>95,"extreme grace then slow net health loss")
	var chilly: float=cold.felt_temperature;cold.exposure=condition();cold.exposure.heat=1;wet=cold.wetness;advance_model(cold,1)
	check(cold.felt_temperature>chilly and cold.felt_temperature<5 and cold.wetness<wet,"heat warms smoothly and dries")
	advance_model(cold,180);check(cold.cold_level==0,"comfort recovers over time")
	for level in 4:
		m.cold_level=level;check(is_equal_approx(m.recovery_factor(),float(Config.data.recovery_factors[level])),"recovery effect "+str(level))
		check(is_equal_approx(m.movement_factor(),float(Config.data.move_factors[level])),"movement effect "+str(level))
	m.cold_level=2;m.felt_temperature=10;m.exposure=condition(0,8);m.exposure.warmth=2;m.advance_weather(.001);check(m.cold_level==2,"hysteresis retains cold within recovery buffer")
	var old: Dictionary=m.serialize();old.erase("weather_body");var restored=Body.new();check(restored.restore(old) and restored.wetness==0 and restored.cold_level==0,"old body save defaults")
	old=m.serialize();check(restored.restore(old) and restored.wetness==m.wetness and restored.cold_level==m.cold_level,"new body roundtrip")
	var before: Dictionary=restored.serialize();old.weather_body.wetness=-1;check(not restored.restore(old) and restored.serialize()==before,"invalid weather save rejects atomically")
	var a=Body.new();var z=Body.new();a.exposure=condition(1,4);z.exposure=a.exposure.duplicate(true);advance_model(a,100)
	for i in 100:advance_model(z,1)
	check(is_equal_approx(a.wetness,z.wetness) and is_equal_approx(a.felt_temperature,z.felt_temperature),"bounded large and small steps agree")
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds
	w.set_process(false);w.player.set_physics_process(false);s.set_process(false);v.set_process(false);s.combat_view.set_process(false)
	root.size=default_size();root.content_scale_size=root.size
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	check(not w.persistent_world,"isolated world")
	b.states.clear();b.refresh_all();s.camps.states.clear();s.camps.rebuild();await frames()
	stock();s.inventory.add("broad_leaf",30)
	check(s.database.errors.is_empty() and s.craft_book.errors.is_empty() and s.camps.build_book.errors.is_empty(),"item and both recipe registries valid")
	check(s.craft_book.available().any(func(r):return r.output_id=="rain_umbrella") and s.camps.build_book.available().any(func(r):return r.output_id=="rain_shelter"),"candidate recipes playable")
	var request: int=s.new_craft_request()
	check(s.craft("hand_rain_umbrella",1,request).is_empty() and s.inventory.count_item("rain_umbrella")==1,"actual umbrella craft transaction")
	check(not s.craft("hand_rain_umbrella",1,request).is_empty() and s.inventory.count_item("rain_umbrella")==1,"duplicate craft cannot grant second umbrella")
	s.inventory.slots[0]=s.inventory.instance("rain_umbrella");check(s.inventory.equip(0),"umbrella equips actual main hand")
	check(s.inventory.has_capability("chop")==false and s.inventory.has_capability("mine")==false,"umbrella cannot act as axe/pick")
	check(s.inventory.equipment.main_hand.durability==null,"umbrella no durability")
	v.simulation.blend=Vector3(0,0,1);check(Exposure.sample(s).umbrella,"equipped umbrella active in rain")
	w.player.position=w.generator.spawn+Vector2(-240,0)
	for facing in ["front","back","left","right"]:
		w.player.facing=facing;w.player.update_animation();w.player.reset_physics_interpolation();w.player.character.reset_physics_interpolation();await frames(2)
		var arm: Node2D=w.player.character.get_node("Visual/Pelvis/ArmL")
		var tool: Sprite2D=arm.get_node("HeldTool")
		check(arm.get_node("Grip").global_position.y<arm.global_position.y,"hand raised above shoulder "+facing)
		check((-tool.global_transform.y.normalized()).dot(Vector2.UP)>.999,"umbrella remains upright "+facing)
		check(w.player.held_tool.definitions.has("tool:rain_umbrella"),"four view shared held registry "+facing)
		await capture_weather("umbrella-"+facing)
	check(s.inventory.unequip(40) and not Exposure.sample(s).umbrella,"unequip removes rain protection")
	w.player.update_animation();check(w.player.held_tool.raised_arm==null,"unequip releases raised arm")
	s.inventory.slots[1]=s.inventory.instance("stone_axe");check(s.inventory.equip(1) and s.inventory.has_capability("chop") and not Exposure.sample(s).umbrella,"tool switching restores capability")
	# Find real ground; both builds go through normal placement and collision.
	var site: Dictionary={}
	for yy in range(-3,4):
		for xx in range(-3,4):
			var at: Vector2=w.generator.spawn+Vector2(xx*96,yy*64);w.player.position=at+Vector2(0,120)
			var row: Dictionary=b.candidate("rain_shelter",at,false,true,0)
			if b.reason(row).is_empty():site=row;break
		if not site.is_empty():break
	check(not site.is_empty(),"large canopy actual build site")
	if not site.is_empty():
		var at:=Vector2(site.x,site.y)
		check(b.place(site,s.inventory.slots.duplicate(true)).is_empty(),"place shelter via original transaction")
		await frames();var shelter_id: String=b.states.keys().filter(func(id):return b.states[id].kind=="rain_shelter")[0]
		check(Exposure.covered(s,at) and not Exposure.covered(s,at+Vector2(145,0)),"precise coverage inside/outside")
		check(b.visuals[shelter_id].shape.disabled and b.visuals[shelter_id].body.get_child_count()==6,"four poles only, interior clear")
		w.player.position=at+Vector2(0,80);var bed: Dictionary=b.candidate("wood_bed",at,false,true,0)
		check(b.reason(bed).is_empty(),"bed can be built under existing shelter")
		check(b.place(bed,s.inventory.slots.duplicate(true)).is_empty(),"place real bed below shelter")
		await frames();var bed_id: String=b.states.keys().filter(func(id):return b.states[id].kind=="wood_bed")[0]
		check(Exposure.covered(s,Exposure.sleep_point(b.states[bed_id])),"sleep and standing use same coverage")
		var saved_shelter: Dictionary=b.states[shelter_id];b.states.erase(shelter_id);b.refresh_all();await frames()
		s.body.energy=30;w.player.position=at+Vector2(0,80)
		var exposed_error: String=s.sleep.start(bed_id)
		print("EXPOSED BED: ",exposed_error)
		check(exposed_error=="床铺正在淋雨" and not s.body.sleeping,"rain rejects exposed bed")
		check(b.reason(saved_shelter).is_empty(),"shelter can be built after bed")
		check(b.place(saved_shelter,s.inventory.slots.duplicate(true)).is_empty(),"build shelter over actual bed")
		await frames();check(s.sleep.start(bed_id).is_empty() and s.body.sleeping,"sheltered rain bed allows sleep")
		check(not Exposure.sample(s).umbrella and Exposure.sample(s).shelter,"sleep uses bed position and ignores held umbrella")
		await capture_weather("shelter-sleep")
		s.sleep.interrupt();w.player.position=at+Vector2(0,70);w.player.update_animation()
		await capture_weather("shelter-standing")
		# Atomic failure through actual filesystem path, no player data.
		var before_slots: Array=s.inventory.slots.duplicate(true);var before_states: Dictionary=b.states.duplicate(true)
		w.persistent_world=true;s.save_path="res://reports/weather-v1/nonexistent/blocked/save.json"
		var failure: Dictionary=b.candidate("rain_shelter",at+Vector2(0,350),false,true,0);w.player.position=at+Vector2(0,350)
		if b.reason(failure).is_empty():
			check(b.place(failure,s.inventory.slots.duplicate(true)).contains("回滚") and s.inventory.slots==before_slots and b.states==before_states,"failed building save restores material and states")
		w.persistent_world=false
		var target_id: String=b.states.keys().filter(func(id):return b.states[id].kind=="rain_shelter")[0]
		s.inventory.equipment.main_hand=s.inventory.instance("stone_hammer");w.player.position=at+Vector2(190,96)
		for i in 4:check(b.strike(target_id,b.visuals[target_id]),"real pole demolition strike "+str(i))
		check(not b.states.has(target_id) and b.states.has(bed_id),"shelter demolition preserves bed")
		await frames()
	var p: Vector2=w.player.position
	s.camps.states["weather:heat"]={"x":p.x+15,"y":p.y,"lit":true,"fuel":50.0}
	check(Exposure.sample(s).heat>0,"lit fuelled campfire warms")
	s.camps.states["weather:heat"].fuel=0;check(Exposure.sample(s).heat==0,"empty fuel does not warm")
	s.camps.states.erase("weather:heat")
	var warmth: float=Exposure.sample(s).warmth
	preload("res://scripts/character_catalog.gd").enable_candidate(s.database);s.inventory.equipment.outfit=s.inventory.instance("modern_outfit")
	check(Exposure.sample(s).warmth>warmth,"existing equipped clothes give configured warmth")
	var before_wet: float=s.body.wetness;v.simulation.paused=true;v.advance_gameplay(20);check(s.body.wetness==before_wet,"paused no weather body time")
	v.simulation.paused=false;v.simulation.blend=Vector3(0,0,1);v.advance_gameplay(1);check(s.body.wetness>=before_wet,"runtime authoritative advance wired")
	var ui=w.item_ui.body_ui;ui.refresh();check(ui.weather_summary.text.contains("受潮：") and ui.weather_summary.text.contains("体感："),"two HUD text rows")
	ui.toggle();ui.refresh();check(ui.overlay.visible and ui.details.text.contains("雨棚") and ui.details.text.contains("保暖"),"click existing HUD opens live details")
	await capture_weather("details");ui.close_panel();check(not ui.overlay.visible,"close details restores operation")
	await create_timer(.2).timeout
	var spot: Vector2=ui.hud.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new();motion.position=spot;Input.parse_input_event(motion);await frames(2)
	for pressed in [true,false]:
		var click := InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=pressed;click.position=spot;Input.parse_input_event(click);await frames(2)
	check(ui.overlay.visible,"real mouse opens HUD details");ui.close_panel()
	w.persistent_world=true;s.save_path="res://reports/weather-v1/isolated-save.json"
	s.body.wetness=43.25;s.body.felt_temperature=7;s.body.cold_level=2
	check(s.save_state(),"actual atomic weather-body save")
	s.body.wetness=0;s.load_state()
	check(s.writable and is_equal_approx(s.body.wetness,43.25) and s.body.cold_level==2,"actual file restores weather state")
	var legacy: Dictionary=s.snapshot();legacy.body.erase("weather_body")
	FileAccess.open(s.save_path,FileAccess.WRITE).store_string(JSON.stringify(legacy));s.load_state()
	check(s.writable and s.body.wetness==0 and s.body.cold_level==0,"old actual file loads safely")
	w.persistent_world=false
	FileAccess.open("res://reports/weather-v1/"+("headless" if DisplayServer.get_name()=="headless" else "native")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	var failures:=checks.filter(func(c):return not c.pass).size();print("WEATHER V1 ",checks.size()," checks, ",failures," failures")
	w.queue_free();await frames(4);quit(1 if failures else 0)
