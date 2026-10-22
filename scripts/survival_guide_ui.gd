extends Control
## Local first-entry guide. Progress belongs to the original character item snapshot.
const DIR="res://assets/ui/survival_guide_v1/"
var screen: Control
var letter:=ColorRect.new()
var page:=Control.new()
var ring:=TextureRect.new()
var arrow:=TextureRect.new()
var caption:=Label.new()
var handwriting: Font

func picture(path: String) -> TextureRect:
	var image:=TextureRect.new()
	image.texture=load(DIR+path)
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode=TextureRect.STRETCH_SCALE
	image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return image

func configure(owner_screen: Control) -> void:
	screen=owner_screen
	name="SurvivalGuide"
	z_index=80
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	handwriting=load(DIR+"LXGWWenKai-Regular.ttf")
	ring.texture=load(DIR+"ring.png")
	arrow.texture=load(DIR+"arrow.png")
	for image in [ring,arrow]:
		image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		image.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(image)
	caption.add_theme_font_override("font",handwriting)
	caption.add_theme_font_size_override("font_size",23)
	caption.add_theme_color_override("font_color",Color("fff4d6"))
	caption.add_theme_color_override("font_shadow_color",Color("433827"))
	caption.add_theme_constant_override("shadow_offset_x",1)
	caption.add_theme_constant_override("shadow_offset_y",2)
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	letter.name="GuideLetter"
	letter.color=Color(0.08,0.07,0.04,.42)
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(letter)
	letter.add_child(page)
	page.size=Vector2(780,600)
	var paper:=picture("letter.png")
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(paper)
	var title:=Label.new()
	title.text="生存指南"
	title.position=Vector2(72,48);title.size=Vector2(636,56)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font",handwriting)
	title.add_theme_font_size_override("font_size",36)
	title.add_theme_color_override("font_color",Color("5d4933"))
	page.add_child(title)
	var words:=Label.new()
	words.text="W A S D  移动             E  交互\n\nB  打开背包               M  打开地图\n\nC  打开工具制作           V  打开建造\n\n鼠标拖动物品，可移动、调整位置，也可投放\n鼠标右键可使用物品，装备道具\n\n将物品放入快捷栏，按对应数字键快捷使用\n\n收集资源，建造营地，努力活下去。"
	words.position=Vector2(80,128);words.size=Vector2(640,400)
	words.add_theme_font_override("font",handwriting)
	words.add_theme_font_size_override("font_size",25)
	words.add_theme_color_override("font_color",Color("5d4933"))
	page.add_child(words)
	var close:=Button.new()
	close.name="CloseGuide";close.text="收起"
	close.position=Vector2(658,58);close.size=Vector2(64,36)
	close.set_meta("audio_window_close",true)
	close.pressed.connect(close_letter)
	page.add_child(close)
	letter.hide()

func open_letter() -> void:
	if screen.service.body.sleep_active():return
	screen.hide_item_hover()
	letter.show()
	if screen.service.guide_stage<2:
		var before: int=screen.service.guide_stage
		screen.service.guide_stage=2
		if not screen.service.save_state():screen.service.guide_stage=before
	screen.world.player.cancel_action()
	screen.update_input_block()

func close_letter() -> void:
	letter.hide()
	if is_instance_valid(screen):screen.update_input_block()

func _process(_delta: float) -> void:
	if screen==null:return
	var area:=get_viewport_rect().size
	page.position=(area-page.size)*.5
	var stage: int=screen.service.guide_stage
	if stage==0 and screen.bag.visible:
		screen.service.guide_stage=1
		if not screen.service.save_state():screen.service.guide_stage=0
		stage=screen.service.guide_stage
	var active: bool=stage<2 and not letter.visible and not screen.service.body.sleep_active()
	ring.visible=active;arrow.visible=active;caption.visible=active
	if not active:return
	var target: Rect2=screen.bag_button.get_global_rect()
	caption.text="按 B 键，打开背包"
	if stage==1 and screen.bag.visible:
		for i in range(40):
			if screen.service.inventory.get_slot(i).get("item_id","")=="survival_guide":
				target=screen.cells[i].get_global_rect();break
		caption.text="右键生存指南，选择「查看」"
		if screen.item_menu.visible and screen.modal_stack.get("item_id","")=="survival_guide":
			target=screen.use_button.get_global_rect();caption.text="点击「查看」，读一读生存指南"
	ring.position=target.position-Vector2(10,8)
	ring.size=target.size+Vector2(20,16)
	arrow.size=Vector2(45,70)
	arrow.rotation=0
	arrow.position=Vector2(target.get_center().x-22,target.position.y-76)
	caption.reset_size()
	caption.position=Vector2(clampf(target.get_center().x-caption.size.x*.5,12,area.x-caption.size.x-12),target.position.y-112)
	if caption.position.y<16:
		# Top bag rows have no room above them: keep the whole instruction to the left.
		arrow.rotation=-PI*.5
		arrow.position=Vector2(target.position.x-84,target.get_center().y+20)
		caption.position=Vector2(maxf(12,target.position.x-caption.size.x-100),target.get_center().y-16)
