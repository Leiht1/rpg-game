extends Node2D
## F7 development-only distribution overlay, reads the same cached world layer.
var world: Node
var panel := PanelContainer.new()
var details := Label.new()
var seed_input := LineEdit.new()
var active := false
var timer := 0.0
var packet: Dictionary = {}

func configure(owner_world: Node) -> void:
	world=owner_world
	z_index=20
	panel.position=Vector2(860,100)
	panel.custom_minimum_size=Vector2(400,0)
	panel.theme=preload("res://scripts/item_ui_style.gd").theme()
	panel.add_theme_stylebox_override("panel",preload("res://scripts/item_ui_style.gd").frame())
	world.ui.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var heading := Label.new()
	heading.text="自然资源 · F7关闭 · ×拒绝 ○未采 ◇已采"
	box.add_child(heading)
	box.add_child(details)
	details.add_theme_font_size_override("font_size",12)
	var row := HBoxContainer.new()
	box.add_child(row)
	seed_input.text=str(world.world_seed)
	seed_input.custom_minimum_size.x=170
	seed_input.focus_entered.connect(func():world.player.input_blocked=true; world.player.cancel_action())
	seed_input.focus_exited.connect(func():world.item_ui.call_deferred("update_input_block"))
	row.add_child(seed_input)
	var apply := Button.new()
	apply.text="切换临时Seed"
	row.add_child(apply)
	apply.pressed.connect(func():
		if not seed_input.text.is_valid_int(): return
		world.item_service.save_state()
		Engine.set_meta("resources_debug_seed",int(seed_input.text))
		world.persistent_world=false
		world.item_service.dirty=false
		get_tree().reload_current_scene())
	panel.hide()
	visibility_changed.connect(func():panel.visible=visible and active)

func _input(event: InputEvent) -> void:
	if OS.has_feature("debug") and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F7:
		active=not active
		panel.visible=active
		if not active: seed_input.release_focus()
		timer=1
		queue_redraw()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active: return
	timer+=delta
	if timer<.4: return
	timer=0
	var service: Node = world.item_service
	var c: Vector2i = world.stream.chunk_at(world.player.position)
	packet=service.chunk_distribution(c).duplicate(true)
	# Loose stone stays retired; sparse flint uses the existing accepted candidates.
	packet.accepted=packet.accepted.filter(func(row):return str(row.item_id) != "stone")
	var counts := {}
	var reasons := {}
	var removed := 0
	var closest := {}
	var distance := INF
	for row in packet.accepted:
		if service.consumed.has(row.id): removed+=1
		else: counts[row.item_id]=int(counts.get(row.item_id,0))+1
	for row in packet.rejected: reasons[row.reason]=int(reasons.get(row.reason,0))+1
	for row in packet.accepted+packet.rejected:
		var d: float = world.player.position.distance_to(Vector2(row.x,row.y))
		if d<distance: distance=d; closest=row
	var text := "%s · %s\n区块%s · 原始%d / 可见%d / 已采%d\n有效陆地资源密度 %.2f / 24²格\n"%[service.RESOURCE_VERSION,world.generator.biome(world.player.position),str(c),packet.accepted.size(),packet.accepted.size()-removed,removed,land_density(c,packet.accepted.size())]
	for id in counts: text+="%s:%d  "%[service.database.item(id).name,counts[id]]
	text+="\n拒绝：%s\n"%str(reasons)
	if not closest.is_empty():
		text+="最近ID：%s\n状态：%s\n生态：%s\n规则：%s\n"%[closest.id,"已采集" if service.consumed.has(closest.id) else "未采集" if closest.reason=="" else closest.reason,str(closest.get("ecology",service.ecology(Vector2(closest.x,closest.y)))),str(service.rules.resources.get(closest.get("item_id",""),{}))]
	text+="生成 %.1fms · 导航一次 %.1fms\n物品画稿已确认并正式接入"%[service.generation_ms,service.navigation_ms]
	details.text=text
	details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x=370
	queue_redraw()

func land_density(c: Vector2i, count: int) -> float:
	var land := 0
	for y in 8:
		for x in 8:
			if world.generator.can_walk((Vector2(c)+Vector2((x+.5)/8,(y+.5)/8))*world.Gen.CHUNK_PX,20): land+=1
	return count*64.0/maxi(1,land)

func _draw() -> void:
	if not active or packet.is_empty(): return
	for row in packet.rejected:
		var p := Vector2(row.x,row.y)
		draw_line(p-Vector2(3,3),p+Vector2(3,3),Color(1,.35,.3,.6),1,true)
		draw_line(p-Vector2(3,-3),p+Vector2(3,-3),Color(1,.35,.3,.6),1,true)
	for row in packet.accepted:
		var p := Vector2(row.x,row.y)
		var consumed: bool = world.item_service.consumed.has(row.id)
		draw_arc(p,float(row.spacing)*.5,0,TAU,24,Color(.9,.75,.3,.5) if consumed else Color(.4,1,.6,.4),1,true)
		if consumed: draw_polyline(PackedVector2Array([p+Vector2(0,-6),p+Vector2(6,0),p+Vector2(0,6),p+Vector2(-6,0),p+Vector2(0,-6)]),Color("e8cb64"),1,true)
