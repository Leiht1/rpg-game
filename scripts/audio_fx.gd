extends Node
## Session-only audio. Never consumes world RNG or writes gameplay/save state.
signal sound_played(key: String)
var configuration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/audio.json"))
var streams: Dictionary={}
var last_played: Dictionary={}
var random := RandomNumberGenerator.new()
var world: Node
var voices: Array[Node]=[]
var step_voice: AudioStreamPlayer2D
var ui_voice := AudioStreamPlayer.new()
var pending_ui := ""
var ui_flush_queued := false
var ui_epoch := 0
var rain := AudioStreamPlayer.new()
var light_rain := AudioStreamPlayer.new()
var rain_gain := 0.0
var light_rain_gain := 0.0
var animal_wait := 8.0
var last_position := Vector2.ZERO
var last_gait := 0.0
var muted := false

func _ready() -> void:
	random.randomize()
	add_child(rain)
	add_child(light_rain)
	add_child(ui_voice)
	rain.bus="Master"
	light_rain.bus="Master"
	get_tree().node_added.connect(watch_button)

func watch_button(node: Node) -> void:
	if node is BaseButton and not node.has_meta("audio_click_bound"):
		node.set_meta("audio_click_bound",true)
		node.pressed.connect(func():play_sfx("sfx_ui_close" if bool(node.get_meta("audio_window_close",false)) else "sfx_ui_click"))
	elif node is PopupMenu and not node.has_meta("audio_click_bound"):
		node.set_meta("audio_click_bound",true)
		node.id_pressed.connect(func(_id):play_sfx("sfx_ui_click"))

func bind_world(owner_world: Node) -> void:
	clear_world()
	world=owner_world
	last_position=world.player.position
	last_gait=world.player.gait_distance
	world.tree_exiting.connect(clear_world,CONNECT_ONE_SHOT)
	world.item_service.inventory.sound_requested.connect(play_sfx)
	world.item_service.notice.connect(notice_sound)
	world.item_service.food_effect.connect(func(_id,_effect):play_sfx("sfx_eat"))
	# Only intentional window closures, not tooltips, HUD redraws or hidden subpanels.
	for panel in [world.item_ui.bag,world.item_ui.craft_panel,world.map_view,world.camp_ui.panel,world.item_service.industry_ui,world.item_ui.body_ui.overlay,world.item_ui.split_panel,world.item_service.planting_ui.panel]:
		panel.visibility_changed.connect(panel_changed.bind(panel))

func notice_sound(message: String) -> void:
	for fragment in ["不足","失败","不能","无法","没有种子","已满","不喜欢","刚吃过","耗尽","请靠近","被挡","现在还不能"]:
		if message.contains(fragment):
			play_sfx("sfx_ui_error");return

func panel_changed(panel: CanvasItem) -> void:
	if is_instance_valid(world) and world.started:
		play_sfx("sfx_ui_open" if panel.visible else "sfx_ui_close")

func clear_world() -> void:
	world=null
	ui_epoch+=1;pending_ui="";ui_flush_queued=false;ui_voice.stop()
	rain.stop();light_rain.stop();rain_gain=0.0;light_rain_gain=0.0;last_gait=0.0;animal_wait=8.0
	for voice in voices:
		if is_instance_valid(voice):voice.queue_free()
	voices.clear();step_voice=null;last_played.clear()

func stream_for(path: String) -> AudioStream:
	if not streams.has(path):streams[path]=load(path)
	return streams[path] as AudioStream

func play_sfx(key: String, at: Vector2=Vector2.INF) -> bool:
	if not is_instance_valid(world) or not configuration.has(key):return false
	if get_tree().paused:return false
	var entry: Dictionary=configuration[key]
	if not bool(entry.get("enabled",true)):return false
	var now := Time.get_ticks_msec()/1000.0
	if now-float(last_played.get(key,-100.0))<float(entry.get("cooldown",0.1)):return false
	if at!=Vector2.INF and world.player.position.distance_to(at)>700.0:return false
	if key.begins_with("sfx_ui_") or (at==Vector2.INF and key in ["sfx_item_move","sfx_equip","sfx_bag_organize"]):
		# Resolve all callbacks for one input before playing: a close/open or
		# successful inventory operation wins over its generic button click.
		if pending_ui.is_empty() or ui_priority(key)>=ui_priority(pending_ui):pending_ui=key
		if not ui_flush_queued:
			ui_flush_queued=true
			flush_ui.call_deferred(ui_epoch)
		return true
	var footstep := key.begins_with("sfx_step_")
	if footstep and at==Vector2.INF:at=world.player.position
	# Finish the current original sample naturally. Busy footfalls are skipped,
	# never cut off, layered, or queued to play after the player stops.
	if footstep and is_instance_valid(step_voice) and step_voice.playing:return false
	voices=voices.filter(func(v):return is_instance_valid(v) and not v.is_queued_for_deletion())
	if voices.size()>=16:return false
	var paths: Array=entry.files
	var path: String=str(paths[random.randi_range(0,paths.size()-1)])
	var stream: AudioStream=stream_for(path)
	if stream==null:return false
	var voice: Node
	if at==Vector2.INF:
		voice=AudioStreamPlayer.new()
	else:
		voice=AudioStreamPlayer2D.new()
		voice.max_distance=700.0;voice.panning_strength=.6
	add_child(voice)
	if voice is AudioStreamPlayer2D:voice.global_position=at
	voice.stream=stream
	voice.volume_db=-80.0 if muted else float(entry.get("volume_db",-12.0))+float(entry.get("file_gain_db",{}).get(path,0.0))
	voice.pitch_scale=random.randf_range(.96,1.04) if not key.begins_with("sfx_ui_") and not footstep else 1.0
	if footstep:step_voice=voice as AudioStreamPlayer2D
	voices.append(voice)
	voice.finished.connect(func():voices.erase(voice);voice.queue_free())
	last_played[key]=now
	voice.play()
	sound_played.emit(key)
	return true

