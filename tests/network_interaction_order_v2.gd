extends SceneTree
class TestUI extends Control:
	var notices: Array=[]
	func show_notice(message: String) -> void:notices.append(message)
class Channel extends RefCounted:
	var world
	var calls: Array=[]
	var reject:=false
	func exchange(tree: SceneTree,_host: String,_port: int,_tls: TLSOptions,_identity: String,path: String,_headers: PackedStringArray,body: String,_timeout: float) -> Array:
		var data: Dictionary=JSON.parse_string(body)
		calls.append({"path":path,"data":data})
		await tree.create_timer(.08).timeout
		var result: Dictionary={"ok":true}
		if path.ends_with("move"):
			var batch: Array=data.inputs
			result={"ok":true,"character":{"x":0,"y":0},"input_ack":int(batch[-1].id) if not batch.is_empty() else world.player.acknowledged_input_id}
		else:
			assert(world.player.acknowledged_input_id>=int(data.input_boundary))
			var count_before: int=calls.size()
			world.move_server()
			assert(calls.size()==count_before,"post-click movement cannot overtake action")
			result={"ok":not reject,"snapshot":{},"error":"目标已被拾取" if reject else ""}
		return [HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify(result).to_utf8_buffer()]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var network=root.get_node("Network")
	var previous: Dictionary=network.http_channels
	var w=load("res://tests/network_interaction_order_fixture_v2.gd").new();root.add_child(w)
	w.player=load("res://scripts/network_game_player.gd").new()
	w.item_service=load("res://scripts/item_service.gd").new()
	w.item_ui=TestUI.new()
	var channel=Channel.new();channel.world=w
	network.http_channels={"move":channel,"game":channel}
	for rejected in [false,true]:
		channel.reject=rejected;channel.calls.clear()
		w.player.record_input(Vector2.RIGHT,.025,false)
		var boundary: int=w.player.input_id
		w.requesting=true;w.enqueue("interact",[{"drop_id":"ordered-test"}]);w.requesting=false
		w.player.record_input(Vector2.RIGHT,.025,false)
		assert(w.player.input_id>boundary,"click boundary cannot merge with later input")
		w.sync_server()
		while w.requesting:await process_frame
		assert(w.commands.is_empty() and not w.interaction_fence)
		assert(channel.calls.size()==2)
		assert(channel.calls[0].path.ends_with("move") and int(channel.calls[0].data.inputs[-1].id)==boundary)
		assert(channel.calls[1].path.ends_with("game_command"))
		assert(int(w.player.pending_inputs[0].id)>boundary,"later movement retained for replay")
		w.move_server()
		while w.moving_request:await process_frame
		assert(w.player.pending_inputs.is_empty(),"later movement resumes after success or rejection")
	w.requesting=true;w.enqueue("interact",[{"drop_id":"old-region"}]);w.requesting=false
	w.cancel_movement_interactions()
	assert(w.commands.is_empty(),"region reset cancels intents waiting for discarded input IDs")
	network.http_channels=previous
	w.stopping=true
	for row in [w,w.player,w.item_service]:
		for property in row.get_property_list():
			if not int(property.usage)&PROPERTY_USAGE_SCRIPT_VARIABLE:continue
			var value=row.get(property.name)
			if value is Node and is_instance_valid(value) and value!=w and value!=w.player and value!=w.item_service and value.get_parent()==null:value.free()
	w.player.free();w.item_service.free();w.queue_free()
	await process_frame
	print("INTERACTION_ORDER_V2_PASS delayed_move/click_boundary/no_overtake/rejection/resume")
	quit(0)
