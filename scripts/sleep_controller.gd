extends RefCounted
## Single character sleep lifecycle; the world owns every elapsed-time step.
const Rules = preload("res://scripts/sleep_rules.gd")
var service: Node
var symbols: Label
var last_reason := ""
var head_cover := preload("res://scripts/sleep_head_cover.gd").new()

static func valid_session(value: Variant, body: Dictionary) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true # body V1/V2 legacy migration
	if value.get("version")!=1 or value.get("phase") not in ["align","lie","sleep","wake"]: return false
	if not value.get("vertical",false) is bool: return false
	if not value.get("source") is String or Rules.facility(value.source).is_empty() or not value.get("id") is String or not value.get("reason") is String: return false
	for key in ["clock","rate","target","max_minutes","x","y","exit_x","exit_y","start_day","start_minute"]:
		var n=value.get(key)
		if not (n is int or n is float) or not is_finite(float(n)) or float(n)<0 or float(n)>10000000: return false
	if value.clock>float(Rules.data().legacy_phase_seconds.get(value.phase,100000)) or value.target>100 or value.target<=0: return false
	var config := Rules.facility(value.source)
	if (not is_equal_approx(value.rate,config.rate) and not config.get("legacy_rates",[]).any(func(rate):return is_equal_approx(value.rate,float(rate)))) or value.max_minutes<=0 or value.max_minutes>config.max_minutes: return false
	if bool(body.get("sleeping",false))!=(value.phase=="sleep"): return false
	if bool(body.get("sleep_forced",false))!=(value.source=="forced"): return false
	if value.source=="forced" and (not value.id.is_empty() or value.get("vertical",false)): return false
	if not is_equal_approx(float(body.get("sleep_duration",0)),value.max_minutes): return false
	if value.phase=="sleep" and float(body.get("energy",100))>=value.target: return false
	return true

func active() -> bool:
	return service.body.sleep_active()

func valid_pair(body: RefCounted, objects: Dictionary) -> bool:
	var s: Dictionary=body.sleep_session
	var extent: float=service.world.generator.extent
	if not s.is_empty():
		for key in ["x","y","exit_x","exit_y"]:
			if float(s[key])>extent: return false
		if s.source!="forced":
			if not objects.has(s.id): return s.phase=="wake" and s.reason=="facility_lost"
			var row: Dictionary=objects[s.id]
			if row.kind!=s.source or row.get("vertical",false)!=s.get("vertical",false) or not is_equal_approx(row.x,s.x) or not is_equal_approx(row.y,s.y): return false
			if row.get("sleep_state","PLACED") not in (["RESERVED"] if s.phase in ["align","lie"] else ["IN_USE"] if s.phase=="sleep" else ["RESERVED","IN_USE"]): return false
	for id in objects:
		if objects[id].get("sleep_state","PLACED")!="PLACED" and (s.is_empty() or s.id!=id):
			var owner:=str(objects[id].get("network_sleep_owner",""))
			if (service.world.get_meta("network_game",false) or service.world.get_meta("network_rules_host",false)) and not owner.is_empty() and owner!=str(service.world.get_meta("network_player_id","")):continue
			return false
	return true

func ready_reason() -> String:
	var w=service.world
	if not service.writable: return "存档受保护，无法睡眠"
	if active(): return "正在休息"
	if w.get_viewport().gui_is_dragging(): return "请先结束物品拖拽"
	if service.body.down: return "身体正在休养"
	if not w.player.action.is_empty() or service.craft_busy or not service.craft_job.is_empty() or service.camps.busy or service.builds.busy: return "请等待当前动作完成"
	return ""

func available(id: String) -> bool:
	return service.builds.states.has(id) and not service.builds.states[id].get("abandoned",false) and not Rules.facility(str(service.builds.states[id].kind)).is_empty() and service.builds.states[id].get("sleep_state","PLACED")=="PLACED"

