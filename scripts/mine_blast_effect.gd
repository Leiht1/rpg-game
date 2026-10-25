extends Node2D
## Painted layers share one origin; each fragment keeps its own continuous trajectory.
var clock:=0.0
var active:=false
var started_ticks:=0
var frame_index:=-1
var frames: Array[Texture2D]=[]
var endpoints: Array[float]=[]
var duration:=0.0
var flash_duration:=0.0
var sprite:=Sprite2D.new()
var blend_material:=ShaderMaterial.new()
var smoke: Array[Sprite2D]=[]
var stones: Array[Sprite2D]=[]
func configure(manifest_path: String,width: float) -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var folder:=manifest_path.get_base_dir()
	for i in data.frames.size():
		frames.append(load(folder.path_join(data.frames[i])))
		flash_duration+=float(data.duration_ms[i])/1000.0;endpoints.append(flash_duration)
	duration=float(data.tail_seconds)
	sprite.centered=false;sprite.position=-Vector2(data.anchor_px[0],data.anchor_px[1])
	var factor: float=width/float(data.canvas[0]);sprite.scale=Vector2.ONE*factor;sprite.position*=factor
	blend_material.shader=preload("res://scripts/mine_blast_blend.gdshader");sprite.material=blend_material
	add_child(sprite)
	for i in 10:
		var part:=Sprite2D.new();part.texture=load(folder.path_join(data.stones[i%data.stones.size()]))
		add_child(part);stones.append(part)
	for i in 8:
		var part:=Sprite2D.new();part.texture=load(folder.path_join(data.smoke[i]))
		add_child(part);smoke.append(part)
	z_index=15;hide()
func start(at: Vector2) -> void:
	position=at;active=true;started_ticks=Time.get_ticks_msec();sample_at(0.0);show()
func advance(_delta: float) -> void:
	if active:sample_at(float(Time.get_ticks_msec()-started_ticks)/1000.0)
func sample_at(elapsed: float) -> void:
	clock=elapsed
	if clock>=duration:active=false;hide();return
	var index:=0
	while index<endpoints.size()-1 and clock>=endpoints[index]:index+=1
	frame_index=index;sprite.texture=frames[index];sprite.visible=clock<flash_duration
	var begin: float=0.0 if index==0 else endpoints[index-1]
	blend_material.set_shader_parameter("next_frame",frames[mini(index+1,frames.size()-1)])
	blend_material.set_shader_parameter("frame_blend",clampf((clock-begin)/(endpoints[index]-begin),0,1))
	sprite.modulate.a=clampf((flash_duration-clock)/.12,0,1)
	for i in stones.size():
		var part:=stones[i]
		var angle: float=TAU*float(i)/stones.size()+.21
		var flight: float=.65+float(i%4)*.13
		var t: float=minf(clock,flight)
		var velocity:=Vector2(cos(angle)*(.8+float(i%3)*.16),sin(angle)*.42)*145.0
		part.position=velocity*t+Vector2(0,-4.0*62.0*(t/flight)*(1.0-t/flight))
		part.rotation=float(i)*1.7+t*(3.0 if i%2==0 else -2.5)
		part.scale=Vector2.ONE*(10.0+float(i%3)*3.0)/part.texture.get_width()
		part.modulate.a=clampf((flight+.28-clock)/.28,0,1)
	for i in smoke.size():
		var part:=smoke[i]
		var angle: float=TAU*float(i)/smoke.size()+.1
		var expansion: float=1.0-exp(-clock*1.1)
		part.position=Vector2(cos(angle)*155.0,sin(angle)*76.0)*expansion+Vector2(0,-clock*12.0)
		var size: float=(95.0+float(i%3)*18.0)*(1.0+clock*.18)
		part.scale=Vector2.ONE*size/part.texture.get_width()
		part.rotation=angle*.15
		var appear: float=clampf(clock/.13,0,1)
		part.modulate=Color(.86,.83,.77,appear*.58*pow(clampf(1.0-clock/duration,0,1),1.5))
