extends Node2D
## World presentation reads the same authoritative records on host and clients.
var service: Node
var relics: Dictionary={}
var boars: Dictionary={}
var portal: Node2D
var clock:=0.0
var relic_panel: PanelContainer
var relic_list: VBoxContainer
var current:=""
var relic_fingerprint:=""
var last_phase:=""
var render_clock:=0.0
var render_attack_clock:=0.0
var last_attack_clock:=-1.0
var hit_serial:=-1
var recoil:=Vector2.ZERO
var hit_clock:=0.0
var drop_count:=-1
var soul: Node2D
var duel_panel:=VBoxContainer.new()
var duel_toggle: Button

func _ready() -> void:
	portal=Portal.new();portal.scale=Vector2.ONE*2.0;service.world.object_root.add_child(portal)
	portal.position=service.combat.spawn_point()
	for id in relics.keys():
		if not service.combat.state.relics.has(id):relics[id].queue_free();relics.erase(id)
	for id in boars.keys():
		if not service.combat.state.boars.has(id):boars[id].queue_free();boars.erase(id)
	var layer:=CanvasLayer.new();layer.layer=15;add_child(layer)
	relic_panel=PanelContainer.new();relic_panel.theme=preload("res://scripts/item_ui_style.gd").theme()
	relic_panel.add_theme_stylebox_override("panel",preload("res://scripts/item_ui_style.gd").frame(16))
	relic_panel.position=Vector2(450,160);relic_panel.custom_minimum_size=Vector2(360,0);layer.add_child(relic_panel)
	var contents:=VBoxContainer.new();relic_panel.add_child(contents)
	var heading:=Label.new();heading.text="遗物";contents.add_child(heading)
	var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(330,260);contents.add_child(scroll)
	relic_list=VBoxContainer.new();relic_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(relic_list)
	var close:=Button.new();close.text="关闭";close.set_meta("audio_window_close",true);close.pressed.connect(func():relic_panel.hide());contents.add_child(close)
	relic_panel.hide()
	duel_panel.position=Vector2(1010,82);layer.add_child(duel_panel)
	if service.world.get_meta("network_game",false):
		duel_toggle=Button.new();duel_toggle.text="切磋";duel_toggle.position=Vector2(1160,45);duel_toggle.size=Vector2(70,30);layer.add_child(duel_toggle)
		duel_toggle.pressed.connect(show_duels)
	duel_panel.hide()

func show_duels() -> void:
	for node in duel_panel.get_children():duel_panel.remove_child(node);node.queue_free()
	var owner:=str(service.world.get_meta("network_player_id","local"))
	for id in service.world.actors:
		var actor: Node=service.world.actors[id]
		var character_id:=str(actor.get_meta("combat_id",""))
		var pair: Array=[owner,character_id];pair.sort()
		var offer: Dictionary=service.combat.state.get("duels",{}).get(":".join(pair),{})
		var button:=Button.new();button.text=("结束 " if offer.get("accepted",false) else "接受 " if offer.get("to")==owner else "等待 " if offer.get("from")==owner else "挑战 ")+actor.get_node("Nickname").text
		button.pressed.connect(func():
			service.combat.duel(character_id,not bool(offer.get("accepted",false)));duel_panel.hide())
		duel_panel.add_child(button)
		if not offer.is_empty() and not offer.get("accepted",false):
			var cancel:=Button.new();cancel.text="拒绝 / 撤回";cancel.pressed.connect(func():service.combat.duel(character_id,false);duel_panel.hide());duel_panel.add_child(cancel)
	duel_panel.visible=not duel_panel.visible

func open_relic(id: String) -> void:
	current=id;refresh_relic();relic_panel.show()

func refresh_relic() -> void:
	for node in relic_list.get_children():relic_list.remove_child(node);node.queue_free()
	var row: Dictionary=service.combat.state.relics.get(current,{})
	relic_fingerprint=relic_stamp(row.get("contents",[]))
	for i in row.get("contents",[]).size():
		var item: Dictionary=row.contents[i];var button:=Button.new()
		button.text=service.stack_name(item)+" ×%d"%int(item.count);button.icon=service.stack_texture(item,"icon");button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",24)
		button.pressed.connect(func():
			var message: String=service.combat.claim(current,i,item)
			if not message.is_empty():service.notice.emit(message)
			refresh_relic())
		relic_list.add_child(button)

func relic_stamp(contents: Array) -> String:
	var stable: Array=contents.duplicate(true)
	for value in stable:
		if value.has("spoilage"):value.spoilage=1 if preload("res://scripts/food_freshness.gd").rotten(value) else 0
	return JSON.stringify(stable)