func start(id: String, option: String="maximum", forced: bool=false) -> String:
	if preload("res://scripts/network_game_route.gd").send(self,"sleep",[id,option]):return ""
	var error := ready_reason()
	if not error.is_empty(): return error
	var w=service.world
	var p=w.player
	var source := "forced"
	var anchor: Vector2=p.position
	if not forced:
		if not available(id): return "设施无法使用"
		var row: Dictionary=service.builds.states[id]
		source=row.kind;anchor=Vector2(row.x,row.y)
		var rain: float=w.environment_view.simulation.blend.y+w.environment_view.simulation.blend.z
		if rain>0.01 and not preload("res://scripts/weather_exposure.gd").covered(service,preload("res://scripts/weather_exposure.gd").sleep_point(row)): return "床铺正在淋雨"
		var bounds: Rect2=service.builds.footprint_rect(row)
		var edge: Vector2=anchor+(p.position-anchor).clamp(bounds.position,bounds.end)
		if p.position.distance_to(edge)>=100: return "请靠近睡眠设施"
		if not path_clear(p.position,edge,id): return "无法到达睡眠位置"
	if option not in ["nap","target","full","maximum"]: return "睡眠目标无效"
	var config := Rules.facility(source)
	var target: float=float(Rules.data().target_energy) if option=="target" else float(Rules.data().full_energy) if option=="full" else 100.0
	if forced: target=100
	if service.body.energy>=target: return "当前精力已达到目标"
	var duration: float=minf(float(Rules.data().nap_minutes),float(config.max_minutes)) if option=="nap" and not forced else float(config.max_minutes)
	var old: Dictionary=service.body.serialize()
	var previous: Dictionary=service.builds.states.duplicate(true)
	service.body.sleep_forced=forced;service.body.sleep_elapsed=0;service.body.sleep_duration=duration
	service.body.sleep_session={"version":1,"phase":"sleep","clock":0.0,"source":source,"id":id,"rate":config.rate,"target":target,"max_minutes":duration,"x":anchor.x,"y":anchor.y,"exit_x":p.position.x,"exit_y":p.position.y,"start_day":w.environment_view.simulation.day,"start_minute":w.environment_view.simulation.minute,"reason":""}
	service.body.sleeping=true
	if not forced: service.builds.states[id].sleep_state="IN_USE"
	service.body.sleep_session.vertical=false if forced else service.builds.states[id].vertical
	if not service.save_state():
		service.body.restore(old);service.builds.states=previous;return "保存失败，未开始睡眠"
	w.item_ui.close_panels();w.camp_ui.close_panel()
	if is_instance_valid(service.industry_ui):service.industry_ui.close_panel()
	if w.map_view.visible: w.map_view.close_map()
	if is_instance_valid(service.storage_ui): service.storage_ui.close_panel()
	p.cancel_action();p.moving=false;p.running=false;p.velocity=Vector2.ZERO
	w.item_ui.update_input_block()
	render()
	p.reset_physics_interpolation();p.character.reset_physics_interpolation()
	return ""

func path_clear(from: Vector2, to: Vector2, id: String) -> bool:
	var w=service.world
	var circle := CircleShape2D.new();circle.radius=10
	var query := PhysicsShapeQueryParameters2D.new();query.shape=circle;query.collision_mask=1
	var excluded: Array[RID]=[w.player.get_rid()]
	if service.builds.visuals.has(id) and is_instance_valid(service.builds.visuals[id]): excluded.append(service.builds.visuals[id].body.get_rid())
	query.exclude=excluded
	for i in range(maxi(1,ceili(from.distance_to(to)/5.0))+1):
		var point := from.lerp(to,float(i)/maxi(1,ceili(from.distance_to(to)/5.0)))
		if not w.generator.can_walk(point,10): return false
		query.transform=Transform2D(0,point)
		if not w.get_world_2d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	return true

func interrupt(reason: String="manual") -> void:
	if preload("res://scripts/network_game_route.gd").send(self,"wake",[]):return
	if not active(): return
	if service.body.sleep_session.is_empty(): migrate_legacy()
	if service.body.sleep_session.is_empty(): return
	service.body.sleep_session.reason=reason
	finish()

func migrate_legacy() -> void:
	if not service.body.sleeping or not service.body.sleep_session.is_empty(): return
	var b=service.body;var p=service.world.player
	var source := "forced"
	b.sleep_forced=true
	b.sleep_session={"version":1,"phase":"sleep","clock":0.0,"source":source,"id":"","rate":Rules.facility(source).rate,"target":100.0,"max_minutes":minf(b.sleep_duration,180),"x":p.position.x,"y":p.position.y,"exit_x":p.position.x,"exit_y":p.position.y,"start_day":service.world.environment_view.simulation.day,"start_minute":service.world.environment_view.simulation.minute,"reason":""}
	b.sleep_duration=minf(b.sleep_duration,180)
	# An old voluntary session beyond this bound safely wakes without replaying time.
	if b.sleep_elapsed>=b.sleep_duration: b.sleeping=false;finish()

