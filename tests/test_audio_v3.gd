extends SceneTree
var w: Node
var fx: Node
var checks: Array=[]
var events: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func active_steps() -> int:
	var count := 0
	for voice in fx.voices:
		if is_instance_valid(voice) and voice.playing and voice.get_meta("audio_step",false):count+=1
	return count
func step(key: String) -> Node:
	fx.last_played.clear()
	check(fx.play_sfx(key,w.player.position),key+" starts")
	fx.step_voice.set_meta("audio_step",true)
	return fx.step_voice
func run() -> void:
	fx=root.get_node("AudioFX");fx.muted=true
	fx.sound_played.connect(func(key):events.append(key))
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/v2/provenance.json"))
	for record in provenance.files:
		var path: String="res://assets/audio/v2/"+record.file
		check(FileAccess.get_sha256(path)==record.sha256,"original bytes preserved: "+record.key)
		check(fx.configuration["sfx_step_dirt" if record.key=="sfx_step_grass" else "sfx_step_grass" if record.key=="sfx_step_dirt" else record.key].files==[path],"only supplied single original configured: "+record.key)
		var audio: AudioStream=fx.stream_for(path)
		check(audio!=null and audio.get_length()>0,"replacement decodes: "+record.key)
	check(fx.configuration.sfx_step_grass.files==["res://assets/audio/v2/sfx_step_dirt_01.mp3"],"grass terrain now uses former dirt sample")
	check(fx.configuration.sfx_step_dirt.files==["res://assets/audio/v2/sfx_step_grass_01.ogg"],"dirt terrain now uses former grass sample")
	check(fx.configuration.sfx_step_dirt.volume_db==13.7,"quiet OGG raised to previous reference level")
	check(fx.configuration.sfx_step_grass.volume_db==-2.7,"MP3 balanced to same reference level")
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.player.set_physics_process(false);w.item_ui.set_process(false)
	w.environment_view.simulation.paused=true;fx.set_process(false)
	var previous: Node=step("sfx_step_grass")
	check(previous.pitch_scale==1.0,"grass uses original pitch")
	var current: Node=step("sfx_step_grass")
	check(not previous.playing and current.playing and active_steps()==1,"rapid grass steps never overlap")
	previous=current;current=step("sfx_step_dirt")
	check(not previous.playing and current.playing and active_steps()==1,"grass to dirt never overlaps")
	check(current.pitch_scale==1.0,"dirt uses original pitch")
	for key in ["sfx_step_stone","sfx_step_wood","sfx_step_grass","sfx_step_dirt"]:
		previous=current;current=step(key)
		check(not previous.playing and active_steps()==1,"single channel across "+key)
	fx.last_played.clear();events.clear()
	var button := Button.new();w.item_ui.add_child(button);button.pressed.emit()
	check(events.has("sfx_ui_click"),"new click sample triggered by real button")
	w.item_ui.toggle_bag();w.item_ui.toggle_bag()
	check(events.has("sfx_ui_close"),"new close sample triggered by bag closure")
	for i in 3:await process_frame
	w.item_service.dirty=false;w.queue_free()
	for i in 3:await process_frame
	check(fx.world==null and not is_instance_valid(fx.step_voice),"world exit clears footstep channel")
	var failures := checks.filter(func(c):return not c.pass).size()
	FileAccess.open("res://reports/audio-v3/window.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failures,"checks":checks},"  "))
	print("AUDIO V3: ",checks.size()," checks; ",failures," failures")
	quit(0 if failures==0 else 1)
