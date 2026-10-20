extends Node2D
## Isolated preview only. No dependency on the production game.

const RIG = preload("res://hero_rig.tscn")
const DURATIONS := {"walk": 8.0 / 13.8, "breathe": 1.8, "wave": 2.4}
const INK := Color("38493d")
const MUTED := Color("71806a")
@export_range(0.35, 1.2, 0.001) var walk_cycle_seconds := 8.0 / 13.8
var rig: Node2D
var small_rig: Node2D
var reference: Sprite2D
var small_reference: Sprite2D
var reference_frames: Dictionary = {}
var action := "walk"
var paused := false
var speed := 1.0
var clock := 0.0
var zoom := 3.0
var mirror := false
var phase_slider: HSlider
var status_label: Label
var left_note: Label
var pause_button: Button
var action_picker: OptionButton
var outfit_picker: OptionButton
var bone_check: CheckBox
var speed_picker: OptionButton
var mirror_check: CheckBox
var cycle_control: SpinBox

func _ready() -> void:
	for clip in ["walk", "idle"]:
		var frames: Array[Texture2D] = []
		for i in (8 if clip == "walk" else 4):
			frames.append(load("res://reference/side_%s_%02d.png" % [clip, i]))
		reference_frames[clip] = frames
	reference = Sprite2D.new()
	reference.centered = false
	reference.position = Vector2(300, 470) - Vector2(64, 112) * zoom
	reference.scale = Vector2.ONE * zoom
	add_child(reference)
	rig = RIG.instantiate()
	rig.position = Vector2(900, 470) - Vector2(64, 112) * zoom
	rig.scale = Vector2.ONE * zoom
	add_child(rig)
	small_reference = Sprite2D.new()
	small_reference.centered = false
	small_reference.position = Vector2(300, 655) - Vector2(64, 112)
	add_child(small_reference)
	small_rig = RIG.instantiate()
	small_rig.position = Vector2(900, 655) - Vector2(64, 112)
	add_child(small_rig)
	build_controls()
	set_action("walk")
	queue_redraw()

