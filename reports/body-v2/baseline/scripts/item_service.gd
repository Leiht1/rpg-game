extends Node
## Inventory and world edits share one atomic snapshot, isolated by Seed/map/resource versions.
const RESOURCE_VERSION := "natural-resources-0.3.1"
const LEGACY_RESOURCE_VERSION := "natural-resources-0.3.0"
const Scenery = preload("res://scripts/scenery_catalog.gd")
var database := ItemDatabase.new()
var builds: RefCounted=preload("res://scripts/camp_buildings.gd").new()
var storage_ui: Control
var inventory := ItemInventory.new(database)
var craft_book := preload("res://scripts/craft_book.gd").new(database)
var craft_busy := false
var craft_sequence := 0
var craft_last_request := 0
var craft_job: Dictionary = {}
var craft_job_serial := 0
signal item_obtained(item_id: String, count: int)
signal craft_progress(value: float)
signal craft_finished(recipe_id: String, batches: int, reason: String)
var world: Variant
var preview := false
var tools_preview := false
const HARVEST_VERSION := "harvest-resources-2.1.0"
const PREVIOUS_HARVEST_VERSION := "harvest-resources-2.0.0"
const LEGACY_HARVEST_VERSION := "harvest-resources-1.0.0"
var resource_hits: Dictionary = {}
var ore_nodes: Dictionary = {}
var consumed: Dictionary = {}
var loose: Dictionary = {}
var clock := 0.0
var dirty := false
var writable := true
var save_path := ""
var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/natural_resources.json"))
var raw_cells: Dictionary = {}
var chunk_cache: Dictionary = {}
var prop_cache: Dictionary = {}
var reachable: Dictionary = {}
var navigation_ready := false
var patch_noise := FastNoiseLite.new()
var generation_ms := 0.0
var navigation_ms := 0.0
var discard_serial := 0
var texture_cache: Dictionary = {}
signal notice(message: String)

func configure(owner_world: Node, art_preview: bool) -> void:
	world = owner_world
	camps.service=self
	builds.service=self
	if Engine.get_meta("camp_build_preview",false):
		for row in camps.build_book.recipes.values(): row.default_unlocked=true
		if craft_book.recipes.has("hand_stone_hammer"): craft_book.recipes.hand_stone_hammer.default_unlocked=true
	preview = art_preview
	tools_preview = owner_world.get("tools_preview")==true
	patch_noise.seed = world.world_seed ^ 87361
	patch_noise.frequency = 1.0 / float(rules.noise_scale)
	patch_noise.fractal_octaves = 2
	# Once during the loading screen; immutable navigation is shared by workers.
	prepare_navigation()
	save_path = "user://items-%s-%d-%d-%s%s.json" % [world.Gen.VERSION,world.world_seed,world.map_cells,RESOURCE_VERSION,"-preview" if preview else ""]
	if not FileAccess.file_exists(save_path):
		var legacy := save_path.replace(RESOURCE_VERSION,LEGACY_RESOURCE_VERSION)
		if FileAccess.file_exists(legacy): load_state(legacy,true)
	else: load_state()
	camps.rebuild()
	for coord in world.stream.loaded: builds.install(coord)
	world.stream.items = self
	world.player.body=body
	inventory.body=body
	body.changed.connect(func(): dirty=true)
	inventory.changed.connect(func(): dirty = true; call_deferred("save_state"))
	inventory.used.connect(func(id,effect):
		if database.item(id).use_action=="unpack": notice.emit("打开补给包 · 野胡萝卜×2、燧石×1、遗物碎片×2")
		elif database.item(id).use_action=="place_campfire": world.camp_ui.begin_placement(int(effect.slot))
		elif database.item(id).use_action=="light": toggle_lantern(int(effect.get("slot",-1)))
		else: notice.emit("吃下了%s" % database.item(id).name); food_effect.emit(id,effect))

signal food_effect(item_id: String, effect: Dictionary)

func new_craft_request() -> int:
	craft_sequence+=1
	return craft_sequence

func craft_check(recipe_id: String, batches: int) -> String:
	if not writable: return "存档受保护，暂不能制作"
	if not craft_job.is_empty(): return "正在制作，请等待进度完成"
	if craft_busy: return "正在提交制作，请稍候"
	var row: Dictionary=craft_book.recipe(recipe_id)
	if row.is_empty(): return "配方不存在"
	var reason: String=craft_book.validate(row)
	if not reason.is_empty(): return reason
	if not row.default_unlocked: return "配方尚未解锁"
	if not row.conditions.is_empty(): return "尚未满足制作设施条件"
	if batches<1 or batches>craft_book.MAX_BATCH: return "制作次数须为1–99"
	var materials := {}
	for id in row.materials: materials[id]=int(row.materials[id])*batches
	return inventory.craft_exchange(materials,str(row.output_id),int(row.output_count)*batches)

