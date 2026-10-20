extends Node2D

const Gen = preload("res://scripts/world_generator.gd")
const Stream = preload("res://scripts/chunk_stream.gd")
const Player = preload("res://scripts/player.gd")
@export var world_seed: int = 271828
@export_range(128,1024,8) var map_cells: int = 1024
var generator: WildGenerator
var stream: WildStream
var player: WildPlayer
var object_root := Node2D.new()
var ui := CanvasLayer.new()
var title := Label.new()
var hint := Label.new()
var debug_label := Label.new()
var loading_cover := ColorRect.new()
var loading_label := Label.new()
var map_view: Control
var item_service: Node
var camp_ui: Control
var item_ui: Control
var items_preview := false
var tools_preview := false
var environment_view: CanvasLayer
var debug_on := false
var started := false
var occlusion_clock := 0.0
var ui_clock := 0.0
var elapsed := 0.0
var frametimes: Array[float] = []
var benchmark := false
var benchmark_duration := 70.0
var checkpoint := 0
var coverage_gaps := 0
var gap_frames := 0
var peak_memory := 0.0
var sample_start := 0.0
var settings: Dictionary = {}
var run_id := "runtime"
var benchmark_captures := false
var last_frame_usec := 0
var benchmark_travel := 0.0
var memory_samples: Array[Dictionary] = []
var benchmark_north := false
var persistent_world := true
const WORLD_ID_PATH = "user://world-continent-v06.json"
const LEGACY_WORLD_ID_PATH = "user://world-biome-v02.json"
var migration_notice := ""
var migrated_from := ""

func _ready() -> void:
	# Static streamed scenery and idle tweens do not need physics interpolation.
	# The player explicitly enables it for its moving body, rig and camera.
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	load_world_identity()
	parse_arguments()
	if persistent_world: save_world_identity()
	setup_input()
	generator=Gen.new(world_seed,map_cells)
	object_root.name="YSortedNatureAndActor"
	object_root.y_sort_enabled=true
	stream=Stream.new()
	stream.name="StreamedTerrain"
	add_child(stream)
	add_child(object_root)
	stream.configure(generator,object_root)
	player=Player.new()
	player.name="Wanderer"
	player.generator=generator
	player.stream=stream
	player.position=generator.spawn
	object_root.add_child(player)
	player.reset_physics_interpolation()
	player.camera.reset_smoothing()
	stream.update_target(player.position)
	setup_ui()
	ui.layer=2
	environment_view=preload("res://scripts/environment_view.gd").new()
	add_child(environment_view)
	environment_view.configure(self)
	map_view=load("res://scripts/world_map.gd").new()
	var map_layer := CanvasLayer.new()
	map_layer.name="TopmostWorldMap"
	map_layer.layer=10
	add_child(map_layer)
	map_layer.add_child(map_view)
	map_view.configure(generator,player)
	item_service=preload("res://scripts/item_service.gd").new()
	add_child(item_service)
	item_service.configure(self,items_preview)
	restore_player_entry()
	if tools_preview:
		for id in ["stone_axe","stone_pickaxe","simple_shovel"]: item_service.inventory.add(id,1)
	if Engine.get_meta("camp_build_preview",false):
		item_service.inventory.add("stone_hammer",1)
		for id in ["stone","wood","plant_fiber","flint"]: item_service.inventory.add(id,500 if id!="flint" else 20)
	item_ui=preload("res://scripts/item_ui.gd").new()
	ui.add_child(item_ui)
	item_ui.configure(self,item_service)
	camp_ui=preload("res://scripts/campfire_ui.gd").new()
	ui.add_child(camp_ui)
	camp_ui.configure(self)
	item_service.sleep_ui=preload("res://scripts/sleep_ui.gd").new()
	ui.add_child(item_service.sleep_ui);item_service.sleep_ui.configure(item_service)
	item_service.storage_ui=preload("res://scripts/camp_storage_ui.gd").new()
	ui.add_child(item_service.storage_ui);item_service.storage_ui.configure(item_service)
	# Pointer priority follows scene order as well as visual Z.
	item_ui.ground_drop.reparent(ui)
	ui.move_child(item_ui.ground_drop,item_ui.get_index())
	ui.move_child(item_service.storage_ui,item_ui.get_index())
	item_service.industry_ui=preload("res://scripts/industry_ui.gd").new()
	ui.add_child(item_service.industry_ui);item_service.industry_ui.configure(item_service)
	item_service.expansion_ui=preload("res://scripts/camp_expansion_ui.gd").new()
	ui.add_child(item_service.expansion_ui);item_service.expansion_ui.configure(item_service)
	item_service.planting_ui=preload("res://scripts/planting_ui.gd").new()
	ui.add_child(item_service.planting_ui);item_service.planting_ui.configure(item_service)
	item_service.merchant.ready_world()
	map_view.item_screen=item_ui
	if OS.has_feature("debug"):
		var resource_debug := preload("res://scripts/resource_debug.gd").new()
		resource_debug.name="ResourceDebug"
		add_child(resource_debug)
		resource_debug.configure(self)
	AudioFX.bind_world(self)
	if not Engine.get_meta("fishing_preview_fixture",false):
		var fishing := preload("res://scripts/fishing.gd").new()
		fishing.name="Fishing"
		add_child(fishing)
		fishing.configure(self,item_service.fishing_population.spots)
	if benchmark:
		player.automated=true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(item_service):
		item_service.save_state()

