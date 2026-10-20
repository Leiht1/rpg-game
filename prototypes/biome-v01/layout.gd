extends RefCounted
# Independent, finite art-layout generator. Never substitutes the live world generator.
const VERSION := "biome-layout-0.1.0"
const SIZE := Vector2(2400,1320)
const CENTERS := [Vector2(1000,740),Vector2(490,390),Vector2(1750,340),Vector2(1950,1010),Vector2(510,1070)]
const NAMES := ["出生草地区", "森林区", "山地区", "水岸区", "稀疏原野区"]
const RADII := [Vector2(470,410),Vector2(650,480),Vector2(610,460),Vector2(530,390),Vector2(650,390)]
static func weights(p:Vector2)->PackedFloat32Array:
	var result:=PackedFloat32Array()
	var total:=0.0
	for i in 5:
		var q:Vector2=(p-CENTERS[i])/RADII[i]
		var w:=exp(-q.length_squared()*2.4)
		result.append(w)
		total+=w
	for i in 5:result[i]/=total
	return result
static func biome(p:Vector2)->int:
	var w:=weights(p)
	var best:=0
	for i in range(1,5):
		if w[i]>w[best]:best=i
	return best
static func lake(p:Vector2)->float:
	var q:Vector2=(p-Vector2(2180,1080))/Vector2(330,260)
	return q.length()+.045*sin(p.y*.017)+.03*sin(p.x*.023)
static func objects(seed_value:int)->Array[Dictionary]:
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value
	var result:Array[Dictionary]=[]
	# Cells supply candidates only. Region masks, clearings and bands govern acceptance.
	for y in range(120,1280,85):
		for x in range(90,2340,85):
			var p:=Vector2(x,y)+Vector2(rng.randf_range(-28,28),rng.randf_range(-28,28))
			var b:=biome(p)
			var chance:=rng.randf()
			var kind:=""
			if lake(p)<1.14 or p.distance_to(CENTERS[0])<230:continue
			match b:
				0:
					if chance<.10:kind="tree"
					elif chance<.15:kind="rock"
				1:
					if p.distance_to(Vector2(470,440))<145:continue
					if chance<.78:kind="tree"
					elif chance<.85:kind="leaves"
				2:
					var ridge:=absf(p.y-(300+95*sin(p.x*.007)))
					if chance<(.85 if ridge<115 else .26):kind="rock"
					elif chance>.93:kind="tree"
				3:
					if lake(p)<1.65 and chance<.65:kind="rock"
					elif chance<.09:kind="tree"
				4:
					if chance<.035:kind="tree"
					elif chance<.075:kind="rock"
			if kind=="" and chance>.93:kind="flowers"
			if kind!="":result.append({"p":p,"biome":b,"kind":kind,"variant":rng.randi_range(0,1)})
	return result
