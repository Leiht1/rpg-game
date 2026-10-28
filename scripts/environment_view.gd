extends CanvasLayer
const Simulation = preload("res://scripts/world_environment.gd")
var simulation: Node
var world: Node2D
var effect := ColorRect.new()
var material_effect := ShaderMaterial.new()
var dial := preload("res://scripts/environment_dial.gd").new()
var season_dial := preload("res://scripts/season_dial.gd").new()
var panel := PanelContainer.new()
var detail := Label.new()
var rain_visual := preload("res://scripts/weather_rain.gd").new()
var save_clock := 0.0
var hallucination_visual := 0.0
var preview := false
var previous_scale := 1.0
var previous_pause := false
var save_path := ""
var lightning_random := RandomNumberGenerator.new()
var lightning_wait := 60.0
var lightning_age := -1.0
const LIGHTNING_INTERVAL_MIN := 45.0
const LIGHTNING_INTERVAL_MAX := 90.0
const LIGHTNING_DURATION := .28

func configure(owner_world: Node2D) -> void:
	world = owner_world
	layer = 1
	simulation = Simulation.new()
	simulation.name = "WorldEnvironment"
	world.add_child(simulation)
	world.generator.season_sim=simulation
	simulation.rng.seed = world.world_seed ^ 78041
	lightning_random.seed=world.world_seed ^ 93617
	lightning_wait=lightning_random.randf_range(LIGHTNING_INTERVAL_MIN,LIGHTNING_INTERVAL_MAX)
	if world.persistent_world and not world.get_meta("character_preview",false) and not world.get_meta("isolated_environment",false):
		save_path = "user://environment-%s-%d.json" % [world.generator.VERSION,world.world_seed]
		if FileAccess.file_exists(save_path):
			var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
			if data is Dictionary: simulation.restore(data)
	rain_visual.name="VisibleRainAndGroundArcs"
	rain_visual.world=world
	world.add_child(rain_visual)
	# After streamed ground/copy, before every sorted prop and the player.
	world.move_child(rain_visual,world.object_root.get_index())
	var season_visual := preload("res://scripts/season_features_visual.gd").new()
	season_visual.name="SeasonFlecks"
	season_visual.world=world
	world.add_child(season_visual)
	world.move_child(season_visual,world.object_root.get_index())
	material_effect.shader = preload("res://scripts/world_environment.gdshader")
	var world_copy := BackBufferCopy.new()
	world_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(world_copy)
	effect.material = material_effect
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effect)
	# UI is a later CanvasLayer, so world grading never tints the HUD or map.
	var hud := CanvasLayer.new()
	hud.layer = 3
	add_child(hud)
	hud.add_child(dial)
	dial.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	dial.offset_left=20
	dial.offset_right=160
	dial.offset_top=16
	dial.offset_bottom=180
	dial.simulation=simulation
	dial.add_child(season_dial)
	season_dial.position=Vector2(144,19)
	season_dial.size=Vector2(100,116)
	season_dial.simulation=simulation
	world.title.position.x=280
	world.hint.position.x=280
	world.debug_label.position.x=280
	panel.position = Vector2(880,190)
	panel.custom_minimum_size = Vector2(365,0)
	hud.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var label := Label.new()
	label.text = "环境调试 · F4 收起"
	box.add_child(label)
	detail.add_theme_font_size_override("font_size",14)
	box.add_child(detail)
	var times := HBoxContainer.new()
	box.add_child(times)
	for hour in [5,8,17,18.5,20,0]:
		button(times,str(hour)+"时",func(): simulation.set_time(float(hour)))
	var row := HBoxContainer.new()
	box.add_child(row)
	var hour_input := SpinBox.new()
	hour_input.min_value=0;hour_input.max_value=23.99;hour_input.step=.01;hour_input.value=8
	row.add_child(hour_input)
	button(row,"设定小时",func(): simulation.set_time(hour_input.value))
	var speeds := HBoxContainer.new()
	box.add_child(speeds)
	for speed in [0,1,10,60]:
		button(speeds,"暂停" if speed==0 else "×"+str(speed),func():
			stop_preview()
			if speed==0: simulation.paused=not simulation.paused
			else: simulation.time_scale=float(speed);simulation.paused=false)
	button(box,"60秒预览一天 / 结束预览",func():
		if preview: stop_preview()
		else:
			previous_scale=simulation.time_scale;previous_pause=simulation.paused
			preview=true;simulation.time_scale=simulation.day_length_minutes;simulation.paused=false)
	button(box,"切换四季（下一季）",debug_next_season)
	var weather_row := HBoxContainer.new()
	box.add_child(weather_row)
	for weather in [Simulation.Weather.CLEAR, Simulation.Weather.RAIN, Simulation.Weather.THUNDERSTORM]:
		button(weather_row,simulation.weather_name(weather),func(): simulation.force_weather(weather))
	button(box,"预览一次闪电（雷暴雨时）",func():
		if simulation.blend.y>.7: lightning_age=0.0)
	panel.hide()

