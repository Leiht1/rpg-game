extends Node2D
## Generated artwork; attack geometry doubles as readable warnings.
const ART="res://assets/exploration/final-v1/"
const SCENERY="res://assets/exploration/final-v2/"
var s: Node
var ground: Sprite2D
var guardian: Node2D
var body: Sprite2D
var visual_root: Node2D
var rendered_at:=Vector2.ZERO
var previous_health:=-1.0
var hit_flash:=0.0
var chest: Node2D
var core: Node2D
var health: ProgressBar
var props: Array[Node2D]=[]
var model: RefCounted:
	get:return s.chapter.finale
func picture(file: String, width: float, parent: Node2D, offset: Vector2) -> Sprite2D:
	var pic:=Sprite2D.new();pic.texture=load(ART+file+".png");pic.scale=Vector2.ONE*width/pic.texture.get_width();pic.position=offset;parent.add_child(pic);return pic
func target(kind: String, pos: Vector2, caption: String) -> Node2D:
	var node:=Node2D.new();node.position=pos;node.set_meta("mine_kind","final:"+kind);node.set_meta("mine_caption",caption);node.set_meta("display_name",caption.trim_prefix("E "));node.set_meta("interaction_action","inspect");node.set_meta("interaction_range",100.0);s.world.object_root.add_child(node);return node
func build() -> void:
	ground=Sprite2D.new();ground.texture=load(SCENERY+"ground.png");ground.position=model.at();ground.scale=Vector2.ONE*1440.0/ground.texture.get_height();ground.z_index=-1;add_child(ground)
	var blend:=ShaderMaterial.new();blend.shader=preload("res://scripts/ruins_ground_blend.gdshader");blend.set_shader_parameter("display_size",ground.texture.get_size()*ground.scale);ground.material=blend
	for spec in model.config.scenery:
		var node:=Node2D.new();node.position=model.at()+Vector2(spec.at[0],spec.at[1]);s.world.object_root.add_child(node)
		var pic:=Sprite2D.new();pic.texture=load(SCENERY+spec.file+".png");pic.scale=Vector2.ONE*float(spec.width)/pic.texture.get_width();pic.position=Vector2(0,-pic.texture.get_height()*pic.scale.y*.5+6);node.add_child(pic);props.append(node)
		var obstacle:=StaticBody2D.new();var collision:=CollisionShape2D.new();var shape:=CircleShape2D.new();shape.radius=float(spec.radius);collision.shape=shape;obstacle.add_child(collision);node.add_child(obstacle)
	guardian=Node2D.new();s.world.object_root.add_child(guardian);visual_root=Node2D.new();guardian.add_child(visual_root);body=picture("boss",190,visual_root,Vector2(0,-93));rendered_at=model.boss_at()
	var volume:=StaticBody2D.new();volume.name="Volume";var collider:=CollisionShape2D.new();var footprint:=CircleShape2D.new();footprint.radius=35;collider.shape=footprint;volume.add_child(collider);guardian.add_child(volume)
	health=ProgressBar.new();health.size=Vector2(180,9);health.position=Vector2(-90,-211);health.show_percentage=false;health.max_value=float(model.config.health);visual_root.add_child(health)
	var title:=Label.new();title.text="远古领主";title.position=Vector2(-44,-239);title.add_theme_font_size_override("font_size",15);visual_root.add_child(title)
	chest=target("chest",model.chest_at(),"E 打开遗迹宝箱");picture("chest",105,chest,Vector2(0,-39))
	core=target("core",model.boss_at(),"E 拾取远古领主的内核");picture("core",42,core,Vector2(0,-20))
func _process(_delta: float) -> void:
	if model.state.site.is_empty():return
	if not is_instance_valid(ground):build()
	var shown: bool=not s.chapter.mine.travel.inside and s.world.player.position.distance_to(model.at())<1800
	visible=shown;guardian.visible=shown and not model.state.defeated;chest.visible=shown;core.visible=shown and model.state.defeated and not model.state.core_claimed
	for node in props:node.visible=shown
	for node in [core,chest]:
		var active: bool=node.visible and (node==core or model.state.defeated and not model.state.chest_open)
		if active and not node.is_in_group("world_interactables"):node.add_to_group("world_interactables")
		if not active and node.is_in_group("world_interactables"):node.remove_from_group("world_interactables")
	core.position=model.boss_at();guardian.position=model.boss_at();health.value=model.state.boss.health
	rendered_at=rendered_at.lerp(model.boss_at(),1-exp(-_delta*18)) if s.world.get_meta("network_game",false) and rendered_at.distance_to(model.boss_at())<500 else model.boss_at()
	visual_root.position=rendered_at-model.boss_at()
	guardian.get_node("Volume").get_child(0).set_deferred("disabled",not guardian.visible)
	chest.modulate=Color(.65,.77,.78) if not model.state.defeated else Color(.73,.76,.71) if model.state.chest_open else Color.WHITE
	var b: Dictionary=model.state.boss
	var pose:=float(b.clock)
	body.rotation=sin(pose*7)*.035 if b.mode=="chase" else -.09 if b.mode=="windup" and b.attack=="slam" else .10 if b.mode=="active" and b.attack=="slam" else 0.0
	body.position=Vector2(0,-93+sin(pose*8)*2 if b.mode=="chase" else -93)
	body.modulate=Color(1.18,1.3,1.3) if b.attack=="core" and b.mode in ["windup","active"] else Color(1.07,.82,.71) if b.health<=float(model.config.health)*.5 else Color.WHITE
	if b.attack=="core" and b.mode=="recover":body.modulate=Color(1.1,1.45,1.45)
	if previous_health>=0 and b.health<previous_health:hit_flash=.16
	previous_health=b.health;hit_flash=maxf(0,hit_flash-_delta)
	if hit_flash>0:body.modulate=body.modulate.lerp(Color(1.9,1.9,1.9),hit_flash/.16)
	health.visible=model.state.triggered
	queue_redraw()
func _draw() -> void:
	if s==null or model.state.site.is_empty() or model.state.defeated:return
	var b: Dictionary=model.state.boss
	if b.mode not in ["windup","active"]:return
	var p: Vector2=model.boss_at();var dir:=Vector2(b.direction.x,b.direction.y)
	var active: bool=b.mode=="active";var color:=Color(.95,.40,.18,.48 if active else .22)
	if b.attack=="core":color=Color(.20,.92,.94,.5 if active else .2)
	if b.attack=="charge":
		var end:=p+dir*float(model.config.charge_speed)*float(model.config.active.charge)
		draw_line(p,end,color,88);draw_line(p,end,Color(1,.75,.4,.8),3)
	elif b.attack=="slam":
		var points:=PackedVector2Array([p])
		for i in 25:points.append(p+Vector2.from_angle(dir.angle()-1.35+i*2.7/24)*float(model.config.range.slam))
		draw_colored_polygon(points,color);draw_polyline(points,Color(1,.70,.36,.8),2)
	else:
		var radius: float=model.config.range[b.attack]
		draw_circle(p,radius,color);draw_arc(p,radius,0,TAU,80,Color(.35,.95,1,.9) if b.attack=="core" else Color(1,.75,.4,.8),3)
