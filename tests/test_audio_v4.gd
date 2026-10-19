extends SceneTree
var fx: Node
var w: Node
var checks: Array=[]
var events: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func run() -> void:
	fx=root.get_node("AudioFX");fx.muted=true
	fx.sound_played.connect(func(key):events.append(key))
	var changes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/audio-v4/volume-change.json"))
	for key in changes:check(is_equal_approx(float(fx.configuration[key].volume_db),float(changes[key].before)-4.0),key+" reduced 4dB")
	check(fx.configuration.sfx_step_grass.files==["res://assets/audio/v2/sfx_step_dirt_01.mp3"],"grass keeps requested swapped original")
	check(fx.configuration.sfx_step_dirt.files==["res://assets/audio/v2/sfx_step_grass_01.ogg"],"dirt keeps requested swapped original")
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.player.set_physics_process(false);w.item_ui.set_process(false)
	w.environment_view.simulation.paused=true;fx.set_process(false)
	fx.last_played.clear();events.clear()
	check(fx.play_sfx("sfx_step_grass",w.player.position),"first long step starts")
	var voice: AudioStreamPlayer2D=fx.step_voice
	check(voice.pitch_scale==1.0,"original pitch retained")
	for key in ["sfx_step_grass","sfx_step_dirt","sfx_step_stone"]:
		await create_timer(.21).timeout
		fx.last_played.clear()
		check(not fx.play_sfx(key,w.player.position) and fx.step_voice==voice and voice.playing,"running footfall preserves active voice: "+key)
	check(voice.get_playback_position()>.5,"sample progresses through tail without restarting")
	check(events==["sfx_step_grass"],"no overlapping or queued footsteps")
	await create_timer(.6).timeout
	check(not is_instance_valid(voice) or not voice.playing,"first sample finishes naturally")
	check(events==["sfx_step_grass"],"stopping movement does not replay skipped footfalls")
	check(fx.play_sfx("sfx_step_dirt",w.player.position),"new real footfall starts after old sample finishes")
	await create_timer(.4).timeout
	check(not is_instance_valid(fx.step_voice) or not fx.step_voice.playing,"short sample also finishes naturally")
	check(fx.play_sfx("sfx_step_wood",w.player.position),"wood footfall still plays")
	await create_timer(.4).timeout
	check(fx.play_sfx("sfx_step_stone",w.player.position),"stone footfall still plays")
	for i in 3:await process_frame
	w.item_service.dirty=false;w.queue_free()
	for i in 3:await process_frame
	check(fx.world==null and not is_instance_valid(fx.step_voice),"world exit cleans up")
	var failures := checks.filter(func(c):return not c.pass).size()
	FileAccess.open("res://reports/audio-v4/window.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failures,"checks":checks},"  "))
	print("AUDIO V4: ",checks.size()," checks; ",failures," failures")
	quit(0 if failures==0 else 1)
