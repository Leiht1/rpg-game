extends "res://tests/sleep_v8_fixture.gd"
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started: await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds
	v.set_process(false);w.player.set_physics_process(false)
	root.size=default_size();root.content_scale_size=root.size
	b.states.clear();b.refresh_all();stock()
	var row := find_site("wood_bed",false)
	check(not row.is_empty(),"bed site")
	check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"place bed")
	await frames()
	var id: String=b.states.keys()[0]
	w.player.position=Vector2(row.x,row.y)+Vector2(0,85);s.body.energy=10
	var sleep_reason: String=s.sleep.start(id)
	check(sleep_reason.is_empty(),"sleep starts: "+sleep_reason)
	for code in [KEY_B,KEY_V,KEY_M,KEY_C]:
		root.push_input(key(code),true);await frames()
		check(s.body.sleep_active() and w.player.input_blocked,"view stays asleep and blocked "+str(code))
		check(w.item_ui.bag.visible if code==KEY_B else w.map_view.visible if code==KEY_M else w.item_ui.craft_panel.visible,"view opened "+str(code))
	check(w.item_ui.item_modal_open(),"inventory mutation guards retained")
	check(w.item_ui.cells[8]._get_drag_data(Vector2.ZERO)==null,"sleep inventory cannot begin drag")
	check(is_equal_approx(w.item_ui.cells[8].durability_bar.scale.y,.36),"tool durability bar renders at double prior scale")
	var denied: Array=[]
	s.notice.connect(func(message):denied.append(message))
	var before: Array=s.inventory.slots.duplicate(true)
	w.item_ui.craft_panel.submit(1)
	check(denied.has("睡醒了再试试") and before==s.inventory.slots,"sleep craft click shows notice and consumes nothing")
	check(s.craft_check("combat_tusk_club",1)=="睡醒了再试试","craft denied during sleep")
	check(s.camps.build_check("invalid")=="睡醒了再试试","build denied before recipe validation")
	check(s.camps.act("invalid","cook")=="睡醒了再试试","cooking denied")
	s.sleep.interrupt();w.item_ui.close_panels()
	for i in 40:s.inventory.slots[i]={}
	s.inventory.equipment={};s.inventory.hotbar_equipment={}
	s.inventory.add("wood_club",1);s.inventory.add("boar_tusk",2)
	var recovered: Dictionary={}
	for i in 40:
		if s.inventory.slots[i].get("item_id","")=="wood_club":recovered=s.inventory.slots[i].duplicate(true);s.inventory.slots[i]={};break
	var at: Vector2=w.player.position
	s.combat.state.relics["test"]={"x":at.x,"y":at.y,"owner":"other-player","contents":[recovered]}
	check(s.combat.claim("test",0,recovered).is_empty(),"claim recovered weapon with original instance metadata")
	var original: Dictionary={}
	for slot in s.inventory.slots:
		if slot.get("item_id","")=="wood_club": original=slot.duplicate(true)
	check(s.inventory.craft_exchange({"wood_club":1,"boar_tusk":2},"tusk_club",1).is_empty(),"recovered instance metadata accepted in bag")
	for i in 40:
		if s.inventory.slots[i].get("item_id","")=="wood_club":s.inventory.slots[i]={}
	s.inventory.equipment.main_hand=original;s.inventory.hotbar_equipment["0"]=original.instance_id
	check(s.inventory.craft_count_item("wood_club")==1,"equipped alias counted once")
	check(s.inventory.craft_exchange({"wood_club":1,"boar_tusk":2},"tusk_club",1,true).is_empty(),"equipped weapon can craft")
	check(s.inventory.equipment.is_empty() and s.inventory.hotbar_equipment.is_empty() and s.inventory.count_item("tusk_club")==1,"consume equipped instance and alias atomically")
	# Abandoned camp hints share selection and actual capability requirements.
	b.states[id].abandoned=true
	var interaction=preload("res://scripts/world_interaction.gd")
	check(interaction.caption(b.visuals[id],s.inventory)=="前人废弃的营地，需要石锤","abandoned needs hammer")
	s.inventory.add("stone_hammer",1)
	for i in 40:
		if s.inventory.slots[i].get("item_id","")=="stone_hammer":s.inventory.equip(i);break
	check(interaction.caption(b.visuals[id],s.inventory)=="前人废弃的营地，按E拆除","abandoned demolition caption")
	s.inventory.equipment={}
	var messages: Array=[]
	s.notice.connect(func(message):messages.append(message))
	s.animals.states.clear()
	var origin: Vector2=w.player.position
	for species in ["chicken","sheep"]:
		s.animals.states["hint-test"]={"x":origin.x,"y":origin.y,"species":species}
		s.combat.resolve_hits({"direction":{"x":1,"y":0},"weapon":s.combat.weapon(),"targets":{}})
		check(messages.has("小鸡这么可爱，怎么能打它呢？" if species=="chicken" else "小羊这么可爱，怎么能打它呢？"),"animal attack notice "+species)
	s.animals.states.clear()
	var failed := checks.filter(func(c):return not c.pass).size()
	print("SLEEP READONLY RELIC ",checks.size()," checks; ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(0 if failed==0 else 1)