func start_craft(recipe_id: String, batches: int) -> String:
	var reason := craft_check(recipe_id,batches)
	if not reason.is_empty(): return reason
	var row: Dictionary=craft_book.recipe(recipe_id)
	craft_job_serial+=1
	craft_job={"recipe_id":recipe_id,"batches":batches,"elapsed":0.0,"duration":float(row.get("craft_time",1.5)),"serial":craft_job_serial}
	craft_progress.emit(0.0)
	return ""

func cancel_craft() -> void:
	if craft_job.is_empty(): return
	var job := craft_job
	craft_job={}
	craft_finished.emit(str(job.recipe_id),int(job.batches),"制作已取消，材料未消耗")

func advance_craft(delta: float) -> void:
	if craft_job.is_empty() or delta<=0: return
	var serial: int=craft_job.serial
	craft_job.elapsed=minf(float(craft_job.duration),float(craft_job.elapsed)+delta)
	var progress := float(craft_job.elapsed)/float(craft_job.duration)
	craft_progress.emit(progress)
	# A callback may close the UI, cancel, or start a replacement operation.
	if craft_job.is_empty() or int(craft_job.serial)!=serial or progress<1.0: return
	var job := craft_job
	craft_job={}
	# Revalidate the entire operation against current inventory at completion.
	var reason := craft(str(job.recipe_id),int(job.batches),new_craft_request())
	craft_finished.emit(str(job.recipe_id),int(job.batches),reason)

func craft(recipe_id: String, batches: int, request: int) -> String:
	if request<=craft_last_request or request!=craft_sequence or request<1: return "此制作操作已处理或已失效"
	if craft_busy: return "正在提交制作，请稍候"
	craft_last_request=request
	var reason := craft_check(recipe_id,batches)
	if not reason.is_empty(): return reason
	craft_busy=true
	var row: Dictionary=craft_book.recipe(recipe_id)
	var materials := {}
	for id in row.materials: materials[id]=int(row.materials[id])*batches
	reason=inventory.craft_exchange(materials,str(row.output_id),int(row.output_count)*batches,true)
	craft_busy=false
	if reason.is_empty():
		dirty=true
		save_state()
		item_obtained.emit(str(row.output_id),int(row.output_count)*batches)
	return reason

var camps := preload("res://scripts/campfire_service.gd").new()

var body := preload("res://scripts/body_state.gd").new()
var lantern_remaining := 1800.0
var active_lamp := ""
var lantern: Node2D
func lamp_slot() -> Dictionary:
	for slot in inventory.slots:
		if slot.get("lamp_id","")==active_lamp and not active_lamp.is_empty(): return slot
	return {}

func burn_lantern(dt: float) -> void:
	var slot := lamp_slot()
	if slot.is_empty():
		lantern.hide();return
	lantern_remaining=maxf(0.0,float(slot.get("fuel",1800.0))-dt)
	slot.fuel=lantern_remaining
	dirty=true
	if lantern_remaining<=0: lantern.hide()

func toggle_lantern(index: int = -1) -> void:
	if index<0:
		for i in inventory.slots.size():
			if inventory.slots[i].get("item_id","")=="field_lantern": index=i;break
	if index<0: return
	var slot: Dictionary=inventory.slots[index]
	if not slot.has("lamp_id"): slot.lamp_id=str(ResourceUID.create_id());slot.fuel=1800.0
	var same := active_lamp==str(slot.lamp_id)
	active_lamp=str(slot.lamp_id)
	lantern_remaining=float(slot.get("fuel",1800.0))
	if lantern_remaining<=0:
		if is_instance_valid(lantern): lantern.hide()
		notice.emit("提灯燃料已耗尽"); return
	if not is_instance_valid(lantern):
		lantern=preload("res://scripts/field_lantern.gd").new()
		world.player.add_child(lantern)
		lantern.service=self
	lantern.visible=not lantern.visible if same else true
	dirty=true

