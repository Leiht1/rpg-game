extends "res://tests/sleep_v8_fixture.gd"
const Surface=preload("res://scripts/season_surface.gd")
const DEST="res://reports/season-features-v1/"
func snap(label: String) -> void:
	v._process(0)
	await create_timer(.4).timeout;await frames(8);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DEST+label+".png")
func clear_camps() -> void:
	for node in s.camps.visuals.values():
		if is_instance_valid(node):node.queue_free()
	s.camps.visuals.clear();s.camps.states.clear();s.camps.rebuild()
func run() -> void:
	Engine.set_meta("season_features_preview",true)
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds
	w.set_process(false);s.set_process(false);v.set_process(false);w.player.set_physics_process(false)
	root.size=default_size();root.content_scale_size=root.size
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	check(not w.persistent_world and v.save_path.is_empty(),"isolated world and environment")
	var sim=v.simulation
	w.player.camera.position_smoothing_enabled=false
	for season in 4:
		sim.day=season*7+3;sim.minute=720
		sim.snow=.85 if season==3 else 0.0
		v._process(0)
		check(sim.light_hours()==preload("res://scripts/season_rules.gd").data.seasons[season].light_hours,"configured day span "+str(season))
		await snap("season-"+str(season))
	var visual=w.get_node("SeasonFlecks")
	visual.set_process(false)
	for pair in [[0,6.0,"bird-wing-up"],[0,6.125,"bird-wing-level"],[0,6.25,"bird-wing-down"],[2,6.0,"leaves-turn"]]:
		sim.day=int(pair[0])*7+3;visual.clock=float(pair[1]);visual._process(0)
		await snap(str(pair[2]))
	check(visual.art.size()==12 and visual.art[0]!=visual.art[2],"distinct sequence frames loaded without skeletons")
	visual.set_process(true)
	sim.day=24;sim.minute=720;sim.snow=0
	sim.advance_calendar(1000)
	check(sim.snow>.5,"winter snow accumulates from normal game time")
	var amount: float=sim.snow;sim.blend=Vector3(1,0,0);sim.advance_calendar(1)
	check(sim.snow>=amount,"winter snow persists in clear weather")
	sim.day=29;sim.advance_calendar(1);check(sim.snow<1 and sim.snow>0,"spring gradual thaw")
	var frozen_count:=0
	sim.day=24;sim.minute=720
	for lake in w.generator.lakes:
		var at:=Vector2(lake.x,lake.y)
		if w.generator.lake_weight(at)>.9:
			check(w.generator.frozen_at(at) and w.generator.can_walk(at),"lake passable on ice")
			frozen_count+=1
	check(frozen_count>0,"real inland lake exercised")
	check(not w.generator.frozen_at(Vector2(-100,-100)),"outside ocean never frozen")
	var packed: Dictionary=sim.serialize();sim.snow=0;check(sim.restore(packed) and sim.snow==packed.season_surface.snow,"surface roundtrip exact")
	packed.season_surface.snow=-1;check(not sim.restore(packed),"negative snow rejected before mutation")
	b.states.clear();b.refresh_all();clear_camps()
	var kinds: Array=b.definitions.keys();var placed:=0
	for kind in kinds:
		var row: Dictionary=b.candidate(kind,w.generator.spawn+Vector2((placed%7-3)*122,(placed/7-2)*95),false,true,0)
		if kind=="signpost":row.text="雪景"
		if kind=="tilled_soil":row.crop="carrot";row.growth_minutes=700
		b.states["snow-"+kind]=row;placed+=1
	b.refresh_all();await frames(12)
	sim.day=24;sim.snow=1;Surface.advance(s,1500)
	check(Surface.blocked(s,"snow-advanced_smokehouse"),"heavy snow blocks smokehouse")
	check(not b.visuals["snow-advanced_smokehouse"].perform_interaction("open",w.player),"actual building interaction rejects snow")
	check(s.expansion.check("snow-advanced_smokehouse").contains("积雪"),"existing expansion transaction rejects snow")
	check(s.industry.check("snow-copper_oven").contains("积雪"),"existing machine transaction rejects snow")
	check(not Surface.blocked(s,"snow-wood_chest"),"storage remains usable")
	var row: Dictionary=b.states["snow-advanced_smokehouse"]
	var original: Dictionary=row.duplicate(true)
	s.camps.states["heat"]={"x":row.x+110,"y":row.y,"lit":false,"fuel":1000,"recipe":"","elapsed":0.0,"ready":false}
	check(Surface.heat(s,Vector2(row.x,row.y))==0,"unlit fire no heat")
	s.camps.states.heat.lit=true;s.camps.states.heat.fuel=0
	check(Surface.heat(s,Vector2(row.x,row.y))==0,"empty fire no heat")
	s.camps.states.heat.fuel=1000
	check(Surface.heat(s,Vector2(row.x,row.y))>0,"existing burning fire heat")
	s.camps.states.heat.x=row.x+500
	check(Surface.heat(s,Vector2(row.x,row.y))==0,"fire beyond configured range cannot melt snow")
	s.camps.states.heat.x=row.x+110
	check(s.camps.validate(s.camps.serialize()),"melt source is a valid existing campfire state")
	s.camps.rebuild();s.camps.install(w.stream.chunk_at(Vector2(row.x+110,row.y)))
	await snap("active-heat-source")
	Surface.advance(s,90)
	check(not Surface.blocked(s,"snow-advanced_smokehouse") and row==original,"heat restores use without mutating business row")
	clear_camps()
	var state_path:=DEST+"isolated-items.json"
	s.save_path=state_path;w.persistent_world=true
	check(s.save_state(),"atomic save includes building snow")
	var saved_amount: float=sim.building_snow["snow-copper_oven"].amount
	sim.snow=0;sim.building_snow.clear();s.load_state(state_path)
	check(s.writable and sim.snow==1 and sim.building_snow["snow-copper_oven"].amount==saved_amount,"actual load preserves snow and melt progress")
	w.persistent_world=false
	for variant in ["tree_01","tree_03","tree_04"]:
		var prop=load("res://scripts/scenery_prop.gd").new()
		prop.kind=0;prop.variant_id=variant;prop.surface="grass"
		prop.texture=load("res://assets/environment/contact_v01/"+variant+"_grass.png")
		prop.display_size=Vector2(prop.texture.get_size())*.65
		prop.position=w.generator.spawn+Vector2(-260+["tree_01","tree_03","tree_04"].find(variant)*220,-320)
		prop.prepare();w.object_root.add_child(prop);prop.add_to_group("trees")
	for i in 4:
		w.player.camera.position=Vector2((i%2)*390-190,(i/2)*230-100)
		await snap("buildings-"+str(i))
	var shelter=b.visuals["snow-rain_shelter"]
	w.player.camera.position=Vector2.ZERO
	for offset in [Vector2.ZERO,Vector2(0,180),Vector2(150,-10)]:
		w.player.position=shelter.position+offset;shelter.update_occlusion(w.player.position)
		await snap("snow-shelter-overlap-"+str(int(offset.x))+"-"+str(int(offset.y)))
		check(shelter.shelter_view.parts.all(func(p):return p.modulate.a==1),"snow canopy occlusion retains opaque poles "+str(offset))
	for vertical in [true,false]:
		for kind in ["stone_wall","wood_fence","wood_bed","straw_mat"]:
			var row2: Dictionary=b.candidate(kind,w.generator.spawn+Vector2(-200+["stone_wall","wood_fence","wood_bed","straw_mat"].find(kind)*120,200),vertical,true,0)
			b.states["orientation-"+kind]=row2
		b.refresh_all();w.player.camera.position=Vector2(0,0)
		await snap("orientation-"+str(vertical))
	var lake: Vector4=w.generator.lakes[0]
	var center:=Vector2(lake.x,lake.y)
	w.player.position=center;w.player.camera.position=Vector2.ZERO;w.stream.update_target(center)
	while not w.stream.viewport_ready(center,Vector2(640,360)):await process_frame
	await snap("lake-frozen")
	w.player.automated=true;w.player.input_blocked=false
	b.states["ice-obstacle"]=b.candidate("wood_chest",center+Vector2(80,0),false,true,0);b.refresh_all()
	w.player.input_override=Vector2.RIGHT;w.player.velocity=Vector2.ZERO
	for tick in 55:await physics_frame;w.player._physics_process(1./60)
	check(w.player.position.x<center.x+70 and w.player.position.x>center.x+10,"real building collider still blocks on ice")
	b.states.erase("ice-obstacle");b.refresh_all()
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		w.player.position=center;w.player.velocity=Vector2.ZERO;w.player.input_override=direction
		for tick in 18:await physics_frame;w.player._physics_process(1./60)
		check(w.player.velocity.dot(direction)>30,"ice acceleration direction "+str(direction))
		var speed: float=w.player.velocity.length();w.player.input_override=Vector2.ZERO
		await physics_frame;w.player._physics_process(1./60)
		check(w.player.velocity.length()>0 and w.player.velocity.length()<speed,"finite ice braking "+str(direction))
	w.player.input_override=Vector2.ZERO
	for tick in 160:await physics_frame;w.player._physics_process(1./60)
	check(w.player.velocity.length()<.1,"ice stops without infinite slide")
	sim.day=29
	check(not w.generator.frozen_at(center) and not w.generator.can_walk(center),"thaw restores original water collision")
	w.player.position=center;w.player.input_override=Vector2.ZERO
	await physics_frame;w.player._physics_process(1./60)
	check(w.generator.can_walk(w.player.position),"actor caught in thaw recovers to a real unobstructed bank")
	await snap("lake-thawed")
	var fishing=w.get_node("Fishing")
	var water_checked:=false
	for spot in fishing.spots:
		if int(spot.get("lake",-1))<0:continue
		w.player.position=spot.stand
		sim.day=29
		if fishing.nearest_spot()<0:continue
		sim.day=24
		check(fishing.nearest_spot()<0,"actual inland fishing entry unavailable while frozen")
		sim.day=29;check(fishing.nearest_spot()>=0,"actual fishing entry restored after thaw")
		water_checked=true;break
	check(water_checked,"real existing fishing bank exercised")
	w.player.position=w.generator.spawn;w.player.velocity=Vector2.ZERO;w.stream.update_target(w.player.position)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	w.player.input_override=Vector2.RIGHT;await physics_frame;w.player._physics_process(1./60)
	w.player.input_override=Vector2.ZERO;await physics_frame;w.player._physics_process(1./60)
	check(w.player.velocity.is_zero_approx(),"ordinary ground retains immediate stop after ice")
	var found: Dictionary={}
	for yy in range(4,95,3):
		for xx in range(4,95,3):
			var at: Vector2=Vector2(xx,yy)*w.generator.extent/100
			var biome: String=w.generator.biome(at)
			if biome in ["草原","森林","泥地","岩石区"] and not found.has(biome) and w.generator.can_walk(at,30):found[biome]=at
	sim.day=24;sim.snow=.85
	for biome in found:
		w.player.position=found[biome];w.stream.update_target(w.player.position)
		while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
		await snap("terrain-"+str(["草原","森林","泥地","岩石区"].find(biome)))
	check(found.size()==4,"all four actual terrain types rendered")
	var file:=FileAccess.open(DEST+"results.json",FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
	print("SEASON_FEATURES ",checks.size()," failures ",checks.filter(func(c):return not c.pass).size())
	w.queue_free();await frames(3);quit(1 if checks.any(func(c):return not c.pass) else 0)


