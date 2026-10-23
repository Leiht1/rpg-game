extends Node
## Private, persistent Godot rules host. Only the authenticated Python service
## owns this loopback channel; no client-provided method names are executed.
var folder: String
var world: Node
var busy := false
var startup := true
var channel := StreamPeerTCP.new()
var incoming := PackedByteArray()
var packet_size := 0
func _ready() -> void:
	Engine.max_fps=240
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1:get_tree().quit(2);return
	folder=args[0]
	call_deferred("boot")
func boot() -> void:
	var config=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("bootstrap.json")))
	channel.connect_to_host("127.0.0.1",int(config.ipc_port))
	while channel.get_status()==StreamPeerTCP.STATUS_CONNECTING:
		channel.poll()
		await get_tree().process_frame
	if channel.get_status()!=StreamPeerTCP.STATUS_CONNECTED:get_tree().quit(2);return
	channel.set_no_delay(true)
	world=preload("res://scripts/network_game_host_world.gd").new()
	world.bootstrap=config
	get_tree().root.add_child(world)
	get_tree().current_scene=world
	while not world.started:await get_tree().process_frame
	world.set_process(false)
	world.set_process_unhandled_input(false)
	world.player.set_physics_process(false)
	world.environment_view.set_process(false)
	world.item_service.set_process(false)
	world.item_service.animals.set_physics_process(false)
	world.item_service.combat_view.set_process(false)
	world.stream.set_process(true)
	# Headless authority has no pointer, HUD or map to refresh each frame.
	for node in world.find_children("*","",true,false):
		if node is Control or node is CanvasLayer:
			node.set_process(false);node.set_process_input(false);node.set_process_unhandled_input(false)
	freeze_actors()
	for child in world.get_children():
		if child.name=="Fishing":child.set_process(false);child.set_process_input(false)
	write_result({"ok":true,"ready":true,"ipc_nonce":config.ipc_nonce})
	Engine.set_meta("network_rules_events",[])
	world.item_service.notice.connect(func(message: String):
		var events: Array=Engine.get_meta("network_rules_events")
		if events.size()<48:events.append({"kind":"notice","text":message}))
	world.item_service.item_obtained.connect(func(id: String, count: int):
		var events: Array=Engine.get_meta("network_rules_events")
		if events.size()<48:events.append({"kind":"obtained","id":id,"count":count}))
	startup=false
func _process(_delta: float) -> void:
	if startup or busy:return
	channel.poll()
	if channel.get_status()!=StreamPeerTCP.STATUS_CONNECTED:get_tree().quit(2);return
	var available:=channel.get_available_bytes()
	if available>0:
		var received:=channel.get_data(available)
		if received[0]!=OK:get_tree().quit(2);return
		incoming.append_array(received[1])
	if packet_size==0:
		if incoming.size()<4:return
		packet_size=incoming.decode_u32(0)
		incoming=incoming.slice(4)
		if packet_size<=0 or packet_size>8*1024*1024:get_tree().quit(2);return
	if incoming.size()<packet_size:return
	var text:=incoming.slice(0,packet_size).get_string_from_utf8()
	incoming=incoming.slice(packet_size);packet_size=0
	var parser:=JSON.new()
	busy=true
	if parser.parse(text)!=OK or not parser.data is Dictionary:
		write_result({"ok":false,"error":"服务端请求格式错误，原档已保留"});busy=false;return
	execute(parser.data)
func write_result(value: Dictionary) -> void:
	var body:=JSON.stringify(value).to_utf8_buffer()
	var header:=PackedByteArray();header.resize(4);header.encode_u32(0,body.size())
	if channel.put_data(header+body)!=OK:get_tree().quit(2)
