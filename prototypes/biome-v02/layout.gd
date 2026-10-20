extends RefCounted
const VERSION = "biome-world-0.2.0"
const SIZE = Vector2(6144,4096)
const STEP = 16
var seed_value:int
var spawn = SIZE*.5
var wet = FastNoiseLite.new()
var ridge = FastNoiseLite.new()
var detail = FastNoiseLite.new()
var warp = FastNoiseLite.new()
var lakes:Array[Vector4]=[]
func _init(value:int=271828):
	seed_value=value
	for pair in [[wet,117,.00078],[ridge,912,.0011],[detail,713,.006],[warp,318,.0016]]:
		pair[0].seed=value ^ pair[1]
		pair[0].frequency=pair[2]
		pair[0].fractal_octaves=3
	var rng=RandomNumberGenerator.new()
	rng.seed=value
	for i in rng.randi_range(3,6):
		var p=Vector2(rng.randf_range(650,SIZE.x-650),rng.randf_range(550,SIZE.y-550))
		if p.distance_to(spawn)<850:continue
		lakes.append(Vector4(p.x,p.y,rng.randf_range(280,680),rng.randf_range(230,510)))
func weights(p:Vector2)->Color:
	var q=p+Vector2(warp.get_noise_2d(p.x,p.y),warp.get_noise_2d(p.y+1200,p.x))*240
	var forest=smoothstep(-.18,.25,wet.get_noise_2dv(q))
	var mountain=smoothstep(.04,.40,ridge.get_noise_2dv(q))
	var safe=smoothstep(200,470,p.distance_to(spawn))
	forest*=safe
	mountain*=safe
	var water=0.0
	for lake in lakes:
		var d=((q-Vector2(lake.x,lake.y))/Vector2(lake.z,lake.w)).length()
		water=maxf(water,1.0-smoothstep(.67,1.18,d))
	water*=safe
	return Color(forest*(1-mountain),mountain,(1-forest)*(1-mountain),water)
func can_walk(p:Vector2)->bool:
	return Rect2(Vector2(24,24),SIZE-Vector2(48,48)).has_point(p) and weights(p).a<.56
func field()->Image:
	var image=Image.create(int(SIZE.x/STEP)+1,int(SIZE.y/STEP)+1,false,Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():image.set_pixel(x,y,weights(Vector2(x,y)*STEP))
	return image
func objects()->Array[Dictionary]:
	var rng=RandomNumberGenerator.new()
	rng.seed=seed_value ^ 77111
	var result:Array[Dictionary]=[]
	# Independent continuous candidates, with a spatial minimum separation filter.
	var occupied={}
	for i in 11500:
		var p=Vector2(rng.randf_range(50,SIZE.x-50),rng.randf_range(80,SIZE.y-40))
		var w=weights(p)
		if w.a>.20 or p.distance_to(spawn)<240:continue
		var cluster=smoothstep(-.4,.35,detail.get_noise_2dv(p))
		var roll=rng.randf()
		var kind=""
		if roll<(.014+.43*w.r)*cluster:kind="tree"
		elif roll>.80 and roll<.80+(.15*w.g+.025)*cluster:kind="rock"
		elif roll>.98:kind="tuft_1" if w.r>w.b else "tuft_0"
		if kind=="":continue
		var cell=Vector2i(p/85)
		if occupied.has(cell):continue
		occupied[cell]=true
		result.append({"p":p,"kind":kind,"variant":rng.randi_range(0,1),"scale":rng.randf_range(.80,1.14)})
	return result
func landmarks()->Array[Vector2]:
	var best=[-1.0,-1.0,-1.0,-1.0,-1.0,-1.0,-1.0]
	var points:Array[Vector2]=[spawn,spawn,spawn,spawn,spawn,spawn,spawn]
	for y in range(400,int(SIZE.y)-400,64):
		for x in range(640,int(SIZE.x)-640,64):
			var p=Vector2(x,y)
			var w=weights(p)
			var scores=[w.r*(1-w.a),w.g*(1-w.a),w.b*(1-w.a),1-absf(w.a-.40),minf(w.r,w.b)*(1-w.a),minf(w.g,w.b)*(1-w.a),minf(w.r,w.g)*(1-w.a)]
			for i in 7:
				if scores[i]>best[i]:best[i]=scores[i];points[i]=p
	return points
