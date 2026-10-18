extends Node2D
## Bounded reusable slots, world-space movement; no per-drop nodes or textures.
const CAPACITY := 256
const SPLASH_CAPACITY := 128
const RAIN_COLOR := Color.WHITE
const LINE_WIDTH := 1.15
var world: Node2D
var intensity := 0.0
var storm := 0.0
var random := RandomNumberGenerator.new()
var next_drop := 0.0
var drops: Array[Dictionary] = []
var splashes: Array[Dictionary] = []
var emitted := 0
var last_view := Rect2()

func _init() -> void:
	random.seed=103947
	for i in CAPACITY: drops.append({"life":0.0,"duration":0.0,"ground":Vector2.ZERO,"offset":Vector2.ZERO,"length":0.0,"alpha":0.0,"splash":false})
	for i in SPLASH_CAPACITY: splashes.append({"life":0.0,"duration":0.0,"ground":Vector2.ZERO,"size":0.0,"angle":0.0})

func active_count(slots: Array[Dictionary]) -> int:
	var count := 0
	for slot in slots:
		if slot.life>0.0: count+=1
	return count

func _process(delta: float) -> void:
	if not is_instance_valid(world) or not world.started: return
	var transform := get_viewport().get_canvas_transform()
	var screen := get_viewport_rect().size
	var inverse := transform.affine_inverse()
	last_view=Rect2(inverse*Vector2.ZERO,screen/transform.get_scale())
	var visible_area := last_view.grow(180)
	for drop in drops:
		if drop.life<=0: continue
		drop.life-=delta
		if not visible_area.has_point(drop.ground): drop.life=0;continue
		if drop.life<=0 and drop.splash and intensity>.01: add_splash(drop.ground)
	for splash in splashes:
		if splash.life>0: splash.life=maxf(0,splash.life-delta)
	if intensity>.001:
		next_drop-=delta
		var area_scale := clampf(last_view.get_area()/921600.0,.4,3.0)
		var rate := 42.0*area_scale*(intensity + storm*4.0)
		# Exponentially distributed intervals, occasionally clustered rather than a lattice.
		var attempts := 0
		while next_drop<=0 and attempts<24:
			emit_drop(last_view)
			next_drop+=maxf(lerpf(.008,.001,storm),-log(maxf(.0001,1.0-random.randf()))/maxf(.01,rate))
			attempts+=1
	else:
		next_drop=0.0
	queue_redraw()

func emit_drop(rect: Rect2) -> void:
	for drop in drops:
		if drop.life>0: continue
		var ground:=rect.position+Vector2(random.randf()*rect.size.x,random.randf()*rect.size.y)
		if not world.stream.has_ground(ground): return
		drop.duration=random.randf_range(.22,.40)
		drop.life=drop.duration
		drop.ground=ground
		drop.offset=Vector2(random.randf_range(9,26),-random.randf_range(105,165))
		drop.length=random.randf_range(13,22)
		drop.alpha=random.randf_range(.48,.68)
		# Rain can strike loaded water as well as walkable land.
		drop.splash=random.randf()<.52
		emitted+=1
		return

func add_splash(ground: Vector2) -> void:
	for splash in splashes:
		if splash.life>0: continue
		splash.duration=random.randf_range(.28,.48)
		splash.life=splash.duration
		splash.ground=ground
		splash.size=random.randf_range(5.0,9.0)
		splash.angle=random.randf_range(-.45,.45)
		return

func _draw() -> void:
	if intensity<=.001: return
	for drop in drops:
		if drop.life<=0: continue
		var t:float=drop.life/drop.duration
		var head:Vector2=drop.ground+drop.offset*t
		var tail:Vector2=head+drop.offset.normalized()*drop.length
		var alpha:float=drop.alpha*intensity*smoothstep(1.0,.85,t)
		draw_line(head,tail,Color(RAIN_COLOR,alpha),LINE_WIDTH,true)
	for splash in splashes:
		if splash.life<=0: continue
		var t:float=1.0-splash.life/splash.duration
		var radius:float=lerpf(1.5,splash.size,t)
		var alpha:float=intensity*.64*sin(PI*t)
		# Two broken expanding white arcs on a horizontal ground plane (0.64 ratio).
		for side in 2:
			var points:=PackedVector2Array()
			for i in 11:
				var angle:float=splash.angle+side*PI+lerpf(.12,2.35,float(i)/10)
				points.append(splash.ground+Vector2(cos(angle)*radius,sin(angle)*radius*.64))
			draw_polyline(points,Color(RAIN_COLOR,alpha),LINE_WIDTH,true)
