extends SceneTree
const OUT:='res://reports/map-cache-population-v4/'
var checks: Array=[]
var stats: Dictionary={}
func _initialize() -> void:call_deferred('run')
func check(ok: bool,label: String) -> void:
	checks.append({'pass':ok,'name':label})
	if not ok:push_error(label)
func warm(map: Control) -> void:
	for i in 5:await process_frame
	for i in 2400:
		if map.working.x<0 and map.pending.is_empty():break
		var start:=Time.get_ticks_usec();await process_frame
		if not stats.has('frames'):stats.frames=[]
		stats.frames.append((Time.get_ticks_usec()-start)/1000.)
func run() -> void:
	Engine.max_fps=60;root.get_node('AudioFX').muted=true
	var path:=OUT+'movement-save.json'
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	Engine.set_meta('map_v3_save',path)
	var w=load('res://tests/world_map_v3_fixture.gd').new();root.add_child(w)
	while not w.started:await process_frame
	w.player.set_physics_process(false);w.environment_view.simulation.paused=true
	var map: Control=w.map_view;await warm(map)
	var before: Array=map.cache.keys();var generated: int=map.generated_tiles
	var original: Vector2=w.player.position
	var destination:=Vector2.ZERO
	for i in 1000:
		var p: Vector2=Vector2(w.generator.random_at(i,0,3209),w.generator.random_at(i,1,3209))*w.generator.extent
		if p.distance_to(original)<10000 or w.generator.coast_distance(p)<1000 or not w.generator.can_walk(p,24):continue
		if w.item_service.ground_clear(p,20,w.item_service.nearby_props(p)):destination=p;break
	check(destination!=Vector2.ZERO,'found legal distant player position for cache test')
	w.player.position=destination
	await warm(map)
	check(not map.visible and map.generated_tiles>generated,'real player position updates preheat only new local tiles')
	check(before.all(func(k):return map.cache.has(k)),'new explored region retains cached old terrain')
	check(w.item_service.exploration.explored(original) and w.item_service.exploration.explored(destination),'actual player positions reveal independent permanent regions')
	generated=map.generated_tiles;map.open_map()
	check(map.mask!=null and map.mask_revision==w.item_service.exploration.revision,'fog mask synchronised before first visible callback')
	check(map.fog_material.get_shader_parameter('world_low')==map.center-Vector2.ONE*w.generator.extent/map.zoom*.5,'fog view matches newly opened terrain before rendering')
	for i in 5:await process_frame
	check(not map.view_loading and map.generated_tiles==generated,'new local map opens from background cache')
	map.close_map();w.player.position=original;await warm(map)
	generated=map.generated_tiles;map.open_map()
	for i in 5:await process_frame
	check(not map.view_loading and map.generated_tiles==generated,'returning to earlier explored location reuses its terrain')
	check(map.cache.size()<=map.CACHE_LIMIT,'incremental preheating stays within memory bound')
	var values: Array=stats.get('frames',[]);values.sort();stats.erase('frames')
	stats.background_frames=values.size();stats.background_p95_ms=values[int(values.size()*.95)] if not values.is_empty() else 0
	stats.background_max_ms=values[-1] if not values.is_empty() else 0
	stats.hidden_max_build_ms=map.hidden_build_ms;stats.cache_tiles=map.cache.size();stats.new_tiles=map.generated_tiles-before.size()
	var failed:=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+'movement.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failed':failed,'stats':stats},'  '));print('V4 INCREMENTAL ',checks.size(),' checks ',failed,' failures')
	w.persistent_world=false;w.item_service.writable=false;w.queue_free()
	for i in 6:await process_frame
	quit(0 if failed==0 else 1)
