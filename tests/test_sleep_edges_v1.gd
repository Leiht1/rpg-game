extends SceneTree
const OUT := "res://reports/sleep-v1/"
var checks: Array=[]
var w: Node
var s: Node
var v: Node
var b: RefCounted
var anchor := Vector2.ZERO
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=4) -> void:
	for i in n: await process_frame
func row_for(kind: String) -> Dictionary:
	for y in range(-4,5):
		for x in range(-4,5):
			var at: Vector2=w.generator.spawn+Vector2(x*96,y*64);w.player.position=at+Vector2(0,85)
			var row: Dictionary=b.candidate(kind,at,false,true,0)
			if b.reason(row).is_empty() and s.sleep.path_clear(w.player.position,at,""): anchor=at;return row
	return {}
func stock() -> void:
	for i in 40: s.inventory.slots[i]={}
	for id in ["wood","plant_fiber","broad_leaf","stone","sleeping_bag"]: s.inventory.add(id,50 if id!="sleeping_bag" else 5)
func run() -> void:
	Engine.set_meta("sleep_preview",true);Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started: await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds;v.set_process(false);v.simulation.paused=false;w.player.set_physics_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)): await process_frame
	stock();await frames()
	var row := row_for("straw_mat");check(not row.is_empty(),"edge suite real dry site")
	if row.is_empty(): finish();return
	var full_slots: Array=s.inventory.slots.duplicate(true)
	for i in 40: s.inventory.slots[i]={}
	check(b.reason(row).begins_with("材料不足") and not b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"mat materials insufficient blocks build")
	s.inventory.slots=full_slots
	for kind in ["straw_mat","wood_bed"]:
		var before: Array=s.inventory.slots.duplicate(true)
		w.camp_ui.begin_build("build_"+kind);w.camp_ui.cancel_placement()
		check(s.inventory.slots==before and b.states.is_empty(),"cancel native build no debit "+kind)
	# An actual physics obstacle intersects the new full rectangular footprint.
	var obstacle := StaticBody2D.new();var collision := CollisionShape2D.new();var shape := RectangleShape2D.new();shape.size=Vector2(20,20);collision.shape=shape;obstacle.add_child(collision);obstacle.position=anchor;w.object_root.add_child(obstacle);await frames()
	check(not b.place(row,s.inventory.slots.duplicate(true)).is_empty() and s.inventory.slots==full_slots,"real obstacle refuses facility without debit")
	obstacle.queue_free();await frames()
	var water_found := false
	for y in range(-8,9):
		for x in range(-12,13):
			var at: Vector2=w.generator.spawn+Vector2(x*48,y*48)
			if w.stream.has_ground(at) and w.generator.sample(at).z>.03:
				w.player.position=at+Vector2(0,85)
				check(not b.place(b.candidate("sleeping_bag",at,false,true,0),s.inventory.slots.duplicate(true)).is_empty() and s.inventory.slots==full_slots,"actual loaded water refuses bag without debit")
				water_found=true;break
		if water_found: break
	if not water_found:
		# Spawn seed is inland. Load a real coastal chunk rather than mocking water.
		var coast := Vector2(144,144)
		w.player.position=coast+Vector2(0,85);w.stream.update_target(w.player.position)
		while not w.stream.has_ground(coast): await process_frame
		check(w.generator.sample(coast).z>.03,"actual coastal sample is water")
		check(not b.place(b.candidate("sleeping_bag",coast,false,true,0),s.inventory.slots.duplicate(true)).is_empty() and s.inventory.slots==full_slots,"actual loaded coast rejects bag without debit")
	w.player.position=anchor+Vector2(0,85)
	w.stream.update_target(w.player.position)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)): await process_frame
	# Atomic rollback across inventory and world facility creation.
	w.persistent_world=true;s.save_path=OUT+"does-not-exist/sub/save.json"
	check(not b.place(row,s.inventory.slots.duplicate(true)).is_empty() and b.states.is_empty() and s.inventory.slots==full_slots,"facility save failure rolls back materials and instance")
	w.persistent_world=false
	check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"real mat placed for edge sleeps");await frames()
	var id: String=b.states.keys()[0]
	s.body.energy=20;var body_before: Dictionary=s.body.serialize()
	w.persistent_world=true
	check(s.sleep.start(id).contains("保存失败") and not s.sleep.active() and s.body.serialize()==body_before and b.states[id].sleep_state=="PLACED","reservation save failure no body or lifecycle changes")
	w.persistent_world=false
	s.sleep.start(id);v.advance_gameplay(1.2)
	w.persistent_world=true;v.advance_gameplay(1.1);w.persistent_world=false
	check(not s.body.sleeping and b.states[id].sleep_state=="RESERVED","IN_USE save failure grants no sleep recovery")
	v.advance_gameplay(1.5);check(not s.sleep.active() and b.states[id].sleep_state=="PLACED","failed enter eventually releases all locks")
	# Invalidated facility wakes safely without retained object pointers.
	s.sleep.start(id);v.advance_gameplay(2.2);b.states.erase(id);b.refresh_all();v.advance_gameplay(.1)
	check(not s.body.sleeping and s.body.sleep_session.reason=="facility_lost","missing facility interrupts recovery")
	v.advance_gameplay(1.5);check(not s.sleep.active() and not w.player.input_blocked,"missing facility cleanup releases input")
	await frames()
	for ending in ["target","duration"]:
		stock();row=row_for("sleeping_bag");check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"place bag for "+ending);await frames()
		id=b.states.keys()[0];s.body.energy=99.9 if ending=="target" else 20
		var before: int=s.inventory.count_item("sleeping_bag")
		s.sleep.start(id,"maximum");v.advance_gameplay(2.2)
		if ending=="target": v.advance_gameplay(3)
		else: v.advance_gameplay(450)
		check(not s.body.sleeping and (s.body.sleep_session.get("reason",s.sleep.last_reason)==ending),"bag auto wake reason "+ending)
		v.advance_gameplay(1.5)
		check(not b.states.has(id) and s.inventory.count_item("sleeping_bag")==before,"bag final consumption no returned item "+ending)
		if ending=="duration": check(s.body.energy>49.7 and s.body.energy<=50,"bag caps at3h and +30 energy")
		check(not s.sleep.active(),"bag cannot remain indefinitely "+ending);await frames()
	# Ordinary biology remains active; sleep is not a universal cure.
	stock();row=row_for("wood_bed");b.place(row,s.inventory.slots.duplicate(true));await frames();id=b.states.keys()[0]
	s.body.energy=20;s.body.hunger=0;s.body.illness=1;s.body.health=80;s.body.deprivation=1
	s.sleep.start(id);v.advance_gameplay(152.2)
	check(s.body.energy>36 and s.body.energy<38 and s.body.health<=80 and s.body.illness>=1,"bed restores only energy while illness biology continues")
	s.sleep.interrupt();v.advance_gameplay(1.5)
	# A failed final write must never lock the actor or restore a used facility.
	s.body.energy=20;s.sleep.start(id);v.advance_gameplay(2.2)
	w.persistent_world=true;s.sleep.interrupt();v.advance_gameplay(1.5);w.persistent_world=false
	check(not s.sleep.active() and not w.player.input_blocked and b.states[id].sleep_state=="PLACED" and s.dirty,"failed final save releases controls and retains dirty retry snapshot")
	# Station validation applies at commit as well as menu selection.
	var bench_row := row_for("workbench");check(not bench_row.is_empty(),"legal bench edge fixture")
	if bench_row.is_empty(): finish();return
	check(b.place(bench_row,s.inventory.slots.duplicate(true)).is_empty(),"place workbench for failed craft commit");await frames()
	var bench_id := ""
	for key in b.states:
		if b.states[key].kind=="workbench": bench_id=key;break
	w.player.position=Vector2(bench_row.x,bench_row.y)+Vector2(0,85);s.craft_station_id=bench_id
	var old_inventory: Array=s.inventory.slots.duplicate(true)
	w.persistent_world=true
	check(s.start_craft("bench_sleeping_bag",1).is_empty(),"begin station craft before save failure");s.advance_craft(1.5)
	check(s.inventory.slots==old_inventory,"failed station craft save restores all materials and bag counts")
	w.persistent_world=false
	s.start_craft("bench_sleeping_bag",1);b.states.erase(bench_id);b.refresh_all();s.advance_craft(1.5)
	check(s.craft_job.is_empty() and s.inventory.slots==old_inventory,"removed original workbench cancels pending craft")
	s.craft_station_id="";await frames()
	# Original demolition rules and fractional refunds for both reusable facilities.
	s.body.hunger=80;s.body.illness=0;s.body.health=100;s.body.energy=50
	for kind in ["wood_bed","straw_mat"]:
		if kind=="straw_mat":
			await frames();row=row_for(kind);b.place(row,s.inventory.slots.duplicate(true));await frames();id=b.states.keys()[0]
		w.player.position=Vector2(b.states[id].x,b.states[id].y)+Vector2(0,85)
		s.inventory.equipment.main_hand=s.inventory.instance("stone_hammer")
		var expected_hits: int=b.definitions[kind].hits
		for i in expected_hits: check(b.strike(id,b.visuals[id]),"native demolish "+kind+str(i))
		check(not b.states.has(id),"demolished reusable removed "+kind)
		for material in b.definitions[kind].cost:
			check(s.loose.get(id+":refund:"+material,{}).get("count")==floori(b.definitions[kind].cost[material]*.5),"original50percent refund "+kind+material)
	finish()
func finish() -> void:
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"edges-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("SLEEP EDGES ",checks.size()," checks; ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(0 if failed==0 else 1)