func execute(request: Dictionary) -> void:
	var timing: Array=[Time.get_ticks_usec()]
	Engine.set_meta("network_rules_events",[])
	var service=world.item_service
	if request.get("operation")=="movement":
		movement(request);busy=false;return
	world.set_meta("network_player_id",str(request.get("player_id","")))
	var state: Dictionary=request.get("snapshot",{})
	# JSON numbers arrive as floats; inventory validation normalizes counts to
	# integers. Compare normalized values so identical facilities stay identical.
	var geometry_changed: bool=integral_arguments(service.builds.states)!=integral_arguments(state.get("buildings",{}).get("objects",{})) or integral_arguments(service.camps.states)!=integral_arguments(state.get("campfires",{}).get("objects",{}))
	if not state.is_empty():
		if service.consumed!=state.get("consumed",{}) or world.stream.harvested!=state.get("harvested",{}):
			for coord in world.stream.loaded.keys():world.stream.unload_chunk(coord)
		service.writable=true
		service.load_state("",false,state)
		if not service.writable:
			write_result({"ok":false,"error":"服务端玩法存档校验失败，原档已保留"});busy=false;return
	service.craft_job=state.get("network_craft_job",{}).duplicate(true)
	if not service.craft_job.is_empty():service.craft_job_serial=maxi(service.craft_job_serial,int(service.craft_job.get("serial",0)))
	service.craft_station_id=str(state.get("network_craft_station",""))
	service.restore_network_lamp(state)
	if not bool(request.get("shared",true)) and state.has("network_light_clock") and not service.merchant.state.is_empty():service.merchant.state.last_time=float(state.network_light_clock)
	var character: Dictionary=request.get("character",{})
	if not character.is_empty():
		service.inventory.restore(character.slots)
		service.inventory.restore_equipment(character.equipment)
		service.inventory.restore_hotbar_links(character.get("hotbar_equipment",{}))
		service.inventory.selected=clampi(int(character.get("selected",0)),0,7)
		world.player.position=Vector2(character.x,character.y)
		world.player.character_look=character.appearance
		service.inventory.changed.emit()
	world.stream.update_target(world.player.position)
	var personal: Dictionary=state.get("combat_personal",{})
	var needs_scene: bool=request.get("operation","snapshot")!="snapshot" or personal.get("phase","alive")!="alive" or not personal.get("attack",{}).is_empty() or state.get("network_fishing",{}).get("state","idle")!="idle"
	timing.append(Time.get_ticks_usec())
	# Restore may replace a facility at the same ID. Let deferred deletion and
	# physics registration finish before a ray can hit the superseded collider.
	if needs_scene and (geometry_changed or request.get("operation","snapshot")!="snapshot"):
		await get_tree().process_frame
		await get_tree().physics_frame
	if needs_scene:
		for frame in 300:
			if world.stream.viewport_ready(world.player.position,Vector2(640,360)):break
			await get_tree().process_frame
	service.animals.sync_visuals()
	timing.append(Time.get_ticks_usec())
	freeze_actors()
	world.player.input_blocked=service.body.sleep_active()
	world.player.set_physics_process(false)
	world.player.moving=bool(character.get("moving",false));world.player.running=bool(character.get("running",false))
	var fishing=world.get_node("Fishing")
	fishing.network_restore(state.get("network_fishing",{}))
	var requested_station=request.get("station")
	if requested_station is String and (requested_station.is_empty() or service.workbench_valid(requested_station)):service.craft_station_id=requested_station
	var elapsed:=clampf(float(request.get("elapsed",0)),0,5)
	service.combat.peers=request.get("combat_peers",[])
	service.combat.damage_events=[]
	for incoming in request.get("combat_damage",[]):
		service.combat.damage(float(incoming.amount),point(incoming.source),bool(incoming.duel))
	if elapsed>0:
		if service.body.energy<=0 and not service.body.sleep_active():world.environment_view.try_start_sleep(true)
		world.environment_view.advance_gameplay(elapsed,bool(request.get("shared",true)))
		service.combat.advance(elapsed,bool(request.get("shared",true)))
		service.advance_craft(elapsed)
		fishing.advance(elapsed)
		world.player.set_physics_process(false)
		if bool(request.get("shared",true)):service.animals.ensure_population()
		for actor in service.animals.visuals.values():
			var row: Dictionary=actor.row()
			var owner_id:=str(row.get("network_owner",""))
			if (not owner_id.is_empty() and owner_id==str(request.get("player_id",""))) or (owner_id.is_empty() and bool(request.get("shared",true))):
				var remaining:=elapsed
				while remaining>0.00001:
					actor._physics_process(minf(.05,remaining));remaining-=minf(.05,remaining)
	var message := ""
	timing.append(Time.get_ticks_usec())
	var operation:=str(request.get("operation","snapshot"))
	var args: Array=integral_arguments(request.get("args",[]))
	if service.combat.personal.phase!="alive" and operation!="snapshot":
		write_result({"ok":false,"error":"正在返回传送门，请稍候","snapshot":service.snapshot()});busy=false;return
	for index in request.get("expected",{}):
		if not preload("res://scripts/food_freshness.gd").matches(service.inventory.get_slot(int(index)),request.expected[index]):
			write_result({"ok":false,"error":"背包已变化，请重新操作","snapshot":service.snapshot()});busy=false;return
	# Explicit allowlist. Placement rows are rebuilt from kind and geometry below.
	match operation:
		"guide":
			if not service.advance_guide(int(args[0])):message="指引进度无效"
		"combat_duel":message=service.combat.duel(str(args[0]),bool(args[1]))
		"combat_attack":message=service.combat.attack(point(args[0]))
		"relic_claim":message=service.combat.claim(str(args[0]),int(args[1]),args[2])
		"snapshot":pass
		"organize":message=service.organize_bag()
		"craft":message=service.start_craft(str(args[0]),int(args[1]))
		"craft_cancel":service.cancel_craft()
		"station":
			var station:=str(args[0])
			if station.is_empty() or service.workbench_valid(station):service.craft_station_id=station
			else:message="请靠近工作台"
		"discard":
			if not service.discard(int(args[0]),int(args[1])):message="丢弃失败"
		"inventory":
			var methods:={"equip":1,"unequip":1,"move_slot":2,"split_slot":2,"destroy_slot":1,"use_slot":1,"equip_hotbar":2}
			var method:=str(args.pop_front())
			if not methods.has(method) or args.size()!=methods[method]:message="无效物品操作"
			else:
				var result=service.inventory.callv(method,args)
				if (result is bool and not result) or (result is int and result<0):message="物品操作失败"
		"camp_act":message=service.camps.act(str(args[0]),str(args[1]),str(args[2]),args[3])
		"camp_feed":message=service.camps.feed(str(args[0]),int(args[1]),args[2],int(args[3]))
		"camp_place":message=service.camps.place(point(args[0]),int(args[1]),args[2])
		"camp_build":message=service.camps.build(point(args[0]),str(args[1]),args[2])
		"building_place":
			var row: Dictionary=args[0]
			if not service.builds.definitions.has(str(row.get("kind",""))):message="未知建筑"
			else:
				var candidate=service.builds.candidate(str(row.kind),point(row),bool(row.get("vertical",false)),bool(row.get("inward",false)),int(row.get("facing",0)))
				if row.kind=="signpost":candidate.text=str(row.get("text",""))
				message=service.builds.place(candidate,args[1])
		"building_bag":
			var row: Dictionary=args[0]
			var candidate=service.builds.candidate("sleeping_bag",point(row),false,false,0)
			message=service.builds.place_bag(candidate,int(args[1]),args[2])
		"building_toggle":message=service.builds.toggle(str(args[0]))
		"building_open":message=service.builds.set_chest_open(str(args[0]),bool(args[1]))
		"building_transfer":message=service.builds.transfer(str(args[0]),int(args[1]),int(args[2]),args[3],args[4])
		"building_edit":message=service.builds.chest_edit(str(args[0]),int(args[1]),args[2],str(args[3]),int(args[4]),int(args[5]))
		"industry":message=service.industry.act(str(args[0]),str(args[1]),int(args[2]),str(args[3]),int(args[4]),args[5])
		"expansion":message=service.expansion.act(str(args[0]),str(args[1]),int(args[2]),args[3],str(args[4]),int(args[5]))
		"animal_feed":message=service.animals.feed(str(args[0]),int(args[1]),args[2])
		"plant":
			var target=find_target({"building_id":str(args[0])})
			if target==null or not service.planting.interact(str(args[0]),target,str(args[1])):message="当前无法播种或收获"
		"fertilize":
			var target=find_target({"building_id":str(args[0])})
			if target==null or not service.planting.fertilize(str(args[0]),target):message="当前无法施肥"
		"buy":
			service.merchant.sync_actor();service.merchant.interacting=true
			message=service.merchant.buy(str(args[0]));service.merchant.interacting=false
		"sleep":message=service.sleep.start(str(args[0]),str(args[1]),false)
		"wake":service.sleep.interrupt()
		"lamp":service.toggle_lantern(int(args[0]))
		"fish_start":
			if not fishing.try_start():message="当前无法钓鱼"
		"fish_judge":fishing.judge()
		"fish_cancel":fishing.finish("")
		"interact":
			var target=find_target(args[0])
			if target==null or not preload("res://scripts/world_interaction.gd").in_reach(world.stream,world.player.position,target):message="目标已变化或距离太远"
			elif not preload("res://scripts/world_interaction.gd").execute(world.stream,world.player,target):message="当前无法操作"
		_:message="尚未接入的玩法操作"
	if service.body.sleep_active() and not service.body.sleep_session.id.is_empty() and service.builds.states.has(service.body.sleep_session.id):
		service.builds.states[service.body.sleep_session.id].network_sleep_owner=str(request.get("player_id",""))
	for row in service.builds.states.values():
		if row.get("sleep_state","PLACED")=="PLACED":row.erase("network_sleep_owner")
	world.player.set_physics_process(false)
	var snapshot: Dictionary=service.snapshot().duplicate(true)
	if OS.get_environment("WINDREST_PROFILE_NETWORK")=="1":print("RULES_US ",request.get("operation")," restore=",timing[1]-timing[0]," wait=",timing[2]-timing[1]," advance=",timing[3]-timing[2]," snapshot=",Time.get_ticks_usec()-timing[3])
	snapshot.network_craft_job=service.craft_job.duplicate(true)
	snapshot.network_craft_station=service.craft_station_id
	snapshot.network_active_lamp=service.active_lamp
	snapshot.network_lamp_on=is_instance_valid(service.lantern) and service.lantern.visible
	snapshot.network_fishing=fishing.network_snapshot()
	snapshot.network_light_clock=service.merchant.state.get("last_time",0.0)
	write_result({"ok":message.is_empty(),"error":message,"snapshot":snapshot,"events":Engine.get_meta("network_rules_events"),"combat_damage":service.combat.damage_events})
	busy=false
