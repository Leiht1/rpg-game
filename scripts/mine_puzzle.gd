extends RefCounted
## World-owned incremental state. Every write uses the chapter inventory transaction.
const RECORD="ancient_mine_record"
const OBSERVATIONS=["壁刻·刻痕\n几道纤细的刻痕从岩缝中伸出，顶端分成两片小叶，像是某种刚刚破土的植物。","壁刻·刻纹\n岩面上刻着一个圆形，周围有细长的光线向外散开，仿佛正在照亮四周。","壁刻·旧痕\n几片卷曲的叶子散落在刻痕之间，叶缘已经干枯，似乎正被风吹向地面。","壁刻·细纹\n细密的裂纹向四周延伸，形状像冻结的水，坚硬而冰冷。"]
const RECORD_TEXT="古老的路线记录\n这里似乎还有路……"
var route_hint:=preload("res://scripts/mine_route_hint.gd").new()
var s: Node
var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/mine_puzzle.json"))
var state: Dictionary:
	get:return s.chapter.mine.state.puzzle
static func initial() -> Dictionary:
	return {"version":2,"order":[],"progress":0,"solved":false,"rubble_fallen":false,"vein_unlocked":false,"chest_open":false,"claimed":false,"read":false,"read_at":-1.0,"next_due":-1.0,"ores":[{"hits":0,"depleted_at":-1.0,"respawn_at":-1.0},{"hits":0,"depleted_at":-1.0,"respawn_at":-1.0},{"hits":0,"depleted_at":-1.0,"respawn_at":-1.0}]}
func migrate(value: Dictionary) -> Dictionary:
	var result: Dictionary=value.duplicate(true)
	if result.get("version")==1:
		# Legacy progress was always the correct prefix. Preserve it and all rewards.
		result.version=2;result.order=[]
		for i in int(result.progress):result.order.append(i)
	# JSON whole numbers decode as floats; normalize identities before membership tests.
	if int(result.version)==2:
		result.version=2;result.progress=int(result.progress)
		result.order=result.order.map(func(id):return int(id))
	return result
func valid(v: Variant) -> bool:
	var keys: Array=initial().keys();keys.erase("order")
	if not v is Dictionary or not v.has_all(keys) or not number(v.version,1,2) or v.version!=floor(v.version):return false
	if not number(v.progress,0,4) or v.progress!=floor(v.progress):return false
	if int(v.version)==2:
		if not v.get("order") is Array or v.order.size()!=int(v.progress):return false
		var seen: Array=[]
		for id in v.order:
			if not number(id,0,3) or id!=floor(id) or int(id) in seen:return false
			seen.append(int(id))
		if v.progress==4 and seen!=[0,1,2,3]:return false
	for key in ["solved","rubble_fallen","vein_unlocked","chest_open","claimed","read"]:
		if not v[key] is bool:return false
	if v.solved!=(v.progress==4) or v.rubble_fallen!=v.solved or v.vein_unlocked!=v.solved or v.chest_open!=v.claimed:return false
	if v.claimed and not v.solved or v.read and not v.claimed:return false
	for key in ["read_at","next_due"]:
		if not number(v[key],-1,1e15):return false
	if v.read and (v.read_at<0 or v.next_due<v.read_at+1440 or v.next_due>v.read_at+2880):return false
	if not v.read and (v.read_at!=-1 or v.next_due!=-1):return false
	if not v.ores is Array or v.ores.size()!=3:return false
	for row in v.ores:
		if not row is Dictionary or not row.has_all(["hits","depleted_at","respawn_at"]):return false
		if not number(row.hits,0,config.hits) or row.hits!=floor(row.hits):return false
		if not number(row.depleted_at,-1,1e15) or not number(row.respawn_at,-1,1e15):return false
		if row.hits==config.hits:
			if row.depleted_at<0 or not is_equal_approx(float(row.respawn_at-row.depleted_at),float(config.respawn_days)*1440):return false
		elif row.depleted_at!=-1 or row.respawn_at!=-1:return false
		if not v.solved and row.hits!=0:return false
	return true
static func number(v: Variant, lo: float, hi: float) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and v>=lo and v<=hi
func point(kind: String, index: int=0) -> Vector2:
	var a: Array=config[kind][index] if kind in ["lamps","carvings","ores"] else config[kind]
	return s.chapter.mine.origin()+Vector2(a[0],a[1])
func advance() -> void:
	if not s.writable or s.world.get_meta("network_game",false) or not state.solved:return
	for i in state.ores.size():
		var row: Dictionary=state.ores[i]
		if row.respawn_at>=0 and s.chapter.now()>=row.respawn_at:
			var before: Dictionary=s.chapter.serialize()
			state.ores[i]={"hits":0,"depleted_at":-1.0,"respawn_at":-1.0}
			s.chapter.commit(before)
