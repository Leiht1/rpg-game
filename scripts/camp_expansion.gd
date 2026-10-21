extends RefCounted
## Candidate facilities share the existing building record and item snapshot.
var service: Node
var busy := false
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/camp_expansion_v2.json"))
const Fresh=preload("res://scripts/food_freshness.gd")
const KINDS=["precision_repair_bench","fuel_supply_box","compost_bin","advanced_smokehouse"]

static func preview_enabled() -> bool:
	return bool(Engine.get_meta("camp_expansion_preview",false))

func initial() -> Dictionary:
	return {"version":1,"fuel_items":{},"job":{}}

func valid(row: Dictionary) -> bool:
	if row.kind not in KINDS:return not row.has("expansion")
	var e = row.get("expansion")
	if not e is Dictionary or e.get("version")!=1 or not e.get("fuel_items") is Dictionary or not e.get("job") is Dictionary:return false
	var total := 0
	for key in e.fuel_items:
		var n = e.fuel_items[key]
		if row.kind!="fuel_supply_box" or not service.industry.rules.fuel_items.has(key) or not service.industry.number(n,1,rules.supply_capacity) or n!=floor(n):return false
		total+=int(n)
	if total>int(rules.supply_capacity):return false
	if e.job.is_empty():return true
	if row.kind not in ["compost_bin","advanced_smokehouse"]:return false
	var spec: Dictionary=rules.processes[row.kind]
	var j: Dictionary=e.job
	if not service.industry.number(j.get("minutes"),0,spec.minutes) or not j.get("ready") is bool or j.ready!=(float(j.minutes)>=float(spec.minutes)):return false
	if not j.get("output") is Dictionary or j.output.get("item_id")!=spec.output or j.output.get("count")!=1:return false
	return Fresh.normalize(service.database,j.output)

func check(id: String) -> String:
	if busy or service.builds.busy or service.craft_busy or service.body.sleep_active() or service.body.down:return "正在处理"
	if not service.writable:return "存档受保护"
	var row: Dictionary=service.builds.states.get(id,{})
	if row.get("kind","") not in KINDS and row.get("kind","")!="tilled_soil":return "设施不存在"
	var node: Node2D=service.builds.visuals.get(id)
	if not is_instance_valid(node) or not preload("res://scripts/world_interaction.gd").in_reach(service.world.stream,service.world.player.position,node):return "请靠近设施"
	return ""

func repair_cost(value: Dictionary) -> Dictionary:
	return rules.repairs.get(str(value.get("item_id","")),{}).duplicate(true)

func compost_allowed(value: Dictionary) -> bool:
	return not value.is_empty() and (str(value.item_id) in rules.organic_items or (Fresh.cooked(service.database,str(value.item_id)) and Fresh.rotten(value)))

