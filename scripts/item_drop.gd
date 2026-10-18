extends Node2D
## Fixed landing anchor is persisted; only the child visual flies and bounces.
var visual := Sprite2D.new()
func setup(tex: Texture2D, width: float, padding: float) -> void:
	visual.texture=tex
	visual.scale=Vector2.ONE*width/maxf(1,tex.get_width()-padding*2)
	visual.offset=Vector2(0,-tex.get_height()*.5+padding+1)
	add_child(visual)
func animate_drop() -> void:
	set_meta("airborne",true)
	visual.position=Vector2(-12,-32)
	visual.rotation=-.12
	var flight := create_tween()
	flight.tween_property(visual,"position",Vector2(-5,-40),.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_property(visual,"position",Vector2.ZERO,.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_property(visual,"position",Vector2(0,-6),.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight.tween_property(visual,"position",Vector2.ZERO,.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.parallel().tween_property(visual,"rotation",0.0,.08)
	flight.tween_callback(func():set_meta("airborne",false))
