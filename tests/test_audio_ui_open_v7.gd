extends SceneTree
var checks: Array=[]
var sounds: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func run() -> void:
	Engine.max_fps=60
	var before := {}
	for p in DirAccess.get_files_at("user://"):
		if p.ends_with(".json"):before[p]=FileAccess.get_sha256("user://"+p)
	var fx=root.get_node("AudioFX");fx.muted=true
	fx.sound_played.connect(func(key):sounds.append(key))
	var path: String=fx.configuration.sfx_ui_open.files[0]
	var audio: AudioStream=fx.stream_for(path)
	check(path=="res://assets/audio/v4/sfx_ui_open_short.wav","runtime uses shortened copy")
	check(audio!=null and absf(audio.get_length()-.3)<.001,"short copy decodes as 0.30 seconds")
	check(is_equal_approx(float(fx.configuration.sfx_ui_open.volume_db),-.14),"opening volume unchanged")
	Engine.set_meta("integration_seed",271828)
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.player.set_physics_process(false);w.item_ui.set_process(false);w.environment_view.simulation.paused=true;fx.set_process(false)
	fx.last_played.clear();sounds.clear();w.item_ui.toggle_bag();await process_frame;await process_frame
	check(w.item_ui.bag.visible and sounds.has("sfx_ui_open"),"actual backpack open plays shortened event")
	await create_timer(.38).timeout
	check(fx.voices.all(func(v):return not is_instance_valid(v) or not v.playing),"backpack cue finishes without tail")
	w.item_ui.toggle_bag();fx.last_played.clear();sounds.clear()
	w.map_view.show();await process_frame;await process_frame
	check(sounds.has("sfx_ui_open"),"map open uses same shortened event")
	await create_timer(.38).timeout
	check(fx.voices.all(func(v):return not is_instance_valid(v) or not v.playing),"map cue finishes without tail")
	check(fx.configuration.sfx_ui_close.files.size()==1,"close variants retained")
	w.item_service.dirty=false;w.queue_free()
	for i in 5:await process_frame
	var after := {}
	for p in DirAccess.get_files_at("user://"):
		if p.ends_with(".json"):after[p]=FileAccess.get_sha256("user://"+p)
	check(before==after,"player saves untouched")
	var failed=checks.filter(func(c):return not c.pass).size()
	FileAccess.open("res://reports/audio-ui-open-v7/window.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks},"  "))
	print("UI OPEN V7: ",checks.size()," checks; ",failed," failures")
	quit(0 if failed==0 else 1)