func load_world_identity(path: String = WORLD_ID_PATH) -> void:
	world_seed=int(Time.get_unix_time_from_system()*1000)%2147483647
	migration_notice=""
	migrated_from=""
	if FileAccess.file_exists(path):
		var data=JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary and str(data.get("generator",""))==Gen.VERSION and data.has("seed"):
			world_seed=int(data.seed)
			map_cells=clampi(int(data.get("map_cells",1024)),128,1024)
			migrated_from=str(data.get("migrated_from",""))
		else:
			# Never overwrite an unknown/corrupt identity with a different algorithm.
			persistent_world=false
			migration_notice="世界版本不匹配，当前为临时 V0.6 世界；原存档已保留"
		return
	# Only the normal entry migrates the old identity; explicit test paths stay isolated.
	if path==WORLD_ID_PATH:load_legacy_identity(LEGACY_WORLD_ID_PATH)

func load_legacy_identity(path:String)->void:
	if FileAccess.file_exists(path):
		var legacy=JSON.parse_string(FileAccess.get_file_as_string(path))
		if legacy is Dictionary and str(legacy.get("generator","")).begins_with("windrest-biome-") and legacy.has("seed"):
			world_seed=int(legacy.seed)
			map_cells=clampi(int(legacy.get("map_cells",1024)),128,1024)
			migrated_from=str(legacy.generator)
			migration_notice="已升级 V0.6 大陆，沿用旧 Seed；旧世界身份已保留"
func save_world_identity(path: String = WORLD_ID_PATH) -> void:
	if not persistent_world:return
	var identity:={"seed":world_seed,"map_cells":map_cells,"generator":Gen.VERSION,"props_version":Gen.PROP_VERSION}
	if not migrated_from.is_empty():identity["migrated_from"]=migrated_from
	save_json(path,identity)

func parse_arguments() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--items-preview": items_preview=true
		if arg=="--tools-preview": tools_preview=true; persistent_world=false
		if arg=="--camp-build-preview": tools_preview=true;persistent_world=false;Engine.set_meta("camp_build_preview",true)
		if arg.begins_with("--seed=") or arg.begins_with("--size=") or arg=="--benchmark":persistent_world=false
		if arg.begins_with("--seed="): world_seed=int(arg.get_slice("=",1))
		elif arg.begins_with("--size="): map_cells=clampi(int(arg.get_slice("=",1)),128,1024)
		elif arg=="--benchmark": benchmark=true; debug_on=true
		elif arg.begins_with("--seconds="): benchmark_duration=float(arg.get_slice("=",1))
		elif arg.begins_with("--report="): run_id=arg.get_slice("=",1)
		elif arg=="--capture": benchmark_captures=true
	if Engine.has_meta("resources_debug_seed"):
		world_seed=int(Engine.get_meta("resources_debug_seed"))
		persistent_world=false

