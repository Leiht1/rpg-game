extends SceneTree
var OUT := "res://reports/sleep-v1/"
var checks: Array=[]
var w: Node
var s: Node
var v: Node
var mode := "write"
var cases := ["sleeping_bag","straw_mat","straw_mat-vertical","wood_bed","wood_bed-vertical"]
func _initialize() -> void:
	if "--instant" in OS.get_cmdline_user_args(): OUT="res://reports/sleep-instant-v2/"
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=4) -> void:
	for i in n: await process_frame
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode=arg.trim_prefix("--mode=")
	Engine.set_meta("integration_seed",271828);Engine.set_meta("sleep_preview",true)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started: await process_frame
	s=w.item_service;v=w.environment_view;v.set_process(false);v.simulation.paused=false;w.player.set_physics_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)): await process_frame
	for label in cases:
		w.persistent_world=false;s.writable=true;s.dirty=false
		s.builds.states.clear();s.builds.refresh_all();await frames()
		s.save_path=OUT+"isolated-"+label+".json"
		if mode=="write":
			for i in 40: s.inventory.slots[i]={}
			for id in ["wood","plant_fiber","broad_leaf","sleeping_bag"]: s.inventory.add(id,60 if id!="sleeping_bag" else 3)
			s.inventory.equipment.main_hand=s.inventory.instance("stone_pickaxe");s.inventory.equipment.main_hand.durability=73
			s.inventory.hotbar_equipment={"1":s.inventory.equipment.main_hand.instance_id}
			s.resource_hits["sleep:retained"]=2;s.consumed["sleep:collected"]=true
			var kind: String=label.trim_suffix("-vertical");var row := {}
			for yy in range(-3,4):
				for xx in range(-3,4):
					var at: Vector2=w.generator.spawn+Vector2(xx*96,yy*64);w.player.position=at+Vector2(0,85)
					var candidate: Dictionary=s.builds.candidate(kind,at,label.ends_with("vertical"),true,0)
					if s.builds.reason(candidate).is_empty() and s.sleep.path_clear(w.player.position,at,""): row=candidate;break
				if not row.is_empty(): break
			check(not row.is_empty(),"real placement site "+label)
			if row.is_empty(): continue
			check(s.builds.place(row,s.inventory.slots.duplicate(true)).is_empty(),"placed persistent facility "+label)
			await frames()
			var id: String=s.builds.states.keys()[0]
			s.body.energy=20;w.player.position=Vector2(row.x,row.y)+Vector2(0,85)
			check(s.sleep.start(id,"maximum" if kind=="sleeping_bag" else "full").is_empty(),"start persisted sleep "+label)
			v.advance_gameplay(152.2)
			check(s.body.sleeping and s.builds.states[id].sleep_state=="IN_USE","save mid actual sleep "+label)
			w.persistent_world=true
			check(s.save_state(),"real file atomic write "+label)
			FileAccess.open(OUT+"expected-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(s.snapshot()))
			w.persistent_world=false;s.sleep.interrupt();v.advance_gameplay(1.5)
		else:
			w.persistent_world=true;s.load_state();await frames()
			check(s.writable,"fresh process accepts file "+label)
			if not s.writable: continue
			if mode=="read":
				var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"expected-"+label+".json"))
				check(s.body.sleeping and absf(s.body.energy-float(expected.body.energy))<.000001,"no duplicate energy on load "+label)
				check(absf(v.simulation.minute-float(expected.body_environment.minute))<.000001,"paired clock no advance on load "+label)
				for key in ["slots","equipment","hotbar_equipment","buildings","resource_hits","consumed"]:
					check(JSON.parse_string(JSON.stringify(s.snapshot()[key]))==expected[key],"restart preserves "+key+label)
				var old: float=s.body.energy;s.load_state()
				check(s.body.energy==old,"repeated load no energy bonus "+label)
				v.advance_gameplay(30)
				var rate: float=preload("res://scripts/sleep_rules.gd").facility(label.trim_suffix("-vertical")).rate
				check(absf(s.body.energy-old-rate*.2)<.00001,"resume actual 12 game minutes once "+label)
				s.sleep.interrupt();v.advance_gameplay(1.5)
				check(not s.sleep.active() and not w.player.input_blocked and not s.sleep.symbols.visible,"reload wake cleans symbols and locks "+label)
				check(s.builds.states.is_empty() if label=="sleeping_bag" else s.builds.states.values()[0].sleep_state=="PLACED","bag removed reusable released "+label)
				check(s.save_state(),"persist finished lifecycle "+label)
			else:
				check(not s.sleep.active(),"third process stays awake "+label)
				check(s.builds.states.is_empty() if label=="sleeping_bag" else s.sleep.available(s.builds.states.keys()[0]),"third process consumed or usable "+label)
				check(s.inventory.equipment.main_hand.durability==73 and s.inventory.hotbar_equipment.has("1"),"tool alias and durability survive "+label)
				var original: Dictionary=s.snapshot()
				var bad: Dictionary=original.duplicate(true);bad.body.sleep_session={"version":999}
				FileAccess.open(s.save_path+".invalid",FileAccess.WRITE).store_string(JSON.stringify(bad))
				var text := FileAccess.get_file_as_string(s.save_path+".invalid")
				var proper_path: String=s.save_path;s.save_path+=".invalid";s.load_state()
				check(not s.writable and not s.save_state() and FileAccess.get_file_as_string(s.save_path)==text,"unknown sleep source protected "+label)
				s.save_path=proper_path
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"persistence-"+mode+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("SLEEP PERSISTENCE ",mode," ",checks.size()," checks; ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(0 if failed==0 else 1)