func label_at(text: String, at: Vector2, size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func option_at(items: Array, at: Vector2, width: float) -> OptionButton:
	var option := OptionButton.new()
	for item in items:
		option.add_item(item)
	option.position = at
	option.size = Vector2(width, 36)
	add_child(option)
	return option

func build_controls() -> void:
	label_at("风栖原野  /  原生 2D 骨骼实验", Vector2(30, 16), 25)
	label_at("右侧视角 · 独立原型 v01 · 128×128 / 脚底 (64,112)", Vector2(30, 50), 15, MUTED)
	label_at("已确认 v11 · 完整序列帧", Vector2(64, 126), 22)
	label_at("新中性部件 · 18 骨骼 / 权重网格", Vector2(654, 126), 22)
	left_note = label_at("", Vector2(64, 160), 15, MUTED)
	label_at("两套上衣共用同一组骨骼关键帧", Vector2(654, 160), 15, MUTED)
	label_at("原始 1:1 尺寸", Vector2(244, 677), 14, MUTED)
	label_at("原始 1:1 尺寸", Vector2(844, 677), 14, MUTED)
	action_picker = option_at(["行走  0.580 秒", "呼吸  1.800 秒", "挥手  2.400 秒"], Vector2(30, 84), 184)
	action_picker.item_selected.connect(func(i): set_action(["walk", "breathe", "wave"][i]))
	outfit_picker = option_at(["鼠尾草短外套", "青蓝套头上衣"], Vector2(227, 84), 164)
	outfit_picker.item_selected.connect(set_outfit)
	bone_check = CheckBox.new()
	bone_check.text = "显示骨骼 [B]"
	bone_check.add_theme_color_override("font_color", INK)
	bone_check.position = Vector2(407, 84)
	bone_check.toggled.connect(func(on): rig.show_bones = on)
	add_child(bone_check)
	mirror_check = CheckBox.new()
	mirror_check.text = "镜像左侧"
	mirror_check.add_theme_color_override("font_color", INK)
	mirror_check.position = Vector2(560, 84)
	mirror_check.toggled.connect(set_mirror)
	add_child(mirror_check)
	speed_picker = option_at(["正常 1×", "慢速 0.25×", "半速 0.5×"], Vector2(700, 84), 127)
	speed_picker.item_selected.connect(func(i): speed = [1.0, .25, .5][i])
	pause_button = Button.new()
	pause_button.text = "暂停 [空格]"
	pause_button.position = Vector2(840, 84)
	pause_button.size = Vector2(124, 36)
	pause_button.pressed.connect(toggle_pause)
	add_child(pause_button)
	var step := Button.new()
	step.text = "步进 1/64"
	step.position = Vector2(978, 84)
	step.size = Vector2(110, 36)
	step.pressed.connect(func(): step_phase(1.0 / 64.0))
	add_child(step)
	label_at("行走周期 / 秒", Vector2(1098, 60), 12, MUTED)
	cycle_control = SpinBox.new()
	cycle_control.min_value = .35
	cycle_control.max_value = 1.2
	cycle_control.step = .001
	cycle_control.value = walk_cycle_seconds
	cycle_control.position = Vector2(1100, 84)
	cycle_control.size = Vector2(86, 36)
	cycle_control.value_changed.connect(func(value):
		var previous_phase := clock / current_duration()
		walk_cycle_seconds = value
		if action == "walk":
			clock = previous_phase * current_duration()
		update_pose())
	add_child(cycle_control)
	phase_slider = HSlider.new()
	phase_slider.position = Vector2(65, 715)
	phase_slider.size = Vector2(1065, 28)
	phase_slider.min_value = 0
	phase_slider.max_value = 1
	phase_slider.step = .0001
	phase_slider.value_changed.connect(func(value):
		paused = true
		clock = minf(value, .999999) * current_duration()
		update_pose())
	add_child(phase_slider)
	status_label = label_at("", Vector2(65, 752), 16)
	label_at("1 / 2 / 3 动作   C 上衣   B 骨骼   空格 暂停   ← / → 步进", Vector2(610, 754), 14, MUTED)

func _draw() -> void:
	for x in [30.0, 630.0]:
		draw_style_box(panel_style(), Rect2(x, 193, 540, 315))
		draw_line(Vector2(x + 24, 470), Vector2(x + 516, 470), Color("adbba0"), 1.0)
		for xx in range(5):
			var gx: float = x + 78 + xx * 96
			draw_line(Vector2(gx, 210), Vector2(gx, 493), Color(0.5, .6, .4, .07), 1.0)
		# Fixed registration cross, independent of animated body and shadow.
		draw_line(Vector2(x + 264, 470), Vector2(x + 276, 470), Color("66805f"), 1.5)
		draw_line(Vector2(x + 270, 464), Vector2(x + 270, 476), Color("66805f"), 1.5)
		draw_line(Vector2(x + 220, 655), Vector2(x + 320, 655), Color("adbba0"), 1.0)
	# Slight, fixed grounding shadows; neither is part of the character artwork.
	for x in [300, 900]:
		paint_shadow(Vector2(x, 471), Vector2(42, 5), Color(.29, .38, .24, .12))

func paint_shadow(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(points, color)

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e4ebd7")
	style.set_corner_radius_all(14)
	return style

func set_action(value: String) -> void:
	action = value
	clock = 0.0
	if action_picker:
		action_picker.select(["walk", "breathe", "wave"].find(action))
	for character in [rig, small_rig]:
		var player: AnimationPlayer = character.animation_player()
		player.play(action)
		player.pause()
	left_note.text = "相同周期 / 原版八帧" if action == "walk" else "相同周期 / 原版四帧" if action == "breathe" else "v11 无挥手素材；保留原待机作体型参照"
	update_pose()

func set_outfit(value: int) -> void:
	rig.outfit = value
	small_rig.outfit = value
	outfit_picker.select(value)

func set_mirror(value: bool) -> void:
	mirror = value
	var direction: float = -1.0 if mirror else 1.0
	rig.scale.x = zoom * direction
	rig.position.x = 900 - 64 * zoom * direction
	small_rig.scale.x = direction
	small_rig.position.x = 900 - 64 * direction
	reference.flip_h = value
	small_reference.flip_h = value

func toggle_pause() -> void:
	paused = not paused
	update_pose()

func current_duration() -> float:
	return walk_cycle_seconds if action == "walk" else float(DURATIONS[action])

func step_phase(amount: float) -> void:
	paused = true
	clock = fposmod(clock + amount * current_duration(), current_duration())
	update_pose()

func update_pose() -> void:
	for character in [rig, small_rig]:
		character.animation_player().seek(clock / current_duration() * float(DURATIONS[action]), true)
	var phase: float = clock / current_duration()
	var clip := "walk" if action == "walk" else "idle"
	var frame := mini(int(phase * reference_frames[clip].size()), reference_frames[clip].size() - 1)
	if action == "wave":
		frame = 0
	reference.texture = reference_frames[clip][frame]
	small_reference.texture = reference.texture
	phase_slider.set_value_no_signal(phase)
	pause_button.text = "播放 [空格]" if paused else "暂停 [空格]"
	status_label.text = "%s   %.3f / %.3f 秒   相位 %05.1f%%   %s" % ["暂停" if paused else "播放", clock, current_duration(), phase * 100, "原版第 %d 帧" % (frame + 1)]

func _process(delta: float) -> void:
	if not paused and rig != null:
		clock = fposmod(clock + delta * speed, current_duration())
		update_pose()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: set_action("walk")
		KEY_2: set_action("breathe")
		KEY_3: set_action("wave")
		KEY_C: set_outfit(1 - rig.outfit)
		KEY_B: bone_check.button_pressed = not bone_check.button_pressed
		KEY_SPACE: toggle_pause()
		KEY_LEFT: step_phase(-1.0 / 64)
		KEY_RIGHT: step_phase(1.0 / 64)
