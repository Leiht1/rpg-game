extends Node2D
## Only instantiated for a hit; bounded lifetime, no permanent particles or global scans.
var texture: Texture2D
var direction := Vector2.RIGHT
var soil := false
var clock := 0.0
var pieces: Array[Dictionary]=[]
func _ready() -> void:
	for i in 7:
		pieces.append({"v":Vector2(direction.x*(22+i*6)+(i%3-1)*14,-35-i*7),"size":3.0+(i%3)*1.2})
func _process(delta: float) -> void:
	clock+=delta
	if clock>.55: queue_free();return
	queue_redraw()
func _draw() -> void:
	for part in pieces:
		var p: Vector2=part.v*clock+Vector2(0,180*clock*clock)
		var size: float=part.size
		if texture: draw_texture_rect(texture,Rect2(p-Vector2.ONE*size*.5,Vector2.ONE*size),false,Color(1,1,1,clampf((.55-clock)*5,0,1)))
	# Two subdued, very short contact sparks; never a flash across the rock/UI.
	if not soil and clock<.10:
		for i in 2:
			var a := Vector2(-3+i*6,-3)
			draw_line(a,a+Vector2(-3+i*6,-4),Color(1,.85,.54,(.10-clock)*7),1,true)
