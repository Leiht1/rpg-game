extends "res://tests/sleep_v8_fixture.gd"
const Rules=preload("res://scripts/season_rules.gd")
const Sim=preload("res://scripts/world_environment.gd")
const Exposure=preload("res://scripts/weather_exposure.gd")
const Output="res://reports/seasons-v1/"
func run() -> void:
	var sim=Sim.new()
	check(sim.season_date().index==0 and sim.season_date().day==1,"new world spring day one")
	for season in 4:
		sim.advance(7*sim.day_length_minutes*60)
		check(sim.day==1+(season+1)*7 and sim.season_date().index==(season+1)%4 and sim.season_date().day==1 and absf(sim.minute-480)<.00001,"actual clock advances complete seven day season "+str(season))
	for cycle in 3:
		for season in 4:
			for date in 7:
				sim.day=cycle*28+season*7+date+1;sim.minute=0
				check(sim.season_date().index==season and sim.season_date().day==date+1 and sim.season_date().cycle==cycle+1,"calendar %d %d %d" %[cycle,season,date])
	for boundary in [7,14,21,28,35]:
		check(absf(Rules.temperature(boundary-.00001)-Rules.temperature(boundary+.00001))<.001,"continuous temperature at "+str(boundary))
	check(Rules.temperature(20)<Rules.temperature(15),"autumn gradually cools")
	check(Rules.temperature(24)<-17 and Rules.temperature(10)>7,"winter cold summer warm")
	sim.day=103;sim.minute=719.25
	var old: Dictionary=sim.serialize();old.erase("season")
	var copy=Sim.new();check(copy.restore(old) and copy.day==103 and copy.minute==719.25 and copy.season_origin_day==103,"legacy migration preserves absolute time")
	check(copy.season_date().index==0 and copy.season_date().day==1 and copy.season_temperature()==0,"legacy safely begins mild spring")
	var state: Dictionary=copy.serialize()
	check(copy.restore(JSON.parse_string(JSON.stringify(state))) and copy.day==int(state.day) and copy.season_origin_day==int(state.season.origin_day) and is_equal_approx(copy.minute,float(state.minute)) and is_equal_approx(copy.weather_remaining,float(state.weather_remaining)) and copy.rng.state==int(state.rng_state) and copy.target_weather==int(state.target_weather),"JSON migration idempotent")
	state.season.origin_day=104;var before: Dictionary=copy.serialize()
	check(not copy.restore(state) and copy.serialize()==before,"bad future origin rejects before mutation")
	sim.day=7;sim.minute=1439.9;sim.weather_remaining=10000
	state=sim.serialize();sim.advance(1)
	check(sim.day==8 and sim.season_date().index==1 and sim.season_date().day==1,"actual midnight advances once into summer")
	check(copy.restore(state),"restore preboundary")
	copy.advance(1);check(copy.serialize()==sim.serialize(),"reload boundary deterministic")
	before=sim.serialize();sim.paused=true;var paused: Dictionary=sim.serialize();sim.advance(99999)
	check(sim.serialize()==paused,"paused season and weather frozen")
	sim.paused=false;sim.day=1;sim.minute=480;sim.season_origin_day=1
	state=sim.serialize();copy.restore(state);sim.advance(35000)
	for i in 35000:copy.advance(1)
	check(sim.day==copy.day and absf(sim.minute-copy.minute)<.00001 and sim.target_weather==copy.target_weather and sim.rng.state==copy.rng.state,"large versus small clock weather and season steps")
	for season in 4:
		sim.day=season*7+2;sim.minute=720
		for crop in Rules.data.seasons[season].growth:
			check(absf(Rules.growth(crop,sim.season_elapsed_days(),10)-10*float(Rules.data.seasons[season].growth[crop]))<.00001,"crop configured multiplier %d %s" %[season,crop])
	check(absf(Rules.growth("carrot",7.0+5.0/1440,10)-10.75)<.00001,"crop crossing season integrates five minutes each")
	for season in 4:
		sim.day=season*7+2;sim.minute=720
		var counts := [0,0,0];sim.rng.seed=314159
		for i in 8000:
			var selected: int=sim._choose_next()
			counts[0 if selected==0 else 1 if selected==2 else 2]+=1
		var weights: Array=Rules.data.seasons[season].weather_weights
		var total: float=weights[0]+weights[1]+weights[2]
		for i in 3:check(absf(float(counts[i])/8000-float(weights[i])/total)<.025,"existing weather weighted draw %d %d" %[season,i])
	sim.free();copy.free()
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds
	w.set_process(false);w.player.set_physics_process(false);s.set_process(false);v.set_process(false);s.combat_view.set_process(false)
	root.size=default_size();root.content_scale_size=root.size
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	check(not w.persistent_world and v.save_path.is_empty(),"fixture never writes player save")
	check(v.season_dial.get_global_rect().position.x>=v.dial.get_global_rect().end.x and v.season_dial.get_parent()==v.dial and v.season_dial.simulation==v.simulation,"season dial to right of clock in actual canvas coordinates, inheriting visibility")
	b.states.clear();b.refresh_all();s.camps.states.clear();s.camps.rebuild();stock()
	var row: Dictionary=b.candidate("tilled_soil",w.player.position+Vector2(96,0),false,true,0)
	row.crop="carrot";row.growth_minutes=700.0;row.roots=false
	b.states["season-crop"]=row;b.refresh_all()
	v.simulation.day=23;v.simulation.minute=720;v.simulation.season_origin_day=1
	var progress: float=row.growth_minutes
	v.advance_gameplay(10)
	check(absf(row.growth_minutes-progress-2)<.00001,"actual existing crop gains winter-adjusted growth without reset")
	row.fertilized=true;progress=row.growth_minutes;v.advance_gameplay(10)
	check(absf(row.growth_minutes-progress-2*float(s.expansion.rules.fertilizer_speed))<.00001,"fertilizer multiplies seasonal growth")
	row.growth_minutes=float(s.planting.rules.crops.carrot.minutes);v.advance_gameplay(1)
	check(s.planting.stage(row)==2 and row.growth_minutes==2880,"mature crop remains mature")
	progress=row.growth_minutes;before=v.simulation.serialize();v.advance_gameplay(5,false)
	check(v.simulation.serialize()==before and row.growth_minutes==progress,"second personal client step never advances shared calendar or crops")
	v.simulation.paused=true;before=v.simulation.serialize();v.advance_gameplay(10)
	check(v.simulation.serialize()==before and row.growth_minutes==progress,"paused gameplay freezes crop and season")
	v.simulation.paused=false
	var snapshot: Dictionary=s.snapshot()
	check(s.valid_body_environment(snapshot.body_environment),"atomic item validator accepts seasons")
	snapshot.body_environment.season.origin_day=-1
	check(not s.valid_body_environment(snapshot.body_environment),"atomic validator rejects invalid season origin")
	var path := Output+"isolated-items.json"
	s.save_path=path;w.persistent_world=true
	check(s.save_state(),"real atomic seasonal item save")
	var disk: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	before=v.simulation.serialize();var health: float=s.body.health
	v.simulation.day=99;s.load_state(path)
	check(s.writable and v.simulation.day==int(before.day) and v.simulation.season_origin_day==int(before.season.origin_day) and is_equal_approx(v.simulation.minute,float(before.minute)) and v.simulation.rng.state==int(before.rng_state) and s.body.health==health and s.planting.stage(b.states["season-crop"])==2,"actual reload retains season body and mature crop without offline advancement")
	var old_disk: Dictionary=disk.duplicate(true);old_disk.body_environment.erase("season")
	var file:=FileAccess.open(Output+"legacy-items.json",FileAccess.WRITE);file.store_string(JSON.stringify(old_disk));file.close()
	s.load_state(Output+"legacy-items.json")
	check(s.writable and v.simulation.day==int(disk.body_environment.day) and s.body.health==health and b.states["season-crop"].growth_minutes==2880 and v.simulation.season_date().index==0,"actual legacy item load preserves world body and crop")
	var inventory_before: Array=s.inventory.slots.duplicate(true)
	var crop_before: Dictionary=b.states["season-crop"].duplicate(true)
	w.player.position=b.visuals["season-crop"].position
	check(preload("res://scripts/world_interaction.gd").in_reach(w.stream,w.player.position,b.visuals["season-crop"]),"harvest fixture is actually within original pickup reach")
	before=v.simulation.serialize();s.save_path=Output+"absent-directory/items.json"
	check(not s.planting.interact("season-crop",b.visuals["season-crop"]),"crop harvest rejects actual save failure")
	check(s.inventory.slots==inventory_before and b.states["season-crop"]==crop_before and v.simulation.serialize()==before,"failed crop transaction restores reward progress and season")
	s.save_path=path
	var produce_before: int=s.inventory.count_item("wild_carrot")
	var seed_before: int=s.inventory.count_item("carrot_seed")
	check(s.planting.interact("season-crop",b.visuals["season-crop"]) and b.states["season-crop"].roots and s.inventory.count_item("wild_carrot")==produce_before+4 and s.inventory.count_item("carrot_seed")==seed_before+2,"seasonal mature harvest retains original produce seed and roots transaction")
	before=v.simulation.serialize()
	w.item_ui.body_ui.toggle();w.item_ui.body_ui.close_panel()
	check(v.simulation.serialize()==before,"opening and closing native details does not advance season")
	s.body.energy=30
	check(s.sleep.start("","maximum",true).is_empty(),"existing forced sleep starts")
	check(v.simulation.serialize()==before,"entering sleep does not jump calendar")
	v.advance_gameplay(2)
	check(absf(v.simulation.minute-float(before.minute)-.8)<.00001,"sleep advances exactly normal authority time")
	before=v.simulation.serialize();s.sleep.interrupt()
	check(v.simulation.serialize()==before,"leaving sleep does not jump calendar")
	v.simulation.season_origin_day=1;v.simulation.day=24;v.simulation.minute=720;v.simulation.blend=Vector3(0,1,0)
	var exposure: Dictionary=Exposure.sample(s)
	check(absf(exposure.ambient-(22-18-6-4))<.001,"winter adds once to original storm temperature chain")
	s.inventory.slots[0]=s.inventory.instance("rain_umbrella");check(s.inventory.equip(0),"actual umbrella equip")
	exposure=Exposure.sample(s);check(exposure.umbrella and exposure.ambient<0,"umbrella protects rain without erasing winter cold")
	s.camps.states["season-fire"]={"x":w.player.position.x,"y":w.player.position.y,"fuel":100.0,"lit":true,"hits":0,"recipe":"","elapsed":0.0,"ready":false}
	check(Exposure.sample(s).heat==1,"existing lit campfire still contributes heat in winter")
	for season in 4:
		v.simulation.day=season*7+3;v.simulation.minute=720;v.simulation.blend=Vector3(1,0,0)
		v.dial.queue_redraw();v.season_dial.queue_redraw()
		await frames(5);await RenderingServer.frame_post_draw
		if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(Output+str(Rules.data.seasons[season].id)+".png")
		check(v.season_dial.simulation.season_date().index==season,"native dial follows authoritative season "+str(season))
	w.persistent_world=false
	var failures: int=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(Output+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	print("SEASONS V1 ",checks.size()," checks ",failures," failures")
	w.queue_free();await frames(5);quit(1 if failures else 0)
