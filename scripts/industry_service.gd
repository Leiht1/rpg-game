extends RefCounted
var service: Node
var busy := false
signal product_finished(building_id: String)
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/industry_rules.json"))
const Fresh=preload("res://scripts/food_freshness.gd")

func machine(kind: String) -> bool: return kind in ["stone_furnace","metal_workbench","copper_oven","feed_trough","copper_lamp"]
func burner(kind: String) -> bool: return kind in ["stone_furnace","copper_oven"]
func initial(kind: String) -> Dictionary:
	var jobs: Array=[]
	for i in (4 if kind=="copper_oven" else 1): jobs.append({})
	return {"version":2,"fuel":0.0,"jobs":jobs,"queue":[],"completed":[],"feed":{},"enabled":not burner(kind),"legacy_queue":[],"legacy_fuel":0.0}

func valid_job(kind: String, j: Variant, complete: bool=false) -> bool:
	if not j is Dictionary:return false
	if j.is_empty():return not complete
	var r := recipe(kind,str(j.get("recipe","")))
	if r.is_empty() or not number(j.get("elapsed"),0,float(r.seconds)) or not j.get("ready") is bool:return false
	if j.ready and float(j.elapsed)<float(r.seconds):return false
	if complete and not j.ready:return false
	if kind=="copper_oven":
		var ingredients = j.get("materials",r.materials)
		if not ingredients is Dictionary or oven_recipe(ingredients)!=j.recipe:return false
	if not j.get("output") is Dictionary or j.output.get("item_id")!=r.output or j.output.get("count")!=int(r.get("count",1)) or not Fresh.normalize(service.database,j.output):return false
	if service.database.item(r.output).get("equippable",false):
		if str(j.output.get("instance_id","")).is_empty() or not j.output.get("state",{}) is Dictionary or not service.inventory.normalize_durability(j.output):return false
	return true

func valid(row: Dictionary) -> bool:
	if not machine(str(row.kind)):return true
	var m = row.get("machine")
	if not m is Dictionary or not number(m.get("version"),1,2) or float(m.version)!=floor(float(m.version)) or not m.get("enabled") is bool:return false
	var legacy: bool=int(m.version)==1
	if not number(m.get("fuel"),0,2400.0 if legacy else float(rules.max_fuel)):return false
	if not m.get("jobs") is Array or m.jobs.size()!=(4 if row.kind=="copper_oven" else 1):return false
	if not m.get("queue") is Array or m.queue.size()>(12 if legacy else int(rules.queue_limit)) or not m.get("feed") is Dictionary:return false
	var completed: Variant=[] if legacy else m.get("completed")
	var backlog: Variant=[] if legacy else m.get("legacy_queue")
	var reserve: Variant=0.0 if legacy else m.get("legacy_fuel")
	if not completed is Array or completed.size()>int(rules.completed_limit) or not backlog is Array or backlog.size()>7 or not number(reserve,0,400):return false
	var total := 0
	for id in m.feed:
		var n = m.feed[id]
		if not feed_allowed(id) or not number(n,1,float(rules.trough_capacity)) or n!=floor(n):return false
		total+=int(n)
	if total>int(rules.trough_capacity):return false
	for j in m.jobs+m.queue+backlog:
		if not valid_job(str(row.kind),j):return false
	for j in completed:
		if not valid_job(str(row.kind),j,true):return false
	if legacy:
		m.version=2;m.completed=[];m.legacy_fuel=maxf(0,float(m.fuel)-float(rules.max_fuel));m.fuel=minf(float(m.fuel),float(rules.max_fuel));m.legacy_queue=[]
		while m.queue.size()>int(rules.queue_limit):m.legacy_queue.push_front(m.queue.pop_back())
		if burner(row.kind):m.enabled=false
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
	var claimed: Array=[]
	busy=true
	match action:
		"toggle":
			if row.kind!="copper_lamp":reason="操作无效"
			else:m.enabled=not m.enabled
		"ignite", "extinguish":
			if not burner(row.kind):reason="操作无效"
			elif action=="ignite" and float(m.fuel)+float(m.legacy_fuel)<=0:reason="请先添加燃料"
			else:m.enabled=action=="ignite"
		"fuel", "feed":
			if count<1 or count>99:reason="数量无效"
			elif action=="fuel" and (not burner(row.kind) or not rules.fuel_items.has(key)):reason="这种物品不能燃烧"
			elif action=="feed" and (row.kind!="feed_trough" or not feed_allowed(key)):reason="这种物品不能作为饲料"
			else:
				var total := 0
				for n in m.feed.values():total+=int(n)
				if action=="fuel" and (float(m.legacy_fuel)>0 or float(m.fuel)+float(rules.fuel_items[key])*count>float(rules.max_fuel)):reason="燃料已达上限"
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
			if row.kind=="metal_workbench":reason="请在金属加工台制作界面制作"
			elif r.is_empty():reason="没有对应配方"
			elif index<0 or index>=m.jobs.size():reason="加工位置无效"
			elif m.queue.size()>=int(rules.queue_limit) or not m.legacy_queue.is_empty():reason="加工队列已满"
			else:
				var staged: ItemInventory=service.camps.consume(materials if row.kind=="copper_oven" else r.materials)
				if staged==null:reason="材料不足"
				else:
					var output := {"item_id":r.output,"count":int(r.get("count",1))}
					Fresh.normalize(service.database,output)
					var job := {"recipe":key,"elapsed":0.0,"ready":false,"output":output}
					if row.kind=="copper_oven":job.materials=materials.duplicate(true)
					if m.jobs[index].is_empty() and m.queue.is_empty():m.jobs[index]=job
					else:m.queue.append(job)
					service.inventory.slots=staged.slots
		"claim_all", "claim":
			var staged := ItemInventory.new(service.database);staged.slots=slots.duplicate(true)
			var remain: Array=[]
			for job in m.completed:
				var attempt := ItemInventory.new(service.database);attempt.slots=staged.slots.duplicate(true)
				if attempt.add_value(job.output)>0:remain.append(job)
				else:staged.slots=attempt.slots;claimed.append(job.output.duplicate(true))
			if claimed.is_empty():reason="暂无可领取成品" if m.completed.is_empty() else "背包已满，成品保留"
			else:m.completed=remain;service.inventory.slots=staged.slots
		_:reason="操作无效"
	if reason.is_empty():
		service.dirty=true
		if not service.save_state():reason="保存失败，操作已回滚"
	if not reason.is_empty():service.builds.states[id]=old;service.inventory.slots=slots
	else:
		if action=="toggle" and bool(old.machine.enabled)!=bool(m.enabled):
			AudioFX.play_sfx("sfx_lantern_on" if m.enabled else "sfx_lantern_off",Vector2(row.x,row.y))
		service.inventory.changed.emit()
		for output in claimed:service.item_obtained.emit(output.item_id,int(output.count))
	busy=false
	return reason

