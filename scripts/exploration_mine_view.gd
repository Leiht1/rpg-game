extends Node2D
const BLAST_OFFSET:=Vector2(0,-30)
var s: Node
var targets: Dictionary={}
var exterior: Node2D
var record_view: Node2D
var rubble: Sprite2D
var pack: Sprite2D
var barrier: StaticBody2D
var interior: Node2D
var last_phase:=""
var blast:=preload("res://scripts/mine_blast_effect.gd").new()
var countdown:=Label.new()
var shown_remaining:=0.0
var was_armed:=false
func _ready() -> void:
	blast.configure(s.chapter.mine.config.blast_visual.manifest,float(s.chapter.mine.config.blast_visual.width));add_child(blast)
	countdown.size=Vector2(64,58);countdown.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	countdown.add_theme_font_size_override("font_size",44)
	countdown.add_theme_color_override("font_color",Color("fff6df"))
	countdown.add_theme_color_override("font_outline_color",Color("39271d"));countdown.add_theme_constant_override("outline_size",6)
	countdown.mouse_filter=Control.MOUSE_FILTER_IGNORE;countdown.z_index=20;s.world.ui.add_child(countdown);countdown.hide()
var mine: RefCounted:
	get:return s.chapter.mine
func sprite(parent: Node2D, file: String, width: float, at: Vector2) -> Sprite2D:
	var node:=Sprite2D.new();node.texture=load("res://assets/exploration/mine-v1/"+file+".png")
	node.scale=Vector2.ONE*(width/node.texture.get_width());node.position=at;parent.add_child(node);return node
func target(parent: Node2D, kind: String, at: Vector2) -> Node2D:
	var node:=Node2D.new();node.position=parent.global_position+at;node.set_meta("mine_kind",kind)
	node.set_meta("display_name",{"entrance":"废弃矿洞","record":"旧工具箱","exit":"矿洞出口"}[kind]);node.set_meta("interaction_action","inspect");node.set_meta("interaction_range",82.0)
	node.add_to_group("world_interactables");s.world.object_root.add_child(node);targets[kind]=node;return node
func body(parent: Node2D, at: Vector2, size: Vector2) -> StaticBody2D:
	var node:=StaticBody2D.new();node.position=at;parent.add_child(node)
	var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=size;collider.shape=shape;node.add_child(collider);return node
func build_exterior() -> void:
	exterior=Node2D.new();exterior.position=mine.at();s.world.object_root.add_child(exterior)
	sprite(exterior,"entrance",310,Vector2(0,-72))
	rubble=sprite(exterior,"rubble",188,Vector2(0,-14))
	barrier=body(exterior,Vector2(0,-15),Vector2(180,100))
	# The painted shell is solid, including the back and the roof. Only the
	# foreground threshold is walkable; E transfers into the separate room.
	var shell:=StaticBody2D.new();shell.name="MineShell";exterior.add_child(shell)
	var outline:=CollisionPolygon2D.new()
	outline.polygon=PackedVector2Array([Vector2(-151,23),Vector2(-148,-52),Vector2(-110,-128),Vector2(-22,-169),Vector2(40,-160),Vector2(112,-124),Vector2(151,-42),Vector2(151,23),Vector2(66,23),Vector2(62,0),Vector2(-62,0),Vector2(-66,23)])
	shell.add_child(outline)
	pack=sprite(exterior,"pack",28,Vector2(0,45));pack.hide()
	var entrance:=target(exterior,"entrance",Vector2(0,55))
	entrance.set_meta("display_name","废弃矿洞")

func build_interior() -> void:
	interior=Node2D.new();interior.position=mine.origin();interior.z_index=-10;s.world.add_child(interior)
	var backdrop:=Polygon2D.new();backdrop.polygon=PackedVector2Array([Vector2(-3000,-2000),Vector2(3000,-2000),Vector2(3000,2000),Vector2(-3000,2000)])
	backdrop.color=Color("302d29");interior.add_child(backdrop)
	sprite(interior,"interior",2000,Vector2.ZERO)
	var exit_target:=target(s.world.object_root,"exit",mine.origin()+Vector2(0,350));exit_target.set_meta("mine_caption","E 返回地表")
