extends PanelContainer
var owner_ui: Control
var index := 0
var image := TextureRect.new()
var amount := Label.new()
var bar := ProgressBar.new()
func _ready() -> void:
	custom_minimum_size=Vector2(40,40);add_theme_stylebox_override("panel",preload("res://scripts/item_ui_style.gd").slot(false,false))
	var canvas := Control.new();canvas.custom_minimum_size=Vector2(40,40);canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(canvas)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);image.offset_left=6;image.offset_top=5;image.offset_right=-6;image.offset_bottom=-6
	image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(image)
	amount.add_theme_font_size_override("font_size",12);amount.position=Vector2(18,20);amount.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(amount)
	bar.position=Vector2(4,35);bar.size=Vector2(32,3);bar.scale=Vector2(1,.18);bar.show_percentage=false;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas.add_child(bar)
	gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			if e.button_index==MOUSE_BUTTON_RIGHT: owner_ui.menu(index,get_global_mouse_position())
			if e.button_index==MOUSE_BUTTON_LEFT and e.ctrl_pressed: owner_ui.split(index))
	refresh()
func refresh() -> void:
	var v: Dictionary=owner_ui.contents(index)
	image.texture=null;amount.text="";tooltip_text="空木箱格";bar.hide()
	if v.is_empty(): return
	image.texture=owner_ui.service.stack_texture(v,"icon");amount.text=str(v.count)
	var d: Dictionary=owner_ui.service.database.item(v.item_id);tooltip_text=d.name+"\n"+d.description
	if d.get("durability")!=null:
		bar.show();bar.max_value=d.durability;bar.value=v.durability
		var track := StyleBoxFlat.new();track.bg_color=Color("c6baa4");bar.add_theme_stylebox_override("background",track)
		var fill := StyleBoxFlat.new();var ratio := bar.value/bar.max_value
		fill.bg_color=Color("b55745").lerp(Color("c4aa53"),ratio*2) if ratio<.5 else Color("c4aa53").lerp(Color("71895d"),(ratio-.5)*2)
		bar.add_theme_stylebox_override("fill",fill)
		tooltip_text+="\n耐久度：%d / %d"%[v.durability,d.durability]
func _get_drag_data(_at: Vector2) -> Variant:
	var v: Dictionary=owner_ui.contents(index)
	if v.is_empty(): return null
	var preview := TextureRect.new();preview.texture=image.texture;preview.custom_minimum_size=Vector2(44,44);preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;set_drag_preview(preview)
	return {"chest":owner_ui.current,"chest_slot":index,"snapshot":v.duplicate(true),"storage":owner_ui}
func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if index>=9: return false
	if data is Dictionary and data.get("storage")==owner_ui: return data.chest==owner_ui.current
	return data is Dictionary and data.get("inventory")==owner_ui.service.inventory and data.get("slot",-1)>=0 and data.slot<43 and owner_ui.service.world.item_ui.valid_drag(data)
func _drop_data(_at: Vector2, data: Variant) -> void:
	if data.has("chest"):
		owner_ui.report(owner_ui.service.builds.chest_edit(owner_ui.current,int(data.chest_slot),data.snapshot,"move",index));return
	owner_ui.report(owner_ui.service.builds.transfer(owner_ui.current,index,int(data.slot),owner_ui.contents(index).duplicate(true),data.snapshot))