func burning(row: Dictionary) -> bool:
	return burner(row.kind) and row.machine.enabled and float(row.machine.fuel)+float(row.machine.legacy_fuel)>0

func advance_machine(id: String, row: Dictionary, seconds: float, minutes: float) -> void:
	var m: Dictionary=row.machine
	for j in m.completed:Fresh.advance(service.database,j.output,minutes)
	var powered := seconds
	if burner(row.kind):
		powered=minf(seconds,float(m.fuel)+float(m.legacy_fuel)) if m.enabled else 0.0
		var reserve_used := minf(powered,float(m.legacy_fuel));m.legacy_fuel-=reserve_used
		m.fuel=maxf(0,float(m.fuel)-(powered-reserve_used))
		if float(m.fuel)+float(m.legacy_fuel)<=0:m.enabled=false
	var remaining := powered
	# Move old ready slots into the output tray, without replaying completion smoke on load.
	for i in m.jobs.size():
		if not m.jobs[i].is_empty() and m.jobs[i].ready and m.completed.size()<int(rules.completed_limit):m.completed.append(m.jobs[i]);m.jobs[i]={}
	while remaining>.000001 and m.completed.size()<int(rules.completed_limit):
		while m.queue.size()<int(rules.queue_limit) and not m.legacy_queue.is_empty():m.queue.append(m.legacy_queue.pop_front())
		for i in m.jobs.size():
			if m.jobs[i].is_empty() and not m.queue.is_empty():m.jobs[i]=m.queue.pop_front()
		var step := remaining;var active := false
		for j in m.jobs:
			if not j.is_empty() and not j.ready:
				active=true;step=minf(step,float(recipe(row.kind,j.recipe).seconds)-float(j.elapsed))
		if not active:break
		for j in m.jobs:
			if not j.is_empty() and not j.ready:j.elapsed+=step
		remaining-=step
		for i in m.jobs.size():
			var j: Dictionary=m.jobs[i]
			if j.is_empty() or m.completed.size()>=int(rules.completed_limit):continue
			var duration := float(recipe(row.kind,j.recipe).seconds)
			if float(j.elapsed)>=duration-.000001:
				j.elapsed=duration;j.ready=true
				Fresh.advance(service.database,j.output,minutes*maxf(0,seconds-powered+remaining)/seconds)
				m.completed.append(j);m.jobs[i]={}
				if row.kind=="copper_oven" and service.camps.rules.recipes.has(j.recipe):service.camps.discovered[j.recipe]=true
				product_finished.emit(id)
		if step<=.000001:break

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
	for building_id in service.builds.states:
		var row: Dictionary=service.builds.states[building_id]
		for v in row.contents:Fresh.advance(service.database,v,minutes,row.kind=="refrigerator")
		if not row.has("machine"):continue
		if row.kind!="feed_trough" and row.kind!="copper_lamp":advance_machine(str(building_id),row,seconds,minutes)
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