func _process(delta: float) -> void:
	if mine.state.site.is_empty():return
	var loaded: bool=s.world.stream.loaded.has(s.world.stream.chunk_at(mine.at()))
	if loaded and not is_instance_valid(exterior):build_exterior()
	if not loaded and is_instance_valid(exterior):
		exterior.queue_free();exterior=null
		for kind in ["entrance"]:
			if targets.has(kind):targets[kind].queue_free();targets.erase(kind)
	var record_loaded: bool=s.world.stream.loaded.has(s.world.stream.chunk_at(mine.record_at()))
	if is_instance_valid(record_view) and (not record_loaded or record_view.position!=mine.record_at()):
		record_view.queue_free();record_view=null
		if targets.has("record"):targets.record.queue_free();targets.erase("record")
	if record_loaded and not is_instance_valid(record_view):
		record_view=Node2D.new();record_view.position=mine.record_at();s.world.object_root.add_child(record_view)
		sprite(record_view,"record",58,Vector2(0,4))
		target(record_view,"record",Vector2(0,12)).set_meta("mine_caption","E 调查旧工具箱")
	if not is_instance_valid(interior):build_interior()
	var inside: bool=mine.travel.inside
	interior.visible=inside
	# Limits move with this player's region, never with another player's entry.
	var camera: Camera2D=s.world.player.camera
	camera.limit_left=int(mine.origin().x-1000) if inside else 0
	camera.limit_right=int(mine.origin().x+1000) if inside else int(s.world.generator.extent)
	camera.limit_top=int(mine.origin().y-666) if inside else 0;camera.limit_bottom=int(mine.origin().y+666) if inside else int(s.world.generator.extent)
	s.world.environment_view.rain_visual.visible=not inside
	var flecks=s.world.get_node_or_null("SeasonFlecks")
	if flecks!=null:flecks.visible=not inside
	var phase: String=mine.state.phase
	var armed: bool=phase=="armed"
	if armed:
		var authority_remaining: float=mine.remaining_seconds()
		shown_remaining=authority_remaining if not was_armed else minf(shown_remaining,authority_remaining)
		if s.world.get_meta("network_game",false):shown_remaining=maxf(0.0,shown_remaining-delta)
		countdown.text=str(clampi(ceili(shown_remaining-.000001),1,int(mine.config.fuse_seconds)))
		countdown.position=s.world.get_viewport().get_canvas_transform()*(mine.at()+Vector2(0,-45))-Vector2(32,29)
	countdown.visible=armed and is_instance_valid(exterior)
	if last_phase=="armed" and phase=="open" and is_instance_valid(exterior):
		blast.start(mine.at()+BLAST_OFFSET);AudioFX.play_sfx("sfx_ore_break",mine.at())
	last_phase=phase;was_armed=armed
	blast.advance(delta)
	if is_instance_valid(exterior):
		var breaking: bool=blast.active and blast.clock<.2
		rubble.visible=phase!="open" or breaking
		rubble.modulate.a=clampf((.2-blast.clock)/.12,0,1) if phase=="open" and breaking else 1.0
		rubble.position=Vector2(0,-14)+Vector2(sin(blast.clock*95)*1.7,cos(blast.clock*75)) if breaking else Vector2(0,-14)
		barrier.get_child(0).set_deferred("disabled",phase=="open")
		pack.visible=armed
		pack.modulate=Color(1.18,1,.8) if sin(Time.get_ticks_msec()*.025)>0 else Color.WHITE
		targets.entrance.set_meta("mine_caption","E 进入矿洞" if phase=="open" else "引线正在燃烧……" if armed else "E 安放爆破包" if mine.state.investigated and mine.state.recipe and mine.count_pack()>0 else "E 调查塌方")
func _exit_tree() -> void:
	for node in [exterior,interior,record_view,countdown]+targets.values():
		if is_instance_valid(node):node.queue_free()

