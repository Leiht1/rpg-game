extends Node
## One global merchant, persisted in the existing item snapshot.
const Actor=preload("res://scripts/merchant_actor.gd")
var service: Node
var enabled := false
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/merchant_v1.json"))
var state: Dictionary={}
var rng := RandomNumberGenerator.new()
var dialogue_rng := RandomNumberGenerator.new()
var actor: Node2D
var ui: Control
var lights := preload("res://scripts/solar_flashlight.gd").new()
var interacting := false
var busy := false

func configure(owner_service: Node) -> void:
	service=owner_service;enabled=true
	lights.merchant=self
	rng.seed=service.world.world_seed^416719
	dialogue_rng.randomize()

func serialize() -> Dictionary:
	return state.duplicate(true)

func number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func valid(value: Variant) -> bool:
	if not value is Dictionary:return false
	if value.is_empty():return true
	if value.get("version")!=1 or not value.get("rng") is String or not value.rng.is_valid_int():return false
	for key in ["x","y","remaining","last_time"]:
		if not number(value.get(key)):return false
	if value.remaining<0 or value.remaining>rules.migration_minutes or value.last_time<0:return false
	if value.x<0 or value.y<0 or value.x>service.world.generator.extent or value.y>service.world.generator.extent:return false
	if not service.world.generator.can_walk(Vector2(value.x,value.y),24):return false
	if not value.get("offers") is Dictionary or value.offers.size()!=4:return false
	for id in rules.products:
		var row=value.offers.get(id)
		if not row is Dictionary or not number(row.get("template")) or row.template!=floor(row.template) or row.template<0 or row.template>=rules.products[id].size():return false
		if not number(row.get("stock")) or row.stock!=floor(row.stock) or int(row.stock) not in [0,1]:return false
	return true

func restore(value: Dictionary) -> void:
	state=value.duplicate(true)
	if not state.is_empty():
		state.version=1
		for id in state.offers:
			state.offers[id].template=int(state.offers[id].template)
			state.offers[id].stock=int(state.offers[id].stock)
		rng.state=int(state.rng)

func ready_world() -> void:
	if not enabled or not service.writable:return
	if state.is_empty():migrate()
	else:sync_actor()
	ui=preload("res://scripts/merchant_ui.gd").new();ui.merchant=self
	service.world.ui.add_child(ui);ui.setup()

func safe_point(point: Vector2) -> bool:
	var props: Array[Dictionary]=service.nearby_props(point)
	if not service.ground_clear(point,28,props) or not service.has_approach(point,props):return false
	# Reserve a clear 80-unit approach halo, including unloaded persistent buildings.
	for row in service.builds.states.values():
		var center := Vector2(row.x,row.y)
		if center.distance_to(point)<140:return false
	for row in service.camps.states.values():
		if Vector2(row.x,row.y).distance_to(point)<100:return false
	for offset in [Vector2(44,0),Vector2(-44,0),Vector2(0,44),Vector2(0,-44)]:
		if not service.ground_clear(point+offset,12,props,false):return false
	return true

func choose_point() -> Vector2:
	var extent: float=service.world.generator.extent
	for attempt in 2048:
		# Uniform domain sampling, independent of player position or streamed chunks.
		var point := Vector2(rng.randf_range(96,extent-96),rng.randf_range(96,extent-96))
		if not state.is_empty() and point.distance_to(Vector2(state.x,state.y))<512:continue
		if safe_point(point):return point
	return Vector2.INF

func migrate() -> bool:
	if not enabled or interacting or busy or not service.writable:return false
	var before := state.duplicate(true);var previous_rng := rng.state
	var point := choose_point()
	if point==Vector2.INF:rng.state=previous_rng;return false
	var offers := {}
	for id in rules.products:offers[id]={"template":rng.randi_range(0,rules.products[id].size()-1),"stock":1}
	var simulation=service.world.environment_view.simulation
	state={"version":1,"x":point.x,"y":point.y,"remaining":float(rules.migration_minutes),"rng":str(rng.state),"offers":offers,"last_time":(simulation.day-1)*1440.0+simulation.minute}
	service.dirty=true
	if not service.save_state():state=before;rng.state=previous_rng;return false
	sync_actor();return true

func sync_actor() -> void:
	if state.is_empty():return
	if not is_instance_valid(actor):
		actor=Actor.new();actor.merchant=self;service.world.object_root.add_child(actor)
	actor.position=Vector2(state.x,state.y)

func advance(minutes: float) -> void:
	if not enabled or not service.writable or state.is_empty() or minutes<=0:return
	lights.advance(minutes)
	state.remaining=maxf(0,float(state.remaining)-minutes);service.dirty=true
	if state.remaining<=0 and not interacting:migrate()

func talk() -> bool:
	if not enabled or not service.writable or not service.world.player.action.is_empty() or service.body.sleep_active():return false
	if not is_instance_valid(actor) or not preload("res://scripts/world_interaction.gd").in_reach(service.world.stream,service.world.player.position,actor):return false
	service.world.item_ui.close_panels()
	interacting=true;ui.open_dialogue(str(rules.dialogue[dialogue_rng.randi_range(0,rules.dialogue.size()-1)]))
	return true

func price(id: String) -> Dictionary:
	if not state.get("offers",{}).has(id):return {}
	var result: Dictionary=rules.products[id][int(state.offers[id].template)].duplicate(true)
	for key in result:result[key]=int(result[key])
	return result

func buy(id: String) -> String:
	if not enabled or not service.writable:return "存档受保护，暂不能交易"
	if busy or not interacting or not state.get("offers",{}).has(id):return "交易已失效"
	if not is_instance_valid(actor) or not preload("res://scripts/world_interaction.gd").in_reach(service.world.stream,service.world.player.position,actor):return "请靠近商人"
	if service.body.sleep_active() or not service.world.player.action.is_empty() or service.craft_busy or not service.craft_job.is_empty():return "请等待当前操作完成"
	if state.offers[id].stock<=0:return "这件商品已经换走了"
	var materials := price(id)
	for key in materials:
		if service.inventory.count_item(key)<materials[key]:return "身上的东西不够，带齐了再来吧"
	var staged := ItemInventory.new(service.database);staged.slots=service.inventory.slots.duplicate(true)
	var reason := staged.craft_exchange(materials,id,1,true)
	if not reason.is_empty():return reason
	busy=true
	var before: Array[Dictionary]=service.inventory.slots
	service.inventory.slots=staged.slots;state.offers[id].stock=0;service.dirty=true
	if not service.save_state():
		service.inventory.slots=before;state.offers[id].stock=1;busy=false
		return "保存失败，交易已回滚"
	busy=false;service.inventory.changed.emit();service.item_obtained.emit(id,1)
	return ""

func _process(_delta: float) -> void:
	if not enabled or state.is_empty() or not service.world.started:return
	lights.render()
	if interacting and (service.body.sleep_active() or not is_instance_valid(actor) or service.world.player.position.distance_to(actor.position)>100):ui.close_panel()