func debug_next_season() -> void:
	if not preload("res://scripts/debug_access.gd").allowed():return
	stop_preview()
	var date: Dictionary=simulation.season_date()
	var days: float=float(preload("res://scripts/season_rules.gd").data.seasons[date.index].days)
	# Debug calendar jump only; do not replay elapsed body/cooking/crop time.
	simulation.day+=maxi(1,int(ceil(days-float(date.progress))))
	simulation.state_changed.emit()
	world.item_service.dirty=true
	dial.queue_redraw();season_dial.queue_redraw()

func button(parent: Node, text: String, action: Callable) -> void:
	var control := Button.new()
	control.text = text
	control.pressed.connect(action)
	control.focus_mode = Control.FOCUS_NONE
	parent.add_child(control)

func stop_preview() -> void:
	if not preview: return
	preview=false;simulation.time_scale=previous_scale;simulation.paused=previous_pause

func _process(delta: float) -> void:
	if not is_instance_valid(world) or not world.started: return
	if world.get_meta("network_game",false):
		pass
	elif not preview and not simulation.paused and is_instance_valid(world.item_service):
		var body = world.item_service.body
		if body.energy<=0.0 and not body.sleep_active():
			try_start_sleep(body.energy<=0.0)
		advance_gameplay(delta*maxf(0.0,simulation.time_scale))
	else:
		simulation.advance(delta)
	var state = world.item_service.body
	var target := float(state.rules.hallucination_strength) if state.hallucination_remaining>0.0 else 0.0
	hallucination_visual=move_toward(hallucination_visual,target,delta/maxf(.01,float(state.rules.hallucination_fade_seconds)))
	material_effect.set_shader_parameter("hallucination",hallucination_visual)
	var light: Dictionary = simulation.light_parameters()
	for key in ["brightness","saturation","contrast"]: material_effect.set_shader_parameter(key,light[key])
	material_effect.set_shader_parameter("light_tint",light.tint)
	var lamp_on: bool=is_instance_valid(world.item_service) and is_instance_valid(world.item_service.lantern) and world.item_service.lantern.visible
	material_effect.set_shader_parameter("lantern_strength",1.0 if lamp_on else 0.0)
	if lamp_on:
		var viewport := get_viewport()
		var center: Vector2=viewport.get_canvas_transform()*(world.player.position+Vector2(0,-20))
		material_effect.set_shader_parameter("lantern_center",center/viewport.get_visible_rect().size)
		material_effect.set_shader_parameter("lantern_radius",float(world.item_service.database.item(str(world.item_service.lamp_slot().get("item_id",""))).get("light_radius",260.0))*viewport.get_canvas_transform().get_scale().x)
	if world.item_service.merchant.enabled:world.item_service.merchant.lights.shader_parameters(material_effect)
	var centers := PackedVector2Array()
	var radii := PackedFloat32Array()
	var strengths := PackedFloat32Array()
	if world.get_meta("network_game",false):
		for actor in world.actors.values():
			if not is_instance_valid(actor) or actor.lamp_item.is_empty():continue
			var radius: float=float(world.item_service.database.item(actor.lamp_item).get("light_radius",0))
			if radius<=0:continue
			var screen: Vector2=get_viewport().get_canvas_transform()*actor.position
			if not get_viewport().get_visible_rect().grow(radius*get_viewport().get_canvas_transform().get_scale().x).has_point(screen):continue
			centers.append(screen/get_viewport().get_visible_rect().size)
			radii.append(radius*get_viewport().get_canvas_transform().get_scale().x);strengths.append(1.0)
	for node in world.item_service.camps.visuals.values():
		if is_instance_valid(node) and world.item_service.camps.states[node.camp_id].lit:
			var screen: Vector2=get_viewport().get_canvas_transform()*node.position
			var radius: float=float(world.item_service.camps.rules.light_radius)*world.item_service.camps.light_scale(node.camp_id)
			if radius>0 and get_viewport().get_visible_rect().grow(maxf(240.0,radius*get_viewport().get_canvas_transform().get_scale().x)).has_point(screen):
				centers.append(screen/get_viewport().get_visible_rect().size)
				radii.append(radius*get_viewport().get_canvas_transform().get_scale().x)
				strengths.append(1.0)
	for id in world.item_service.builds.visuals:
		if (world.item_service.builds.states[id].kind!="camp_torch" or not world.item_service.camps.fuel_lit(id)) and not (world.item_service.builds.states[id].kind=="copper_lamp" and world.item_service.builds.states[id].machine.enabled): continue
		var node: Node2D=world.item_service.builds.visuals[id]
		var screen: Vector2=get_viewport().get_canvas_transform()*node.position
		var radius: float=float(world.item_service.industry.rules.copper_lamp_radius) if world.item_service.builds.states[id].kind=="copper_lamp" else 210.0*world.item_service.camps.light_scale(id)
		if get_viewport().get_visible_rect().grow(maxf(240.0,radius*get_viewport().get_canvas_transform().get_scale().x)).has_point(screen):
			centers.append(screen/get_viewport().get_visible_rect().size);radii.append(radius*get_viewport().get_canvas_transform().get_scale().x)
			strengths.append(float(world.item_service.industry.rules.copper_lamp_strength) if world.item_service.builds.states[id].kind=="copper_lamp" else 1.0)
	material_effect.set_shader_parameter("camp_count",mini(32,centers.size()))
	centers.resize(32);radii.resize(32);strengths.resize(32)
	material_effect.set_shader_parameter("camp_centers",centers)
	material_effect.set_shader_parameter("camp_radii",radii)
	material_effect.set_shader_parameter("camp_strengths",strengths)
	rain_visual.intensity=0.0 if simulation.season_date().index==3 else light.rain
	rain_visual.storm=light.storm
	update_lightning(delta,light.storm)
	dial.queue_redraw()
	season_dial.queue_redraw()
	detail.text="流速 ×%.1f%s\n%s → %s  %.0f%%\n持续剩余 %.0f秒 · 每日 %.0f分" % [simulation.time_scale,"（暂停）" if simulation.paused else "",simulation.weather_name(simulation.current_weather),simulation.weather_name(),minf(100.,simulation.transition_elapsed/simulation.transition_seconds*100.),simulation.weather_remaining,simulation.day_length_minutes]
	detail.text=simulation.clock_text()+" · "+simulation.phase()+"\n"+detail.text
	save_clock += delta
	if save_clock >= 15.0:
		save_clock=0;save_state()

