extends SceneTree
class MockService extends Node:
	var world={"environment_view":{"simulation":{"day":28,"minute":1439}}}
	var builds={"states":{"bench":{"kind":"metal_workbench","abandoned":false}}}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var service=MockService.new()
	var chapter=load("res://scripts/exploration_chapter.gd").new()
	chapter.service=service
	assert(not chapter.eligible(),"day 28 final minute must not qualify")
	service.world.environment_view.simulation.day=29
	service.world.environment_view.simulation.minute=0
	assert(chapter.eligible(),"day 29 midnight qualifies with built workbench")
	service.builds.states.bench.abandoned=true
	assert(not chapter.eligible(),"abandoned workbench must not qualify")
	service.builds.states.clear()
	assert(not chapter.eligible(),"day 29 still requires actual workbench")
	var old=chapter.initial();old.stage=1;old.eligible_at=4320.0
	assert(chapter.migrate(old).stage==1,"already triggered progress remains intact")
	service.free()
	print("DAY29_PASS 5 checks")
	quit()
