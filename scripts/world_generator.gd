class_name WildGenerator
extends RefCounted

## All randomness is coordinate-addressed. No shared RNG or load-order state.
const VERSION := "windrest-0.1.0"
const CELL := 48
const CHUNK_CELLS := 24
const CHUNK_PX := CELL * CHUNK_CELLS
const TEX_RES := 144
const TEX_STEP := float(CHUNK_PX) / TEX_RES
const PROP_STEP := 144

var world_seed: int
var map_cells: int
var extent: float
var elevation := FastNoiseLite.new()
var moisture := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var phase: float
var lakes: Array[Vector4] = []
var spawn := Vector2.ZERO

func _init(seed_value: int = 271828, size_cells: int = 1024) -> void:
	world_seed = seed_value
	map_cells = clampi(size_cells, 128, 1024)
	extent = map_cells * CELL
	elevation.seed = world_seed ^ 741103
	elevation.frequency = 0.00072
	elevation.fractal_octaves = 3
	moisture.seed = world_seed ^ 18019
	moisture.frequency = 0.00105
	moisture.fractal_octaves = 3
	detail.seed = world_seed ^ 90821
	detail.frequency = 0.006
	detail.fractal_octaves = 2
	phase = random_at(0, 0, 711) * TAU
	# Lakes touch the river centerline, so water forms connected natural systems.
	for i in range(8):
		var y := extent * (0.08 + 0.84 * random_at(i, 13, 22))
		var x := river_x(y)
		lakes.append(Vector4(x, y, 250.0 + random_at(i, 17, 2) * 390.0, 150.0 + random_at(i, 9, 3) * 260.0))
	spawn = Vector2(extent * (0.23 + random_at(3, 11, 9) * .08), extent * .5)

func random_at(x: int, y: int, salt: int = 0) -> float:
	# 31-bit arithmetic stays below signed int64 overflow on all Godot targets.
	var h := (world_seed & 0x7fffffff) ^ ((x * 374761393) & 0x7fffffff) ^ ((y * 668265263) & 0x7fffffff) ^ (salt * 69069)
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = (h ^ (h >> 16)) & 0x7fffffff
	return float(h) / 2147483647.0

func river_x(y: float) -> float:
	return extent * .51 + sin(y * .00057 + phase) * extent * .10 + sin(y * .0017 + phase * 1.7) * 270.0

func water_distance(p: Vector2) -> float:
	var width := 63.0 + 20.0 * sin(p.y * .003 + phase)
	var edge := absf(p.x - river_x(p.y)) - width
	for lake in lakes:
		# Cheap y rejection matters for per-pixel terrain sampling.
		if absf(p.y - lake.y) > lake.w + 120.0:
			continue
		var q := (p - Vector2(lake.x, lake.y)) / Vector2(lake.z, lake.w)
		edge = minf(edge, (q.length() - 1.0) * minf(lake.z, lake.w))
	return edge + detail.get_noise_2d(p.x, p.y) * 23.0

func sample(p: Vector2) -> Vector4:
	var e := elevation.get_noise_2d(p.x, p.y)
	var m := moisture.get_noise_2d(p.x, p.y)
	var forest := smoothstep(-.13, .38, m)
	var mountain := smoothstep(.13, .48, e)
	var water := 1.0 - smoothstep(-12.0, 18.0, water_distance(p))
	var clear := 1.0 - smoothstep(140.0, 260.0, p.distance_to(spawn))
	forest *= 1.0 - clear
	mountain *= 1.0 - clear
	water *= 1.0 - clear
	# Broad shallow fords keep both sides of the river reachable. Their positions
	# are deterministic; lakes keep their depth. This is terrain, no bridge system.
	var ford := absf(sin((p.y+phase*200)*PI/3200.0))*3200.0/PI
	var in_lake := false
	for lake in lakes:
		if absf(p.y-lake.y)<lake.w+100 and ((p-Vector2(lake.x,lake.y))/Vector2(lake.z,lake.w)).length()<1.15:
			in_lake=true
			break
	if not in_lake: water *= lerpf(.32,1.0,smoothstep(55,135,ford))
	return Vector4(forest, mountain, water, e)

func biome(p: Vector2) -> String:
	var v := sample(p)
	if v.z > .5:
		for lake in lakes:
			if ((p - Vector2(lake.x,lake.y)) / Vector2(lake.z,lake.w)).length() < 1.0:
				return "湖泊"
		return "河流"
	if v.y > .5: return "山地"
	if v.x > .5: return "森林"
	return "草原"

func can_walk(p: Vector2, radius: float = 10.0) -> bool:
	if p.x < radius or p.y < radius or p.x > extent-radius or p.y > extent-radius:
		return false
	for offset in [Vector2.ZERO,Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
		if sample(p + offset).z > .46: return false
	return true

func props_for_chunk(coord: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var origin := Vector2(coord) * CHUNK_PX
	var first := Vector2i(origin / PROP_STEP)
	var count := CHUNK_PX / PROP_STEP
	for y in range(first.y, first.y + count):
		for x in range(first.x, first.x + count):
			var p := Vector2((x+.18+random_at(x,y,1)*.64)*PROP_STEP,(y+.18+random_at(x,y,2)*.64)*PROP_STEP)
			if p.x >= extent-64 or p.y >= extent-64 or p.distance_to(spawn) < 150: continue
			var v := sample(p)
			if v.z > .03: continue
			var roll := random_at(x,y,3)
			var kind := -1
			var scale_value := .8 + random_at(x,y,5)*.35
			if roll < (.06 + v.x*.48) * (1.0-v.y*.7):
				kind = 0 if random_at(x,y,7)<.7 else 1
			elif roll < .15 + v.y*.5:
				kind = 2 if random_at(x,y,7)<.7 else 3
			elif roll < .67:
				kind = 4 + mini(2,int(random_at(x,y,8)*3))
			if kind >= 0:
				result.append({"position":p,"kind":kind,"scale":scale_value,"id":"%d:%d"%[x,y]})
	return result

func build_chunk(coord: Vector2i) -> Dictionary:
	var begin := Time.get_ticks_usec()
	var bytes := PackedByteArray()
	bytes.resize((TEX_RES+2)*(TEX_RES+2)*4)
	var index := 0
	var origin := Vector2(coord) * CHUNK_PX
	for y in range(-1,TEX_RES+1):
		for x in range(-1,TEX_RES+1):
			var p := origin + Vector2(x,y)*TEX_STEP
			var v := sample(p)
			var c := Color("9cbf79").lerp(Color("648d65"),v.x*.82)
			c = c.lerp(Color("a9a68b"),v.y*.85)
			var shore := (1.0-smoothstep(15,70,absf(water_distance(p)))) * (1.0-v.z)
			c = c.lerp(Color("bdb589"),shore*.5)
			var variation := detail.get_noise_2d(p.x,p.y)*.035
			bytes[index] = clampi(roundi((c.r+variation)*255),0,255)
			bytes[index+1] = clampi(roundi((c.g+variation)*255),0,255)
			bytes[index+2] = clampi(roundi((c.b+variation)*255),0,255)
			bytes[index+3] = roundi(v.z*255)
			index += 4
	return {"coord":coord,"image":Image.create_from_data(TEX_RES+2,TEX_RES+2,false,Image.FORMAT_RGBA8,bytes),
		"props":props_for_chunk(coord),"build_ms":(Time.get_ticks_usec()-begin)/1000.0}
