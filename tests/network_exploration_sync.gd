extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	var server=load("res://scripts/world_exploration.gd").new()
	var client=load("res://scripts/world_exploration.gd").new()
	server.configure("isolated-exploration",1536*48.0);client.configure("isolated-exploration",1536*48.0)
	server.reveal(Vector2(12000,12000),true)
	assert(client.restore(server.serialize()))
	for i in 6:
		server.reveal(Vector2(12000+i*120,12000),true)
		var value:Dictionary=server.serialize()
		var clock:=Time.get_ticks_usec()
		assert(client.restore(value))
		print("EXPLORATION_RESTORE_MS ",(Time.get_ticks_usec()-clock)/1000.0)
		assert(client.bits==server.bits)
		assert(client.mask_cache.get_data()==server.mask_cache.get_data())
		await process_frame
	var image:Image=client.mask_cache
	server.configure("isolated-exploration",1536*48.0)
	assert(client.restore(server.serialize()))
	assert(client.mask_cache==image and client.mask_cache.get_data()==server.mask_cache.get_data())
	var invalid:Dictionary=server.serialize();invalid.sha256="invalid"
	var revision:int=client.revision
	assert(not client.restore(invalid) and client.revision==revision)
	server.configure("edge",13*96.0);client.configure("edge",13*96.0)
	server.reveal(Vector2(1200,1200),true)
	assert(client.restore(server.serialize()) and client.mask_cache.get_data()==server.mask_cache.get_data())
	print("EXPLORATION_SYNC_PASS addition, clearing, image identity, checksum, partial byte")
	quit()