func setup_input() -> void:
	var keys := {"run":[KEY_SHIFT],"interact":[KEY_E],"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN]}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode=key
			InputMap.action_add_event(action,event)

func restore_player_entry() -> void:
	if not item_service.body.sleep_active() and not item_service.restored_player_position:
		player.position=choose_entry_point()
	player.reset_physics_interpolation()
	player.camera.reset_smoothing()
	stream.update_target(player.position)

func choose_entry_point() -> Vector2:
	# Keep generator.spawn as the historical terrain/lake/resource anchor.
	# Entry placement uses the actual four-way ecology and completed water layer.
	for attempt in 2048:
		var p:=Vector2(generator.random_at(attempt,0,16061),generator.random_at(attempt,1,16061))*generator.extent
		if generator.coast_distance(p)<160 or generator.sample(p).z>.03:continue
		if not item_service.ground_clear(p,20,item_service.nearby_props(p)):continue
		var blocked:=false
		for row in item_service.builds.states.values():
			if row.layer=="ground":continue
			var bounds:Rect2=item_service.builds.footprint_rect(row)
			bounds.position+=Vector2(row.x,row.y)
			if row.layer=="edge":bounds=Rect2(Vector2(row.x,row.y)-Vector2(80,80),Vector2(160,160))
			if bounds.grow(24).has_point(p):blocked=true;break
		if not blocked:return p
	return generator.spawn

func make_label(node: Label, text_value: String, pos: Vector2, size: int) -> void:
	node.text=text_value
	node.position=pos
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",Color("edf0cf"))
	node.add_theme_color_override("font_shadow_color",Color(.15,.21,.13,.7))
	node.add_theme_constant_override("shadow_offset_x",1)
	node.add_theme_constant_override("shadow_offset_y",2)
	ui.add_child(node)

func setup_ui() -> void:
	add_child(ui)
	make_label(title,"风栖原野 · V0.4"+(" · 工具试用（临时）" if tools_preview else " · 物品预览存档" if items_preview else ""),Vector2(26,20),25)
	if not migration_notice.is_empty():title.text+="  |  "+migration_notice
	make_label(hint,"WASD 移动 · 按住 Shift 奔跑 · E 交互 · 滚轮缩放 · B 背包 · 1–8 快捷栏 · M 地图 · N 新世界 · F3 调试 · F4 环境",Vector2(26,58),15)
	make_label(debug_label,"",Vector2(26,112),16)
	debug_label.visible=debug_on
	loading_cover.color=Color("6c8c62")
	loading_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(loading_cover)
	loading_label.text="风栖原野\n正在铺展原野…"
	loading_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	loading_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	loading_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_label.add_theme_font_size_override("font_size",26)
	loading_label.add_theme_color_override("font_color",Color("eff0da"))
	ui.add_child(loading_label)

func _process(delta: float) -> void:
	elapsed+=delta
	if not started:
		if stream.viewport_ready(player.position,get_viewport_rect().size/(player.camera.zoom*2)):
			started=true
			loading_cover.hide()
			loading_label.hide()
			sample_start=elapsed
			last_frame_usec=Time.get_ticks_usec()
		return
	ui_clock+=delta
	occlusion_clock+=delta
	if occlusion_clock>.1:
		occlusion_clock=0
		for prop in object_root.get_children():
			if is_instance_valid(prop) and prop!=player and prop.has_method("update_occlusion"): prop.update_occlusion(player.position)
	if ui_clock>.25:
		ui_clock=0
		var target := player.selected_target()
		hint.text="WASD 移动 · Shift 奔跑 · E 交互 · 滚轮缩放 · B 背包 · 1–8 快捷栏 · M 地图 · N 新世界 · F3 调试 · F4 环境"
		if target!=null: hint.text += "  |  "+preload("res://scripts/world_interaction.gd").caption(target,item_service.inventory)
		if OS.has_feature("debug"): hint.text+=" · F7 资源分布"
		var memory := OS.get_static_memory_usage()/1048576.0
		peak_memory=maxf(peak_memory,memory)
		debug_label.text="Seed %d  ·  %s  ·  %d×%d\n%s  (%.0f, %.0f)\n%d FPS · %.2f ms\n区块 %d · 对象 %d · 节点 %d\n内存 %.1f MiB · 前方待生成 %d\n挂载 %.2f ms · 后台生成 %.1f ms"%[
			world_seed,Gen.VERSION,map_cells,map_cells,generator.biome(player.position),player.position.x,player.position.y,
			Engine.get_frames_per_second(),delta*1000,stream.loaded.size(),stream.object_count,get_tree().get_node_count(),memory,
			stream.requested.size()+stream.tasks.size(),stream.last_install_ms,stream.last_build_ms]
	if benchmark: run_benchmark(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F3:
		debug_on=not debug_on
		debug_label.visible=debug_on

	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_N and persistent_world:
		if item_service: item_service.save_state()
		world_seed=(world_seed+int(Time.get_ticks_msec())+1)%2147483647
		save_world_identity()
		get_tree().reload_current_scene()

func save_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"\t"))

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func run_benchmark(delta: float) -> void:
	var time := elapsed-sample_start
	var now := Time.get_ticks_usec()
	var wall_ms := (now-last_frame_usec)/1000.0
	last_frame_usec=now
	# 8 direction input, rapid direction changes, idle transitions, then sustained
	# traversal across many chunk seams. Acceleration is test-only, never gameplay.
	if time<8:
		var dirs := [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP,Vector2(1,1).normalized(),Vector2(-1,1).normalized(),Vector2(-1,-1).normalized(),Vector2(1,-1).normalized()]
		player.input_override=dirs[int(time)%8]
	elif time<12:
		player.input_override=[Vector2.RIGHT,Vector2.UP,Vector2.LEFT,Vector2.DOWN,Vector2.ZERO][int(time*18)%5]
	else:
		if player.position.y>generator.extent-1200: benchmark_north=true
		if player.position.y<1200: benchmark_north=false
		player.input_override=Vector2.UP if benchmark_north else Vector2.DOWN
		# Test-only acceleration checks water and visible chunk coverage. It skips
		# prop collisions; the normal physics step and dedicated tests cover those.
		var extra := player.input_override*Player.WALK_SPEED*7*delta
		if generator.can_walk(player.position+extra) and stream.viewport_ready(player.position+extra,get_viewport_rect().size/(player.camera.zoom*2)):
			player.position+=extra
			benchmark_travel+=extra.length()
	if time>2:
		frametimes.append(wall_ms)
	if memory_samples.is_empty() or time-float(memory_samples.back().time)>=5:
		memory_samples.append({"time":time,"static_memory_mib":OS.get_static_memory_usage()/1048576.0,"loaded":stream.loaded.size(),"objects":stream.object_count})
	var visible_ready := stream.viewport_ready(player.position,get_viewport_rect().size/(player.camera.zoom*2))
	if not visible_ready: gap_frames+=1
	if not stream.has_ground(player.position): coverage_gaps+=1
	if benchmark_captures and checkpoint==0 and time>3:
		checkpoint=1
		capture("res://reports/%s-spawn.png"%run_id)
	if benchmark_captures and checkpoint==1 and time>16:
		checkpoint=2
		capture("res://reports/%s-exploration.png"%run_id)
	if time>=benchmark_duration:
		set_process(false)
		frametimes.sort()
		var total := 0.0
		for value in frametimes: total+=value
		var mean := total/maxi(1,frametimes.size())
		var report := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
			"adapter":RenderingServer.get_video_adapter_name(),"seed":world_seed,"generator":Gen.VERSION,"map_cells":map_cells,
			"viewport":str(get_viewport_rect().size),"seconds":time,"samples":frametimes.size(),"average_fps":1000.0/maxf(.001,mean),
			"mean_frame_ms":mean,"p95_frame_ms":frametimes[int(frametimes.size()*.95)],"p99_frame_ms":frametimes[int(frametimes.size()*.99)],
			"max_frame_ms":frametimes.back(),"static_memory_mib":OS.get_static_memory_usage()/1048576.0,"peak_static_memory_mib":peak_memory,
			"video_memory_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,
			"loaded_chunks":stream.loaded.size(),"total_chunks_loaded":stream.total_loaded,"total_chunks_unloaded":stream.total_unloaded,
			"objects":stream.object_count,"nodes":get_tree().get_node_count(),"max_chunk_install_ms":stream.max_install_ms,
			"missing_player_ground_frames":coverage_gaps,"viewport_not_ready_frames":gap_frames,
			"position":str(player.position),"spawn":str(generator.spawn),"vsync":false,
			"accelerated_distance_px":benchmark_travel,"memory_samples":memory_samples,"captures_during_run":benchmark_captures,
			"method":"Rendered window; wall-clock frame intervals. 8-way input + rapid switching + 8x accelerated streaming stress (harness skips prop collisions); excludes startup and first 2s. Physics collisions tested separately."}
		save_json("res://reports/%s-performance.json"%run_id,report)
		print("BENCHMARK ",JSON.stringify(report))
		if benchmark_captures: await capture("res://reports/%s-final.png"%run_id)
		get_tree().quit()

