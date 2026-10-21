extends SceneTree
var checks: Array=[]
var events: Array=[]
var fx: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func reset() -> void:
	events.clear();fx.last_played.clear()
func save_hashes() -> Dictionary:
	var hashes := {}
	for path in DirAccess.get_files_at("user://"):
		if path.ends_with(".json"):hashes[path]=FileAccess.get_sha256("user://"+path)
	return hashes
func run() -> void:
	Engine.max_fps=60
	var before := save_hashes()
	fx=root.get_node("AudioFX");fx.muted=true
	fx.sound_played.connect(func(key):events.append(key))
	Engine.set_meta("integration_seed",271828)
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.player.set_physics_process(false);w.item_ui.set_process(false);w.environment_view.simulation.paused=true;fx.set_process(false)
	await frames()
	var active := 0
	for key in fx.configuration:
		var entry: Dictionary=fx.configuration[key]
		if entry.get("enabled",true):
			active+=1
			check(entry.files.all(func(p):return str(p).begins_with("res://assets/audio/v3/runtime/") or str(p).begins_with("res://assets/audio/v4/")),key+" uses only current selected batch")
	check(active==33,"exactly 33 selected event groups active")
	for key in ["sfx_build_stone","sfx_build_wood","sfx_chest_close","sfx_chest_open","sfx_fridge_close","sfx_fridge_open","sfx_lantern_off","sfx_lantern_on"]:
		check(not fx.play_sfx(key),key+" legacy playback disabled")
	var plain := Button.new();w.item_ui.add_child(plain)
	reset();plain.pressed.emit();await frames(2)
	check(events==["sfx_ui_click"] and fx.ui_voice.playing,"ordinary button plays only selected click")
	check(fx.voices.is_empty(),"UI cues never allocate overlapping general voices")
	reset();w.item_ui.toggle_bag();await frames(2)
	check(events==["sfx_ui_open"] and fx.ui_voice.stream.resource_path=="res://assets/audio/v4/sfx_ui_open_short.wav","keyboard backpack open replaces click on same channel with short sound")
	var close: Button
	for node in w.item_ui.bag.find_children("*","Button",true,false):
		if node.text=="关闭":close=node;break
	check(close!=null,"actual backpack close button found")
	if close:
		reset();close.pressed.emit();await frames(2)
		check(not w.item_ui.bag.visible and events==["sfx_ui_close"],"actual close button produces close cue without button-click layer")
	reset();w.map_view.show();await frames(2)
	check(events==["sfx_ui_open"],"map opens with only current opening cue")
	var first := Button.new();first.pressed.connect(func():w.map_view.hide());w.item_ui.add_child(first)
	reset();first.pressed.emit();await frames(2)
	check(events==["sfx_ui_close"],"close wins when handler runs before generic click callback")
	w.map_view.show();await frames(2)
	var last := Button.new();w.item_ui.add_child(last);last.pressed.connect(func():w.map_view.hide())
	reset();last.pressed.emit();await frames(2)
	check(events==["sfx_ui_close"],"close wins when handler runs after generic click callback")
	reset()
	for i in 12:plain.pressed.emit()
	await frames(2)
	check(events==["sfx_ui_click"] and fx.ui_voice.playing and fx.voices.is_empty(),"rapid same-input callbacks coalesce into one click and one player")
	reset();fx.play_sfx("sfx_ui_close");fx.play_sfx("sfx_ui_click");fx.play_sfx("sfx_ui_error");await frames(2)
	check(events==["sfx_ui_error"],"main error feedback wins over generic click and panel close")
	reset();fx.play_sfx("sfx_item_move");fx.play_sfx("sfx_ui_click");await frames(2)
	check(events==["sfx_item_move"] and fx.voices.is_empty(),"inventory feedback replaces incidental button click")
	reset();fx.play_sfx("sfx_ui_open");await frames(2)
	var old_stream: AudioStream=fx.ui_voice.stream
	fx.play_sfx("sfx_ui_click");await frames(2)
	check(fx.ui_voice.stream!=old_stream and fx.voices.is_empty(),"subsequent action switches sole UI player without overlap")
	check(fx.configuration.sfx_ui_close.files.size()==1,"both user-selected close variants retained, never layered")
	for key in ["sfx_step_grass","sfx_step_dirt","sfx_step_stone","sfx_step_wood"]:
		check(fx.configuration[key].enabled,key+" remains enabled")
	reset();fx.play_sfx("sfx_step_grass",w.player.position)
	check(fx.step_voice!=null and fx.step_voice.pitch_scale==1.0,"footsteps retain separate natural playback channel")
	reset();fx.play_sfx("sfx_ui_click");w.item_service.dirty=false;w.queue_free();await frames(5)
	check(not fx.ui_voice.playing and fx.pending_ui.is_empty() and fx.world==null,"world exit cancels deferred UI cue and stops shared player")
	check(save_hashes()==before,"player JSON unchanged")
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open("res://reports/audio-ui-single-v8/window.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks},"  "))
	print("UI SINGLE V8: ",checks.size()," checks; ",failed," failures")
	quit(0 if failed==0 else 1)
