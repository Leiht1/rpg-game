extends Control
## Bounded LRU mip tiles. View transforms, fog, and dynamic markers are independent.
const TILE := 64
const CACHE_LIMIT := 384
var generator: WildGenerator
var player: WildPlayer
var item_screen: Control
var zoom := 8.0
var center := Vector2.ZERO
var dragging := false
var map_rect := Rect2()
var font := ThemeDB.fallback_font
var cache := {}
var pending: Array[Vector3i]=[]
var working := Vector3i(-1,-1,-1)
var tile_image: Image
var tile_row := 0
var row := 512 # Legacy instrumentation: no full overview sweep is required.
var resolution := 512
var max_build_ms := 0.0
var total_build_ms := 0.0
var clock := 0
var detailed := false
var fog: ColorRect
var fog_material := ShaderMaterial.new()
var mask: ImageTexture
var mask_revision := -1
var recenter: Button
var cache_hits := 0
var generated_tiles := 0
var known_tiles := {}
var known_revision := -1
var wanted: Array[Vector3i]=[]
var protected_tiles := {}
var request_stamp: Array=[]
var draw_stamp: Array=[]
var view_loading := false
var hidden_generated_tiles := 0
var hidden_build_ms := 0.0

func configure(gen: WildGenerator, actor: WildPlayer) -> void:
	generator=gen;player=actor
	detailed=actor.get_parent().get_parent().get_meta('map_art_v3',false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	fog=ColorRect.new();fog.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(fog)
	fog_material.shader=preload('res://scripts/map_fog.gdshader');fog.material=fog_material
	# Remain fully concealed even before the first visible process callback.
	var blank:=Image.create(1,1,false,Image.FORMAT_L8);blank.fill(Color.BLACK)
	fog_material.set_shader_parameter('exploration_mask',ImageTexture.create_from_image(blank))
	recenter=Button.new();recenter.text='回到人物';add_child(recenter)
	recenter.theme=preload('res://scripts/item_ui_style.gd').theme()
	recenter.pressed.connect(focus_player)
	hide()

func exploration() -> RefCounted:
	return item_screen.service.exploration if item_screen else null

func sync_fog_mask() -> void:
	var ex:=exploration()
	if not ex or ex.revision==mask_revision:return
	var image: Image=ex.mask_image()
	if mask:mask.update(image)
	else:mask=ImageTexture.create_from_image(image)
	mask_revision=ex.revision;fog_material.set_shader_parameter('exploration_mask',mask)

func apply_fog_view() -> void:
	fog_material.set_shader_parameter('world_low',center-Vector2.ONE*generator.extent/zoom*.5)
	fog_material.set_shader_parameter('span',generator.extent/zoom)
	fog_material.set_shader_parameter('extent',generator.extent)

func update_layout() -> void:
	var side:=maxf(100,minf(size.x-100,size.y-150))
	map_rect=Rect2((size-Vector2.ONE*side)*.5,Vector2.ONE*side)
	if fog:
		fog.position=map_rect.position;fog.size=map_rect.size
		recenter.position=Vector2(size.x-185,24);recenter.size=Vector2(140,40)

func focus_player() -> void:
	center=player.position;zoom=maxf(zoom,4.0);clamp_center();queue_redraw()

func open_map() -> void:
	if item_screen:item_screen.close_panels()
	update_layout();center=player.position;clamp_center()
	player.input_blocked=true
	if player.action in ['chop','throw']:player.cancel_action()
	player.chop_buffer=0;sync_fog_mask();apply_fog_view();show();queue_redraw()

func close_map() -> void:
	hide();dragging=false
	if item_screen:item_screen.update_input_block()
	else:player.input_blocked=false

func world_to_screen(p: Vector2) -> Vector2:
	return map_rect.get_center()+(p-center)*map_rect.size.x*zoom/generator.extent

func screen_to_world(p: Vector2) -> Vector2:
	return center+(p-map_rect.get_center())*generator.extent/(map_rect.size.x*zoom)

func clamp_center() -> void:
	center=clamped_view(center,zoom)

func clamped_view(value: Vector2, view_zoom: float) -> Vector2:
	var half_span:=generator.extent/(2.0*view_zoom)
	return value.clamp(Vector2.ONE*half_span,Vector2.ONE*(generator.extent-half_span))

func mip(view_zoom: float=-1.0) -> int:
	var desired:=maxf(512.,map_rect.size.x*(zoom if view_zoom<0 else view_zoom))
	var result:=512
	while result*2<=desired and result<4096:result*=2
	return result

func visible_tiles() -> Array[Vector3i]:
	return tiles_for_view(center,zoom)

func tiles_for_view(view_center: Vector2, view_zoom: float) -> Array[Vector3i]:
	var result: Array[Vector3i]=[]
	var level:=mip(view_zoom);var span:=generator.extent/view_zoom
	var low: Vector2=(view_center-Vector2.ONE*span*.5)/generator.extent*level/TILE
	var high: Vector2=(view_center+Vector2.ONE*span*.5)/generator.extent*level/TILE
	for y in range(maxi(0,floori(low.y)),mini(level/TILE,ceili(high.y))):
		for x in range(maxi(0,floori(low.x)),mini(level/TILE,ceili(high.x))):
			var key:=Vector3i(x,y,level)
			var ex:=exploration()
			if ex:
				if known_revision!=ex.revision:known_tiles.clear();known_revision=ex.revision
				if not known_tiles.has(key):
					var area:=Rect2(Vector2(x,y)*TILE/float(level)*generator.extent,Vector2.ONE*TILE/float(level)*generator.extent)
					known_tiles[key]=ex.intersects(area.grow(ex.CELL*2))
				if not known_tiles[key]:continue
			result.append(key)
	return result

func _process(delta: float) -> void:
	if not item_screen:return
	clock+=1;update_layout()
	if visible:clamp_center()
	var ex:=exploration()
	if not ex:return
	# Hidden maps warm the local/default and retained zoom views during normal play.
	# This reads existing exploration only; it never reveals terrain or pins a player.
	var stamp: Array=[visible,center if visible else Vector2.ZERO,zoom,size,ex.revision,Vector2i(player.position/192.)]
	if request_stamp!=stamp:
		request_stamp=stamp
		wanted.clear();protected_tiles.clear()
		var views: Array=[]
		if visible:views.append([center,zoom])
		views.append([clamped_view(player.position,8.),8.])
		views.append([clamped_view(player.position,zoom),zoom])
		for view in views:
			for key in tiles_for_view(view[0],view[1]):
				if not protected_tiles.has(key):wanted.append(key);protected_tiles[key]=true
	if visible:
		sync_fog_mask()
		var draw_state: Array=[center,zoom,size,mask_revision]
		if draw_stamp!=draw_state:
			draw_stamp=draw_state;queue_redraw()
			apply_fog_view()
		if has_node('Markers'):get_node('Markers').queue_redraw()
	pending.clear()
	for key in wanted:
		if cache.has(key):cache[key].used=clock;cache_hits+=1
		elif key!=working:pending.append(key)
	var begin:=Time.get_ticks_usec()
	var budget:=1800 if visible else 600
	while Time.get_ticks_usec()-begin<budget:
		if working.x<0:
			if pending.is_empty():break
			working=pending.pop_front();tile_row=0
			tile_image=Image.create(TILE+2,TILE+2,false,Image.FORMAT_RGB8)
		for x in TILE+2:
			var p: Vector2=(Vector2(working.x,working.y)*TILE+Vector2(x-1,tile_row-1)+Vector2.ONE*.5)/float(working.z)*generator.extent
			tile_image.set_pixel(x,tile_row,preload('res://scripts/map_cartography.gd').color_at(generator,p,detailed))
		tile_row+=1
		if tile_row==TILE+2:
			cache[working]={"texture":ImageTexture.create_from_image(tile_image),"used":clock};generated_tiles+=1
			if not visible:hidden_generated_tiles+=1
			if cache.size()>CACHE_LIMIT:
				var oldest:=Vector3i(-1,-1,-1)
				for key in cache:
					if protected_tiles.has(key):continue
					if oldest.x<0 or cache[key].used<cache[oldest].used:oldest=key
				cache.erase(oldest if oldest.x>=0 else working)
			working=Vector3i(-1,-1,-1)
			if visible:queue_redraw()
	var ms:=(Time.get_ticks_usec()-begin)/1000.0
	max_build_ms=maxf(max_build_ms,ms);total_build_ms+=ms
	if not visible:hidden_build_ms=maxf(hidden_build_ms,ms)
	if visible:
		var loading:=false
		for key in visible_tiles():
			if not cache.has(key):loading=true;break
		if view_loading!=loading:view_loading=loading;queue_redraw()

func _draw() -> void:
	update_layout();clamp_center()
	draw_rect(Rect2(Vector2.ZERO,size),Color('22342e'))
	draw_rect(map_rect,Color('8ba69a'))
	var pixels:=map_rect.size.x*zoom/generator.extent
	for key in visible_tiles():
		if not cache.has(key):continue
		var low: Vector2=Vector2(key.x,key.y)*TILE/float(key.z)*generator.extent
		var high: Vector2=low+Vector2.ONE*TILE/float(key.z)*generator.extent
		var dest:=Rect2(world_to_screen(low),(high-low)*pixels)
		var clipped:=dest.intersection(map_rect)
		if not clipped.has_area():continue
		var source:=Rect2(Vector2.ONE+(clipped.position-dest.position)/dest.size*TILE,clipped.size/dest.size*TILE)
		draw_texture_rect_region(cache[key].texture,clipped,source)
	if detailed:draw_landmarks()
	draw_rect(map_rect,Color('ccd5b6'),false,2)
	# Children draw fog over geography; markers use an independent foreground child.
	draw_string(font,Vector2(76,38),'风栖原野 · 地图     北 ↑',HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color('e6ecd8'))
	draw_string(font,Vector2(40,size.y-42),'草原 · 森林 · 泥地 · 岩石区 · 水域',HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color('cbd8bd'))
	draw_string(font,Vector2(40,size.y-18),('滚轮缩放 · 拖动查看 · M / Esc 关闭    %.1f×'%zoom)+('    地形绘制中…' if view_loading else ''),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color('cbd8bd'))
	if not has_node('Markers'):
		var markers:=Control.new();markers.name='Markers';markers.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(markers)
		markers.draw.connect(draw_markers.bind(markers))
	get_node('Markers').queue_redraw()

func draw_landmarks() -> void:
	# World-space glyph lattice: deterministic, sparse and sampled entirely inside
	# its actual biome. Omit at overview scale to avoid dense repeated patterns.
	if zoom<3:return
	var step:=640.0
	var lo:=screen_to_world(map_rect.position)
	var hi:=screen_to_world(map_rect.end)
	for y in range(floori(lo.y/step),ceili(hi.y/step)):
		for x in range(floori(lo.x/step),ceili(hi.x/step)):
			var p: Vector2=(Vector2(x,y)+Vector2(.2+generator.random_at(x,y,710)*.6,.2+generator.random_at(x,y,711)*.6))*step
			var point:=world_to_screen(p)
			if not map_rect.grow(-14).has_point(point):continue
			var water: float=generator.sample(p).z
			if water>.9:
				if generator.random_at(x,y,714)<.13:draw_line(point-Vector2(5,0),point+Vector2(5,0),Color(.8,.9,.88,.22),1,true)
				continue
			if water>.02:continue
			var w: Color=generator.ecology_weights(p)
			var scale_g:=clampf(zoom/8.,.65,1.4)
			if w.r>.85 and generator.random_at(x,y,715)<.60:
				for shift in [Vector2(-4,1),Vector2(3,-2),Vector2(6,3)]:
					var at: Vector2=point+shift*scale_g
					draw_colored_polygon(PackedVector2Array([at+Vector2(-4,2)*scale_g,at+Vector2(-3,-3)*scale_g,at+Vector2(0,-6)*scale_g,at+Vector2(4,-2)*scale_g,at+Vector2(5,3)*scale_g,at+Vector2(0,5)*scale_g]),Color('54785d'))
					draw_arc(at,3*scale_g,3.5,5.5,6,Color('91b28a'),1,true)
			elif w.a>.8 and generator.random_at(x,y,716)<.45:
				draw_polyline(PackedVector2Array([point+Vector2(-8,4)*scale_g,point+Vector2(-2,-5)*scale_g,point+Vector2(1,-3)*scale_g,point+Vector2(4,-7)*scale_g,point+Vector2(10,3)*scale_g]),Color('7a817c'),1.4,true)
				draw_line(point+Vector2(4,-5)*scale_g,point+Vector2(3,2)*scale_g,Color('d1d2bd'),1,true)
			elif w.b>.8 and generator.random_at(x,y,717)<.18:
				draw_arc(point,6*scale_g,3.5,5.5,8,Color(.36,.49,.31,.23),1,true)

func draw_markers(layer: Control) -> void:
	var ex:=exploration()
	if item_screen:
		for sign in item_screen.service.builds.map_signposts():
			var world_p:=Vector2(sign.x,sign.y)
			var point:=world_to_screen(world_p)
			if not map_rect.grow(-8).has_point(point) or not ex or not ex.explored(world_p):continue
			layer.draw_line(point,point+Vector2(0,-12),Color('604b32'),2,true)
			layer.draw_rect(Rect2(point+Vector2(-5,-15),Vector2(10,7)),Color('efcc87'))
			var label: String=sign.text
			var label_size:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,15)
			var origin:=Vector2(clampf(point.x+8,map_rect.position.x+3,maxf(map_rect.position.x+3,map_rect.end.x-label_size.x-3)),clampf(point.y-6,map_rect.position.y+18,map_rect.end.y-3))
			layer.draw_string(font,origin,label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color('fff0c8'))
	for marker in player_markers():
		var point:=world_to_screen(marker.position)
		if not map_rect.grow(-8).has_point(point):continue
		var color:=Color('ffdf74') if marker.self else Color('83e5ef')
		layer.draw_circle(point,8,Color('253c3b'));layer.draw_circle(point,5,color)
		if marker.self:layer.draw_line(point,point+Vector2(0,-13),Color('fff9db'),2,true)
		var label:=str(marker.name)
		var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		var origin:=Vector2(clampf(point.x+12,map_rect.position.x+3,maxf(map_rect.position.x+3,map_rect.end.x-width-3)),clampf(point.y-10,map_rect.position.y+18,map_rect.end.y-3))
		layer.draw_string_outline(font,origin,label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,3,Color('253c3b'))
		layer.draw_string(font,origin,label,HORIZONTAL_ALIGNMENT_LEFT,-1,15,color)

