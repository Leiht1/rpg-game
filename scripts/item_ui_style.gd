extends RefCounted
## Lightweight field notebook: paper, linen inserts and cloth tabs, distinct visual weights.
static var cache: Dictionary = {}

static func art(name_value: String) -> Texture2D:
	if not cache.has(name_value):
		var path := "res://assets/ui/rework_v1/"+name_value+".png"
		if name_value in ["slot","slot_selected","button","nav_button"]: path="res://assets/ui/refine_v1/"+name_value+".png"
		if name_value=="section": path="res://assets/ui/rework_v1/slot.png"
		if name_value=="target_hint": path="res://assets/ui/hints_v1/target_hint.png"
		cache[name_value]=load(path)
	return cache[name_value]

static func texture_style(name_value: String, border: int, inset: int, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture=art(name_value)
	for edge in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(edge,border)
		style.set_content_margin(edge,inset)
	style.modulate_color=tint
	return style

static func frame(inset: int = 14) -> StyleBoxTexture:
	# Keep the complete cloth corner reinforcements inside fixed source patches.
	var style := texture_style("panel",54,maxi(inset,24))
	style.content_margin_bottom=maxi(inset,28)
	return style

static func section(inset: int = 14) -> StyleBoxTexture:
	return texture_style("section",14,inset)

static func tooltip(inset: int = 22) -> StyleBoxTexture:
	var style := texture_style("tooltip",36,maxi(18,inset))
	style.content_margin_bottom=maxi(28,inset)
	return style

static func target_hint() -> StyleBoxTexture:
	var style := texture_style("target_hint",10,7)
	style.texture_margin_left=14;style.texture_margin_right=14
	style.content_margin_left=12;style.content_margin_right=12
	return style

static func recipe_style(state: String) -> StyleBoxTexture:
	var style := button_style(state)
	# A separately painted gold rim makes selection visible without darkening the card.
	if state in ["pressed","hover_pressed"]:
		style=texture_style("slot_selected",8,10)
		style.content_margin_left=18;style.content_margin_right=18
	return style

static func hotbar() -> StyleBoxTexture:
	return texture_style("section",14,7)

static func slot(selected: bool, hovered: bool, equipped: bool = false, disabled: bool = false) -> StyleBoxTexture:
	var tint := Color(1.035,1.025,1.0) if hovered else Color.WHITE
	if equipped and not selected: tint=Color(.97,1.0,.95)
	if disabled: tint=Color(.84,.84,.81)
	return texture_style("slot_selected" if selected else "slot",8,2,tint)

static func button_style(state: String, compact: bool = false) -> StyleBoxTexture:
	var tint: Color={"normal":Color.WHITE,"hover":Color(1.035,1.02,.97),"pressed":Color(.96,.92,.83),"disabled":Color(.91,.91,.87),"focus":Color(1,.97,.88)}.get(state,Color.WHITE)
	var style := texture_style("nav_button" if compact else "button",10,6 if compact else 10,tint)
	style.texture_margin_left=10 if compact else 16
	style.texture_margin_right=10 if compact else 16
	style.content_margin_left=6 if compact else 18
	style.content_margin_right=6 if compact else 18
	return style

static func theme() -> Theme:
	var skin := Theme.new()
	skin.default_font_size=14
	skin.set_color("font_color","Label",Color("4e493d"))
	for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		skin.set_color(state,"Button",Color("4b4437"))
	skin.set_color("font_disabled_color","Button",Color("746a5b"))
	skin.set_constant("h_pressed_offset","Button",0)
	skin.set_constant("v_pressed_offset","Button",0)
	for state in ["normal","hover","pressed","disabled","focus"]: skin.set_stylebox(state,"Button",button_style(state))
	skin.set_stylebox("hover_pressed","Button",button_style("pressed"))
	skin.set_stylebox("normal","LineEdit",texture_style("button",8,10))
	skin.set_stylebox("focus","LineEdit",texture_style("button",8,10,Color(1,.97,.88)))
	skin.set_stylebox("read_only","LineEdit",texture_style("button",8,10,Color(.97,.96,.92)))
	skin.set_color("font_uneditable_color","LineEdit",Color("786d5a"))
	skin.set_color("font_color","LineEdit",Color("454b37"))
	skin.set_color("font_placeholder_color","LineEdit",Color("8c866f"))
	return skin
