extends RefCounted
const Rules=preload("res://scripts/mine_rules.gd")
var service: Node
var chapter: RefCounted:
	get:return service.chapter
var travel: Dictionary={"serial":0,"inside":false}
var last_attempt:=-30000
var last_record_attempt:=-30000
var timer_ticks:=-1
var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/mine_rules.json"))
var s: Node:
	get:return service
var state: Dictionary:
	get:return chapter.state.mine
func at() -> Vector2:return Vector2(state.site.get("x",0),state.site.get("y",0))
func record_at() -> Vector2:
	var point: Dictionary=state.get("record_site",{})
	return Vector2(point.x,point.y) if not point.is_empty() else at()+Vector2(-115,55)
func find_record(site: Vector2) -> Vector2:
	var rng:=RandomNumberGenerator.new();rng.seed=s.world.world_seed^197356
	for i in 160:
		var candidate: Vector2=site+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(config.record_min_distance,config.record_max_distance)
		if chapter.clear_site(candidate,38) and s.ground_clear(candidate+Vector2(0,55),20,s.nearby_props(candidate)) and s.has_approach(candidate,s.nearby_props(candidate)):return candidate
	return Vector2.INF
func origin() -> Vector2:return Rules.origin(s.world.generator.extent)
func sync_recipe() -> void:
	if s.craft_book!=null and s.craft_book.recipes.has(config.recipe_id):s.craft_book.recipes[config.recipe_id].default_unlocked=state.recipe
func remaining_seconds() -> float:
	if state.phase!="armed":return 0.0
	if state.has("fuse_remaining_seconds"):return float(state.fuse_remaining_seconds)
	# Legacy armed saves keep their existing deadline, then adopt elapsed seconds.
	var seconds_per_minute: float=s.world.environment_view.simulation.day_length_minutes*60.0/1440.0
	return clampf((float(state.fuse_due)-chapter.now())*seconds_per_minute,0,float(config.fuse_seconds))
func valid(value: Variant) -> bool:
	if value is Dictionary and value.has("puzzle"):
		if not chapter.puzzle.valid(value.puzzle) or (value.puzzle.solved and value.get("phase")!="open"):return false
	if not value is Dictionary or not value.has_all(["site","investigated","recipe","phase","fuse_due","opened_at","entered"]):return false
	for key in ["investigated","recipe","entered"]:
		if not value[key] is bool:return false
	if value.phase not in ["sealed","armed","open"] or not value.site is Dictionary:return false
	for key in ["fuse_due","opened_at"]:
		if not (value[key] is float or value[key] is int) or not is_finite(float(value[key])) or value[key]<-1:return false
	if not value.site.is_empty():
		for axis in ["x","y"]:
			if not (value.site.get(axis) is float or value.site.get(axis) is int) or not is_finite(float(value.site[axis])) or value.site[axis]<300 or value.site[axis]>s.world.generator.extent-300:return false
	if (value.recipe or value.investigated or value.phase!="sealed") and value.site.is_empty():return false
	if value.phase=="armed" and (not value.recipe or value.fuse_due<0):return false
	if value.recipe and not value.investigated:return false
	if value.has("fuse_remaining_seconds"):
		var seconds=value.fuse_remaining_seconds
		if not (seconds is float or seconds is int) or not is_finite(float(seconds)) or seconds<0 or seconds>60:return false
		if value.phase=="open" and seconds!=0:return false
	if value.phase=="open" and (not value.recipe or value.fuse_due<0 or value.opened_at<0):return false
	if value.phase=="open" and not value.has("fuse_remaining_seconds") and value.opened_at+.000001<value.fuse_due:return false
	if value.has("record_site"):
		if not value.record_site is Dictionary:return false
		if not value.record_site.is_empty():
			for axis in ["x","y"]:
				if not (value.record_site.get(axis) is int or value.record_site.get(axis) is float) or not is_finite(float(value.record_site[axis])) or value.record_site[axis]<0 or value.record_site[axis]>=s.world.generator.extent:return false
	return not value.entered or value.phase=="open"
