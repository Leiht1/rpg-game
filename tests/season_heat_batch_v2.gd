extends SceneTree
const Surface=preload("res://scripts/season_surface.gd")
func _initialize() -> void:run.call_deferred()
func reference_advance(service: Node, minutes: float) -> void:
	var sim=service.world.environment_view.simulation
	var f: Dictionary=preload("res://scripts/season_rules.gd").data.features
	var winter: bool=sim.season_date().index==3
	for id in sim.building_snow.keys():
		if not service.builds.states.has(id):sim.building_snow.erase(id)
	for id in service.builds.states:
		var row: Dictionary=service.builds.states[id]
		var rule: Dictionary=f.buildings.get(row.kind,{})
		if rule.is_empty() or not rule.get("allowed",false):sim.building_snow.erase(id);continue
		var state: Dictionary=sim.building_snow.get(id,{"amount":0.0,"blocked":false})
		var warmth:=Surface.heat(service,Vector2(row.x,row.y))
		var gain:=maxf(float(f.winter_snow_minimum),sim.blend.y+sim.blend.z)*float(f.snow_gain_per_minute)*float(rule.gain) if winter else -float(f.snow_melt_per_minute)
		state.amount=clampf(float(state.amount)+minutes*(gain-warmth*float(f.heat_melt_per_minute)*float(rule.melt)),0,1)
		if state.amount>=float(f.blocking_on):state.blocked=bool(rule.blocks)
		elif state.amount<=float(f.blocking_off):state.blocked=false
		sim.building_snow[id]=state
func run() -> void:
	Engine.set_meta("integration_seed",98171023)
	var w=load("res://tests/world_clean_camp_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.set_process(false);w.player.set_physics_process(false);w.environment_view.set_process(false)
	var s=w.item_service
	var sim=w.environment_view.simulation
	s.builds.states.clear()
	for i in 74:s.builds.states[str(i)]={"kind":"wood_floor" if i%2==0 else "workbench","x":w.player.position.x+i*12,"y":w.player.position.y}
	s.builds.states.torch={"kind":"camp_torch","x":w.player.position.x+100,"y":w.player.position.y,"fuel":10.0,"lit":true}
	s.camps.states={"fire":{"x":w.player.position.x,"y":w.player.position.y,"lit":true,"fuel":20.0}}
	for scenario in 6:
		sim.day=24 if scenario%2==0 else 1;sim.blend=Vector3(.2,.3,.5)
		s.camps.states.fire.fuel=[0.0,1.0,20.0][scenario%3]
		s.builds.states.torch.lit=scenario<3
		sim.building_snow={"removed":{"amount":.9,"blocked":true}}
		for id in s.builds.states:sim.building_snow[id]={"amount":.6 if scenario%2==0 else .1,"blocked":scenario%2==0}
		var before: Dictionary=sim.building_snow.duplicate(true)
		reference_advance(s,10.0)
		var expected: Dictionary=sim.building_snow.duplicate(true)
		sim.building_snow=before
		Surface.advance(s,10.0)
		assert(sim.building_snow==expected,"same snow/heat/blocking state after batched heat query")
	s.builds.states.clear();s.camps.states.clear();w.queue_free();await process_frame
	print("SEASON_HEAT_BATCH_V2_PASS 6 scenarios: summer/winter/fuel/lit/removed/exact-state")
	quit(0)