func texture(id: String, kind: String) -> Texture2D:
	var definition := database.item(id)
	if definition.is_empty(): return null
	var path := str(definition.icon if kind in ["icon","loose"] else definition.world_visual)
	if ResourceLoader.exists(path):
		if not texture_cache.has(path):
			var source: Texture2D = load(path)
			var safe := AtlasTexture.new()
			safe.atlas=source
			safe.region=Rect2(Vector2.ZERO,source.get_size())
			safe.margin=Rect2(8,8,16,16)
			safe.filter_clip=true
			texture_cache[path]=safe
		return texture_cache[path]
	if id == "wood": return load("res://assets/environment/cartoon_v2/wood.png")
	return null

func _process(delta: float) -> void:
	advance_craft(delta)
	clock += delta
	if clock > 15:
		clock = 0
		if dirty: save_state()

func snapshot() -> Dictionary:
	return {"buildings":builds.serialize(),"campfires":camps.serialize(),"body":body.serialize(),"lantern_remaining":lantern_remaining,"version":1,"harvest_version":HARVEST_VERSION,"props_version":world.Gen.PROP_VERSION,"resource_hits":resource_hits,"resource_version":RESOURCE_VERSION,"seed":world.world_seed,"map_cells":world.map_cells,"generator":world.Gen.VERSION,"slots":inventory.slots,"selected":inventory.selected,"hotbar_equipment":inventory.hotbar_equipment,"equipment":inventory.equipment,"ore_nodes":ore_nodes,"equipment_quarantine":inventory.quarantined_equipment,"consumed":consumed,"loose":loose,"harvested":world.stream.harvested,"tree_hits":world.stream.tree_hits}

func save_state() -> bool:
	if world == null or not writable: return false
	if not world.persistent_world: return true
	var temporary := save_path + ".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: notice.emit("物品存档未能写入"); return false
	file.store_string(JSON.stringify(snapshot()))
	file.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(save_path))
	if error == OK: dirty = false
	else: notice.emit("物品存档保存失败，暂存文件已保留")
	return error == OK

