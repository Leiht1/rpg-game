extends Control
const MerchantSkin=preload("res://scripts/item_ui_style.gd")
var merchant: Node
var panel := PanelContainer.new()
var content := VBoxContainer.new()
var dialogue := Label.new()
var trade := Button.new()
var goods := VBoxContainer.new()
var status := Label.new()
var purchase := Button.new()
var selected := "solar_flashlight"
var choices: Dictionary={}
func setup() -> void:
	theme=MerchantSkin.theme();z_index=25;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_STOP
	add_child(panel);panel.custom_minimum_size=Vector2(420,0);panel.add_theme_stylebox_override("panel",MerchantSkin.frame(16))
	panel.add_child(content);content.add_theme_constant_override("separation",14)
	var header := HBoxContainer.new();content.add_child(header)
	var title := Label.new();title.text="异次元商人";title.size_flags_horizontal=SIZE_EXPAND_FILL;header.add_child(title)
	var close := Button.new();close.text="关闭";header.add_child(close);close.pressed.connect(close_panel)
	dialogue.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;dialogue.custom_minimum_size=Vector2(360,0);content.add_child(dialogue)
	trade.text="交易";content.add_child(trade);trade.pressed.connect(show_trade)
	content.add_child(goods)
	for id in merchant.rules.products:
		var row := HBoxContainer.new();goods.add_child(row)
		var choose := Button.new();choose.custom_minimum_size=Vector2(220,58);choose.expand_icon=true;choose.add_theme_constant_override("icon_max_width",42)
		choose.icon=merchant.service.texture(id,"icon");choose.text=merchant.service.database.item(id).name
		choose.pressed.connect(select.bind(id));row.add_child(choose)
		var price := Label.new();price.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;price.custom_minimum_size=Vector2(400,58);row.add_child(price)
		price.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		choices[id]={"button":choose,"label":price}
	content.add_child(status);purchase.text="购买";content.add_child(purchase);purchase.pressed.connect(buy)
	hide()
func open_dialogue(text: String) -> void:
	dialogue.text="“"+text+"”";dialogue.show();trade.show();goods.hide();purchase.hide();status.text="";show()
	status.hide();fit_panel.call_deferred(420.0)
	merchant.service.world.item_ui.update_input_block()
func show_trade() -> void:
	dialogue.hide();trade.hide();goods.show();purchase.show();status.text="";refresh()
	status.hide();fit_panel.call_deferred(720.0)
func fit_panel(width: float) -> void:
	panel.custom_minimum_size=Vector2(width,0);panel.size=Vector2(width,0);panel.reset_size()
	panel.position=(get_viewport_rect().size-panel.size)*.5
func select(id: String) -> void:selected=id;status.text="";refresh()
func refresh() -> void:
	for id in choices:
		var parts: Array[String]=[]
		for key in merchant.price(id):parts.append(str(merchant.service.database.item(key).name)+" ×%d"%int(merchant.price(id)[key]))
		choices[id].label.text=" + ".join(parts)+(" · 已售罄" if merchant.state.offers[id].stock==0 else "")
		choices[id].button.button_pressed=selected==id;choices[id].button.toggle_mode=true
	purchase.disabled=merchant.state.offers[selected].stock==0
func buy() -> void:
	var reason: String=merchant.buy(selected);status.text=reason if not reason.is_empty() else "交易完成";refresh()
	status.show();fit_panel.call_deferred(720.0)
func close_panel() -> void:
	hide();merchant.interacting=false;merchant.service.world.item_ui.update_input_block()
	if merchant.state.get("remaining",1)<=0:merchant.migrate()
func handle_input(event: InputEvent) -> bool:
	if not visible:return false
	# Let viewport GUI dispatch mouse events to the actual buttons.
	if event is InputEventMouse:return false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:close_panel()
	return true

