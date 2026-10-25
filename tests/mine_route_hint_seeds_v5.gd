extends SceneTree
const DEST="res://reports/mine-clues-route-v5/"
class MineSample extends RefCounted:
	var state: Dictionary={"site":{}}
	func at() -> Vector2:return Vector2(state.site.x,state.site.y)
class ChapterSample extends RefCounted:
	var mine:=MineSample.new()
class WorldSample extends Node:
	var world_seed: int
	var generator: RefCounted
class ServiceSample extends Node:
	var world: Node
	var chapter:=ChapterSample.new()
var checks: Array=[]
func check(value: bool, label: String) -> void:
	checks.append({"name":label,"pass":value});if not value:push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var results: Array=[]
	for seed_value in [271828,314159,161803]:
		var service:=ServiceSample.new();var world:=WorldSample.new();world.world_seed=seed_value;world.generator=load("res://scripts/world_generator.gd").new(seed_value,1024);service.world=world
		var gen=world.generator;var site:=Vector2.INF
		for point in gen.region_cores:
			if gen.can_walk(point,24) and gen.biome(point)=="岩石区":site=point;break
		if site==Vector2.INF:
			for i in 1024:
				var point:=Vector2(float(i%32)+.5,float(i/32)+.5)*float(gen.extent)/32
				if gen.can_walk(point,24) and gen.biome(point)=="岩石区":site=point;break
		check(site!=Vector2.INF,"seed "+str(seed_value)+" uses actual rocky mine site")
		service.chapter.mine.state.site={"x":site.x,"y":site.y};var before: Dictionary=service.chapter.mine.state.duplicate(true)
		var hint: Dictionary=preload("res://scripts/mine_route_hint.gd").new().resolve(service)
		var again: Dictionary=preload("res://scripts/mine_route_hint.gd").new().resolve(service)
		check(not hint.is_empty() and hint==again,"seed "+str(seed_value)+" deterministic across readers")
		var center:=Vector2(hint.search_area.center.x,hint.search_area.center.y)
		check(gen.can_walk(center,24) and gen.sample(center).z<=.12,"seed "+str(seed_value)+" hint uses real traversable land")
		check(hint.terrain_link>=0 and not hint.target_generated,"seed "+str(seed_value)+" graph corridor without ruin creation")
		check(service.chapter.mine.state==before,"seed "+str(seed_value)+" hint has no persistent state side effects")
		results.append(hint);service.free();world.free()
	check(results[0].search_area!=results[1].search_area and results[1].search_area!=results[2].search_area,"different world seeds do not reuse a fictitious fixed location")
	FileAccess.open(DEST+"seed-hints.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "));FileAccess.open(DEST+"seed-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));var failed: int=checks.filter(func(row):return not row.pass).size();print("ROUTE SEEDS ",checks.size()," checks ",failed," failures");quit(1 if failed else 0)
