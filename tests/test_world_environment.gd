extends "res://tests/capture_world_v06.gd"
const Env = preload("res://scripts/world_environment.gd")
const OUT = "res://reports/storm-v01/"
func shot(label:String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func run()->void:
	var env := Env.new()
	check(env.clock_text()=="08:00" and env.day_length_minutes==60,"default 08:00 / 60 real minutes per day")
	env.advance(3600)
	check(env.day==2 and absf(env.minute-480)<.00001,"3600s advances exactly one day")
	env.set_time(23.99);env.advance(10)
	check(env.day==3 and env.minute<5,"midnight increments date")
	env.paused=true;var before:Dictionary=env.serialize();env.advance(120)
	check(before==env.serialize(),"pause freezes date and weather")
	env.paused=false;env.time_scale=10;env.set_time(8);env.advance(1)
	check(absf(env.minute-484)<.0001,"time scale x10")
	for entry in [[5,"清晨"],[8,"白天"],[17,"黄昏"],[20,"夜晚"],[0,"夜晚"]]:
		env.set_time(entry[0]);check(env.phase()==entry[1],"phase "+str(entry[0]))
	env.free();env=Env.new();env.force_weather(2)
	check(env.target_weather==2 and env.blend.z==0,"clear to rain directly starts a smooth transition")
	env.advance(12.5)
	check(env.blend.z>.49 and env.blend.z<.51 and env.blend.y==0,"halfway rain without overcast state")
	var saved:Dictionary=JSON.parse_string(JSON.stringify(env.serialize()))
	var restored:=Env.new()
	check(restored.restore(saved),"JSON restore mid transition")
	check(restored.blend.distance_to(env.blend)<.000001,"transition blend survives roundtrip")
	env.advance(1300);restored.advance(1300)
	check(env.serialize()==restored.serialize(),"restored RNG and timer produce identical future weather")
	check(not restored.restore({"version":99}),"unknown save version rejected")
	env.free();env=Env.new();env.force_weather(2);env.advance(25);env.force_weather(0)
	check(env.target_weather==0 and env.blend.z>.99,"rain to clear preserves rain at start of fade")
	env.advance(25);check(env.current_weather==0 and env.blend.z==0,"forced clear completes smooth fade")
	var legacy:Dictionary=env.serialize()
	legacy.version=1;legacy.weights=[5,3,2];legacy.blend=[.2,.5,.3]
	legacy.transition_from=[1,0,0];legacy.current_weather=1;legacy.target_weather=1;legacy.queued_weather=2
	legacy.day=7;legacy.minute=1205.5
	check(restored.restore(legacy),"v1 overcast save migrates")
	check(restored.day==7 and restored.minute==1205.5 and restored.target_weather==2 and absf(restored.blend.z-.3)<.00001 and restored.blend.y==0,"migration retains date/time/rain and queued rain destination")
	legacy.queued_weather=-1
	check(restored.restore(legacy) and restored.target_weather==0,"retired overcast without queued rain fades to clear")
	var valid_weather:=true
	var encountered:={}
	for i in 500:
		env.advance(60)
		encountered[env.target_weather]=true
		if env.current_weather not in [0,2,3] or env.target_weather not in [0,2,3]: valid_weather=false
	check(valid_weather and encountered.has(3),"long simulation supports clear/light rain/storm without overcast")
	env.force_weather(2 if env.blend.z<.5 else 0)
	var expected_weather:int=env.target_weather
	for i in 1506:env.advance(1.0/60.0)
	check(env.current_weather==expected_weather and env.blend[env.weather_slot(expected_weather)]==1,"frame-sized steps commit completed weather exactly")
	var old_v2:Dictionary=env.serialize();old_v2.version=2;old_v2.weights=[5,2]
	check(restored.restore(old_v2) and restored.day==env.day and restored.minute==env.minute,"v2 save migrates without resetting date/time")
	env.force_weather(3);env.advance(12.5)
	check(env.target_weather==3 and env.blend.y>.49 and env.blend.y<.51,"halfway storm transition")
	check(restored.restore(JSON.parse_string(JSON.stringify(env.serialize()))),"v3 storm mid-transition save restores")
	env.advance(2400);restored.advance(2400)
	check(env.serialize()==restored.serialize(),"storm save restores identical future weather")
	env.free();env=Env.new();var last:Color
	var maximum_delta:=0.0;var minimum:=1.0
	for i in 1441:
		env.minute=fposmod(float(i),1440.)
		var color:Color=env.light_parameters().tint
		minimum=minf(minimum,minf(color.r,minf(color.g,color.b)))
		if i>0:maximum_delta=maxf(maximum_delta,Vector3(color.r-last.r,color.g-last.g,color.b-last.b).length())
		last=color
	check(maximum_delta<.007,"continuous light including midnight",maximum_delta)
	check(minimum>=.69,"night retains readable channel floor",minimum)
	env.set_time(12);check(env.light_parameters().tint==Color.WHITE,"daylight identity")
	env.free();restored.free()
	Engine.set_meta("integration_seed",447349832)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	await settle()
	var sim:Node=w.environment_view.simulation
	sim.paused=true
	for pair in [[8,"day"],[6.5,"dawn"],[18.5,"dusk"],[0,"night"]]:
		sim.set_time(pair[0]);await process_frame;await shot(pair[1])
	sim.set_time(12);sim.force_weather(2);sim.paused=false;sim.advance(25);sim.paused=true
	for i in 90:await process_frame
	await process_frame;await shot("rain")
	for zoom in [.65,1.6]:
		w.player.camera.zoom=Vector2.ONE*zoom
		w.player.position+=Vector2(200,100);w.player.reset_physics_interpolation();w.player.camera.reset_smoothing()
		await settle();await shot("rain-zoom-"+str(zoom))
		var actual:Rect2=w.environment_view.rain_visual.last_view
		var expected:Vector2=Vector2(root.size)/root.get_canvas_transform().get_scale()
		check(actual.size.is_equal_approx(expected),"rain visible region follows camera zoom "+str(zoom))
	w.environment_view.panel.show();await process_frame;await shot("debug")
	check(w.environment_view.find_children("*","AudioStreamPlayer",true,false).is_empty() and not w.environment_view.has_method("make_rain_sound"),"synthetic rain audio removed")
	check(w.generator.VERSION=="windrest-continent-0.6.0","map generator unchanged")
	var view:CanvasLayer=w.environment_view
	view.save_path="user://environment-test-roundtrip.json"
	view.save_state()
	var disk=JSON.parse_string(FileAccess.get_file_as_string(view.save_path))
	var disk_env:=Env.new()
	var restored_disk:=disk_env.restore(disk)
	check(restored_disk and JSON.stringify(disk_env.serialize())==JSON.stringify(sim.serialize()),"atomic disk save restores complete environment",[disk_env.serialize(),sim.serialize()] if not restored_disk or JSON.stringify(disk_env.serialize())!=JSON.stringify(sim.serialize()) else "")
	disk_env.free();DirAccess.remove_absolute(view.save_path);view.save_path=""
	view.panel.hide()
	w.player.camera.zoom=Vector2.ONE
	w.player.position=w.generator.region_cores[w.generator.region_kinds.find(0)]
	w.player.camera.reset_smoothing();await settle()
	sim.set_time(0);await process_frame;await shot("forest-night-rain")
	sim.set_time(12);await process_frame;await shot("forest-day-rain")
	var rain:Node2D=view.rain_visual
	check(rain.get_index()<w.object_root.get_index() and rain.z_index==0,"ground arcs and rain below actors/props, above pure ground copy")
	var costs:Array[float]=[]
	var drop_counts:Array[int]=[]
	var splash_counts:Array[int]=[]
	for i in 180:
		var start:=Time.get_ticks_usec()
		await process_frame
		costs.append((Time.get_ticks_usec()-start)/1000.0)
		drop_counts.append(rain.active_count(rain.drops))
		splash_counts.append(rain.active_count(rain.splashes))
	costs.sort()
	check(drop_counts.max()<40 and splash_counts.max()>0,"sparse falling rain with live ground arcs",{"drops_max":drop_counts.max(),"arcs_max":splash_counts.max()})
	check(rain.get_child_count()==0 and rain.drops.size()==256 and rain.splashes.size()==128,"bounded storm slot pools and no per-drop nodes")
	var perf:={"method":"180 rendered frame intervals, sparse rain in loaded forest, 60 FPS cap; includes pacing; not a full exploration benchmark","median_ms":costs[90],"p95_ms":costs[171],"nodes":get_node_count(),"static_memory_mib":OS.get_static_memory_usage()/1048576.0,"max_visible_drops":drop_counts.max(),"max_ground_arcs":splash_counts.max()}
	var small_light:Dictionary=sim.light_parameters()
	var small_emitted:int=rain.emitted
	for i in 120:await process_frame
	var small_rate:int=rain.emitted-small_emitted
	sim.force_weather(3);sim.paused=false;sim.advance(25);sim.paused=true
	for i in 120:await process_frame
	var storm_counts:Array[int]=[];var storm_costs:Array[float]=[]
	var storm_emitted:int=rain.emitted
	for i in 120:
		var frame_start:=Time.get_ticks_usec()
		await process_frame
		storm_counts.append(rain.active_count(rain.drops))
		storm_costs.append((Time.get_ticks_usec()-frame_start)/1000.0)
	var storm_rate:int=rain.emitted-storm_emitted
	check(storm_rate>small_rate*3 and storm_counts.max()>50,"storm emission substantially heavier than light rain",{"small_emitted_120frames":small_rate,"storm_emitted_120frames":storm_rate,"storm_max_drops":storm_counts.max()})
	check(sim.light_parameters().brightness<small_light.brightness and sim.weather_name()=="雷暴雨" and sim.weather_name(2)=="小雨","storm darker and rain renamed light rain")
	await shot("forest-day-storm")
	sim.set_time(0);await process_frame;await shot("forest-night-storm")
	sim.set_time(12);await process_frame
	view.panel.show();await process_frame;await shot("debug-three-weather");view.panel.hide()
	# Test the real-time flash scheduler without changing game speed.
	view.lightning_age=-1.0;view.lightning_wait=.01
	view.update_lightning(.02,1.0)
	check(view.lightning_age==0.0 and view.lightning_wait>=45 and view.lightning_wait<=90,"storm flash begins then schedules 45-90 real second quiet interval")
	var pulse_starts:=0;var was_lit:=false
	for i in 350:
		var lit:bool=view.lightning_strength(float(i)/1000.0)>.001
		if lit and not was_lit:pulse_starts+=1
		was_lit=lit
	check(pulse_starts==2 and view.lightning_strength(.30)==0,"exactly two short flashes within 0.28 seconds")
	view.update_lightning(.01,0.0)
	check(view.lightning_age<0 and view.material_effect.get_shader_parameter("lightning")==0,"no lightning outside storm")
	view.set_process(false)
	view.material_effect.set_shader_parameter("lightning",.26);await process_frame;await shot("storm-first-flash")
	view.material_effect.set_shader_parameter("lightning",0.0);await process_frame;await shot("storm-flash-gap")
	view.material_effect.set_shader_parameter("lightning",.20);await process_frame;await shot("storm-second-flash")
	view.material_effect.set_shader_parameter("lightning",0.0);view.set_process(true)
	storm_costs.sort()
	perf["storm"]={"median_ms":storm_costs[60],"p95_ms":storm_costs[114],"max_drops":storm_counts.max(),"emitted_in_120frames":storm_rate}
	var result:={"engine":Engine.get_version_info().string,"checks":checks,"performance_sample":perf,"failures":checks.filter(func(c):return not c.pass).size(),"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name()}
	var f:=FileAccess.open(OUT+"validation.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	print("ENVIRONMENT_TEST ",JSON.stringify(result))
	w.queue_free();await process_frame
	quit(0 if result.failures==0 else 1)