func point(value: Dictionary) -> Vector2:
	return Vector2(float(value.x),float(value.y))
func find_target(identity: Dictionary) -> Node2D:
	for child in world.object_root.get_children():
		for key in identity:
			if child.has_meta(key) and str(child.get_meta(key))==str(identity[key]):return child
	# A restored drop can arrive after this chunk was installed. Materialize
	# only the authoritative row; normal distance/obstruction checks still apply.
	var id:=str(identity.get("drop_id",""))
	if world.item_service.loose.has(id):
		var row: Dictionary=world.item_service.loose[id].duplicate(true)
		if world.stream.loaded.has(world.stream.chunk_at(Vector2(row.x,row.y))):
			row.id=id
			return world.stream.create_item_drop(row)
	return null
func freeze_actors() -> void:
	# Visual animals normally update their persistent coordinates from physics.
	# A rules request is deterministic: simulation only advances explicitly.
	for child in world.object_root.get_children():
		if child.has_meta("animal_id"):child.set_physics_process(false)

func movement(request: Dictionary) -> void:
	var character: Dictionary=request.character
	var at:=Vector2(character.x,character.y)
	var body=preload("res://scripts/body_state.gd").new()
	body.restore(character.gameplay.body)
	var fishing: Dictionary=character.gameplay.get("network_fishing",{})
	if body.sleep_active() or body.down or character.gameplay.get("combat_personal",{}).get("phase","alive")!="alive" or not character.gameplay.get("combat_personal",{}).get("attack",{}).is_empty() or fishing.get("state","idle")!="idle":
		write_result({"x":at.x,"y":at.y});return
	for item in request.inputs:
		# The client sends actual displacement, including its original shore slide.
		var direction:=Vector2(item.dx,item.dy).limit_length(body.efficiency())
		var motion:=direction*(310.0 if item.get("run",false) and not body.exhausted else 200.0)*float(item.dt)
		var count:=maxi(1,ceili(motion.length()/6.0))
		for step in count:
			var target:=at+motion/float(count)
			if movement_clear(target,request):at=target
			else:
				if movement_clear(Vector2(target.x,at.y),request):at.x=target.x
				if movement_clear(Vector2(at.x,target.y),request):at.y=target.y
	write_result({"x":at.x,"y":at.y})

