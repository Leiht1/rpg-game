extends SceneTree
class World extends Node2D:
	var actors: Dictionary={}
class Service extends RefCounted:
	var world: Node2D
class Manager extends RefCounted:
	var service: RefCounted
class Building extends Node2D:
	var manager: RefCounted
	var preview:=false
var checks: Array=[]
func check(value: bool,label: String) -> void:
	checks.append({"name":label,"pass":value})
	if not value:push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var world:=World.new();root.add_child(world);world.set_meta("network_game",true)
	var service:=Service.new();service.world=world
	var manager:=Manager.new();manager.service=service
	var building:=Building.new();building.manager=manager;world.add_child(building)
	var view=preload("res://scripts/rain_shelter_view.gd").new();view.configure(building)
	var actor:=Node2D.new();world.add_child(actor);world.actors["remote"]=actor
	var inside:=Vector2.INF
	for y in range(-40,90,5):
		for x in range(-140,141,5):
			if view.covers_head(Vector2(x,y)):inside=Vector2(x,y);break
		if inside.is_finite():break
	check(inside.is_finite(),"use real roof image alpha to locate actual head overlap")
	var outside:=Vector2(10000,10000)
	actor.position=outside;view.update_occlusion(outside)
	check(not view.faded and view.roof.modulate.a==1,"unobstructed online roof opaque")
	actor.position=inside;view.update_occlusion(outside)
	await create_timer(.4).timeout
	check(view.faded and is_equal_approx(view.roof.modulate.a,float(view.Config.data.shelter_roof_occluded_alpha)),"remote actual head overlap fades roof with local player outside")
	check(view.parts.all(func(part):return part.modulate.a==1),"remote occlusion never fades poles or caps")
	actor.position=outside;view.update_occlusion(outside)
	await create_timer(.4).timeout
	check(not view.faded and view.roof.modulate.a==1,"remote departure restores roof opacity")
	view.update_occlusion(inside);await create_timer(.4).timeout
	check(view.faded,"local occlusion still works with remote outside")
	actor.free();view.update_occlusion(outside);await create_timer(.4).timeout
	check(not view.faded,"freed remote actor safely ignored")
	FileAccess.open("res://reports/network-local-rollup-v1/shelter-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	var failed:=checks.filter(func(row):return not row.pass).size()
	print("REMOTE_SHELTER ",checks.size()," checks ",failed," failed")
	world.queue_free();await process_frame;quit(1 if failed else 0)