func ready() -> bool:
	return s.writable and s.chapter.mine.travel.inside and s.chapter.mine.state.phase=="open" and not s.body.down and not s.body.sleep_active() and s.combat.personal.phase=="alive" and s.craft_job.is_empty()
func interact(kind: String) -> String:
	if not ready() or not s.world.player.action.is_empty():return "当前无法操作"
	var parts:=kind.split(":");var id: int=int(parts[1]) if parts.size()==2 and parts[1].is_valid_int() else -1
	var target: Vector2
	if parts[0] in ["lamp","carving"]:
		if id<0 or id>3:return "无效的刻记"
		target=point("lamps" if parts[0]=="lamp" else "carvings",id)
	elif kind=="chest":target=point(kind)
	else:return "无效操作"
	if s.world.player.position.distance_to(target)>float(config.range):return "请靠近再调查"
	if parts[0]=="carving":return OBSERVATIONS[id]
	var before: Dictionary=s.chapter.serialize()
	if parts[0]=="lamp":
		if state.solved:return ""
		if id in state.order:return ""
		state.order.append(id);state.progress=state.order.size()
		var failed: bool=false
		if state.progress==4:
			if state.order==[0,1,2,3]:state.solved=true;state.rubble_fallen=true;state.vein_unlocked=true
			else:state.order.clear();state.progress=0;failed=true
		if not s.chapter.commit(before):return "保存失败，请再试一次"
		if failed:return "四盏灯同时一颤，光熄灭了。"
		return ""
	if not state.solved:return "碎石挡住了这里"
	if state.claimed:
		if not read_record():return "保存失败，请再试一次"
		return RECORD_TEXT
	var slots: Array=s.inventory.slots.duplicate(true)
	if s.inventory.add(RECORD,1)!=0:
		s.inventory.slots.assign(slots);s.inventory.changed.emit();return "背包已满，请留出一格"
	state.claimed=true;state.chest_open=true
	if not s.chapter.commit(before,slots):return "保存失败，记录仍在箱中"
	s.inventory.changed.emit();s.item_obtained.emit(RECORD,1)
	return "木箱中留着一份古老的路线记录。"
func read_record() -> bool:
	if not s.writable or not state.claimed:return false
	if state.read:return true
	var before: Dictionary=s.chapter.serialize()
	state.read=true;state.read_at=s.chapter.now();state.next_due=state.read_at+1440.0*(1+posmod(s.world.world_seed^73931,2))
	return s.chapter.commit(before)
func hit(target: Node2D) -> bool:
	advance()
	var i: int=target.get_meta("crystal_index",-1)
	if i<0 or i>=3 or not ready() or not state.vein_unlocked or state.ores[i].hits>=int(config.hits):return false
	if not s.inventory.has_capability("mine") or not s.body.can_labor("mine",s.world.player.action=="mine"):return false
	if not preload("res://scripts/world_interaction.gd").in_reach(s.world.stream,s.world.player.position,target):return false
	var before: Dictionary=s.chapter.serialize();var slots: Array=s.inventory.slots.duplicate(true)
	var equipment: Dictionary=s.inventory.equipment.duplicate(true);var links: Dictionary=s.inventory.hotbar_equipment.duplicate(true);var body: Dictionary=s.body.serialize()
	var row: Dictionary=state.ores[i]
	row.hits=mini(int(config.hits),int(row.hits)+s.inventory.harvest_power())
	var complete: bool=row.hits>=int(config.hits)
	if complete and s.inventory.add("crystal",int(config["yield"]))!=0:
		s.chapter.state=before;s.inventory.slots.assign(slots);s.inventory.changed.emit();s.notice.emit("背包已满，矿石仍在这里");return false
	s.body.spend_labor("mine")
	s.inventory.wear_held(str(s.inventory.equipment.get("main_hand",{}).get("instance_id","")),"mine")
	if complete:row.depleted_at=s.chapter.now();row.respawn_at=row.depleted_at+float(config.respawn_days)*1440
	if not s.chapter.commit(before,slots):
		s.inventory.equipment=equipment;s.inventory.hotbar_equipment=links;s.body.restore(body);s.inventory.changed.emit();s.notice.emit("保存失败，矿石与工具已恢复");return false
	target.feedback(s.world.player.position,complete)
	if complete:s.item_obtained.emit("crystal",int(config["yield"]));AudioFX.play_sfx("sfx_ore_break",target.position)
	return true
func continuation() -> Dictionary:
	var hint: Dictionary=route_hint.resolve(s)
	return {"record_read":state.read,"available_at":state.next_due,"eligible":state.read and s.chapter.now()>=state.next_due,"landmarks":hint.get("landmarks",[]),"route":hint}
