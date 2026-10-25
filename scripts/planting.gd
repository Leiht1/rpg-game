extends RefCounted
## Crop state belongs to the existing building record and atomic item snapshot.
var service: Node
static var configuration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planting.json"))
var rules: Dictionary=configuration

static func art(name_value: String) -> String:
	if name_value=="soil": return "res://assets/planting/v2/soil.png"
	if name_value=="roots": return "res://assets/planting/v1/roots.png"
	return "res://assets/planting/v3/"+name_value+".png"

static func soil_rect() -> Rect2:
	var cell := preload("res://scripts/camp_grid.gd").STEP
	var inset := Vector2.ONE*float(configuration.plot_inset)
	return Rect2(-cell*.5+inset,cell-inset*2)

func valid(row: Dictionary) -> bool:
	if not row.get("crop") is String or not row.get("roots") is bool: return false
	if row.has("fertilized") and not row.fertilized is bool:return false
	if row.get("fertilized",false) and (row.crop.is_empty() or row.roots):return false
	var elapsed = row.get("growth_minutes")
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed<0: return false
	if row.crop.is_empty(): return elapsed==0
	return rules.crops.has(row.crop) and not row.roots and elapsed<=float(rules.crops[row.crop].minutes)

func stage(row: Dictionary) -> int:
	return stage_for(row)

static func stage_for(row: Dictionary) -> int:
	if row.get("crop","").is_empty(): return -1
	var spec: Dictionary=configuration.crops[row.crop]
	return 2 if row.growth_minutes>=spec.minutes else 1 if row.growth_minutes>=spec.stage_minutes else 0

func advance(minutes: float) -> void:
	if minutes<=0 or not service.writable: return
	for id in service.builds.states:
		var row: Dictionary=service.builds.states[id]
		if row.kind!="tilled_soil" or row.crop.is_empty() or row.roots: continue
		var old := stage(row)
		var sim=service.world.environment_view.simulation
		var growth: float=preload("res://scripts/season_rules.gd").growth(str(row.crop),sim.season_elapsed_days(),minutes)
		row.growth_minutes=minf(float(rules.crops[row.crop].minutes),float(row.growth_minutes)+growth*(float(service.expansion.rules.fertilizer_speed) if row.get("fertilized",false) else 1.0))
		service.dirty=true
		if old!=stage(row) and service.builds.visuals.has(id): service.builds.visuals[id].queue_redraw()

func action(id: String) -> String:
	var row: Dictionary=service.builds.states.get(id,{})
	if row.is_empty(): return ""
	if row.roots: return "dig"
	if row.crop.is_empty(): return "sow"
	if stage(row)==2:return "pickup"
	if not row.get("fertilized",false) and service.inventory.count_item("compost_fertilizer")>0:return "fertilize"
	return ""

func interact(id: String, target: Node2D, seed_id: String="") -> bool:
	if preload("res://scripts/network_game_route.gd").send(self,"plant",[id,seed_id]):return true
	var builds: RefCounted=service.builds
	if builds.busy or not service.writable or service.body.sleep_active() or service.body.down: return false
	if not builds.states.has(id) or builds.states[id].kind!="tilled_soil": return false
	if not preload("res://scripts/world_interaction.gd").in_reach(service.world.stream,service.world.player.position,target): return false
	var row: Dictionary=builds.states[id]
	var before := row.duplicate(true)
	var inv: ItemInventory=service.inventory
	var slots := inv.slots.duplicate(true)
	var equipment := inv.equipment.duplicate(true)
	var links := inv.hotbar_equipment.duplicate(true)
	var body_before: Dictionary=service.body.serialize()
	var staged := ItemInventory.new(service.database)
	staged.slots=slots.duplicate(true)
	var rewards := {}
	var request := action(id)
	if request=="sow":
		var crop := ""
		for key in rules.crops:
			if rules.crops[key].seed==seed_id: crop=key
		if crop.is_empty() or inv.count_item(seed_id)<1:service.notice.emit("没有种子");return false
		staged=service.camps.consume({seed_id:1})
		if staged==null:service.notice.emit("没有种子");return false
		row.crop=crop;row.growth_minutes=0.0
	elif request=="dig":
		if not inv.has_capability("dig") or not service.body.can_labor("dig",service.world.player.action=="dig"): return false
		row.roots=false
		service.body.spend_labor("dig")
		inv.wear_held(str(inv.equipment.main_hand.instance_id),"dig")
	elif request=="pickup":
		var spec: Dictionary=rules.crops[row.crop]
		rewards={str(spec.produce):int(spec.yield_count),str(spec.seed):int(spec.seed_count)}
		for item in rewards:
			if staged.add(item,rewards[item])>0: service.notice.emit("背包空间不足，请留出收获和种子的空间");return false
		row.crop="";row.growth_minutes=0.0;row.roots=true;row.erase("fertilized")
	else: return false
	builds.busy=true;inv.slots=staged.slots;service.dirty=true
	if not service.save_state():
		builds.states[id]=before;inv.slots=slots;inv.equipment=equipment;inv.hotbar_equipment=links
		service.body.restore(body_before);builds.busy=false
		service.notice.emit("保存失败，种植操作已回滚");return false
	inv.changed.emit();builds.busy=false;target.queue_redraw()
	for item in rewards: service.item_obtained.emit(item,int(rewards[item]))
	return true

func fertilize(id: String, target: Node2D) -> bool:
	if preload("res://scripts/network_game_route.gd").send(self,"fertilize",[id]):return true
	var reason: String=service.expansion.act(id,"fertilize")
	if not reason.is_empty():service.notice.emit(reason);return false
	service.notice.emit("肥料 -1")
	target.modulate=Color(1.4,1.65,1.15)
	var glow := target.create_tween()
	glow.tween_property(target,"modulate",Color.WHITE,.65)
	target.queue_redraw()
	return true