func safe(candidate: Vector2) -> bool:
	var gen=s.world.generator
	if gen.biome(candidate)!="岩石区" or not chapter.clear_site(candidate,145):return false
	for key in ["site","elder"]:
		if not chapter.state[key].is_empty() and candidate.distance_to(chapter.point(key))<600:return false
	for offset in [Vector2(-150,90),Vector2(150,90),Vector2(0,150),Vector2(0,-70)]:
		if not gen.can_walk(candidate+offset,24):return false
	# All authenticated observers, including currently unloaded chunks.
	for row in s.world.get_meta("network_observers",[]):
		if candidate.distance_to(Vector2(row.x,row.y))<1000:return false
	if candidate.distance_to(s.world.player.position)<1000:return false
	return true
func place() -> void:
	var gen=s.world.generator
	var rng:=RandomNumberGenerator.new();rng.seed=s.world.world_seed^825391
	for i in 1600:
		var candidate:=Vector2(rng.randf_range(400,gen.extent-400),rng.randf_range(400,gen.extent-400))
		if not safe(candidate):continue
		var record:=find_record(candidate)
		if record==Vector2.INF:continue
		var before: Dictionary=chapter.serialize()
		state.record_site={"x":record.x,"y":record.y}
		state.site={"x":candidate.x,"y":candidate.y}
		chapter.commit(before);return
func tick() -> void:
	var current: int=Time.get_ticks_msec()
	var elapsed: float=0.0 if timer_ticks<0 else maxf(0.0,float(current-timer_ticks)/1000.0)
	timer_ticks=current
	advance(elapsed)
func advance(delta: float=0.0) -> void:
	sync_recipe()
	chapter.puzzle.advance()
	if not s.writable or s.world.get_meta("network_game",false) or not chapter.state.bottle_read:return
	if travel.inside and not Rules.pocket(s.world.player.position,s.world.generator.extent) and s.combat.personal.phase!="alive":travel={"inside":false,"serial":int(travel.serial)+1}
	if state.site.is_empty() and chapter.now()>=chapter.state.mine_due and Time.get_ticks_msec()-last_attempt>=int(config.retry_seconds*1000):
		last_attempt=Time.get_ticks_msec();place()
	if not state.site.is_empty() and state.get("record_site",{}).is_empty() and Time.get_ticks_msec()-last_record_attempt>=15000:
		last_record_attempt=Time.get_ticks_msec()
		var record:=find_record(at())
		if record!=Vector2.INF:
			var before: Dictionary=chapter.serialize();state.record_site={"x":record.x,"y":record.y};chapter.commit(before)
	if state.phase=="armed":
		var remaining: float=remaining_seconds()
		state.fuse_remaining_seconds=maxf(0.0,remaining-maxf(0.0,delta));s.dirty=true
		if state.fuse_remaining_seconds<=.000001:
			state.fuse_remaining_seconds=0.0
			var before: Dictionary=chapter.serialize()
			state.phase="open";state.opened_at=chapter.now()
			chapter.commit(before)
func request(kind: String) -> String:
	var action: String="enter" if kind=="entrance" and state.phase=="open" else kind
	if action in ["enter","exit"] and is_instance_valid(s.chapter_view) and not s.world.get_meta("network_rules_host",false):
		s.chapter_view.transition.request(action);return ""
	return interact(kind)
