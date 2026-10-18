extends CanvasLayer
var service: Node
var pending: Array[Dictionary]=[]
var remaining := 0.0
var card := PanelContainer.new()
var icon := TextureRect.new()
var caption := Label.new()
func configure(owner_service: Node) -> void:
	service=owner_service;layer=100
	card.theme=preload("res://scripts/item_ui_style.gd").theme()
	add_child(card);card.add_theme_stylebox_override("panel",preload("res://scripts/item_ui_style.gd").section(10))
	var row := HBoxContainer.new();card.add_child(row)
	icon.custom_minimum_size=Vector2(36,36);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon);row.add_child(caption);card.hide()
	for node in [card,row,icon,caption]: node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	service.item_obtained.connect(func(id: String, count: int): pending.append({"id":id,"count":count}))
func _process(delta: float) -> void:
	remaining=maxf(0,remaining-delta)
	if remaining<=0:
		card.hide()
		if not pending.is_empty():
			var entry: Dictionary=pending.pop_front()
			icon.texture=service.texture(entry.id,"icon")
			caption.text="获得  %s ×%d"%[service.database.item(entry.id).name,entry.count]
			card.reset_size();remaining=2.0;card.modulate.a=1;card.show()
	if card.visible:
		var area := get_viewport().get_visible_rect().size
		var dock: Control=service.world.item_ui.dock
		card.position=Vector2((area.x-card.size.x)*.5,dock.position.y-card.size.y-12)
		card.modulate.a=minf(1,remaining/.3)
	# Keep existing short notices readable when a reward and a failure arrive together.
	service.world.item_ui.message.position.y=minf(558,card.position.y-service.world.item_ui.message.size.y-8) if card.visible else 558