func movement_clear(at: Vector2, request: Dictionary) -> bool:
	if not world.generator.can_walk(at):return false
	var combat_world: Dictionary=request.get("combat_world",{})
	var portal: Dictionary=combat_world.get("spawn",{})
	if not portal.is_empty():
		for side in [-1,1]:
			if at.distance_to(Vector2(portal.x+side*70,portal.y-16))<26:return false
	for boar in combat_world.get("boars",{}).values():
		if boar.health>0 and at.distance_to(Vector2(boar.x,boar.y))<24:return false
	for row in request.buildings.values():
		if row.layer in ["ground","overlay"]:continue
		var polygon: PackedVector2Array=world.item_service.animals.barrier_polygon(row)
		if Geometry2D.is_point_in_polygon(at,polygon):return false
		for n in polygon.size():
			if at.distance_to(Geometry2D.get_closest_point_to_segment(at,polygon[n],polygon[(n+1)%polygon.size()]))<9.8:return false
	return true

func integral_arguments(value: Variant) -> Variant:
	if value is float and is_finite(value) and value==floor(value):return int(value)
	if value is Array:
		var result: Array=[]
		for item in value:result.append(integral_arguments(item))
		return result
	if value is Dictionary:
		var result: Dictionary={}
		for key in value:result[key]=integral_arguments(value[key])
		return result
	return value
