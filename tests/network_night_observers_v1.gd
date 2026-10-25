extends "res://tests/sleep_v8_fixture.gd"
class Harness extends "res://scripts/combat_service.gd":
	func boar_clear(_at: Vector2,_next: Vector2,_node: CollisionObject2D=null) -> bool:return true
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds
	w.set_process(false);w.player.set_physics_process(false);s.set_process(false);v.set_process(false)
	w.set_meta("network_rules_host",true)
	var c:=Harness.new();c.service=s;c.personal=s.combat.personal.duplicate(true);c.personal.phase="alive"
	c.rules=c.rules.duplicate(true);c.rules.boar.night_encounter_chance=1.0
	var at: Vector2=w.player.position
	var observers: Array[Vector2]=[at,at+Vector2(4000,0)]
	check(c.encounter_visible(at,observers),"local observer blocks visible relocation")
	check(c.encounter_visible(observers[1]+Vector2(100,0),observers),"distant authenticated peer blocks visible relocation")
	check(not c.encounter_visible(at+Vector2(0,950),observers),"offscreen vertical location remains eligible")
	c.peers=[{"id":"second","x":observers[1].x,"y":observers[1].y,"phase":"alive"}]
	c.state=s.combat.state.duplicate(true)
	c.state.boars={"distant":{"x":at.x+3000,"y":at.y+3000,"home_x":at.x+3000,"home_y":at.y+3000,"health":45.0,"mode":"patrol","clock":0.0,"hit":0.0,"generation":0}}
	c.state.erase("encounter_night");c.state.encounter_wait=100.0
	# Seeded terrain can reject some nights' 48 sites; retain original checks and
	# try later authoritative nights rather than bypass collision validation.
	for day in range(1,15):
		v.simulation.day=day;c.state.encounter_wait=100.0
		c.advance_night_encounter(1,1260)
		if c.state.has("encounter_night"):break
	check(c.state.has("encounter_night"),"shared host schedules an offscreen encounter")
	var hunter: Dictionary=c.state.boars.distant
	var point:=Vector2(hunter.x,hunter.y)
	check(not c.encounter_visible(point,observers),"actual relocation hidden from both peers at widest zoom")
	check(hunter.get("night_hunter",false) and c.state.boars.size()==1,"existing boar reused without population growth")
	c.advance_night_encounter(100,1260)
	check(Vector2(hunter.x,hunter.y)==point,"second request cannot repeat same-night relocation")
	FileAccess.open("res://reports/network-local-rollup-v1/night-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"))
	var failed:=checks.filter(func(row):return not row.pass).size()
	print("NETWORK_NIGHT_OBSERVERS ",checks.size()," checks ",failed," failed")
	w.queue_free();await process_frame;quit(1 if failed else 0)