func _unhandled_input(event: InputEvent) -> void:
	if relic_panel.visible and event.is_action_pressed("ui_cancel"):relic_panel.hide();get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	clock+=delta
	var world: Node=service.world;var player: Node2D=world.player
	if is_instance_valid(duel_toggle) and is_instance_valid(world.item_ui):
		duel_toggle.visible=service.combat.personal.phase=="alive" and not world.item_ui.bag.visible and not world.item_ui.catalog.visible and not world.item_ui.craft_panel.visible and not world.map_view.visible
		if not duel_toggle.visible:duel_panel.hide()
	if drop_count!=service.loose.size():
		drop_count=service.loose.size()
		var present: Dictionary={}
		for node in world.stream.drops:
			if is_instance_valid(node):present[str(node.get_meta("drop_id",""))]=true
		for id in service.loose:
			var row: Dictionary=service.loose[id]
			if not present.has(id) and world.stream.loaded.has(world.stream.chunk_at(Vector2(row.x,row.y))):
				var value:=row.duplicate(true);value.id=id;world.stream.create_item_drop(value)
	portal.position=service.combat.spawn_point()
	for id in service.combat.state.relics:
		var row: Dictionary=service.combat.state.relics[id]
		if not world.stream.loaded.has(world.stream.chunk_at(Vector2(row.x,row.y))):
			if relics.has(id):relics[id].queue_free();relics.erase(id)
			continue
		if not relics.has(id):
			var node:=Relic.new();node.manager=self;node.identity=id;node.set_meta("interaction_action","open");node.set_meta("interaction_range",78.0)
			node.add_to_group("world_interactables");node.set_meta("relic_id",id);world.object_root.add_child(node);relics[id]=node
		relics[id].position=Vector2(row.x,row.y);relics[id].visible=not row.contents.is_empty();relics[id].set_meta("collected",row.contents.is_empty())
	for id in service.combat.state.boars:
		var row: Dictionary=service.combat.state.boars[id]
		if not world.stream.loaded.has(world.stream.chunk_at(Vector2(row.x,row.y))):
			if boars.has(id):boars[id].queue_free();boars.erase(id)
			continue
		if not boars.has(id):
			var node:=Boar.new();node.record=row;node.max_health=float(service.combat.rules.boar.health);node.respawn_seconds=float(service.combat.rules.boar.respawn_seconds);node.set_meta("boar_id",id);world.object_root.add_child(node);boars[id]=node
		boars[id].record=row;boars[id].position=Vector2(row.x,row.y)
	if relic_panel.visible:
		var row: Dictionary=service.combat.state.relics.get(current,{})
		if row.is_empty() or player.position.distance_to(Vector2(row.x,row.y))>100 or service.combat.personal.phase!="alive":relic_panel.hide()
		elif relic_stamp(row.contents)!=relic_fingerprint:refresh_relic()
	var p: Dictionary=service.combat.personal
	if p.phase!=last_phase:render_clock=float(p.clock)
	elif world.get_meta("network_game",false):render_clock=minf(float(p.clock)+.45,maxf(render_clock,float(p.clock))+delta)
	else:render_clock=float(p.clock)
	player.combat_render_state=p.duplicate(true);player.combat_render_state.clock=render_clock
	if not p.attack.is_empty():
		var elapsed: float=p.attack.elapsed
		if last_attack_clock<0 or elapsed<last_attack_clock:render_attack_clock=elapsed
		else:render_attack_clock=maxf(render_attack_clock,elapsed)
		if world.get_meta("network_game",false):render_attack_clock=minf(elapsed+.45,render_attack_clock+delta)
		player.combat_render_state.attack.elapsed=render_attack_clock
		last_attack_clock=elapsed
	else:last_attack_clock=-1.0
	if hit_serial!=int(p.get("hit_serial",0)):
		if hit_serial>=0:
			hit_clock=.3
			var source: Dictionary=p.get("hit_source",{"x":player.position.x,"y":player.position.y-1})
			recoil=(player.position-Vector2(source.x,source.y)).normalized()*70
		hit_serial=int(p.get("hit_serial",0))
	hit_clock=maxf(0,hit_clock-delta)
	if hit_clock>0:
		player.character.modulate=Color(1,.55,.55,.5 if int(hit_clock*35)%2 else 1)
		recoil=recoil.move_toward(Vector2.ZERO,delta*350)
	else:player.character.modulate=Color.WHITE
	if p.phase!="alive":
		player.input_blocked=true;player.cancel_action();player.moving=false
		player.character.rotation=0
		player.character.modulate.a=1 if p.phase=="dying" else clampf(render_clock,0,1)
		if p.phase=="dying":
			if not is_instance_valid(soul):soul=Soul.new();world.object_root.add_child(soul)
			soul.position=player.position+Vector2(14+sin(clock*3)*5,-12-render_clock*28);soul.modulate.a=sin(clampf(render_clock/float(service.combat.rules.death_seconds),0,1)*PI)
	elif last_phase!="alive":
		player.character.rotation=0;player.character.modulate=Color.WHITE
		if is_instance_valid(soul):soul.queue_free()
		if world.item_ui!=null:world.item_ui.update_input_block()
	last_phase=p.phase

func _exit_tree() -> void:
	for node in relics.values():if is_instance_valid(node):node.queue_free()
	for node in boars.values():if is_instance_valid(node):node.queue_free()
	if is_instance_valid(soul):soul.queue_free()
	if is_instance_valid(portal):portal.queue_free()

