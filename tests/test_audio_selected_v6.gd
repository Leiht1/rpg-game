extends SceneTree
var fx: Node
var w: Node
var checks: Array=[]
var events: Array=[]
const OUT="res://reports/audio-selected-v6/"
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func reset() -> void:
	fx.last_played.clear();events.clear()
	for v in fx.voices:
		if is_instance_valid(v):v.stop();v.queue_free()
	fx.voices.clear();fx.step_voice=null
func user_files() -> Dictionary:
	var result := {}
	for path in DirAccess.get_files_at("user://"):
		if path.ends_with(".json"):result[path]=FileAccess.get_sha256("user://"+path)
	return result
func equip(id: String) -> bool:
	var inv: ItemInventory=w.item_service.inventory
	inv.add(id,1)
	for i in 40:
		if inv.slots[i].get("item_id","")==id:return inv.equip(i)
	return false
func run() -> void:
	Engine.max_fps=60
	var saves_before := user_files()
	fx=root.get_node("AudioFX");fx.muted=false;fx.set_process(false)
	AudioServer.set_bus_mute(0,true)
	fx.sound_played.connect(func(key):events.append(key))
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.player.set_physics_process(false);w.item_ui.set_process(false);w.environment_view.simulation.paused=true
	check(not w.persistent_world,"isolated fixture never saves player world")
	for key in fx.configuration:
		for path in fx.configuration[key].files:
			var stream: AudioStream=fx.stream_for(path)
			check(stream!=null and stream.get_length()>0,key+" decodes "+str(path))
		if key.begins_with("amb_"):continue
		reset()
		check(fx.play_sfx(key,w.player.position),key+" actual player starts")
		var voice: Node=fx.voices.back()
		var path: String=voice.stream.resource_path
		var expected: float=float(fx.configuration[key].volume_db)+float(fx.configuration[key].file_gain_db.get(path,0.0))
		check(is_equal_approx(voice.volume_db,expected),key+" applies calibrated gain including variant offset")
	for key in ["sfx_step_grass","sfx_step_dirt","sfx_step_stone","sfx_step_wood"]:
		reset();check(fx.configuration[key].enabled,key+" explicitly re-enabled")
		check(fx.play_sfx(key,w.player.position),key+" footstep starts")
		var voice: AudioStreamPlayer2D=fx.step_voice
		check(voice.pitch_scale==1.0,key+" original pitch")
		fx.last_played.clear()
		check(not fx.play_sfx("sfx_step_wood",w.player.position) and fx.step_voice==voice,key+" busy voice skips next footfall")
		await create_timer(voice.stream.get_length()+.08).timeout
		check(not is_instance_valid(voice) or not voice.playing,key+" naturally finishes")
		check(events==[key],key+" no queued replay")
	reset()
	w.item_ui.toggle_bag();w.item_ui.toggle_bag()
	check(events.has("sfx_ui_open") and events.has("sfx_ui_close"),"real keyboard bag open and close")
	reset()
	var drop: Node2D=w.stream.create_item_drop({"id":"audio-v6-pickup","item_id":"wood","count":1,"x":w.player.position.x,"y":w.player.position.y,"mode":"pickup"})
	check(w.item_service.pickup(drop) and events.has("sfx_pickup"),"successful actual ground pickup sounds")
	reset()
	var blocked: Node2D=w.stream.create_item_drop({"id":"audio-v6-blocked","item_id":"wood","count":1,"x":w.player.position.x,"y":w.player.position.y,"mode":"pickup"})
	w.item_service.writable=false
	check(not w.item_service.pickup(blocked) and events.is_empty(),"protected pickup has no success cue")
	w.item_service.writable=true
	reset()
	check(equip("stone_axe"),"axe equips for real tree hit")
	reset()
	var tree: Node2D=get_nodes_in_group("trees")[0]
	var home: Vector2=w.player.position
	w.player.position=tree.position+Vector2(0,35)
	w.stream.tree_hits[str(tree.get_meta("prop_id"))]=tree.required_hits-1
	w.stream.chop_tree(tree)
	check(events.has("sfx_chop_hit") and events.has("sfx_tree_fall"),"actual final tree hit and felling sound")
	w.player.position=home
	check(equip("stone_pickaxe"),"pickaxe equips")
	reset()
	var ore: Node2D=w.item_service.create_harvest("audio-v6-ore",{"kind":"stone_outcrop","x":home.x+35,"y":home.y})
	w.item_service.resource_hits["audio-v6-ore"]=int(ore.definition.hits)-1
	check(w.item_service.harvest_hit(ore,"mine") and events.has("sfx_ore_break"),"actual ore depletion emits break sound")
	reset()
	w.environment_view.lightning_wait=0;w.environment_view.lightning_age=-1
	w.environment_view.update_lightning(.1,1.0);w.environment_view.update_lightning(.2,1.0)
	check(events.count("sfx_thunder")==1,"double lightning flash produces exactly one thunder")
	fx.update_rain(2.1,0.0,false,1.0)
	check(fx.light_rain.playing and not fx.rain.playing,"light rain uses its own selected loop")
	check(fx.light_rain.stream is AudioStreamWAV and fx.light_rain.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"selected light WAV loops correctly")
	fx.update_rain(2.1,1.0,false,0.0)
	check(fx.rain.playing and not fx.light_rain.playing,"storm transitions to selected storm loop")
	fx.update_rain(.1,1.0,true,0.0)
	check(fx.rain.stream_paused and not fx.light_rain.playing,"weather pause freezes active storm and leaves inactive light rain stopped")
	fx.update_rain(2.1,0.0,false,0.0)
	check(not fx.rain.playing and not fx.light_rain.playing,"clear weather fades both loops to silence")
	reset()
	var fish=w.get_node_or_null("Fishing")
	if fish!=null:
		fish.selected=0;fish.transition("cast");fish.transition("bite")
		check(events.has("sfx_fishing_cast") and events.has("sfx_fishing_bite"),"fishing state transitions sound")
		fish.finish("")
	else:check(false,"fishing node found")
	reset()
	var m=w.item_service.merchant
	w.player.position=m.actor.position+Vector2(0,45);m.interacting=true
	var product: String=m.state.offers.keys()[0]
	for material in m.price(product):w.item_service.inventory.add(material,int(m.price(product)[material]))
	var reason: String=m.buy(product)
	check(reason.is_empty() and events.has("sfx_merchant_trade"),"actual committed merchant trade cue: "+reason)
	reset();m.buy(product)
	check(not events.has("sfx_merchant_trade"),"sold-out trade has no success cue")
	w.player.position=home
	reset()
	var camps=w.item_service.camps
	var camp_visual := Node2D.new();camp_visual.position=home;w.add_child(camp_visual)
	camps.states["audio-v6-fire"]={"x":home.x,"y":home.y,"fuel":0.0,"lit":false,"recipe":"","elapsed":0.0,"ready":false}
	camps.visuals["audio-v6-fire"]=camp_visual
	w.item_service.inventory.add("wood",10)
	var wood_slot := -1
	for i in 40:
		if w.item_service.inventory.slots[i].get("item_id","")=="wood":wood_slot=i;break
	var slots_before: Array=w.item_service.inventory.slots.duplicate(true)
	var save_path: String=w.item_service.save_path
	w.persistent_world=true;w.item_service.save_path=OUT+"does-not-exist/items.json"
	var fire_reason: String=camps.feed("audio-v6-fire",wood_slot,w.item_service.inventory.slots[wood_slot].duplicate(true),1)
	check(not fire_reason.is_empty() and not camps.states["audio-v6-fire"].lit and w.item_service.inventory.slots==slots_before,"fire save failure restores fuel and source stack")
	check(not events.has("sfx_fire_ignite"),"failed ignition has no success sound")
	w.persistent_world=false;w.item_service.save_path=save_path
	reset()
	fire_reason=camps.feed("audio-v6-fire",wood_slot,w.item_service.inventory.slots[wood_slot].duplicate(true),1)
	check(fire_reason.is_empty() and events.has("sfx_fire_ignite"),"successful new campfire ignition cue")
	reset();camps.feed("audio-v6-fire",wood_slot,w.item_service.inventory.slots[wood_slot].duplicate(true),1)
	check(not events.has("sfx_fire_ignite"),"adding fuel to burning campfire does not replay ignition")
	camps.states.erase("audio-v6-fire");camps.visuals.erase("audio-v6-fire");camps.burning.erase("audio-v6-fire");camp_visual.queue_free()
	check(equip("stone_hammer"),"stone hammer equips for demolition")
	var builds=w.item_service.builds
	var paving: Dictionary=builds.candidate("stone_path",home,false,true,0)
	builds.states["audio-v6-demolish"]=paving;builds.install(w.stream.chunk_at(Vector2(paving.x,paving.y)))
	var target: Node2D=builds.visuals["audio-v6-demolish"]
	w.player.position=target.position+Vector2(0,40)
	reset();w.persistent_world=true;w.item_service.save_path=OUT+"does-not-exist/items.json"
	check(not builds.strike("audio-v6-demolish",target) and not events.has("sfx_demolish_hit"),"demolition save failure stays silent")
	w.persistent_world=false;w.item_service.save_path=save_path;reset()
	check(builds.strike("audio-v6-demolish",target) and events.has("sfx_demolish_hit"),"actual committed demolition strike cue")
	builds.states.erase("audio-v6-demolish");builds.visuals.erase("audio-v6-demolish");target.queue_free();w.player.position=home
	var floor_row: Dictionary=builds.candidate("wood_floor",home,false,true,0)
	builds.states["audio-v6-surface"]=floor_row
	check(fx.surface_at(Vector2(floor_row.x,floor_row.y))=="wood","wood paving selects wood footstep")
	floor_row.kind="stone_path"
	check(fx.surface_at(Vector2(floor_row.x,floor_row.y))=="stone","stone paving selects stone footstep")
	builds.states.erase("audio-v6-surface")
	reset();w.player.input_blocked=false;w.player.action="";w.player.body.down=false
	fx.last_position=w.player.position;fx.last_gait=w.player.gait_distance
	w.player.position+=Vector2(65,0);w.player.gait_distance+=65;fx._process(.1)
	check(events.any(func(key):return key.begins_with("sfx_step_")),"actual half-stride movement triggers enabled footsteps")
	reset();fx._process(.1)
	check(not events.any(func(key):return key.begins_with("sfx_step_")),"stationary player stays silent")
	reset();w.player.input_blocked=true
	w.player.position+=Vector2(65,0);w.player.gait_distance+=65;fx._process(.1)
	check(not events.any(func(key):return key.begins_with("sfx_step_")),"blocked movement has no footstep")
	w.player.input_blocked=false;w.player.position=home
	reset()
	var animals=w.item_service.animals
	animals.states["audio-v6-chicken"]=animals.make_row("chicken",home+Vector2(0,50),true)
	var chicken=load("res://scripts/animal_actor.gd").new();chicken.manager=animals;chicken.animal_id="audio-v6-chicken";chicken.position=home+Vector2(0,50);w.object_root.add_child(chicken);chicken.set_physics_process(false)
	var movement_rng=chicken.rng.state
	w.environment_view.simulation.paused=false;fx.animal_wait=0.0;fx._process(.01)
	check(events.has("sfx_chicken_idle"),"nearby actual chicken emits occasional selected call")
	check(chicken.rng.state==movement_rng,"audio never consumes animal movement RNG")
	w.environment_view.simulation.paused=true;reset();fx.animal_wait=0.0;fx._process(.01)
	check(not events.has("sfx_chicken_idle"),"paused simulation has no animal chatter")
	animals.states.erase("audio-v6-chicken");chicken.queue_free()
	reset();w.item_service.dirty=false;w.queue_free();await frames(5)
	check(fx.world==null and not fx.rain.playing and not fx.light_rain.playing,"world exit clears both loops and voices")
	check(user_files()==saves_before,"player JSON saves untouched")
	var failures := checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"window.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failures,"checks":checks},"  "))
	print("AUDIO SELECTED V6: ",checks.size()," checks; ",failures," failures")
	quit(0 if failures==0 else 1)
