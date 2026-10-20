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
func reset() -> void:events.clear();fx.last_played.clear()
func save_hashes() -> Dictionary:
	var hashes := {}
	for p in DirAccess.get_files_at("user://"):
		if p.ends_with(".json"):hashes[p]=FileAccess.get_sha256("user://"+p)
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
	check(fx.configuration.sfx_ui_close.files==["res://assets/audio/v3/runtime/sfx_ui_close_02_3793dd767f.wav"],"only distinct selected close sound remains")
	check(FileAccess.get_sha256(fx.configuration.sfx_ui_close.files[0])!=FileAccess.get_sha256(fx.configuration.sfx_ui_click.files[0]),"close sound differs from click data")
	var marked := 0
	for b in w.find_children("*","Button",true,false):
		if b.get_meta("audio_window_close",false):marked+=1
	check(marked>=8,"actual window close buttons explicitly tagged")
	var detached := Button.new();detached.set_meta("audio_window_close",true);w.item_ui.add_child(detached)
	reset();detached.pressed.emit();await frames(2)
	check(events==["sfx_ui_close"],"close button without visibility callback still emits close, never click")
	var plain := Button.new();w.item_ui.add_child(plain)
	reset();plain.pressed.emit();await frames(2)
	check(events==["sfx_ui_click"],"ordinary button still emits click")
	w.item_ui.toggle_bag();await frames(10)
	var close: Button
	for b in w.item_ui.bag.find_children("*","Button",true,false):
		if b.get_meta("audio_window_close",false):close=b;break
	check(close!=null,"backpack close tagged")
	if close:
		reset()
		var at := close.get_global_rect().get_center()
		var motion := InputEventMouseMotion.new();motion.position=at;motion.global_position=at;Input.parse_input_event(motion)
		await frames(2)
		for pressed in [true,false]:
			var mouse := InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=pressed;mouse.position=at;mouse.global_position=at;Input.parse_input_event(mouse)
			await frames(2)
		await frames(8)
		check(not w.item_ui.bag.visible,"real mouse closes backpack")
		check(events==["sfx_ui_close"],"real close click emits exactly one close sound and zero click sounds")
		check(fx.ui_voice.stream.resource_path==fx.configuration.sfx_ui_close.files[0],"sole UI player uses distinct close file")
	reset();w.map_view.show();await frames(2);reset();w.map_view.hide();await frames(2)
	check(events==["sfx_ui_close"],"map hide emits only close")
	reset();detached.pressed.emit();detached.pressed.emit();await frames(2)
	check(events==["sfx_ui_close"] and fx.voices.is_empty(),"repeat close callbacks never layer click or extra players")
	for k in ["sfx_step_grass","sfx_step_dirt","sfx_step_stone","sfx_step_wood"]:check(fx.configuration[k].enabled,k+" unchanged")
	w.item_service.dirty=false;w.queue_free();await frames(5)
	check(save_hashes()==before,"player saves unchanged")
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open("res://reports/audio-close-only-v9/window.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed,"checks":checks},"  "))
	print("CLOSE ONLY V9: ",checks.size()," checks; ",failed," failures")
	quit(0 if failed==0 else 1)