func player_markers() -> Array[Dictionary]:
	var world=player.get_parent().get_parent()
	if world and world.has_method("map_players"):return world.map_players()
	return [{"position":player.position,"name":"自己","self":true}]

func _input(event: InputEvent) -> void:
	if item_screen and item_screen.service.body.sleep_active():return
	if item_screen and (item_screen.item_modal_open() or get_viewport().gui_is_dragging()):return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_M:
			if visible:close_map()
			else:open_map()
			get_viewport().set_input_as_handled();return
		if visible and event.physical_keycode==KEY_ESCAPE:
			close_map();get_viewport().set_input_as_handled();return
	if not visible:return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		for trigger in get_tree().get_nodes_in_group("world_menu_trigger"):
			if trigger.is_visible_in_tree() and trigger.get_global_rect().has_point(event.position):return
	if event is InputEventMouseButton:
		if recenter.get_global_rect().has_point(event.position) and event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:recenter.pressed.emit()
			dragging=false
		elif event.button_index==MOUSE_BUTTON_LEFT:dragging=event.pressed and map_rect.has_point(event.position)
		if event.pressed and map_rect.has_point(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var before:=screen_to_world(event.position)
			zoom=clampf(zoom*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .8),1,32)
			center+=before-screen_to_world(event.position)
	if event is InputEventMouseMotion and dragging:center-=event.relative*generator.extent/maxf(map_rect.size.x*zoom,1)
	clamp_center();get_viewport().set_input_as_handled()
