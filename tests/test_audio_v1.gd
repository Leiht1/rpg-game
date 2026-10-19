extends SceneTree
var w: Node
var checks: Array=[]
var events: Array=[]
var fx: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func reset_audio() -> void:
	fx.last_played.clear();events.clear()
	for voice in fx.voices:
		if is_instance_valid(voice):voice.stop();voice.queue_free()
	fx.voices.clear()
func add_build(id: String,kind: String,at: Vector2) -> Dictionary:
	var b: RefCounted=w.item_service.builds
	var row: Dictionary=b.candidate(kind,at,false,true,0)
	b.states[id]=row
	return row
func run() -> void:
	fx=root.get_node("AudioFX");fx.muted=true
	fx.sound_played.connect(func(key):events.append(key))
	var files: Array=[]
	for key in fx.configuration:
		for path in fx.configuration[key].files:
			var audio: AudioStream=fx.stream_for(path)
			check(audio!=null and audio.get_length()>0,str(path)+" decodes")
			files.append({"file":path,"seconds":audio.get_length() if audio else 0})
	FileAccess.open("res://reports/audio-v1/assets.json",FileAccess.WRITE).store_string(JSON.stringify(files,"  "))
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.player.set_physics_process(false)
	w.item_ui.set_process(false)
	w.environment_view.simulation.paused=true
	fx.set_process(false)
	check(fx.world==w,"normal world binds audio service")
	for key in fx.configuration:
		if key.begins_with("amb_"):continue
		fx.last_played.clear()
		check(fx.play_sfx(key),key+" starts playback")
		await create_timer(.02).timeout
		for voice in fx.voices:
			if is_instance_valid(voice):voice.stop();voice.queue_free()
		fx.voices.clear()
	check(not fx.play_sfx("missing_sound"),"missing sounds stay silent")
	fx.last_played.clear();events.clear()
	fx.play_sfx("sfx_drop_land",w.player.position);fx.play_sfx("sfx_drop_land",w.player.position)
	check(events.count("sfx_drop_land")==1,"simultaneous drops coalesce")
	check(not fx.play_sfx("sfx_mine_hit",w.player.position+Vector2(800,0)),"distant sound is culled")
	reset_audio()
	var button := Button.new();w.item_ui.add_child(button)
	button.pressed.emit()
	check(events.has("sfx_ui_click"),"actual button press cue")
	button.queue_free()
	fx.last_played.clear();events.clear()
	w.item_ui.toggle_bag();w.item_ui.toggle_bag()
	check(events.count("sfx_ui_close")==1,"keyboard bag closure sounds once")
	fx.last_played.clear();events.clear()
	fx.notice_sound("背包空间不足");fx.notice_sound("获得羊毛 ×2")
	check(events==["sfx_ui_error"],"failure cue excludes success notices")
	fx.last_played.clear();events.clear()
	var inv: ItemInventory=w.item_service.inventory
	inv.add("wood",5)
	var source := -1
	for i in 40:
		if inv.slots[i].get("item_id","")=="wood":source=i;break
	check(source>=0 and inv.move_slot(source,39),"inventory transfer succeeds")
	check(events.has("sfx_item_move"),"successful inventory move sounds")
	events.clear();check(not inv.move_slot(39,39) and events.is_empty(),"no-op inventory move silent")
	reset_audio()
	inv.add("stone_pickaxe",1)
	var tool_index := -1
	for i in 40:
		if inv.slots[i].get("item_id","")=="stone_pickaxe":tool_index=i;break
	check(tool_index>=0 and inv.equip(tool_index),"tool equips")
	check(events.has("sfx_equip"),"equipment cue on success")
	reset_audio()
	inv.add("wild_carrot",2);w.item_service.body.hunger=20.0
	for i in 40:
		if inv.slots[i].get("item_id","")=="wild_carrot":inv.use_slot(i);break
	check(events.has("sfx_eat"),"food consumption sounds")
	reset_audio()
	inv.add("silver_lantern",1)
	var lantern_index := -1
	for i in 40:
		if inv.slots[i].get("item_id","")=="silver_lantern":lantern_index=i;break
	if lantern_index>=0:
		w.item_service.toggle_lantern(lantern_index);w.item_service.toggle_lantern(lantern_index)
	check(events.has("sfx_lantern_on") and events.has("sfx_lantern_off"),"portable lantern on/off sounds")
	var b: RefCounted=w.item_service.builds
	var here: Vector2=w.player.position
	for pair in [["audio_chest","wood_chest","sfx_chest_"],["audio_fridge","refrigerator","sfx_fridge_"]]:
		var row := add_build(pair[0],pair[1],here)
		w.player.position=Vector2(row.x,row.y)+Vector2(0,40)
		reset_audio()
		check(b.set_chest_open(pair[0],true).is_empty() and b.set_chest_open(pair[0],false).is_empty(),str(pair[1])+" opens/closes")
		check(events.has(pair[2]+"open") and events.has(pair[2]+"close"),str(pair[1])+" sound transitions")
		reset_audio();b.set_chest_open(pair[0],false)
		check(events.is_empty(),"already closed storage stays silent")
		reset_audio()
		var old_path: String=w.item_service.save_path
		w.item_service.save_path="res://reports/audio-v1/no-such-directory/fail.json";w.persistent_world=true
		check(not b.set_chest_open(pair[0],true).is_empty() and not row.open,"storage failure rolls back")
		check(not events.has(pair[2]+"open"),"storage rollback excludes open sound")
		w.persistent_world=false;w.item_service.save_path=old_path
		b.states.erase(pair[0])
	w.player.position=here
	reset_audio()
	var lamp := add_build("audio_lamp","copper_lamp",here)
	lamp.machine.enabled=false
	b.install(w.stream.chunk_at(Vector2(lamp.x,lamp.y)))
	w.player.position=Vector2(lamp.x,lamp.y)+Vector2(0,40)
	await frames()
	check(w.item_service.industry.act("audio_lamp","toggle").is_empty(),"copper lamp toggle succeeds")
	check(events.has("sfx_lantern_on"),"copper lamp on cue")
	w.item_service.industry.act("audio_lamp","toggle")
	check(events.has("sfx_lantern_off"),"copper lamp off cue")
	b.visuals["audio_lamp"].queue_free();b.visuals.erase("audio_lamp");b.states.erase("audio_lamp")
	reset_audio()
	for material in ["stone","wood","plant_fiber","flint"]:inv.add(material,80)
	var place_row: Dictionary={}
	for y in range(-3,4):
		for x in range(-3,4):
			var at: Vector2=here+Vector2(x*96,y*64)
			w.player.position=at+Vector2(0,70)
			var candidate: Dictionary=b.candidate("stone_path",at,false,true,0)
			if b.reason(candidate).is_empty():place_row=candidate;break
		if not place_row.is_empty():break
	check(not place_row.is_empty(),"legal build site located")
	if not place_row.is_empty():
		check(b.place(place_row,inv.slots.duplicate(true)).is_empty(),"actual paving placement succeeds")
		check(events.has("sfx_build_stone"),"successful build cue")
		reset_audio()
		check(not b.place(place_row,inv.slots.duplicate(true)).is_empty() and events.is_empty(),"invalid build does not emit success cue")
	w.player.position=here
	reset_audio()
	var gate: Dictionary={}
	for off in [Vector2(192,0),Vector2(-192,0),Vector2(0,128),Vector2(0,-128)]:
		gate=add_build("audio_gate","fence_gate",here+off)
		w.player.position=Vector2(gate.x,gate.y)+Vector2(0,85)
		if not b.gate_blocked("audio_gate"):break
	var gate_reason: String=b.toggle("audio_gate")
	check(gate_reason.is_empty() and events.has("sfx_door_open"),"actual gate opening cue")
	if gate_reason.is_empty():
		gate_reason=b.toggle("audio_gate")
		check(gate_reason.is_empty() and events.has("sfx_door_close"),"actual gate closing cue")
	b.states.erase("audio_gate");w.player.position=here
	reset_audio()
	var drop: Node2D=load("res://scripts/item_drop.gd").new()
	w.object_root.add_child(drop);drop.position=here
	var image := Image.create(4,4,false,Image.FORMAT_RGBA8);image.fill(Color.WHITE)
	drop.setup(ImageTexture.create_from_image(image),4,0);drop.animate_drop()
	await create_timer(.5).timeout
	check(events.count("sfx_drop_land")==1,"drop sounds on first ground contact")
	drop.queue_free()
	var floor_row: Dictionary=w.item_service.builds.candidate("wood_floor",w.player.position,false,true,0)
	w.item_service.builds.states["audio_floor"]=floor_row
	check(fx.surface_at(Vector2(floor_row.x,floor_row.y))=="wood","floor override uses world coordinates")
	floor_row.kind="stone_path"
	check(fx.surface_at(Vector2(floor_row.x,floor_row.y))=="stone","stone paving override")
	w.item_service.builds.states.erase("audio_floor")
	reset_audio()
	w.player.input_blocked=false;w.player.action="";w.player.body.down=false
	fx.last_position=w.player.position;fx.last_gait=w.player.gait_distance
	w.player.position+=Vector2(65,0);w.player.gait_distance+=65
	fx._process(.1)
	check(events.any(func(key):return key.begins_with("sfx_step_")),"actual half-stride movement sounds")
	reset_audio();fx._process(.1)
	check(events.is_empty(),"stationary player has no footsteps")
	reset_audio();w.player.input_blocked=true
	w.player.position+=Vector2(65,0);w.player.gait_distance+=65;fx._process(.1)
	check(events.is_empty(),"blocked controls suppress footsteps")
	w.player.input_blocked=false
	fx.update_rain(2.0,1.0,false)
	check(fx.rain.playing and fx.rain.stream.loop and fx.rain_gain==1.0,"storm rain loops")
	fx.update_rain(.1,1.0,true);check(fx.rain.stream_paused,"weather pause silences loop")
	fx.update_rain(2.0,0.0,false);check(not fx.rain.playing,"dry weather stops rain")
	for voice in fx.voices:
		if is_instance_valid(voice):voice.stop()
	var failures := checks.filter(func(c):return not c.pass).size()
	await frames()
	w.item_service.dirty=false;w.queue_free();await frames()
	check(fx.world==null and not fx.rain.playing,"world exit stops session audio")
	failures=checks.filter(func(c):return not c.pass).size()
	FileAccess.open("res://reports/audio-v1/"+("headless" if DisplayServer.get_name()=="headless" else "window")+".json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failures,"checks":checks},"  "))
	print("AUDIO V1: ",checks.size()," checks; ",failures," failures")
	quit(0 if failures==0 else 1)

