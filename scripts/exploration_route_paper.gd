extends Control
## The route is a single painted sheet; no directions or text are overlaid.
const ART="res://assets/exploration/coastal-route-v7/"
var picture:=TextureRect.new()
var hint: Dictionary={}
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	picture.texture=load(ART+"route-paper.png");picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(picture)
func configure(value: Dictionary) -> Vector2:
	hint=value.duplicate(true)
	var ratio: float=float(picture.texture.get_height())/float(picture.texture.get_width())
	size=Vector2(800,800*ratio);picture.size=size
	return size
