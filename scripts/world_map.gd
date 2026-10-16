extends Control
## A cached 512² overview sampled from the live generator, eight rows per frame.
var generator: WildGenerator
var player: WildPlayer
var image: Image
var terrain: ImageTexture
var row := 0
var max_build_ms := 0.0
var total_build_ms := 0.0
var resolution := 512
var zoom := 1.0
var center := Vector2.ZERO
var dragging := false
var font := ThemeDB.fallback_font
var map_rect := Rect2()

func configure(gen: WildGenerator, actor: WildPlayer) -> void:
	generator=gen
	player=actor
	image=Image.create(resolution,resolution,false,Image.FORMAT_RGB8)
	image.fill(Color("e3ddbd"))
	terrain=ImageTexture.create_from_image(image)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	hide()

func _process(_delta: float) -> void:
	if row<resolution:
		var begin:=Time.get_ticks_usec()
		var previous_row:=row
		# Time budget checked between rows; no full-world synchronous sweep.
		while row<resolution and Time.get_ticks_usec()-begin<1500:
			var y:=row
			for x in resolution:
				var p := (Vector2(x,y)+Vector2.ONE*.5)/resolution*generator.extent
				var color := generator.overview_color(p)
				image.set_pixel(x,y,color)
			row+=1
		if floori(row/8.0)!=floori(previous_row/8.0) or row==resolution:terrain.update(image)
		var work_ms:=(Time.get_ticks_usec()-begin)/1000.0
		max_build_ms=maxf(max_build_ms,work_ms)
		total_build_ms+=work_ms
	if visible: queue_redraw()

func open_map() -> void:
	center=player.position
	zoom=1.0
	player.input_blocked=true
	if player.action=="chop": player.cancel_action()
	player.chop_buffer=0.0
	show()
	queue_redraw()

func close_map() -> void:
	hide()
	dragging=false
	player.input_blocked=false

func world_to_screen(p: Vector2) -> Vector2:
	return map_rect.get_center()+(p-center)/generator.extent*map_rect.size.x*zoom

func clamp_center() -> void:
	var half_span := generator.extent/(2.0*zoom)
	center=center.clamp(Vector2.ONE*half_span,Vector2.ONE*(generator.extent-half_span))

func _draw() -> void:
	clamp_center()
	draw_rect(Rect2(Vector2.ZERO,size),Color(.12,.19,.14,.94))
	var side := minf(size.x-100,size.y-150)
	map_rect=Rect2((size-Vector2.ONE*side)*.5,Vector2.ONE*side)
	var span := generator.extent/zoom
	var lo := center-Vector2.ONE*span*.5
	var hi := center+Vector2.ONE*span*.5
	var clamped_lo := lo.clamp(Vector2.ZERO,Vector2.ONE*generator.extent)
	var clamped_hi := hi.clamp(Vector2.ZERO,Vector2.ONE*generator.extent)
	draw_rect(map_rect,Color("303e31"))
	var dest := Rect2(world_to_screen(clamped_lo),(clamped_hi-clamped_lo)/generator.extent*side*zoom)
	var source := Rect2(clamped_lo/generator.extent*resolution,(clamped_hi-clamped_lo)/generator.extent*resolution)
	draw_texture_rect_region(terrain,dest,source)
	draw_rect(map_rect,Color("d9d9b0"),false,3)
	var spawn_pos := world_to_screen(generator.spawn)
	if map_rect.has_point(spawn_pos):
		draw_rect(Rect2(spawn_pos-Vector2(5,5),Vector2(10,10)),Color("fff0af"))
		draw_string(font,spawn_pos+Vector2(9,4),"出生点",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("fff0af"))
	var actor_pos := world_to_screen(player.position)
	if map_rect.has_point(actor_pos):
		draw_circle(actor_pos,8,Color("253c3b"))
		draw_circle(actor_pos,5,Color("ffdf74"))
		draw_line(actor_pos,actor_pos+Vector2(0,-13),Color("fff9db"),2,true)
	draw_string(font,Vector2(40,36),"风栖原野 · 地图     北 ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("f1efd3"))
	draw_string(font,Vector2(40,size.y-48),"草原  浅绿   |   森林  深绿   |   山地  灰褐   |   河流 / 湖泊  蓝色",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("e4e5c2"))
	draw_string(font,Vector2(40,size.y-22),"滚轮缩放 · 拖动查看 · M / Esc 关闭    Seed %d    坐标 %.0f, %.0f    %.1f×%s"%[generator.world_seed,player.position.x,player.position.y,zoom,"    地形绘制中…" if row<resolution else ""],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e4e5c2"))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_M:
			if visible: close_map()
			else: open_map()
			get_viewport().set_input_as_handled()
		elif visible and event.physical_keycode==KEY_ESCAPE:
			close_map()
			get_viewport().set_input_as_handled()
	if not visible: return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT: dragging=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var old := zoom
			zoom=clampf(zoom*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .8),1,16)
			var point: Vector2 = event.position-map_rect.get_center()
			center+=point*generator.extent/maxf(map_rect.size.x,1)*(1/old-1/zoom)
	if event is InputEventMouseMotion and dragging:
		center-=event.relative*generator.extent/maxf(map_rect.size.x*zoom,1)
	clamp_center()
	get_viewport().set_input_as_handled()

