extends SceneTree
## Uses the production world, production rig, and a disposable restored chapter.
var w: Node
var s: Node
var rig: Node2D
var label: Label
var automatic := true
var moving := false
var world_motion := true
var direction := "front"
var time := 0.0
var anchor := Vector2.ZERO
var sample := Vector2.ZERO
var view: Node
var capture := false
var captured := 0
var checks: Array = []
var pressed: Dictionary = {}
var done := false
var max_slide := 0.0
var last_contacts: Array = []
const DIRECTIONS = {"front":Vector2.DOWN,"back":Vector2.UP,"right":Vector2.RIGHT,"left":Vector2.LEFT}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	s=w.item_service;w.set_process(false);s.set_process(false);w.environment_view.set_process(false);w.player.set_physics_process(false);w.player.automated=true
	s.load_state("",false,JSON.parse_string(FileAccess.get_file_as_string("res://reports/final-chapter-v1/ready.json")))
	var f=s.chapter.finale
	f.state.defeated=false;f.state.triggered=false;f.reset_boss();s.body.health=100;s.combat.personal.phase="alive";s.guide_stage=2;s.combat.state.boars.clear()
	w.environment_view.simulation.day=30;w.environment_view.simulation.minute=600;w.environment_view.simulation.force_weather(0)
	anchor=f.at();sample=anchor
	w.player.position=anchor+Vector2(140,45);w.player.camera.position_smoothing_enabled=false;w.player.camera.zoom=Vector2.ONE
	w.player.camera.offset=Vector2(-140,-90);w.stream.update_target(anchor);w.player.reset_physics_interpolation()
	while not w.stream.viewport_ready(anchor,Vector2(640,360)):await process_frame
	await create_timer(.5).timeout
	view=s.chapter_view.get_node("FinaleView");rig=view.rig
	view.set_process(false)
	view.guardian.visible=true;view.health.visible=false;view.core.visible=false
	w.item_ui.message_time=0;w.item_ui.obtained.hide()
	var layer:=CanvasLayer.new();root.add_child(layer);label=Label.new();label.position=Vector2(280,80);label.add_theme_color_override("font_color",Color.WHITE);layer.add_child(label)
	DisplayServer.window_set_title("远古领主 · 正式骨架移动预览 · 隔离世界")
	capture="--capture" in OS.get_cmdline_user_args()

func _process(delta: float) -> bool:
	if rig==null or done:return false
	for key in [KEY_1,KEY_2,KEY_3,KEY_4,KEY_SPACE,KEY_A,KEY_M,KEY_P]:
		var down := Input.is_physical_key_pressed(key)
		if down and not pressed.get(key,false):
			var event := InputEventKey.new();event.keycode=key;event.pressed=true;_input(event)
		pressed[key]=down
	if capture:delta=1.0/30.0
	time+=delta
	if automatic:
		var block:=int(time/5.0)%4;direction=["front","back","right","left"][block]
		var t:=fmod(time,5);moving=t>=1 and t<3.8
	if moving:sample+=DIRECTIONS[direction]*66*delta
	var root_pos: Vector2=sample if world_motion else anchor
	view.guardian.position=root_pos
	view.visual_root.position=Vector2.ZERO
	rig.advance(delta,sample,"chase" if moving else "idle",direction)
	# Follow displacement in real world mode; nearby original hero remains a scale reference.
	w.player.camera.offset=root_pos-w.player.position+Vector2(0,-90)
	label.text="远古领主 · %s · %s\n1 正面  2 背面  3 右侧  4 左侧  |  空格 走/停  A 自动循环  M 真实位移/原地  P 活动范围\n%s · %.1f / 秒 · 步幅 72 · 不读写玩家存档"%[direction,"行走" if moving else "待机 / 停止", "真实世界位移" if world_motion else "原地观察",66.0 if moving else 0.0]
	if capture and time>=captured/15.0:
		capture_frame.call_deferred(captured);captured+=1
		if time>=20:done=true;finish.call_deferred()
	return false
func capture_frame(index: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/boss-rig-v1/frames/%04d.png"%index)
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4]:
		direction=["front","back","right","left"][event.keycode-KEY_1];automatic=false
	if event.keycode==KEY_SPACE:moving=not moving;automatic=false
	if event.keycode==KEY_A:automatic=not automatic
	if event.keycode==KEY_M:world_motion=not world_motion;rig.initialized=false
	if event.keycode==KEY_P:
		automatic=false;moving=false
		if rig.pose_override.is_empty():rig.pose_override={"RightUpperArm":-2.4,"RightElbow":.8,"LeftUpperArm":1.6,"LeftElbow":-.6}
		else:rig.release_pose()
func finish() -> void:
	await create_timer(.15).timeout
	print("BOSS PREVIEW CAPTURE ",captured," frames")
	s.dirty=false;w.queue_free();await process_frame;quit()