func advance(seconds: float) -> void:
	migrate_legacy()
	if not active(): return
	var b=service.body;var session: Dictionary=b.sleep_session
	# Old candidate transitions are cancelled safely, never replayed.
	if session.phase!="sleep" or not b.sleeping:
		finish();return
	if session.source!="forced" and (not service.builds.states.has(session.id) or service.builds.states[session.id].kind!=session.source):
		interrupt("facility_lost");return
	session.clock+=seconds
	render()

func after_body() -> void:
	var s: Dictionary=service.body.sleep_session
	if not s.is_empty() and s.phase=="sleep" and not service.body.sleeping: finish()

func finish() -> void:
	var b=service.body;var s: Dictionary=b.sleep_session
	if s.is_empty(): return
	if s.phase=="wake": s.clock=minf(s.clock,float(Rules.data().legacy_phase_seconds.wake))
	var row: Dictionary=service.builds.states.get(s.id,{})
	if not row.is_empty():
		if row.kind=="sleeping_bag" and row.get("sleep_state")=="IN_USE": service.builds.states.erase(s.id)
		else: row.sleep_state="PLACED"
	last_reason=s.reason
	b.sleeping=false;b.sleep_session={};b.sleep_forced=false
	if not service.save_state():
		# IN_USE was already committed before recovery started. Keep the completed
		# one-way lifecycle in memory and retry the original atomic autosave; never
		# lock controls forever or make an already-used bag available again.
		service.dirty=true;service.notice.emit("已醒来，存档暂不可写；状态将在下次自动保存时重试")
	var p=service.world.player
	p.position=Vector2(s.exit_x,s.exit_y);p.velocity=Vector2.ZERO;p.character.position=-p.ANCHOR
	p.update_animation()
	p.reset_physics_interpolation();p.character.reset_physics_interpolation()
	p.queue_redraw()
	if not row.is_empty() and not service.builds.states.has(s.id): service.builds.refresh_around(row)
	elif service.builds.visuals.has(s.id) and is_instance_valid(service.builds.visuals[s.id]): service.builds.visuals[s.id].show()
	if is_instance_valid(symbols): symbols.hide()
	if is_instance_valid(service.sleep_ui): service.sleep_ui.wake.hide()
	service.world.item_ui.update_input_block()

func render() -> void:
	if not active(): return
	var w=service.world;var p=w.player;var s: Dictionary=service.body.sleep_session
	if s.is_empty(): return
	# Keep normal world Y sorting: support beneath the actor, local quilt above it.
	if s.phase!="align" and s.source!="forced": p.position=Vector2(s.x,s.y)+Vector2(0,1)
	p.moving=false;p.running=false;p.velocity=Vector2.ZERO
	var head_anchor: Vector2=head_cover.render(p,s,service.builds)
	p.update_animation()
	if not is_instance_valid(symbols):
		symbols=Label.new();symbols.name="SleepSymbols";symbols.text="z  z  z";symbols.add_theme_font_size_override("font_size",17)
		symbols.add_theme_color_override("font_color",Color("e8e0c1"));symbols.add_theme_color_override("font_outline_color",Color("72644f"));symbols.add_theme_constant_override("outline_size",3)
		symbols.mouse_filter=Control.MOUSE_FILTER_IGNORE;p.add_child(symbols)
	symbols.visible=s.phase=="sleep" and service.body.sleeping
	symbols.position=head_anchor+Vector2(-12,-38+sin(float(s.clock)*1.5)*2)
	var canvas: Transform2D=p.get_viewport().get_canvas_transform()
	var screen: Vector2=canvas*p.to_global(symbols.position)
	var extent: Vector2=symbols.get_minimum_size()*canvas.get_scale().abs()
	var bounds: Vector2=p.get_viewport_rect().size
	screen=screen.clamp(Vector2(8,8),(bounds-extent-Vector2(8,8)).max(Vector2(8,8)))
	symbols.position=p.to_local(canvas.affine_inverse()*screen)

static func art_path(name_value: String) -> String:
	var formal := "res://assets/sleep/v1/"+name_value+".png"
	if ResourceLoader.exists(formal): return formal
	return ""

