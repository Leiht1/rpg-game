extends StaticBody2D
var merchant: Node
var sprite := Sprite2D.new()
var glow_phase := 0.0
var backpack_glows: Array[Sprite2D]=[]
func _ready() -> void:
	name="DimensionalMerchant";collision_layer=1;collision_mask=0
	set_meta("interaction_action","talk");set_meta("interaction_range",78.0);add_to_group("world_interactables")
	var shape := CollisionShape2D.new();var ellipse := CapsuleShape2D.new();ellipse.radius=9;ellipse.height=24;shape.shape=ellipse;shape.rotation=PI*.5;add_child(shape)
	set_meta("display_name","异次元商人")
	var gradient := Gradient.new()
	gradient.colors=PackedColorArray([Color(.12,.7,1,.85),Color(.08,.45,1,.24),Color(.05,.35,1,0)])
	gradient.offsets=PackedFloat32Array([0,.4,1])
	var glow_texture := GradientTexture2D.new();glow_texture.gradient=gradient
	glow_texture.width=64;glow_texture.height=64;glow_texture.fill=GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from=Vector2(.5,.5);glow_texture.fill_to=Vector2(1,.5)
	for side in [-1,1]:
		var glow := Sprite2D.new();glow.texture=glow_texture;glow.position=Vector2(side*28,-60)
		glow.scale=Vector2(1.35,1.65);glow.modulate.a=.95;add_child(glow);backpack_glows.append(glow)
	sprite.texture=load("res://assets/merchant/v1/merchant.png")
	if sprite.texture:
		sprite.scale=Vector2.ONE*138.0/sprite.texture.get_height();sprite.position.y=-62
	add_child(sprite)
func _process(delta: float) -> void:
	glow_phase+=delta
	for glow in backpack_glows:glow.modulate.a=.88+sin(glow_phase*2.0)*.12
	queue_redraw()
func _draw() -> void:
	# Soft contact shadow, anchored to the feet rather than the image canvas.
	draw_set_transform(Vector2(0,-1),0,Vector2(1,.28))
	for radius in [25,21,17]:draw_circle(Vector2.ZERO,radius,Color(.1,.16,.12,.10))
	draw_set_transform(Vector2.ZERO)
	# Foreshorten the ground plane; the actor renders above the circle.
	draw_set_transform(Vector2.ZERO,0,Vector2(1,.55))
	for band in [{"width":9.0,"color":Color(.05,.42,1,.12)},{"width":5.0,"color":Color(.08,.6,1,.3)},{"width":1.6,"color":Color(.35,.85,1,.95)}]:
		for radius in [48.0,40.0]:draw_arc(Vector2.ZERO,radius,0,TAU,96,band.color,band.width,true)
		for parity in 2:
			var points := PackedVector2Array()
			for i in 4:
				var angle := -PI*.5+(parity+2*(i%3))*TAU/6
				points.append(Vector2(cos(angle),sin(angle))*35)
			draw_polyline(points,band.color,band.width,true)
	draw_set_transform(Vector2.ZERO)
	for side in [-1,1]:
		for i in 5:
			var rise := fposmod(glow_phase*12+i*12,60)
			draw_circle(Vector2(side*(35+sin(glow_phase+i)*8),-32-rise),2.2,Color(.2,.8,1,sin(rise/60*PI)*.95))
func perform_interaction(_action: String, _player: Node2D) -> bool:return merchant.talk()