func ui_priority(key: String) -> int:
	if key=="sfx_ui_error":return 4
	if key in ["sfx_item_move","sfx_equip","sfx_bag_organize"]:return 3
	if key in ["sfx_ui_open","sfx_ui_close"]:return 2
	return 1

func flush_ui(epoch: int) -> void:
	if epoch!=ui_epoch:return
	var key := pending_ui
	pending_ui="";ui_flush_queued=false
	if key.is_empty() or not is_instance_valid(world) or get_tree().paused:return
	var entry: Dictionary=configuration.get(key,{})
	if entry.is_empty() or not bool(entry.get("enabled",true)):return
	var now := Time.get_ticks_msec()/1000.0
	if now-float(last_played.get(key,-100.0))<float(entry.get("cooldown",.1)):return
	var paths: Array=entry.files
	var path: String=str(paths[random.randi_range(0,paths.size()-1)])
	var stream: AudioStream=stream_for(path)
	if stream==null:return
	ui_voice.stop()
	ui_voice.stream=stream
	ui_voice.pitch_scale=1.0
	ui_voice.volume_db=-80.0 if muted else float(entry.get("volume_db",-12.0))+float(entry.get("file_gain_db",{}).get(path,0.0))
	ui_voice.play()
	last_played[key]=now
	sound_played.emit(key)

func build_placed(kind: String, at: Vector2) -> void:
	if kind=="tilled_soil":
		# No dedicated till sample supplied yet; reuse this batch's natural soil sound.
		play_sfx("sfx_dig_soil",at)
	elif kind in ["stone_wall","stone_gate","stone_path","stone_furnace","simple_campfire"]:
		play_sfx("sfx_build_stone",at)
	elif kind in ["wood_floor","wood_fence","fence_gate","wood_chest","workbench","wood_bed","signpost","camp_torch","feed_trough"]:
		play_sfx("sfx_build_wood",at)
	if kind=="signpost":play_sfx("sfx_map_mark",at)

func surface_at(at: Vector2) -> String:
	var builds: RefCounted=world.item_service.builds
	for row in builds.states.values():
		if row.kind in ["wood_floor","stone_path"] and Rect2(Vector2(row.x,row.y)-Vector2(48,32),Vector2(96,64)).has_point(at):
			return "wood" if row.kind=="wood_floor" else "stone"
	var biome: String=world.generator.biome(at)
	if biome=="岩石区":return "stone"
	if biome in ["泥地","山地","水岸"]:return "dirt"
	return "grass"

func _process(delta: float) -> void:
	if not is_instance_valid(world):return
	var player: Node2D=world.player
	var distance := player.position.distance_to(last_position)
	last_position=player.position
	if not world.started or get_tree().paused:
		rain.stream_paused=true;light_rain.stream_paused=true;last_gait=player.gait_distance;return
	var simulation: Node=world.environment_view.simulation
	var half_stride := maxf(1.0,float(player.actor.get("stride_world_units",128.0))*.5)
	if not player.input_blocked and player.action.is_empty() and not player.body.down and not player.body.sleep_active() and distance>.01 and distance<=100.0:
		if floori(player.gait_distance/half_stride)>floori(last_gait/half_stride):
			play_sfx("sfx_step_"+surface_at(player.position),player.position)
	last_gait=player.gait_distance
	update_rain(delta,float(simulation.blend.y),bool(simulation.paused),float(simulation.blend.z))
	if not simulation.paused:
		animal_wait-=delta
		if animal_wait<=0.0:
			animal_wait=random.randf_range(12.0,24.0)
			var nearby: Array=[]
			for node in get_tree().get_nodes_in_group("world_interactables"):
				if node.has_meta("animal_id") and node.has_method("row") and node.is_visible_in_tree() and node.position.distance_to(player.position)<450.0:
					var row: Dictionary=node.row()
					if row.get("species","")=="chicken" and not row.get("departed",false):nearby.append(node)
			if not nearby.is_empty():play_sfx("sfx_chicken_idle",nearby[random.randi_range(0,nearby.size()-1)].position)

func update_rain(delta: float, storm: float, paused: bool, light: float=0.0) -> void:
	rain.stream_paused=paused
	light_rain.stream_paused=paused
	if paused:return
	rain_gain=move_toward(rain_gain,clampf(storm,0.0,1.0),delta*.5)
	light_rain_gain=move_toward(light_rain_gain,clampf(light,0.0,1.0),delta*.5)
	update_rain_voice(rain,"amb_rain_storm_loop",rain_gain)
	update_rain_voice(light_rain,"amb_rain_light_loop",light_rain_gain)

func update_rain_voice(voice: AudioStreamPlayer, key: String, gain: float) -> void:
	if gain<.002 or not configuration.has(key) or not bool(configuration[key].get("enabled",true)):
		voice.stop();return
	var entry: Dictionary=configuration[key]
	var path: String=str(entry.files[0])
	if not voice.playing:
		var source: AudioStream=stream_for(path)
		if source==null:return
		voice.stream=source.duplicate()
		if voice.stream is AudioStreamWAV:
			voice.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
			voice.stream.loop_begin=0
			voice.stream.loop_end=roundi(voice.stream.get_length()*voice.stream.mix_rate)
		else:voice.stream.loop=true
		voice.volume_db=-80.0
		voice.play()
	voice.volume_db=-80.0 if muted else float(entry.volume_db)+float(entry.get("file_gain_db",{}).get(path,0.0))+linear_to_db(gain)
