extends SceneTree
const OUT="res://reports/camp-food-polish-v2/"
const Fresh=preload("res://scripts/food_freshness.gd")
var w: Node
var s: Node
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=4) -> void:
	for i in n:await process_frame
func files() -> Dictionary:
	var result := {}
	for n in DirAccess.get_files_at("user://"):
		if n.ends_with(".json") or n.ends_with(".tmp"):result[n]=FileAccess.get_sha256("user://"+n)
	return result
func capture(name_value: String) -> void:
	await frames(14)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_value+".png")
func near(kind: String) -> String:
	var id := "expansion-demo:"+kind
	var row: Dictionary=s.builds.states[id]
	w.player.position=Vector2(row.x,row.y)+Vector2(0,65);w.player.camera.position=Vector2.ZERO;w.player.camera.reset_smoothing()
	await frames()
	return id
func clear_slots() -> void:
	for i in 40:s.inventory.slots[i]={}
func run() -> void:
	var original := files()
	w=load("res://scenes/camp_expansion_preview.tscn").instantiate();root.add_child(w)
	while not w.started or w.volume_label==null:await process_frame
	s=w.item_service;w.environment_view.set_process(false);w.environment_view.simulation.set_process(false);w.player.set_physics_process(false);s.set_process(false);s.animals.set_process(false)
	check(not w.persistent_world,"isolated candidate world")
	for id in s.database.ids():
		if not Fresh.cooked(s.database,id):continue
		var good := {"item_id":id,"count":1,"spoilage":0.0};var bad := {"item_id":id,"count":1,"spoilage":1.0}
		check(s.stack_name(good)==s.database.item(id).name,id+" fresh name unchanged")
		check(s.stack_name(bad)==s.database.item(id).name+"（腐烂）",id+" rotten name suffix")
		check(s.stack_texture(bad,"icon")!=null,id+" rotten texture available")
		if id in ["lake_fish","roasted_fish","smoked_fish"]:
			var expected: Texture2D=load("res://assets/camp_expansion/v2/rotten_"+id+".png")
			check(s.stack_texture(bad,"icon")==expected and s.stack_texture(bad,"world")==expected,id+" uses approved whole fish in inventory and world")
	clear_slots();s.inventory.slots[0]={"item_id":"lake_fish","count":3,"spoilage":1.0}
	var card: Control=w.item_ui.make_item_card(0);w.item_ui.add_child(card);await frames()
	var labels := card.find_children("*","Label",true,false);check(labels.any(func(label):return "湖鱼（腐烂）" in label.text),"inventory hover uses rotten name")
	var icons := card.find_children("*","TextureRect",true,false);check(icons[0].texture==s.stack_texture(s.inventory.slots[0],"icon"),"inventory hover uses actual spoiled stack icon");card.free()
	var compost: String=await near("compost_bin");s.expansion_ui.open(compost);await frames()
	check(s.expansion_ui.panel.size==Vector2(420,232),"compost compact fixed frame")
	check("（腐烂）" in s.expansion_ui.choices.get_child(0).text,"compost input uses rotten name")
	await capture("compost-short")
	for i in 40:s.inventory.slots[i]={"item_id":"lake_fish","count":3,"spoilage":1.0}
	s.expansion_ui.fingerprint="";s.expansion_ui.refresh();await frames()
	var scroll: ScrollContainer=s.expansion_ui.scroll
	check(s.expansion_ui.panel.size==Vector2(420,232),"long input list cannot enlarge compost frame")
	check(scroll.get_v_scroll_bar().max_value>scroll.size.y,"long list overflows into vertical scroll")
	scroll.scroll_vertical=10000;await frames();check(scroll.scroll_vertical>0,"long list can scroll to later choices")
	await capture("compost-scroll")
	scroll.scroll_vertical=0;await frames()
	var point := scroll.get_global_rect().get_center();Input.warp_mouse(point)
	var wheel := InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;wheel.position=point;wheel.global_position=point;Input.parse_input_event(wheel);await frames()
	check(scroll.scroll_vertical>0,"native mouse wheel scrolls long input list without enlarging frame")
	s.expansion_ui.close_panel()
	var smoker: String=await near("advanced_smokehouse");clear_slots();s.inventory.slots[8]={"item_id":"wood","count":4}
	for food in ["lake_fish","roasted_carrot","vegetable_fish_soup"]:
		s.inventory.slots[0]={"item_id":food,"count":1,"spoilage":0.0}
		check(not s.expansion.act(smoker,"process").is_empty(),food+" cannot be smoked")
	s.inventory.slots[0]={"item_id":"roasted_fish","count":2,"spoilage":1.0}
	check(not s.expansion.act(smoker,"process").is_empty(),"rotten roasted fish cannot be smoked")
	s.inventory.slots[0].spoilage=.2;s.expansion_ui.open(smoker);await frames()
	check(s.expansion_ui.panel.size==Vector2(420,144),"smokehouse compact fixed frame")
	check("烤鱼" in s.expansion_ui.choices.get_child(0).text,"smoking button shows roasted fish input")
	await capture("smokehouse-idle")
	var before: Array=s.inventory.slots.duplicate(true);var row: Dictionary=s.builds.states[smoker].duplicate(true)
	w.persistent_world=true;s.save_path=OUT+"missing/save.json"
	check(s.expansion.act(smoker,"process").begins_with("保存失败"),"smoking save failure reported")
	check(s.inventory.slots==before and s.builds.states[smoker]==row,"roasted fish wood and job rollback together")
	w.persistent_world=false
	check(s.expansion.act(smoker,"process").is_empty(),"roasted fish starts smoking")
	check(s.inventory.count_item("roasted_fish")==1 and s.inventory.count_item("wood")==3,"smoking pays one roasted fish and one wood")
	s.expansion_ui.refresh();await frames();check(s.expansion_ui.panel.size==Vector2(420,144),"working status keeps same frame")
	await capture("smokehouse-working")
	s.expansion.advance(120);s.expansion_ui.refresh();await frames()
	check(s.builds.states[smoker].expansion.job.ready,"smoking finishes in normal game time")
	check("熏制烤鱼" in s.expansion_ui.choices.get_child(0).text,"claim button names smoked roasted fish")
	check(s.expansion_ui.panel.size==Vector2(420,144),"ready status keeps same frame")
	await capture("smokehouse-ready")
	s.builds.states[smoker].expansion.job.output.spoilage=1.0;s.expansion_ui.refresh();await frames()
	check("熏制烤鱼（腐烂）" in s.expansion_ui.choices.get_child(0).text,"ready product updates rotten name when aging")
	check(s.expansion_ui.choices.get_child(0).icon==s.stack_texture(s.builds.states[smoker].expansion.job.output,"icon"),"ready product updates spoiled fish icon")
	s.builds.states[smoker].expansion.job.output.spoilage=0.0
	var snapshot: Dictionary=s.builds.serialize();check(s.builds.validate(snapshot,{}),"ready output remains save compatible")
	check(s.expansion.act(smoker,"claim").is_empty() and s.inventory.count_item("smoked_fish")==1,"smoked roasted fish claims into inventory")
	var preserved := {"item_id":"smoked_fish","count":1,"spoilage":0.0}
	Fresh.advance(s.database,preserved,30*1440-1);check(not Fresh.rotten(preserved),"smoked fish remains good until just before thirty days")
	Fresh.advance(s.database,preserved,1.01);check(Fresh.rotten(preserved),"smoked fish spoils at thirty days")
	check(s.stack_name(preserved)=="熏制烤鱼（腐烂）","smoking and rotten name suffix compose")
	check(float(s.database.item("smoked_fish").chilled_shelf_days)>=30,"refrigeration cannot shorten thirty day shelf life")
	w.free();await frames();check(files()==original,"all actual player save hashes unchanged")
	var failed := checks.filter(func(c):return not c.pass)
	var file := FileAccess.open(OUT+"window.json",FileAccess.WRITE);file.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"));file.close()
	print("CAMP FOOD POLISH: ",checks.size()," checks, ",failed.size()," failed");quit(0 if failed.is_empty() else 1)
