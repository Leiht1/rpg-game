extends SceneTree
var checks: Array=[]
func _initialize() -> void:call_deferred('run')
func check(ok: bool,name: String) -> void:
	checks.append({'pass':ok,'name':name})
	if not ok:push_error(name)
func settle(n: int=4) -> void:
	for i in n:await process_frame
func ready_map(map: Control) -> void:
	await settle()
	for i in 1000:
		if map.working.x<0 and map.pending.is_empty():break
		await process_frame
	await settle()
func gold(image: Image,at: Vector2) -> int:
	var found:=0
	for y in range(int(at.y)-17,int(at.y)-7):
		for x in range(int(at.x)-7,int(at.x)+7):
			var c:=image.get_pixel(x,y)
			if absf(c.r-.937)<.01 and absf(c.g-.8)<.01 and absf(c.b-.529)<.01:found+=1
	return found
func run() -> void:
	Engine.max_fps=60
	var path:='res://reports/world-map-v3/marker-save.json'
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	Engine.set_meta('map_v3_save',path)
	var fx=root.get_node('AudioFX');fx.muted=true
	var events: Array=[];fx.sound_played.connect(func(event):events.append(event))
	var w=load('res://tests/world_map_v3_fixture.gd').new();root.add_child(w)
	while not w.started:await process_frame
	w.environment_view.simulation.paused=true;w.player.set_physics_process(false)
	w.persistent_world=false
	var map: Control=w.map_view
	events.clear();fx.last_played.clear();map.open_map();await ready_map(map)
	check(events.count('sfx_ui_open')==1,'M opening single audio cue retained')
	events.clear();fx.last_played.clear()
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.position=map.recenter.get_global_rect().get_center();Input.parse_input_event(click);await settle()
	check(events==['sfx_ui_click'],'recenter uses shared single UI feedback')
	var ex: RefCounted=w.item_service.exploration
	var known: Vector2=w.player.position+Vector2(384,0)
	var unknown: Vector2=map.center+Vector2(3000,0)
	var builds: RefCounted=w.item_service.builds
	var sign: Dictionary=builds.candidate('signpost',known,false,false,0);sign.text='营地'
	builds.states['marker-test-known']=sign
	var hidden: Dictionary=builds.candidate('signpost',unknown,false,false,0);hidden.text='远方'
	builds.states['marker-test-unknown']=hidden
	await settle();await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	check(gold(image,map.world_to_screen(known))>10,'known sign actual GPU marker visible')
	check(gold(image,map.world_to_screen(unknown))==0,'unknown sign and label suppressed')
	ex.reveal(unknown);await ready_map(map);await RenderingServer.frame_post_draw
	image=root.get_texture().get_image()
	check(gold(image,map.world_to_screen(unknown))>10,'discovered sign appears at true world coordinate')
	builds.states.erase('marker-test-known');builds.states.erase('marker-test-unknown')
	await settle();await RenderingServer.frame_post_draw
	image=root.get_texture().get_image()
	check(gold(image,map.world_to_screen(known))==0,'removed sign disappears without second registry')
	var zoom: Vector2=w.player.camera.zoom
	map.zoom=1;map.center=Vector2.ONE*w.generator.extent*.5;map.clamp_center()
	check(map.screen_to_world(map.map_rect.position).distance_to(Vector2.ZERO)<.1 and map.screen_to_world(map.map_rect.end).distance_to(Vector2.ONE*w.generator.extent)<.1,'overview covers exact saved world bounds')
	var e:=InputEventKey.new();e.physical_keycode=KEY_ESCAPE;e.pressed=true;Input.parse_input_event(e);await settle()
	check(not map.visible and not w.player.input_blocked,'Escape closes map and restores input')
	check(w.player.camera.zoom==zoom,'map operations preserve real camera')
	# Monotonic offline union also marks the original atomic store dirty.
	var other=preload('res://scripts/world_exploration.gd').new();other.configure(ex.world_id,ex.extent);other.reveal(Vector2(60000,60000))
	w.item_service.saved_exploration_revision=ex.revision;w.item_service.dirty=false
	ex.merge_local(other.serialize());await settle()
	check(w.item_service.dirty,'shared union participates in normal save scheduling')
	var failed:=checks.filter(func(c):return not c.pass).size()
	FileAccess.open('res://reports/world-map-v3/markers.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failed':failed},'  '));print('MARKERS ',checks.size(),' checks ',failed,' failures')
	w.item_service.writable=false;w.queue_free();await settle(6);quit(0 if failed==0 else 1)
