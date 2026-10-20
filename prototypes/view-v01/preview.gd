extends "res://prototypes/view-v01/world_base.gd"
var review_ready:=false
var review_label:=Label.new()
func load_world_identity(path:String=WORLD_ID_PATH)->void:
	world_seed=271828
	map_cells=1024
func save_world_identity(_path:String=WORLD_ID_PATH)->void:pass
func _ready()->void:
	super._ready()
	player.automated=true
	player.camera.position_smoothing_enabled=false
	while not started:await get_tree().process_frame
	for i in 8:await get_tree().process_frame
	ui.hide()
	var layer:=CanvasLayer.new();add_child(layer);layer.add_child(review_label)
	review_label.position=Vector2(18,14)
	review_label.add_theme_font_size_override("font_size",17)
	review_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	review_label.add_theme_constant_override("shadow_offset_x",1)
	review_label.add_theme_constant_override("shadow_offset_y",2)
	review_label.text=("旧版" if Engine.get_meta("view_before",false) else "候选 · 待确认")+"  1旧版 / 2候选 · 3出生 / 4湖岸 / 5森林 / 6山地 · WASD移动
同Seed 271828 · 原相机/角色/尺度 · 湖泊 %d / 原%d"%[generator.lakes.size(),generator.original_lake_count]
	review_ready=true
	goto_view(int(Engine.get_meta("view_location",3)))
func goto_view(which:int)->void:
	Engine.set_meta("view_location",which)
	var point:=generator.spawn
	player.camera.position=Vector2.ZERO
	if which==4:
		var original:WildGenerator=load("res://prototypes/view-v01/formal_v03.gd").new(world_seed,map_cells)
		for lake in original.lakes:
			if original.random_at(roundi(lake.x),roundi(lake.y),934)>=.5 or lake.z>400 or lake.w>280 or original.sample(Vector2(lake.x,lake.y),false).x<.6:continue
			# Pick the same retained lake and land position in both modes.
			point=Vector2(lake.x-lake.z*1.5,lake.y+lake.w*.15)
			while not original.can_walk(point,30):point.x-=12
			var center:=Vector2(lake.x,lake.y)
			for i in 3:center=Vector2(lake.x,lake.y)-Vector2(original.warp.get_noise_2d(center.x,center.y),original.warp.get_noise_2d(center.y+1200,center.x))*240
			player.camera.position=center-point
			break
	if which in [5,6]:
		for site in generator.region_sites.values():
			var pos:=Vector2(site.x,site.y)
			if int(site.z)==which-5 and pos.x>1500 and pos.y>1500 and pos.x<generator.extent-1500 and pos.y<generator.extent-1500 and generator.can_walk(pos,30):point=pos;break
	player.position=point
	player.camera.reset_smoothing()
	stream.update_target(point)
func _unhandled_input(event:InputEvent)->void:
	if not review_ready:return
	if event is InputEventKey and event.pressed:
		if event.physical_keycode in [KEY_1,KEY_2]:
			Engine.set_meta("view_before",event.physical_keycode==KEY_1)
			get_tree().reload_current_scene()
		elif event.physical_keycode in [KEY_3,KEY_4,KEY_5,KEY_6]:goto_view(event.physical_keycode-KEY_0)