func load_state(source_path: String = "", migrate: bool = false) -> void:
	var path := save_path if source_path.is_empty() else source_path
	if not world.persistent_world or not FileAccess.file_exists(path): return
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or int(value.get("version",0)) != 1 or value.get("generator","") != world.Gen.VERSION or int(value.get("seed",-1)) != world.world_seed or int(value.get("map_cells",0)) != world.map_cells or value.get("resource_version","") != (LEGACY_RESOURCE_VERSION if migrate else RESOURCE_VERSION):
		writable = false
		return
	for key in ["consumed","loose","harvested","tree_hits"]:
		if not value.get(key) is Dictionary: writable = false; return
	for id in value.loose:
		var row = value.loose[id]
		if not row is Dictionary or database.item(str(row.get("item_id",""))).is_empty() or int(row.get("count",0)) < 1 or not (row.get("x") is float or row.get("x") is int) or not (row.get("y") is float or row.get("y") is int):
			writable = false; return
	if value.get("harvest_version",LEGACY_HARVEST_VERSION) not in [HARVEST_VERSION,PREVIOUS_HARVEST_VERSION,LEGACY_HARVEST_VERSION] or not value.get("resource_hits",{}) is Dictionary:
		writable=false; return
	for hit_count in value.get("resource_hits",{}).values():
		if not (hit_count is float or hit_count is int) or hit_count<0 or hit_count!=floor(hit_count): writable=false;return
	if value.has("campfires") and not camps.validate(value.campfires): writable=false;return
	var staged_body := preload("res://scripts/body_state.gd").new()
	if value.has("body") and not staged_body.restore(value.body): writable=false; return
	var fuel = value.get("lantern_remaining",1800.0)
	if not (fuel is float or fuel is int) or not is_finite(float(fuel)) or float(fuel)<0 or float(fuel)>1800: writable=false;return
	var staged := ItemInventory.new(database)
	if not staged.restore(value.get("slots")) or not staged.restore_equipment(value.get("equipment",{}),value.get("equipment_quarantine",{})): writable = false; return
	var seen_instances := {}
	var seen_lamps := {}
	var lamp_entries: Array=staged.slots.duplicate()
	for row in value.loose.values():
		if row.item_id=="field_lantern" and row.has("instance"):
			if not row.instance is Dictionary: writable=false;return
			lamp_entries.append(row.instance)
	for slot in lamp_entries:
		if slot.get("item_id","")!="field_lantern": continue
		var lamp_id := str(slot.get("lamp_id",""))
		var fuel_value = slot.get("fuel",1800.0)
		if not (fuel_value is float or fuel_value is int) or not is_finite(float(fuel_value)) or float(fuel_value)<0 or float(fuel_value)>1800: writable=false;return
		if not lamp_id.is_empty():
			if seen_lamps.has(lamp_id): writable=false;return
			seen_lamps[lamp_id]=true
	for instance in staged.slots+staged.equipment.values():
		if instance.has("instance_id"): seen_instances[str(instance.instance_id)]=true
	for row in value.loose.values():
		if not database.item(str(row.item_id)).get("equippable",false): continue
		var instance = row.get("instance",{})
		if not instance is Dictionary or str(instance.get("item_id",""))!=str(row.item_id) or int(instance.get("count",0))!=1 or int(row.count)!=1 or str(instance.get("instance_id","")).is_empty() or not instance.get("state",{}) is Dictionary:
			writable=false; return
		var instance_id := str(instance.instance_id)
		if seen_instances.has(instance_id): writable=false; return
		seen_instances[instance_id]=true
		if not staged.normalize_durability(instance): writable=false;return
	if value.has("buildings") and not builds.validate(value.buildings,seen_instances): writable=false;return
	builds.states=value.get("buildings",{"objects":{}}).objects.duplicate(true)
	if value.get("harvest_version",LEGACY_HARVEST_VERSION)!=HARVEST_VERSION: dirty=true
	for coord in camps.bins.keys(): camps.unload(coord)
	camps.states=value.get("campfires",{"objects":{}}).objects.duplicate(true)
	camps.discovered=value.get("campfires",{}).get("discovered",{}).duplicate(true)
	# Old ready tasks have already completed; old in-progress tasks keep their paid output.
	for camp in camps.states.values():
		if camp.ready: camps.discovered[camp.recipe]=true
	camps.rebuild()
	for coord in world.stream.loaded: camps.install(coord)
	body.restore(staged_body.serialize())
	lantern_remaining=float(fuel)
	resource_hits=value.get("resource_hits",{}).duplicate(true)
	staged.restore_hotbar_links(value.get("hotbar_equipment",{}))
	inventory.hotbar_equipment=staged.hotbar_equipment
	inventory.slots=staged.slots
	inventory.equipment=staged.equipment
	inventory.quarantined_equipment=staged.quarantined_equipment
	inventory.changed.emit()
	if value.get("ore_nodes",{}) is Dictionary: ore_nodes=value.get("ore_nodes",{})
	inventory.selected = clampi(int(value.get("selected",0)),0,7)
	consumed = value.consumed
	loose = value.loose
	world.stream.harvested = value.harvested
	world.stream.tree_hits = value.tree_hits
	builds.refresh_all()
	if migrate:
		# Legacy IDs remain in the snapshot, but cannot suppress a new version's positions.
		dirty = true
		save_state()

