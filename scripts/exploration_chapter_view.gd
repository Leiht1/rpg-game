extends Node2D
## Presentation only. Interaction and rewards remain in the shared rules service.
const ItemSkin=preload("res://scripts/item_ui_style.gd")
const ELDER_CANVAS_HEIGHT:=142.0
var service: Node
var props: Dictionary={}
var panel:=Control.new()
var paper:=preload("res://scripts/exploration_paper.gd").new()
var blocker:=Control.new()
var words:=Label.new()
var pending_item:=""
var transition: CanvasLayer
var carving:=TextureRect.new()
var wall_dimmer:=ColorRect.new()
var route_paper:=preload("res://scripts/exploration_route_paper.gd").new()
var route_visible:=false
var route_zoom:=1.0
var close_button: Button
var reading_layer: CanvasLayer
func _ready() -> void:
	transition=preload("res://scripts/mine_transition.gd").new();transition.s=service;add_child(transition)
	var mine_view:=preload("res://scripts/exploration_mine_view.gd").new();mine_view.name="MineView";mine_view.s=service;add_child(mine_view)
	var puzzle_view:=preload("res://scripts/mine_puzzle_view.gd").new();puzzle_view.name="PuzzleView";puzzle_view.s=service;add_child(puzzle_view)
	var finale_view:=preload("res://scripts/exploration_final_view.gd").new();finale_view.s=service;finale_view.name="FinaleView";add_child(finale_view)
	var layer:=CanvasLayer.new();layer.layer=26;add_child(layer)
	reading_layer=layer
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);blocker.mouse_filter=Control.MOUSE_FILTER_STOP
	layer.add_child(blocker);blocker.hide()
	wall_dimmer.color=Color(.04,.035,.03,.78);wall_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);wall_dimmer.mouse_filter=Control.MOUSE_FILTER_IGNORE;blocker.add_child(wall_dimmer);wall_dimmer.hide()
	panel.theme=ItemSkin.theme();panel.size=Vector2(560,416);layer.add_child(panel)
	panel.add_child(paper);paper.size=panel.size;paper.mouse_filter=Control.MOUSE_FILTER_IGNORE
	carving.position=Vector2.ZERO;carving.size=Vector2(560,416);carving.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;carving.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;carving.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(carving);carving.hide()
	panel.add_child(route_paper);route_paper.hide()
	words.position=Vector2(54,54);words.size=Vector2(450,298);words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	words.add_theme_font_size_override("font_size",18);words.add_theme_color_override("font_color",Color("514736"));panel.add_child(words)
	var close:=Button.new();close.text="×";close.tooltip_text="关闭（E / Esc）";close.flat=true;close.position=Vector2(492,24);close.size=Vector2(32,32);close.set_meta("audio_window_close",true)
	close.pressed.connect(close_page);panel.add_child(close);panel.hide()
	close_button=close
func close_page() -> void:
	panel.hide();blocker.hide();pending_item="";route_visible=false
	reading_layer.layer=26
	if is_instance_valid(service.world.item_ui):service.world.item_ui.update_input_block()
func show_page(text: String) -> void:
	if text=="海彼岸的记录":
		show_route_page();route_paper.picture.texture=load("res://assets/exploration/final-v1/letter.png");panel.size=route_paper.configure({});layout_page();return
	if text.begins_with("古老的路线记录"):
		show_route_page();return
	route_visible=false;route_paper.hide();words.show()
	reading_layer.layer=26
	pending_item=""
	words.text=text
	var dialogue:=text.begins_with("垂钓老者")
	panel.size.x=560
	panel.size.y=416 if dialogue and text.contains("废弃矿洞") else 229 if dialogue else 416
	paper.scale.y=panel.size.y/416.0
	paper.kind="map" if text.begins_with("模糊地图") and not text.contains("残缺文字") else "note" if text.begins_with("残缺文字") else "letter"
	words.size.y=138 if paper.kind=="map" else panel.size.y-94
	paper.queue_redraw();layout_page();blocker.show();panel.show();service.world.player.input_blocked=true
	var index: int=service.chapter.puzzle.OBSERVATIONS.find(text)
	carving.visible=index>=0;paper.visible=not carving.visible;wall_dimmer.visible=carving.visible
	words.position=Vector2(54,310) if carving.visible else Vector2(54,54)
	words.size=Vector2(450,90) if carving.visible else Vector2(450,words.size.y)
	if carving.visible:
		carving.texture=load("res://assets/exploration/mine-clues-v4/closeup-%d.png"%index)
		words.add_theme_color_override("font_color",Color("d5cbb7"))
	else:words.add_theme_color_override("font_color",Color("514736"))
func show_route_page() -> void:
	pending_item="";route_visible=true;route_zoom=1.0;paper.hide();carving.hide();words.hide();route_paper.show();wall_dimmer.show()
	# Keep even a just-received reward toast behind the illustrated paper.
	reading_layer.layer=110
	route_paper.picture.texture=load("res://assets/exploration/coastal-route-v7/route-paper.png")
	panel.size=route_paper.configure(service.chapter.puzzle.route_hint.resolve(service))
	layout_page();blocker.show();panel.show();service.world.player.input_blocked=true