func act(id: String, action: String, index: int=-1, expected: Dictionary={}, key: String="", count: int=1) -> String:
	if preload("res://scripts/network_game_route.gd").send(self,"expansion",[id,action,index,expected,key,count]):return ""
	var reason := check(id)
	if not reason.is_empty():return reason
	var row: Dictionary=service.builds.states[id]
	var inv: ItemInventory=service.inventory
	var slots := inv.slots.duplicate(true);var equipment := inv.equipment.duplicate(true)
	var old := row.duplicate(true)
	var output := {}
	busy=true
	match action:
		"repair":
			var current: Dictionary=inv.get_slot(index) if index>=0 and index<43 else {}
			var cost := repair_cost(current)
			if row.kind!="precision_repair_bench" or current.is_empty() or current!=expected or cost.is_empty():reason="工具已变化或无法修复"
			elif int(current.get("durability",0))<=0 or int(current.durability)>=int(service.database.item(current.item_id).durability):reason="工具无需修复"
			else:
				var staged: ItemInventory=service.camps.consume(cost)
				if staged==null:reason="维修材料不足"
				else:
					inv.slots=staged.slots
					# Consume copies physical slots; resolve the same instance again, including equipped aliases.
					var repaired: Dictionary=inv.get_slot(index)
					repaired.durability=int(service.database.item(current.item_id).durability)
		"deposit", "withdraw":
			if row.kind!="fuel_supply_box" or not service.industry.rules.fuel_items.has(key) or count<1 or count>99:reason="燃料或数量无效"
			elif action=="withdraw":reason="投入的燃料不能取回"
			else:
				var total := 0
				for n in row.expansion.fuel_items.values():total+=int(n)
				var staged: ItemInventory=service.camps.consume({key:count})
				if total+count>int(rules.supply_capacity):reason="供给箱已满"
				elif staged==null:reason="燃料数量不足"
				else:inv.slots=staged.slots;row.expansion.fuel_items[key]=int(row.expansion.fuel_items.get(key,0))+count
		"process":
			if row.kind not in rules.processes or not row.expansion.job.is_empty():reason="设施正在加工或有待领成品"
			else:
				var spec: Dictionary=rules.processes[row.kind]
				var staged := ItemInventory.new(service.database);staged.slots=slots.duplicate(true)
				if row.kind=="compost_bin":
					if index<0 or index>=40 or not Fresh.matches(inv.slots[index],expected) or not compost_allowed(inv.slots[index]) or int(inv.slots[index].get("count",0))<int(spec.input_count):reason="需要足量腐坏食物或植物材料"
					else:
						staged.slots[index].count-=int(spec.input_count)
						if staged.slots[index].count==0:staged.slots[index]={}
				else:
					# First version accepts only non-rotten roasted meat (currently roasted fish).
					var fish := -1
					for i in 40:
						if staged.slots[i].get("item_id","")==str(spec.input) and not Fresh.rotten(staged.slots[i]):fish=i;break
					if fish<0:reason="需要新鲜烤鱼"
					elif inv.count_item("wood")<1:reason="需要木材"
					else:
						staged=service.camps.consume({"wood":1});staged.slots[fish].count-=1
						if staged.slots[fish].count==0:staged.slots[fish]={}
				if reason.is_empty():
					inv.slots=staged.slots;output={"item_id":spec.output,"count":1};Fresh.normalize(service.database,output)
					row.expansion.job={"minutes":0.0,"ready":false,"output":output};output={}
		"claim":
			if row.kind not in rules.processes or row.expansion.job.is_empty() or not row.expansion.job.ready:reason="暂无成品"
			else:
				output=row.expansion.job.output.duplicate(true)
				var staged := ItemInventory.new(service.database);staged.slots=slots.duplicate(true)
				if staged.add_value(output)>0:reason="背包已满，成品保留"
				else:inv.slots=staged.slots;row.expansion.job={}
		"fertilize":
			if row.kind!="tilled_soil" or row.crop.is_empty() or row.roots or service.planting.stage(row)==2 or row.get("fertilized",false):reason="这块耕地暂不能施肥"
			else:
				var staged: ItemInventory=service.camps.consume({"compost_fertilizer":1})
				if staged==null:reason="没有肥料"
				else:inv.slots=staged.slots;row.fertilized=true
		_:reason="操作无效"
	if reason.is_empty():
		service.dirty=true
		if not service.save_state():reason="保存失败，操作已回滚"
	if not reason.is_empty():service.builds.states[id]=old;inv.slots=slots;inv.equipment=equipment
	else:
		inv.changed.emit()
		if action=="claim":service.item_obtained.emit(output.item_id,int(output.count))
	busy=false
	return reason

func protected_reason(row: Dictionary) -> String:
	if row.has("expansion") and (not row.expansion.job.is_empty() or not row.expansion.fuel_items.is_empty()):return "设施内还有物品"
	return ""

func advance(minutes: float) -> void:
	if minutes<=0 or not service.writable:return
	for row in service.builds.states.values():
		if not row.has("expansion") or row.expansion.job.is_empty():continue
		var j: Dictionary=row.expansion.job
		if j.ready:Fresh.advance(service.database,j.output,minutes);continue
		var duration: float=float(rules.processes[row.kind].minutes)
		var remaining := maxf(0,duration-float(j.minutes))
		j.minutes=minf(duration,float(j.minutes)+minutes);j.ready=j.minutes>=duration
		if j.ready:Fresh.advance(service.database,j.output,maxf(0,minutes-remaining))
	service.dirty=true

func supply() -> void:
	if busy or not service.writable:return
	var before := {}
	# Deterministic order gives overlapping suppliers/consumers a stable priority.
	var ids: Array=service.builds.states.keys();ids.sort()
	for id in ids:
		var box: Dictionary=service.builds.states[id]
		if box.kind!="fuel_supply_box" or box.expansion.fuel_items.is_empty():continue
		for target_id in ids:
			var row: Dictionary=service.builds.states[target_id]
			if not service.industry.burner(row.kind) or Vector2(box.x,box.y).distance_to(Vector2(row.x,row.y))>float(rules.supply_range):continue
			var m: Dictionary=row.machine
			if float(m.legacy_fuel)>0 or float(m.fuel)>float(rules.supply_threshold):continue
			for key in service.industry.rules.fuel_items:
				var energy: float=float(service.industry.rules.fuel_items[key])
				if int(box.expansion.fuel_items.get(key,0))<1 or float(m.fuel)+energy>float(service.industry.rules.max_fuel):continue
				if not before.has(id):before[id]=box.duplicate(true)
				if not before.has(target_id):before[target_id]=row.duplicate(true)
				box.expansion.fuel_items[key]-=1
				if box.expansion.fuel_items[key]==0:box.expansion.fuel_items.erase(key)
				m.fuel+=energy
				break
	if before.is_empty():return
	busy=true;service.dirty=true
	if not service.save_state():
		for id in before:service.builds.states[id]=before[id]
	busy=false