func entries(coord: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in chunk_distribution(coord).accepted:
		if not consumed.has(row.id) and str(row.item_id) != "stone": result.append(row.duplicate(true))
	return result

func ecology(p: Vector2) -> Dictionary:
	var gen = world.generator
	var v: Vector3 = gen.macro_weights(p)
	var shore := 0.0
	for offset in [Vector2.ZERO,Vector2(110,0),Vector2(-110,0),Vector2(0,110),Vector2(0,-110)]:
		shore = maxf(shore,gen.sample(p+offset).z)
	shore = smoothstep(.03,.6,shore)
	return {"forest":v.x*(1-shore),"mountain":v.y*(1-shore),"meadow":v.z*(1-shore),"shore":shore}

func nearby_props(p: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var c := Vector2i(floori(p.x/world.Gen.CHUNK_PX),floori(p.y/world.Gen.CHUNK_PX))
	for y in range(c.y-1,c.y+2):
		for x in range(c.x-1,c.x+2):
			var key := Vector2i(x,y)
			if not prop_cache.has(key): prop_cache[key] = world.generator.props_for_chunk(key)
			for prop in prop_cache[key]:
				if prop.kind < 4 and p.distance_squared_to(prop.position) < 340.0*340.0: result.append(prop)
	return result

func source_tag(prop: Dictionary) -> String:
	# Extension point for future actual fruit/conifer species. Current broadleaf
	# art cannot credibly produce pine cones. A few trees may have fallen fruit.
	if prop.has("resource_source"): return str(prop.resource_source)
	return "fallen_fruit" if world.generator.random_at(roundi(prop.position.x),roundi(prop.position.y),8377)<.12 else ""

func ground_clear(p: Vector2, radius: float, props: Array[Dictionary], roots: bool = true) -> bool:
	if not world.generator.can_walk(p,radius): return false
	for prop in props:
		var rel: Vector2 = p-prop.position
		var scale_value := float(prop.scale)
		var appearance: Dictionary = Scenery.appearance(world.generator,prop)
		var poly := Scenery.footprint(appearance.id)
		for i in poly.size(): poly[i] *= scale_value
		if Geometry2D.is_point_in_polygon(rel,poly): return false
		for i in poly.size():
			if rel.distance_to(Geometry2D.get_closest_point_to_segment(rel,poly[i],poly[(i+1)%poly.size()])) < radius: return false
		if roots and prop.kind < 2:
			var root_size := Vector2(49,24)*scale_value+Vector2.ONE*radius
			if Vector2(rel.x/root_size.x,rel.y/root_size.y).length_squared()<1: return false
	return true

func water_line(a: Vector2, b: Vector2) -> bool:
	var steps := maxi(1,ceili(a.distance_to(b)/40.0))
	for i in range(steps+1):
		if not world.generator.can_walk(a.lerp(b,float(i)/steps),20): return false
	return true

func prepare_navigation() -> void:
	if navigation_ready: return
	var start := Time.get_ticks_usec()
	var step := float(rules.navigation_step)
	var side := ceili(world.generator.extent/step)
	var origin := Vector2i((world.generator.spawn-Vector2.ONE*step*.5)/step)
	var queue: Array[Vector2i] = [origin]
	var visited := {origin:true}
	reachable[origin] = true
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		var a := (Vector2(cell)+Vector2.ONE*.5)*step
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+offset
			if next.x<0 or next.y<0 or next.x>=side or next.y>=side or visited.has(next): continue
			var b := (Vector2(next)+Vector2.ONE*.5)*step
			if not world.generator.can_walk(b,24): visited[next]=true; continue
			if not water_line(a,b): continue
			visited[next] = true
			reachable[next] = true
			queue.append(next)
	navigation_ready = true
	navigation_ms = (Time.get_ticks_usec()-start)/1000.0

func has_approach(p: Vector2, props: Array[Dictionary]) -> bool:
	prepare_navigation()
	var step := float(rules.navigation_step)
	var base := Vector2i(p/step)
	for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var c: Vector2i = base+offset
		if not reachable.has(c): continue
		var to := (Vector2(c)+Vector2.ONE*.5)*step
		if not water_line(p,to): continue
		var clear := true
		var count := maxi(1,ceili(p.distance_to(to)/12.0))
		for i in range(count+1):
			if not ground_clear(p.lerp(to,float(i)/count),11,props,false): clear=false; break
		if clear: return true
	return false

func raw_cell(cell: Vector2i) -> Array[Dictionary]:
	if raw_cells.has(cell): return raw_cells[cell]
	var rows: Array[Dictionary] = []
	var gen = world.generator
	var span := float(rules.cell_size)
	for anchor in int(rules.anchors_per_cell):
		var salt := 8800+anchor*37
		var center := (Vector2(cell)+Vector2(gen.random_at(cell.x,cell.y,salt),gen.random_at(cell.x,cell.y,salt+1)))*span
		var members := 1+int(gen.random_at(cell.x,cell.y,salt+2)*4)
		var cluster_roll: float = gen.random_at(cell.x,cell.y,salt+3)
		for member in members:
			var angle: float = gen.random_at(cell.x,cell.y,salt+4+member*3)*TAU
			var radius := sqrt(gen.random_at(cell.x,cell.y,salt+5+member*3))*float(rules.cluster_radius)
			var p := center+Vector2.from_angle(angle)*radius
			var row := {"id":"natural:031:%d:%d:%d:%d"%[cell.x,cell.y,anchor,member],"x":p.x,"y":p.y,"natural":true,"count":1,"reason":"","priority":gen.random_at(cell.x,cell.y,salt+19+member),"cluster":cluster_roll}
			if not gen.can_walk(p,24) or gen.sample(p).z>.32: row.reason="water_or_unwalkable"; rows.append(row); continue
			if p.distance_to(gen.spawn)<75: row.reason="spawn_clearance"; rows.append(row); continue
			var eco := ecology(p)
			var density := 0.0
			var weights: Dictionary = {}
			for biome in eco:
				var rule: Dictionary = rules.biomes[biome]
				density += float(rule.density)*float(eco[biome])
				for id in rule.weights: weights[id]=float(weights.get(id,0))+float(rule.weights[id])*float(eco[biome])
			var patch := smoothstep(-.28,.32,patch_noise.get_noise_2dv(p))
			# Continuous empty areas and clustered density; never a per-chunk quota.
			if patch<.14 or gen.random_at(cell.x,cell.y,salt+24+member)>density/28.125*patch*1.8:
				row.reason="sparse_patch"; rows.append(row); continue
			var props := nearby_props(p)
			var tree_distance := INF
			var source := ""
			for prop in props:
				if prop.kind < 2: tree_distance=minf(tree_distance,p.distance_to(prop.position))
			for id in weights.keys():
				var rule: Dictionary = rules.resources[id]
				if rule.has("source"):
					var found := false
					for prop in props:
						if prop.kind<2 and source_tag(prop)==rule.source and p.distance_to(prop.position)<=float(rule.source_distance): found=true; source=str(prop.id); break
					if not found: weights[id]=0.0
				if rule.has("tree_preference") and tree_distance>float(rule.tree_preference): weights[id]*=.18
				if rule.has("cluster_bias") and cluster_roll>float(rule.cluster_bias): weights[id]*=.12
			var total := 0.0
			for weight in weights.values(): total+=float(weight)
			var roll: float = gen.random_at(cell.x,cell.y,salt+28+member)*total
			var chosen := ""
			for id in weights:
				roll-=float(weights[id])
				if roll<0: chosen=id; break
			if chosen.is_empty(): row.reason="no_ecological_source"; rows.append(row); continue
			var rule: Dictionary = rules.resources[chosen]
			row.merge({"item_id":chosen,"mode":rule.mode,"spacing":rule.spacing,"ecology":eco,"source_id":source if rule.has("source") else ""})
			if chosen=="plant_fiber": row.count=4+int(abs(str(row.id).hash())%3)
			if not ground_clear(p,float(rule.ground_radius),props): row.reason="scenery_contact"
			elif not has_approach(p,props): row.reason="unreachable"
			rows.append(row)
	raw_cells[cell] = rows
	return rows

func chunk_distribution(coord: Vector2i) -> Dictionary:
	if chunk_cache.has(coord): return chunk_cache[coord]
	var start := Time.get_ticks_usec()
	var rect := Rect2(Vector2(coord)*world.Gen.CHUNK_PX,Vector2.ONE*world.Gen.CHUNK_PX)
	var span := float(rules.cell_size)
	# Include the complete candidate influence radius across every boundary.
	var halo := rect.grow(float(rules.cluster_radius)+120)
	var low := Vector2i(floori(halo.position.x/span),floori(halo.position.y/span))
	var high := Vector2i(floori(halo.end.x/span),floori(halo.end.y/span))
	var all: Array[Dictionary] = []
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1): all.append_array(raw_cell(Vector2i(x,y)))
	var accepted: Array[Dictionary] = []
	var rejected: Array[Dictionary] = []
	for raw in all:
		var p := Vector2(raw.x,raw.y)
		if not rect.has_point(p): continue
		var row: Dictionary = raw.duplicate(true)
		if str(row.reason).is_empty():
			for other in all:
				if not str(other.reason).is_empty() or row.id==other.id: continue
				var higher: bool = other.priority<row.priority or (other.priority==row.priority and str(other.id)<str(row.id))
				if higher and p.distance_to(Vector2(other.x,other.y))<maxf(float(row.spacing),float(other.spacing)):
					row.reason="resource_spacing"; break
		if str(row.reason).is_empty(): accepted.append(row)
		else: rejected.append(row)
	generation_ms = (Time.get_ticks_usec()-start)/1000.0
	var packet := {"accepted":accepted,"rejected":rejected,"ms":generation_ms}
	chunk_cache[coord] = packet
	return packet

func release_cache(coord: Vector2i) -> void:
	builds.unload(coord)
	camps.unload(coord)
	chunk_cache.erase(coord)
	# Keep caches bounded while travelling. All entries can be regenerated exactly.
	if raw_cells.size()>160: raw_cells.clear()
	if prop_cache.size()>180: prop_cache.clear()

static func build_distribution(gen: WildGenerator, configuration: Dictionary, navigation: Dictionary, coord: Vector2i) -> Dictionary:
	# The existing ItemService algorithm runs in the terrain worker using only its
	# private generator and caches; no scene tree, inventory or save access.
	var layer = load("res://scripts/item_service.gd").new()
	layer.world={"generator":gen,"Gen":load("res://scripts/world_generator.gd")}
	layer.rules=configuration
	layer.reachable=navigation
	layer.navigation_ready=true
	layer.patch_noise.seed=gen.world_seed ^ 87361
	layer.patch_noise.frequency=1.0/float(configuration.noise_scale)
	layer.patch_noise.fractal_octaves=2
	var result: Dictionary = layer.chunk_distribution(coord)
	var harvest_start := Time.get_ticks_usec()
	result["harvest"]=preload("res://scripts/harvest_distribution.gd").build(layer,coord)
	result["harvest_ms"]=(Time.get_ticks_usec()-harvest_start)/1000.0
	result["ms"]+=result.harvest_ms
	layer.free()
	return result

func install_chunk(coord: Vector2i) -> void:
	builds.install(coord)
	camps.install(coord)
	var packet := chunk_distribution(coord)
	if not packet.has("harvest"): packet["harvest"]=preload("res://scripts/harvest_distribution.gd").build(self,coord)
	for row in packet.harvest:
		if not consumed.has(row.id): create_harvest(row.id,row)
	for id in ore_nodes:
		var row = ore_nodes[id]
		if row is Dictionary and row.get("x") is float and row.get("y") is float and world.stream.chunk_at(Vector2(row.x,row.y))==coord and not consumed.has(id): create_ore(id,row)
	for entry in entries(coord): world.stream.create_item_drop(entry)
	for id in loose:
		var entry: Dictionary = loose[id]
		if world.stream.chunk_at(Vector2(entry.x,entry.y)) == coord: world.stream.create_item_drop(entry)

func pickup(drop: Node2D) -> bool:
	if not is_instance_valid(drop) or drop.get_meta("collected",false) or drop.get_meta("airborne",false): return false
	var id := str(drop.get_meta("drop_id"))
	var item_id := str(drop.get_meta("item_id"))
	var count := int(drop.get_meta("count",1))
	var equipment_item := bool(database.item(item_id).get("equippable",false)) or item_id=="field_lantern"
	var left := count
	if equipment_item:
		for i in range(8,40):
			if inventory.slots[i].is_empty():
				inventory.slots[i]=drop.get_meta("instance",inventory.instance(item_id)).duplicate(true)
				left=0
				inventory.changed.emit()
				break
	else: left=inventory.add(item_id,count)
	if left == count: notice.emit("背包已满，物品仍留在原地"); return false
	# Snapshot only after both inventory and world edit are committed.
	if left > 0:
		drop.set_meta("count",left)
		loose[id] = {"id":id,"item_id":item_id,"count":left,"x":drop.position.x,"y":drop.position.y,"mode":drop.get_meta("mode","pickup"),"origin":drop.get_meta("origin","remainder")}
	else:
		consumed[id] = true
		loose.erase(id)
		drop.set_meta("collected",true)
		world.stream.drops.erase(drop)
		drop.queue_free()
	if drop.get_meta("natural",false): consumed[id] = true
	dirty = true
	save_state()
	var verb := "采集" if drop.get_meta("mode","pickup")=="harvest" else "拾取"
	notice.emit("%s %s ×%d%s" % [verb,database.item(item_id).name,count-left," · 剩余%d留在原地"%left if left>0 else ""])
	return true

func discard(index: int, count: int = 1) -> bool:
	if index<0 or index>=inventory.slots.size() or inventory.slots[index].is_empty() or count<1: return false
	var p: Vector2 = world.player.position
	var place := Vector2.INF
	for offset in [Vector2(28,18),Vector2(-28,18),Vector2(0,32),Vector2(28,-18),Vector2(-28,-18),Vector2.ZERO]:
		if ground_clear(p+offset,10,nearby_props(p+offset),false) and world.stream.has_ground(p+offset): place=p+offset; break
	if place==Vector2.INF: notice.emit("附近没有可放下物品的地面"); return false
	var slot: Dictionary = inventory.slots[index]
	var amount := mini(count,int(slot.count))
	var id := ""
	while id.is_empty() or loose.has(id) or consumed.has(id):
		discard_serial+=1
		id="player:%d:%d"%[Time.get_unix_time_from_system()*1000,discard_serial]
	var entry := {"id":id,"item_id":slot.item_id,"count":amount,"x":place.x,"y":place.y,"origin":"player","mode":"pickup"}
	if database.item(slot.item_id).get("equippable",false) or slot.item_id=="field_lantern": entry["instance"]=slot.duplicate(true)
	# Create successfully before removing inventory; never use natural IDs.
	var animated := entry.duplicate(true)
	animated["drop_animation"]=true
	var node: Node2D = world.stream.create_item_drop(animated)
	if node==null: return false
	loose[id]=entry
	inventory.slots[index].count-=amount
	if int(inventory.slots[index].count)==0: inventory.slots[index]={}
	inventory.changed.emit()
	dirty=true
	save_state()
	notice.emit("放下 %s ×%d"%[database.item(entry.item_id).name,amount])
	return true

func _exit_tree() -> void:
	if dirty: save_state()

func create_harvest(id: String, row: Dictionary) -> Node2D:
	if consumed.has(id) or not preload("res://scripts/harvest_node.gd").configuration().resources.has(str(row.get("kind","flint_outcrop"))): return null
	for node in get_tree().get_nodes_in_group("world_interactables"):
		if not node.is_queued_for_deletion() and node.get_meta("ore_id","")==id: return node
	var node := preload("res://scripts/harvest_node.gd").new()
	node.service=self
	node.resource_id=id
	node.kind=str(row.get("kind","flint_outcrop"))
	node.position=Vector2(row.x,row.y)
	world.object_root.add_child(node)
	return node

func create_ore(id: String, row: Dictionary) -> Node2D:
	return create_harvest(id,row)

func debug_ore() -> Node2D:
	if not OS.has_feature("debug"): return null
	var p: Vector2=world.player.position
	for offset in [Vector2(32,24),Vector2(-32,24),Vector2(0,40),Vector2(40,0),Vector2(-40,0)]:
		var place: Vector2=p+offset
		if not world.stream.has_ground(place) or not ground_clear(place,12,nearby_props(place),false): continue
		var occupied := false
		for node in get_tree().get_nodes_in_group("world_interactables"):
			if node.position.distance_to(place)<28: occupied=true
		if occupied: continue
		var id := "ore:debug:"+str(ResourceUID.create_id())
		var row := {"x":place.x,"y":place.y}
		ore_nodes[id]=row
		var node := create_ore(id,row)
		dirty=true; save_state()
		notice.emit("已在脚边放置燧石矿点（调试） · 装备石镐，按住E连续开采")
		return node
	notice.emit("附近没有可放置矿点的空地")
	return null

func mine(target: Node2D) -> bool:
	return harvest_hit(target,"mine")

func harvest_hit(target: Node2D, action: String) -> bool:
	if not body.can_labor(action): return false
	if not is_instance_valid(target) or not inventory.has_capability(action) or target.get_meta("spent",false): return false
	var id := str(target.get_meta("ore_id",""))
	if id.is_empty() or consumed.has(id) or target.get("definition")==null: return false
	if action!=str(target.definition.action) or not preload("res://scripts/world_interaction.gd").in_reach(world.stream,world.player.position,target): return false
	var hits := int(resource_hits.get(id,0))+1
	body.spend_labor(action)
	var completed := hits>=int(target.definition.hits)
	# Persist all rewards and depletion in the same snapshot. No per-particle save.
	resource_hits[id]=hits
	var held: Dictionary=inventory.equipment.get("main_hand",{})
	inventory.wear_held(str(held.get("instance_id","")),action)
	if completed:
		var serial := 0
		var rewards: Dictionary=target.definition.drops.duplicate(true)
		if target.kind=="stone_outcrop":
			rewards.stone=12+int(abs(id.hash())%5)
			if abs((id+":flint").hash())%10<3: rewards.flint=1
		for item_id in rewards:
			var landing: Vector2=target.position
			# The just-mined footprint is now free. Keep other rewards separated.
			for offset in [Vector2(-18+serial*25,15),Vector2(0,18),Vector2.ZERO]:
				if world.generator.can_walk(target.position+offset,10) and ground_clear(target.position+offset,10,nearby_props(target.position+offset),false):
					landing=target.position+offset;break
			var entry := {"id":id+":loot:"+str(serial),"item_id":item_id,"count":int(rewards[item_id]),"x":landing.x,"y":landing.y,"origin":"excavated","mode":"pickup"}
			loose[entry.id]=entry
			var animated := entry.duplicate(true)
			animated["drop_animation"]=true
			world.stream.create_item_drop(animated)
			serial+=1
		consumed[id]=true
	target.feedback(world.player.position,completed)
	dirty=true;save_state()
	if completed: notice.emit("已完成 · 按E拾取掉落物")
	return true




