extends SceneTree
const OUT:='res://reports/map-cache-population-v4/'
var checks: Array=[]
var stats: Dictionary={}
var w: Node
var map: Control
func _initialize() -> void:call_deferred('run')
func check(ok: bool,label: String) -> void:
	checks.append({'name':label,'pass':ok});print('CHECK ',ok,' ',label)
	if not ok:push_error(label)
func frames(n: int=3) -> void:
	for i in n:await process_frame
func key(code: int) -> void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=InputEventKey.new();e.physical_keycode=code;e.pressed=false;Input.parse_input_event(e);await process_frame
func warm() -> void:
	await frames(4)
	for i in 2400:
		if map.working.x<0 and map.pending.is_empty():break
		await process_frame
	await frames(3)
func run() -> void:
	Engine.max_fps=60
	var path:=OUT+'runtime-save.json'
	var resume:=OS.get_cmdline_user_args().has('--resume')
	if not resume and FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	Engine.set_meta('map_v3_save',path)
	var fx=root.get_node('AudioFX');fx.muted=true
	w=load('res://tests/world_map_v3_fixture.gd').new();root.add_child(w)
	while not w.started:await process_frame
	w.environment_view.simulation.paused=true;w.player.set_physics_process(false)
	var s: Node=w.item_service;var a: Node=s.animals
	a.set_physics_process(false);a.ensure_population()
	map=w.map_view
	if resume:
		check(s.writable and a.spawning.get('population_revision')==2,'independent restart loads animal upgrade')
		check(a.states.size()==15,'independent restart preserves all extra animals and baby')
		var state: Dictionary=a.serialize();a.ensure_population();await frames()
		check(a.serialize()==state,'restart never repeats animal migration')
		check(s.fishing_population.spots.size()==56,'independent restart preserves upgraded fish')
		check(s.fishing_population.serialize().population_revision==2,'fish upgrade marker retained')
		await finish('resume');return
	check(a.states.size()==12 and a.spawning.sequence==12,'new world starts with 12 animals')
	var counts:={'chicken':0,'sheep':0}
	for r in a.states.values():counts[r.species]+=1
	check(counts.chicken==6 and counts.sheep==6,'six chickens and six sheep')
	check(s.fishing_population.spots.size()==56,'new world has 56 finite schools')
	var ex: RefCounted=s.exploration
	var initial: Dictionary=ex.serialize()
	var start:=Time.get_ticks_usec();await warm()
	stats.hidden_warm_ms=(Time.get_ticks_usec()-start)/1000.
	check(not map.visible and map.hidden_generated_tiles>0 and map.cache.size()>0,'closed map actually preheats terrain')
	check(ex.serialize()==initial,'background prefetch never reveals geography')
	var generated: int=map.generated_tiles
	start=Time.get_ticks_usec();await key(KEY_M)
	stats.warm_first_open_ms=(Time.get_ticks_usec()-start)/1000.
	check(map.visible and not map.view_loading,'first warmed M open has no terrain loading')
	check(map.generated_tiles==generated,'first warmed M samples zero new terrain')
	var frame_times: Array[float]=[]
	for i in 12:
		await key(KEY_M)
		start=Time.get_ticks_usec();await key(KEY_M);frame_times.append((Time.get_ticks_usec()-start)/1000.)
		check(not map.view_loading and map.generated_tiles==generated,'cached reopen without regeneration %d'%i)
	check(map.visible and w.player.input_blocked,'map input blocking retained')
	var old_zoom: Vector2=w.player.camera.zoom
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true;wheel.position=map.map_rect.get_center();Input.parse_input_event(wheel)
	await warm();await key(KEY_M);await warm()
	generated=map.generated_tiles;await key(KEY_M);await frames()
	check(not map.view_loading and map.generated_tiles==generated,'last zoom also preheated and reused')
	check(w.player.camera.zoom==old_zoom,'map scroll never changes world camera')
	await key(KEY_M)
	# Distant map views may be evicted; default local tiles must remain protected.
	for i in 280:
		var begin:=Time.get_ticks_usec()
		if i%35==0:
			if not map.visible:map.open_map()
			map.zoom=[1.,2.,4.,8.,16.][(i/35)%5]
			map.center=Vector2.ONE*w.generator.extent*.5+Vector2(sin(i*.1),cos(i*.1))*15000
		await process_frame;frame_times.append((Time.get_ticks_usec()-begin)/1000.)
	map.close_map();await warm();generated=map.generated_tiles
	map.zoom=8.;await key(KEY_M);await frames()
	check(not map.view_loading and map.generated_tiles==generated,'local default survives panning through distant views')
	check(map.cache.size()<=map.CACHE_LIMIT,'map memory remains bounded')
	frame_times.sort();stats.operation_p95_ms=frame_times[int(frame_times.size()*.95)];stats.operation_max_ms=frame_times[-1]
	stats.generated_tiles=map.generated_tiles;stats.cache_tiles=map.cache.size();stats.max_hidden_build_frame_ms=map.hidden_build_ms
	stats.static_memory_mib=OS.get_static_memory_usage()/1048576.
	map.close_map()
	# Preserve all old animals, including a tamed animal and a young animal.
	var old_script:=GDScript.new();old_script.source_code=FileAccess.get_file_as_string(OUT+'animals.gd.before.txt')
	check(old_script.reload()==OK,'old animal baseline compiles')
	var old=old_script.new();old.service=s
	old.rules=JSON.parse_string(FileAccess.get_file_as_string(OUT+'animals.json.before.txt'));old.ensure_population()
	var legacy: Dictionary=old.serialize()
	var id: String=legacy.objects.keys()[0];legacy.objects[id].tamed=true;legacy.objects[id].trust=int(a.rules.chicken.trust_feeds)
	legacy.serial=1;legacy.objects['born:1']=a.make_row('chicken',Vector2(legacy.objects[id].x+50,legacy.objects[id].y),true,true)
	legacy.spawning.next_at=12345.
	check(a.valid(legacy),'legacy animals with tamed parent and baby accepted')
	a.restore(legacy);a.ensure_population()
	check(a.states.size()==13 and a.spawning.sequence==12,'legacy initial batch adds exactly six once')
	check(legacy.objects.keys().all(func(k):return a.states.has(k) and a.states[k]==legacy.objects[k]),'all old animal identities and full state preserved')
	check(a.spawning.next_at==12345. and a.spawning.population_revision==2,'deadline preserved and migration marked')
	var after: Dictionary=a.serialize();a.ensure_population();a.restore(after);a.ensure_population()
	check(a.serialize()==after,'repeat load and exploration never refill initial batch')
	a.clock=12344.;var n: int=a.states.size();var seq: int=a.spawning.sequence
	a.advance(.5);check(a.states.size()==n,'no periodic batch before deadline')
	a.advance(.5)
	check(a.states.size()==n+2 and a.spawning.sequence==seq+2,'seven-day batch adds exactly two animals')
	check(a.states['wild:global:%d'%(seq+1)].species!=a.states['wild:global:%d'%(seq+2)].species,'periodic batch has one chicken and one sheep')
	check(a.spawning.next_at==22425.,'original seven-day interval unchanged')
	old.free()
	# Real atomic world save, failure protection, and next-process recovery.
	check(s.save_state(),'upgraded animal/fish world snapshot saves')
	var previous:=FileAccess.get_file_as_string(path);var real_path: String=s.save_path
	s.save_path=OUT+'missing/state.json';s.dirty=true
	check(not s.save_state() and FileAccess.get_file_as_string(path)==previous,'failed upgraded save protects previous snapshot')
	s.save_path=real_path
	# Four terrain events now use one sample, gain and natural single player.
	fx.set_process(false);fx.last_played.clear()
	for voice in fx.voices:
		if is_instance_valid(voice):voice.queue_free()
	fx.voices.clear();fx.step_voice=null
	var grass: Dictionary=fx.configuration.sfx_step_grass
	for surface in ['grass','dirt','stone','wood']:
		var entry: Dictionary=fx.configuration['sfx_step_'+surface]
		check(entry==grass,'same grass clip and gain on '+surface)
		fx.last_played.clear()
		check(fx.play_sfx('sfx_step_'+surface,w.player.position),'footstep plays on '+surface)
		var voice: AudioStreamPlayer2D=fx.step_voice
		check(voice.stream.resource_path==grass.files[0] and voice.pitch_scale==1.0,'original grass sample and pitch '+surface)
		check(not fx.play_sfx('sfx_step_wood',w.player.position) and fx.step_voice==voice and fx.voices.filter(func(v):return is_instance_valid(v) and v.playing and v.stream==voice.stream).size()==1,'busy voice skips cross-surface overlap '+surface)
		await create_timer(voice.stream.get_length()+.20).timeout
		for i in 60:
			if not is_instance_valid(fx.step_voice):break
			await process_frame
		await frames(3)
		check(not is_instance_valid(fx.step_voice) and fx.voices.is_empty(),'natural end leaves no queued footsteps '+surface)
	var before_audio: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+'audio.json.before.txt'))
	check(before_audio.keys().all(func(k):return k.begins_with('sfx_step_') or fx.configuration[k]==before_audio[k]),'all non-footstep sounds including V9 close unchanged')
	stats.animals_after_periodic_batch=a.states.size();stats.fish_schools=s.fishing_population.spots.size()
	await finish('window')
func finish(name: String) -> void:
	var failed:=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+name+'.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failed':failed,'stats':stats},'  '));print('V4 ',name,' ',checks.size(),' checks ',failed,' failures')
	w.persistent_world=false;w.item_service.writable=false;w.queue_free();await frames(6);quit(0 if failed==0 else 1)
