extends SceneTree
var output: String
func _initialize() -> void:
	output=OS.get_cmdline_user_args()[0]
	run.call_deferred()
func run() -> void:
	var world=load("res://scripts/network_game_host_world.gd").new()
	world.bootstrap={"id":"cache-v4-isolated","seed":271828,"map_cells":1536}
	root.add_child(world)
	while not world.started:await process_frame
	var stream=world.stream
	stream.set_process(false)
	for task in stream.tasks.values():WorkerThreadPool.wait_for_task_completion(task)
	stream.tasks.clear();stream.ready_data.clear();stream.rules_packets.clear()
	if "rules_packet_order" in stream:stream.rules_packet_order.clear()
	var rows: Array=[]
	var saved: Dictionary={}
	# Fill, revisit the oldest entry, overflow, then revisit it: FIFO evicts it;
	# LRU retains it. Continue with travel beyond capacity and an eight-chunk hub.
	var path: Array[Vector2i]=[]
	for i in 64:path.append(Vector2i(i%12,i/12))
	path.append(Vector2i.ZERO);path.append(Vector2i(4,5));path.append(Vector2i.ZERO)
	for lap in 2:
		for i in range(96):
			path.append(Vector2i(i%12,i/12))
			if i%4==0:
				for hot in 8:path.append(Vector2i(hot,0))
	for coord in path:
		var hit: bool=stream.rules_packets.has(coord)
		var start:=Time.get_ticks_usec()
		stream._generate(coord)
		var elapsed: float=(Time.get_ticks_usec()-start)/1000.0
		var packet: Dictionary=stream.ready_data.pop_back()
		var content: Dictionary={"props":packet.props,"resources":packet.resource_distribution.accepted,"harvest":packet.resource_distribution.harvest}
		var key:=str(coord)
		if saved.has(key):assert(saved[key]==content,"Evicted chunk regenerated different gameplay data")
		else:saved[key]=content.duplicate(true)
		rows.append({"coord":key,"hit":hit,"ms":elapsed,"size":stream.rules_packets.size()})
		assert(stream.rules_packets.size()<=64)
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"same_regenerated_state":true,"capacity":64}))
	print("CACHE_V4_PASS samples=",rows.size());quit()