func lightning_strength(age: float) -> float:
	# Two short eased pulses, .07s and .09s, with a .11s dark gap.
	if age>=0.0 and age<.07: return sin(PI*age/.07)*.26
	if age>=.18 and age<.27: return sin(PI*(age-.18)/.09)*.20
	return 0.0

func update_lightning(delta: float, storm: float) -> void:
	if storm<=.7:
		lightning_age=-1.0
	elif lightning_age>=0.0:
		lightning_age+=delta
		if lightning_age>=LIGHTNING_DURATION: lightning_age=-1.0
	else:
		lightning_wait-=delta
		if lightning_wait<=0.0:
			lightning_age=0.0
			AudioFX.play_sfx("sfx_thunder")
			lightning_wait=lightning_random.randf_range(LIGHTNING_INTERVAL_MIN,LIGHTNING_INTERVAL_MAX)
	material_effect.set_shader_parameter("lightning",lightning_strength(lightning_age)*storm)

func _input(event: InputEvent) -> void:
	if preload("res://scripts/debug_access.gd").allowed() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F4:
		panel.visible=not panel.visible
		get_viewport().set_input_as_handled()

func save_state() -> void:
	if save_path.is_empty(): return
	var data: Dictionary=simulation.serialize()
	# Preview speed is a tool preference, never a saved gameplay rate.
	if preview: data.time_scale=previous_scale;data.paused=previous_pause
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(data));file.close()
	DirAccess.rename_absolute(save_path+".tmp",save_path)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST or what==NOTIFICATION_EXIT_TREE:
		if is_instance_valid(simulation): save_state()





