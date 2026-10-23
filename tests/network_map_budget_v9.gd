extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started:await process_frame
	world.player.set_physics_process(false)
	var map=world.map_view;map.set_process(false);map._process(.016)
	assert(not map.wanted.is_empty())
	var key: Vector3i=map.working if map.working.x>=0 else map.wanted[0]
	var passes:=0
	while not map.cache.has(key) and passes<10000:
		map._process(.016);passes+=1
	assert(map.cache.has(key) and passes>1)
	var image: Image=map.cache[key].texture.get_image()
	for cell in [Vector2i(0,0),Vector2i(65,0),Vector2i(0,65),Vector2i(65,65),Vector2i(31,30)]:
		var p: Vector2=(Vector2(key.x,key.y)*map.TILE+Vector2(cell)-Vector2.ONE+Vector2.ONE*.5)/float(key.z)*world.generator.extent
		var expected: Color=preload("res://scripts/map_cartography.gd").color_at(world.generator,p,map.detailed)
		var actual: Color=image.get_pixelv(cell)
		assert(absf(expected.r-actual.r)<.005 and absf(expected.g-actual.g)<.005 and absf(expected.b-actual.b)<.005)
	print("MAP_BUDGET_PASS resumed tile samples unchanged; slices=",passes," max_build_ms=",map.max_build_ms)
	world.queue_free();await process_frame;quit()
