extends RefCounted
var service: Node
var busy := false
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/industry_rules.json"))
const Fresh=preload("res://scripts/food_freshness.gd")

func enabled() -> bool: return Engine.get_meta("industry_preview",false)
func machine(kind: String) -> bool: return kind in ["stone_furnace","metal_workbench","copper_oven","feed_trough","copper_lamp"]
func initial(kind: String) -> Dictionary:
	var jobs: Array=[]
	for i in (4 if kind=="copper_oven" else 1): jobs.append({})
	return {"version":1,"fuel":0.0,"jobs":jobs,"queue":[],"feed":{},"enabled":true}

func valid(row: Dictionary) -> bool:
	if not machine(str(row.kind)): return true
	var m = row.get("machine")
	if not m is Dictionary or m.get("version")!=1 or not m.get("enabled") is bool: return false
	if not number(m.get("fuel"),0,float(rules.max_fuel)) or not m.get("jobs") is Array or m.jobs.size()!=(4 if row.kind=="copper_oven" else 1):return false
	if not m.get("queue") is Array or m.queue.size()>int(rules.queue_limit) or not m.get("feed") is Dictionary:return false
	var total := 0
	for id in m.feed:
		var n = m.feed[id]
		if not feed_allowed(id) or not number(n,1,float(rules.trough_capacity)) or n!=floor(n):return false
		total+=int(n)
	if total>int(rules.trough_capacity):return false
	for j in m.jobs+m.queue:
		if not j is Dictionary:return false
		if j.is_empty():continue
		var r := recipe(str(row.kind),str(j.get("recipe","")))
		if r.is_empty() or not number(j.get("elapsed"),0,float(r.seconds)) or not j.get("ready") is bool or j.ready!=(float(j.elapsed)>=float(r.seconds)):return false
		if row.kind=="copper_oven":
			var ingredients = j.get("materials",r.materials)
			if not ingredients is Dictionary or oven_recipe(ingredients)!=j.recipe:return false
		if not j.get("output") is Dictionary or j.output.get("item_id")!=r.output or j.output.get("count")!=int(r.get("count",1)) or not Fresh.normalize(service.database,j.output):return false
		if service.database.item(r.output).get("equippable",false):
			if str(j.output.get("instance_id","")).is_empty() or not j.output.get("state",{}) is Dictionary or not service.inventory.normalize_durability(j.output):return false
	return true

func number(v: Variant, low: float, high: float) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v>=low and v<=high

func recipe(kind: String, id: String) -> Dictionary:
	if kind=="copper_oven":
		if rules.fallback_recipes.has(id):return rules.fallback_recipes[id]
		var r: Dictionary=service.camps.rules.recipes.get(id,{})
		return {} if r.get("legacy_only",false) else r
	var r: Dictionary=rules.recipes.get(id,{})
	return r if r.get("station","")==kind else {}

func oven_recipe(materials: Dictionary) -> String:
	if materials.is_empty() or materials.size()>4:return ""
	var total := 0
	var normalized := {}
	for id in materials:
		var amount = materials[id]
		if not number(amount,1,99) or amount!=floor(amount) or service.database.item(str(id)).get("food_kind","")!="raw":return ""
		total+=int(amount)
		normalized[id]=int(amount)
	var exact: String=service.camps.match_materials(normalized)
	return exact if not exact.is_empty() else "oven_small_hodgepodge" if total<=2 else "oven_large_hodgepodge"

func feed_allowed(id: String) -> bool:
	for species in ["chicken","sheep"]:
		if id in service.animals.rules[species].foods:return true
	return false

func check(id: String) -> String:
	if busy or service.craft_busy or service.body.sleep_active():return "正在处理"
	if not service.writable:return "存档受保护"
	if not service.builds.states.has(id):return "设施不存在"
	var row: Dictionary=service.builds.states[id]
	if not machine(row.kind):return "设施不可用"
	if not is_instance_valid(service.builds.visuals.get(id)) or not preload("res://scripts/world_interaction.gd").in_reach(service.world.stream,service.world.player.position,service.builds.visuals[id]):return "请靠近设施"
	return ""