func interact(kind: String) -> String:
	if preload("res://scripts/network_game_route.gd").send(s,"mine",[kind]):return ""
	if kind.begins_with("final:"):return chapter.finale.interact(kind.trim_prefix("final:"))
	if kind.begins_with("lamp:") or kind.begins_with("carving:") or kind=="chest":return chapter.puzzle.interact(kind)
	if not s.writable or s.body.down or s.body.sleep_active() or s.combat.personal.phase!="alive" or not s.world.player.action.is_empty() or not s.craft_job.is_empty():return "当前无法操作"
	if state.site.is_empty() or not chapter.state.bottle_read or chapter.now()<chapter.state.mine_due:return "尚未发现矿洞"
	var target:=record_at()+Vector2(0,12) if kind=="record" else at()+Vector2(0,55)
	if kind=="exit":target=origin()+Vector2(0,350)
	if kind not in ["record","entrance","place","enter","exit"]:return "无法在这里使用"
	if s.world.player.position.distance_to(target)>float(config.placement_radius):return "请靠近矿洞的操作位置"
	var view=s.chapter_view.get_node_or_null("MineView")
	var prop: Node2D=view.targets.get("exit" if kind=="exit" else "record" if kind=="record" else "entrance") if view!=null else null
	if not s.world.stream.clear_reach(s.world.player.position,target,prop):return "前方有障碍"
	var before: Dictionary=chapter.serialize()
	if kind=="record":
		state.recipe=true;state.investigated=true
		if not chapter.commit(before):return "保存失败，请再试一次"
		sync_recipe()
		return "矿工的残页\n普通石镐已经撬不动这些石块了……用纤维扎紧铜矿石、燧石和遗物碎片，遗物的余光便能震松塌方。\n\n已记下「矿工爆破包」的制作方法。"
	if kind in ["enter","exit"]:
		if state.phase!="open":return "入口仍被塌方封住"
		if (kind=="exit")!=bool(travel.inside):return "你已在这一侧"
		var old_travel:=travel.duplicate(true);var old_position: Vector2=s.world.player.position
		var transition: CanvasLayer=s.chapter_view.transition if is_instance_valid(s.chapter_view) and not s.world.get_meta("network_rules_host",false) else null
		if transition!=null:transition.cover_now()
		travel={"inside":kind=="enter","serial":int(travel.serial)+1}
		state.entered=true
		s.world.player.position=origin()+Vector2(0,275) if kind=="enter" else at()+Vector2(0,110)
		if not chapter.commit(before):
			travel=old_travel;s.world.player.position=old_position
			if transition!=null:transition.prepare_reveal()
			return "保存失败，请再试一次"
		s.world.player.velocity=Vector2.ZERO;s.world.player.reset_physics_interpolation();s.world.player.camera.reset_smoothing()
		if transition!=null:transition.prepare_reveal()
		return ""
	if kind=="entrance":
		if state.phase=="open":return interact("enter")
		if state.phase=="armed":return "引线正在燃烧……"
		if not state.investigated:
			state.investigated=true
			if not chapter.commit(before):return "保存失败，请再试一次"
			return "入口被塌落的巨石堵住了。附近还留着矿工作业的痕迹。"
		if state.recipe and count_pack()>0:return interact("place")
		return "入口被塌落的巨石堵住了。"
	if state.phase!="sealed":return "这里已安放过爆破包"
	if not state.recipe:return "还不知道如何处理这处塌方"
	if count_pack()==0:return "没有矿工爆破包"
	var slots: Array=s.inventory.slots.duplicate(true)
	for i in s.inventory.slots.size():
		if s.inventory.slots[i].get("item_id","")=="miner_blast_pack":
			s.inventory.slots[i].count-=1
			if s.inventory.slots[i].count==0:s.inventory.slots[i]={}
			break
	state.phase="armed";state.fuse_remaining_seconds=float(config.fuse_seconds);timer_ticks=Time.get_ticks_msec()
	state.fuse_due=chapter.now()+float(config.fuse_seconds)*1440.0/(s.world.environment_view.simulation.day_length_minutes*60.0)
	if not chapter.commit(before,slots):return "保存失败，爆破包已保留"
	s.inventory.changed.emit();return ""
func count_pack() -> int:
	var count:=0
	for slot in s.inventory.slots:
		if slot.get("item_id","")=="miner_blast_pack":count+=int(slot.count)
	return count

func continuation() -> Dictionary:
	return {"entrance_open":state.phase=="open","entered":state.entered,"interior_origin":{"x":origin().x,"y":origin().y},"extension":"north_rock_boundary","next":chapter.puzzle.continuation()}