func layout_page() -> void:
	var viewport:=get_viewport_rect().size
	var factor:=minf(route_zoom if route_visible else 1.0,minf((viewport.x-32)/panel.size.x,(viewport.y-32)/panel.size.y))
	panel.scale=Vector2.ONE*factor;panel.position=(viewport-panel.size*factor)*.5
	if is_instance_valid(close_button):close_button.position=Vector2(panel.size.x-48,14) if route_visible else Vector2(492,24)
func investigate(kind: String) -> void:
	var result: String=service.chapter.interact(kind)
	if not result.is_empty():show_page(result)
func open_item(id: String) -> void:
	show_page("正在打开……" if id==service.chapter.BOTTLE and not service.chapter.state.bottle_read else service.chapter.text(id))
	pending_item=id
func create_prop(kind: String, at: Vector2) -> void:
	var node:=Node2D.new();node.position=at;node.set_meta("chapter_kind",kind)
	node.set_meta("interaction_action","inspect");node.set_meta("interaction_range",95.0)
	if kind=="shore":node.set_meta("interaction_action","talk")
	node.set_meta("display_name",{"remains":"前辈遗骸","belongings":"前辈遗留物","shore":"垂钓老者"}[kind])
	node.add_to_group("world_interactables");service.world.object_root.add_child(node);props[kind]=node
	var sprite:=Sprite2D.new();node.add_child(sprite)
	if kind=="remains":
		sprite.texture=load("res://assets/exploration/v1/remains.png");sprite.scale=Vector2.ONE*(88.0/sprite.texture.get_width());sprite.position.y=-12
	elif kind=="belongings":
		sprite.texture=load("res://assets/combat/v1/relic.png");sprite.scale=Vector2.ONE*.12;sprite.position=Vector2(38,-10)
		for offset in [Vector2(22,7),Vector2(43,11)]:
			var paper:=Sprite2D.new();paper.texture=load("res://assets/ui/survival_guide_v1/letter_icon.png");paper.scale=Vector2.ONE*(18.0/paper.texture.get_width());paper.position=offset;node.add_child(paper)
	else:
		sprite.texture=load("res://assets/exploration/v3/elder.png")
		sprite.scale=Vector2.ONE*(ELDER_CANVAS_HEIGHT/sprite.texture.get_height());sprite.centered=false
		# Ground and torso anchor measured on the processed master, not rod bounds.
		sprite.position=Vector2(-28,-108)*(ELDER_CANVAS_HEIGHT/112.0);sprite.name="Elder"
		if service.chapter.point("river_fish").x<at.x:
			sprite.flip_h=true;sprite.position.x=-79*(ELDER_CANVAS_HEIGHT/112.0)
		var body:=StaticBody2D.new();var collider:=CollisionShape2D.new();var shape:=CircleShape2D.new();shape.radius=12
		collider.shape=shape;body.add_child(collider);node.add_child(body)
		var line:=Line2D.new();line.name="FishingLine";line.width=.65;line.default_color=Color(.86,.84,.70,.8);line.antialiased=true;node.add_child(line)
		var bobber:=Sprite2D.new();bobber.name="Bobber";bobber.texture=load("res://assets/fishing/v1/float.res")
		bobber.scale=Vector2.ONE*(5.0/bobber.texture.get_width());node.add_child(bobber)
func _process(_delta: float) -> void:
	var chapter=service.chapter
	if chapter.state.stage<2:
		for node in props.values():node.queue_free()
		props.clear()
	if chapter.state.stage>=2:
		for kind in ["remains","belongings","shore"]:
			var at: Vector2=chapter.point("elder" if kind=="shore" else "site")
			var loaded: bool=service.world.stream.loaded.has(service.world.stream.chunk_at(at))
			if kind=="shore" and (not chapter.elder_on_coast() or chapter.now()<chapter.state.elder_due):loaded=false
			if props.has(kind) and props[kind].position!=at:props[kind].queue_free();props.erase(kind)
			if loaded and not props.has(kind):create_prop(kind,at)
			elif not loaded and props.has(kind):props[kind].queue_free();props.erase(kind)
	if panel.visible:
		layout_page()
		service.world.player.input_blocked=true
		if not pending_item.is_empty() and (pending_item!=chapter.BOTTLE or chapter.state.bottle_read):words.text=chapter.text(pending_item)
		if service.body.down or service.body.sleep_active():close_page()
	if props.has("shore"):
		var elder: Sprite2D=props.shore.get_node("Elder")
		elder.scale.y=ELDER_CANVAS_HEIGHT/elder.texture.get_height()*(1.0+sin(Time.get_ticks_msec()*.0014)*.002)
		var tip: Vector2=elder.position+Vector2(132 if elder.flip_h else 892,67)*elder.scale
		var water: Vector2=chapter.point("river_fish")-props.shore.position+Vector2(0,sin(Time.get_ticks_msec()*.002)*.65)
		props.shore.get_node("Bobber").position=water
		props.shore.get_node("FishingLine").points=PackedVector2Array([tip,tip.lerp(water,.5)+Vector2(2,4),water])
func _input(event: InputEvent) -> void:
	if panel.visible and route_visible and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		route_zoom=clampf(route_zoom*(1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.12),1.0,1.5);layout_page();get_viewport().set_input_as_handled();return
	if panel.visible and event is InputEventKey and event.pressed:
		if event.physical_keycode in [KEY_ESCAPE,KEY_E] and not event.echo:close_page()
		get_viewport().set_input_as_handled()
func _exit_tree() -> void:
	for node in props.values():
		if is_instance_valid(node):node.queue_free()