class Relic extends Node2D:
	var manager: Node
	var identity: String
	func _ready() -> void:
		set_meta("display_name","遗物")
		var sprite:=Sprite2D.new();sprite.texture=load("res://assets/combat/v1/relic.png");sprite.scale=Vector2.ONE*.18;sprite.position.y=-15;add_child(sprite)
	func interact() -> void:manager.open_relic(identity)

class Portal extends Node2D:
	var clock:=0.0
	func _ready() -> void:
		var sprite:=Sprite2D.new();sprite.texture=load("res://assets/combat/v1/portal.png");sprite.scale=Vector2.ONE*.47;sprite.position=Vector2(0,-51);add_child(sprite)
		for side in [-1,1]:
			var pillar:=StaticBody2D.new();pillar.position=Vector2(side*35,-8);add_child(pillar)
			var collision:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=8;collision.shape=circle;pillar.add_child(collision)
	func _process(delta: float) -> void:clock+=delta;queue_redraw()
	func _draw() -> void:
		for arm in 4:
			var points:=PackedVector2Array()
			for step in 48:
				var t:=float(step)/47;var a:=t*TAU*1.2+clock*1.6+arm*TAU/4
				points.append(Vector2(cos(a)*25*t,sin(a)*35*t)-Vector2(0,53))
			draw_polyline(points,Color(.35,.8,.76,.65),2,true)
		for i in 12:
			var a:=clock*.7+float(i)*TAU/12
			draw_circle(Vector2(cos(a)*36,sin(a)*46-53),1.5,Color(.72,.94,.8,.6))

class Soul extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2.ZERO,9,Color(.7,.92,.91,.65))
		var points:=PackedVector2Array([Vector2(-8,0),Vector2(8,0),Vector2(5,13),Vector2(0,23),Vector2(-4,13)])
		draw_colored_polygon(points,Color(.7,.92,.91,.55))
		draw_circle(Vector2(-3,-2),1,Color(.3,.5,.5));draw_circle(Vector2(3,-2),1,Color(.3,.5,.5))

class Boar extends StaticBody2D:
	var record: Dictionary
	var max_health:=45.0
	var respawn_seconds:=3600.0
	var skeleton:=Skeleton2D.new()
	var body:=Bone2D.new()
	var head:=Bone2D.new()
	var legs: Array[Bone2D]=[]
	var clock:=0.0
	var previous:=Vector2.ZERO
	func part(bone: Bone2D, file: String, at: Vector2, scale_value: Vector2) -> void:
		var sprite:=Sprite2D.new();sprite.texture=load("res://assets/combat/v1/"+file+".png");sprite.position=at;sprite.scale=scale_value;bone.add_child(sprite)
	func _ready() -> void:
		var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=14;shape.shape=circle;add_child(shape)
		body.set_autocalculate_length_and_angle(false);head.set_autocalculate_length_and_angle(false)
		body.length=12;head.length=12
		body.position=Vector2(0,-24);body.rest=body.transform;head.rest=Transform2D.IDENTITY
		add_child(skeleton);skeleton.add_child(body)
		for i in 4:
			var leg:=Bone2D.new();leg.set_autocalculate_length_and_angle(false);leg.length=12;leg.position=Vector2(-16+(i%2)*31,0);leg.rest=leg.transform;body.add_child(leg);legs.append(leg)
			part(leg,"boar_leg",Vector2(0,12),Vector2(.07,.10))
		part(body,"boar_torso",Vector2.ZERO,Vector2(.24,.19));body.add_child(head);head.position=Vector2(14,-1)
		part(head,"boar_head",Vector2(4,0),Vector2(.25,.25));part(body,"boar_tail",Vector2(-24,-3),Vector2(.08,.08))
		head.rest=head.transform
		previous=position
	func _process(delta: float) -> void:
		clock+=delta
		collision_layer=1 if record.health>0 else 0
		var moving: bool=position.distance_to(previous)>.01
		if absf(position.x-previous.x)>.01:skeleton.scale.x=1 if position.x>previous.x else -1
		previous=position
		for i in legs.size():legs[i].rotation=sin(clock*12+(i%2)*PI+(i/2)*PI)*.45 if moving else 0
		head.rotation=sin(clock*2)*.03
		if record.mode=="attack":head.rotation=-.2+sin(float(record.clock)*8)*.25
		if record.health<=0:body.rotation=lerpf(body.rotation,PI*.5,minf(delta*5,1));modulate.a=clampf((float(record.get("respawn",0))-respawn_seconds+2)/2,0,1)
		else:body.rotation=0;modulate=Color(1,.65,.65) if float(record.get("hit",0))>5.75 else Color.WHITE
		queue_redraw()
	func _draw() -> void:
		if record.health>0 and float(record.get("hit",0))>0:
			draw_rect(Rect2(-22,-56,44,4),Color(.2,.18,.16,.8));draw_rect(Rect2(-22,-56,44*float(record.health)/max_health,4),Color(.7,.25,.2))