# Sleep is a character state. It never controls the world's clock or speed.
func try_start_sleep(forced: bool) -> bool:
	return world.item_service.sleep.start("","maximum",forced).is_empty() if forced else false

func advance_gameplay(seconds: float, shared: bool=true) -> void:
	if seconds<=0 or preview or simulation.paused: return
	var remaining := seconds
	var service = world.item_service
	var body = service.body
	var player = world.player
	# Every subsystem receives the same normal elapsed step. No sleep multiplier.
	while remaining>0.000001:
		var step := minf(remaining,1.0/30.0)
		service.sleep.advance(step)
		if body.sleeping:
			var minutes_left: float=maxf(0.000001,body.sleep_duration-body.sleep_elapsed)
			var target: float=float(body.sleep_session.get("target",100))
			var rate: float=float(body.sleep_session.get("rate",body.rules.sleep_energy_per_hour))*body.energy_recovery_factor()
			minutes_left=minf(minutes_left,maxf(.000001,(target-body.energy)/rate*60))
			step=minf(step,minutes_left*simulation.day_length_minutes*60.0/1440.0)
		var original_scale: float=simulation.time_scale
		if shared:simulation.time_scale=1.0;simulation.advance(step);simulation.time_scale=original_scale
		body.busy=player.input_blocked and not body.sleeping
		body.exposure=preload("res://scripts/weather_exposure.gd").sample(service)
		body.advance(step,step*1440.0/maxf(1.0,simulation.day_length_minutes*60.0),player.running and player.moving and not player.input_blocked,player.action in ["chop","mine","dig"] and not player.input_blocked,player.moving and not player.input_blocked)
		service.industry.advance(step,step*1440.0/maxf(1.0,simulation.day_length_minutes*60.0),shared)
		if shared:
			preload("res://scripts/season_surface.gd").advance(service,step*1440.0/maxf(1.0,simulation.day_length_minutes*60.0))
			service.planting.advance(step*1440.0/maxf(1.0,simulation.day_length_minutes*60.0))
			service.animals.advance(step*1440.0/maxf(1.0,simulation.day_length_minutes*60.0))
			if service.writable and service.fishing_population.advance(step*1440.0/maxf(1.0,simulation.day_length_minutes*60.0)): service.dirty=true
			service.merchant.advance(step*1440.0/maxf(1.0,simulation.day_length_minutes*60.0))
			service.camps.advance(step,simulation.blend.z+simulation.blend.y,simulation.blend.y)
		elif service.merchant.enabled:service.merchant.lights.advance(step*1440.0/maxf(1.0,simulation.day_length_minutes*60.0),true)
		if is_instance_valid(service.lantern) and service.lantern.visible: service.burn_lantern(step)
		service.sleep.after_body()
		remaining-=step

func body_environment_snapshot() -> Dictionary:
	var data: Dictionary=simulation.serialize()
	if preview: data.time_scale=previous_scale;data.paused=previous_pause
	return data