func act(id: String, action: String, index: int=0, key: String="", count: int=1, materials: Dictionary={}) -> String:
	var reason := check(id)
	if not reason.is_empty():return reason
	var row: Dictionary=service.builds.states[id];var m: Dictionary=row.machine
	var old: Dictionary=row.duplicate(true);var slots: Array=service.inventory.slots.duplicate(true)
	var claimed := "";var claimed_count := 0
	busy=true
	match action:
		"toggle":
			if row.kind!="copper_lamp":reason="操作无效"
			else:m.enabled=not m.enabled
		"fuel", "feed":
			if count<1 or count>99:reason="数量无效"
			elif action=="fuel" and (row.kind not in ["stone_furnace","copper_oven"] or not rules.fuel_items.has(key)):reason="这种物品不能燃烧"
			elif action=="feed" and (row.kind!="feed_trough" or not feed_allowed(key)):reason="这种物品不能作为饲料"
			else:
				var total := 0
				for n in m.feed.values():total+=int(n)
				if action=="fuel" and float(m.fuel)+float(rules.fuel_items[key])*count>float(rules.max_fuel):reason="燃料已足够"
				elif action=="feed" and total+count>int(rules.trough_capacity):reason="饲料槽已满"
				else:
					var staged: ItemInventory=service.camps.consume({key:count})
					if staged==null:reason="物品数量不足"
					else:
						service.inventory.slots=staged.slots
						if action=="fuel":m.fuel+=float(rules.fuel_items[key])*count
						else:m.feed[key]=int(m.feed.get(key,0))+count
		"start":
			if row.kind=="copper_oven":key=oven_recipe(materials)
			var r := recipe(row.kind,key)
			if r.is_empty():reason="没有对应配方"
			elif index<0 or index>=m.jobs.size():reason="加工位置无效"
			elif row.kind=="copper_oven" and not m.jobs[index].is_empty():reason="请先领取当前料理"
			elif row.kind!="copper_oven" and m.queue.size()>=int(rules.queue_limit):reason="加工队列已满"
			else:
				var staged: ItemInventory=service.camps.consume(materials if row.kind=="copper_oven" else r.materials)
				if staged==null:reason="材料不足"
				else:
					var output: Dictionary={"item_id":r.output,"count":int(r.get("count",1))}
					if service.database.item(r.output).get("equippable",false):output=service.inventory.instance(r.output)
					elif r.output=="silver_lantern":output={"item_id":r.output,"count":1,"lamp_id":str(ResourceUID.create_id()),"fuel":3600.0}
					Fresh.normalize(service.database,output)
					var job := {"recipe":key,"elapsed":0.0,"ready":false,"output":output}
					if row.kind=="copper_oven":job.materials=materials.duplicate(true)
					if m.jobs[index].is_empty():m.jobs[index]=job
					else:m.queue.append(job)
					service.inventory.slots=staged.slots
		"claim":
			if index<0 or index>=m.jobs.size() or m.jobs[index].is_empty() or not m.jobs[index].ready:reason="暂无可领取成品"
			else:
				var output: Dictionary=m.jobs[index].output
				var staged := ItemInventory.new(service.database);staged.slots=slots.duplicate(true)
				if staged.add_value(output)>0:reason="背包已满，成品保留"
				else:
					service.inventory.slots=staged.slots;claimed=output.item_id;claimed_count=int(output.count);m.jobs[index]={}
		_:reason="操作无效"
	if reason.is_empty():
		service.dirty=true
		if not service.save_state():reason="保存失败，操作已回滚"
	if not reason.is_empty():service.builds.states[id]=old;service.inventory.slots=slots
	else:
		service.inventory.changed.emit()
		if not claimed.is_empty():service.item_obtained.emit(claimed,claimed_count)
	busy=false
	return reason

func advance(seconds: float, minutes: float) -> void:
	if seconds<=0 or not service.writable:return
	var visual_changed := false
	for v in service.inventory.slots:
		var was := Fresh.rotten(v);Fresh.advance(service.database,v,minutes)
		visual_changed=visual_changed or was!=Fresh.rotten(v)
	for id in service.loose:
		var v: Dictionary=service.loose[id]
		if v.has("instance"):
			var was := Fresh.rotten(v.instance);Fresh.advance(service.database,v.instance,minutes)
			if was!=Fresh.rotten(v.instance):
				for drop in service.world.stream.drops:
					if is_instance_valid(drop) and drop.get_meta("drop_id","")==id and drop.has_method("setup"):
						var texture: Texture2D=service.stack_texture(v.instance,"world")
						if texture:drop.visual.texture=texture
						break
	for camp in service.camps.states.values():
		if camp.ready:
			if not camp.has("output"):camp.output={"item_id":service.camps.rules.recipes[camp.recipe].output,"count":1,"spoilage":0.0}
			Fresh.advance(service.database,camp.output,minutes)
	for row in service.builds.states.values():
		for v in row.contents:Fresh.advance(service.database,v,minutes,row.kind=="refrigerator")
		if not row.has("machine"):continue
		var m: Dictionary=row.machine
		if row.kind=="feed_trough":continue
		for i in m.jobs.size():
			if m.jobs[i].is_empty() and not m.queue.is_empty():m.jobs[i]=m.queue.pop_front()
		var working := false
		for j in m.jobs:
			if not j.is_empty() and not j.ready:working=true
		var powered := seconds
		if row.kind in ["stone_furnace","copper_oven"]:
			powered=minf(seconds,float(m.fuel))
			if working:m.fuel=maxf(0,float(m.fuel)-powered)
		for i in m.jobs.size():
			var j: Dictionary=m.jobs[i]
			if j.is_empty():continue
			var r := recipe(row.kind,j.recipe)
			if j.ready:Fresh.advance(service.database,j.output,minutes);continue
			var before := float(j.elapsed)
			j.elapsed=minf(float(r.seconds),before+powered);j.ready=j.elapsed>=float(r.seconds)
			if j.ready:
				Fresh.advance(service.database,j.output,minutes*maxf(0,seconds-(float(r.seconds)-before))/seconds)
				if row.kind=="copper_oven" and service.camps.rules.recipes.has(j.recipe):service.camps.discovered[j.recipe]=true
	auto_feed()
	if visual_changed:service.inventory.changed.emit()
	service.dirty=true

func auto_feed() -> void:
	var before_builds: Dictionary={};var before_animals: Dictionary={}
	for id in service.animals.states:
		var animal: Dictionary=service.animals.states[id]
		if not animal.tamed or animal.departed or service.animals.good(animal):continue
		for bid in service.builds.states:
			var row: Dictionary=service.builds.states[bid]
			if row.kind!="feed_trough" or Vector2(row.x,row.y).distance_to(Vector2(animal.x,animal.y))>float(rules.trough_range):continue
			for food in row.machine.feed.keys():
				if food not in service.animals.rules[animal.species].foods:continue
				if before_builds.is_empty():before_builds=service.builds.states.duplicate(true);before_animals=service.animals.states.duplicate(true)
				row.machine.feed[food]-=1
				if row.machine.feed[food]==0:row.machine.feed.erase(food)
				animal.feed_at=service.animals.clock;animal.fed_until=service.animals.clock+float(service.animals.rules.feed_minutes)
				break
			if service.animals.good(animal):break
	if not before_builds.is_empty() and not service.save_state():
		service.builds.states=before_builds;service.animals.states=before_animals
