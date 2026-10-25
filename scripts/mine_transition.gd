extends CanvasLayer
## Presentation fence: region changes remain inside the original saved transaction.
var s: Node
var active:=false
var settling:=false
var curtain:=ColorRect.new()
var fade: Tween
var content:=VBoxContainer.new()
var caption:=Label.new()
var progress:=ProgressBar.new()
var ready_to_show:=false
func _ready() -> void:
	layer=200
	curtain.color=Color("171a1c");curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(curtain);curtain.modulate.a=0;curtain.hide()
	content.add_theme_constant_override("separation",12);curtain.add_child(content)
	var icon:=TextureRect.new();icon.texture=load("res://assets/exploration/mine-v1/entrance.png")
	icon.custom_minimum_size=Vector2(240,68);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(icon)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_font_size_override("font_size",22)
	caption.add_theme_color_override("font_color",Color("e6ddca"));content.add_child(caption)
	progress.min_value=0;progress.max_value=1;progress.show_percentage=false
	progress.custom_minimum_size=Vector2(180,4);progress.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	var track:=StyleBoxFlat.new();track.bg_color=Color("3b3e3c");track.set_corner_radius_all(2)
	var fill:=StyleBoxFlat.new();fill.bg_color=Color("c4ad7f");fill.set_corner_radius_all(2)
	progress.add_theme_stylebox_override("background",track);progress.add_theme_stylebox_override("fill",fill);content.add_child(progress)
	for node in [content,icon,caption,progress]:node.mouse_filter=Control.MOUSE_FILTER_IGNORE
func set_caption(kind: String) -> void:
	caption.text="进入矿洞…" if kind=="enter" else "返回地表…"
func loaded_fraction() -> float:
	var world=s.world
	if s.chapter.mine.travel.inside:
		var view=world.item_service.chapter_view.get_node("MineView")
		return 1.0 if is_instance_valid(view.interior) and view.interior.visible else 0.0
	var half: Vector2=world.get_viewport_rect().size/(world.player.camera.zoom*2.0)
	var lo: Vector2i=world.stream.chunk_at(world.player.position-half-Vector2(180,280))
	var hi: Vector2i=world.stream.chunk_at(world.player.position+half+Vector2(180,180))
	var total:=0;var count:=0
	for y in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			var coord:=Vector2i(x,y)
			if world.stream.valid_chunk(coord):
				total+=1
				if world.stream.loaded.has(coord):count+=1
	return float(count)/maxi(total,1)
func _process(delta: float) -> void:
	if not active:return
	content.size=Vector2(240,130);content.position=(get_viewport().get_visible_rect().size-content.size)*.5
	var target: float=1.0 if ready_to_show else .2+.65*loaded_fraction() if settling else .18
	progress.value=move_toward(progress.value,target,delta*3.5)
func cover_now() -> void:
	if not active:set_caption("exit" if s.chapter.mine.travel.inside else "enter");progress.value=0
	ready_to_show=false
	if is_instance_valid(fade):fade.kill()
	active=true;s.world.set_meta("mine_transition_active",true)
	s.world.player.input_blocked=true;s.world.player.velocity=Vector2.ZERO
	curtain.show();curtain.modulate.a=1
func request(kind: String) -> void:
	if active:return
	set_caption(kind);progress.value=0;ready_to_show=false
	active=true;s.world.set_meta("mine_transition_active",true)
	s.world.player.input_blocked=true;s.world.player.velocity=Vector2.ZERO
	curtain.show();curtain.modulate.a=0
	fade=create_tween();fade.tween_property(curtain,"modulate:a",1.0,.18)
	await fade.finished
	var serial: int=int(s.chapter.mine.travel.serial)
	var result: String=s.chapter.mine.interact(kind)
	if not result.is_empty():
		s.notice.emit(result);prepare_reveal();return
	if s.world.get_meta("network_game",false):
		var limit: int=Time.get_ticks_msec()+12000
		while active and int(s.chapter.mine.travel.serial)==serial and Time.get_ticks_msec()<limit:
			await get_tree().process_frame
		if active and int(s.chapter.mine.travel.serial)==serial:prepare_reveal()
func prepare_reveal() -> void:
	if settling:return
	settling=true;reveal_when_ready.call_deferred()
func reveal_when_ready() -> void:
	cover_now()
	var world=s.world
	world.stream.update_target(world.player.position)
	await get_tree().process_frame;await get_tree().process_frame
	var half: Vector2=world.get_viewport_rect().size/(world.player.camera.zoom*2.0)
	while not world.stream.viewport_ready(world.player.position,half) or not world.stream.has_ground(world.player.position):
		world.stream.update_target(world.player.position)
		await get_tree().process_frame
	var view=world.item_service.chapter_view.get_node("MineView")
	if s.chapter.mine.travel.inside:
		while not is_instance_valid(view.interior) or not view.interior.visible:await get_tree().process_frame
	world.player.reset_physics_interpolation();world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	await get_tree().physics_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	ready_to_show=true;progress.value=1.0
	await get_tree().create_timer(.06).timeout
	fade=create_tween();fade.tween_property(curtain,"modulate:a",0.0,.22)
	await fade.finished
	curtain.hide();active=false;settling=false;world.set_meta("mine_transition_active",false)
	world.item_ui.update_input_block()
func _input(_event: InputEvent) -> void:
	if active:get_viewport().set_input_as_handled()
