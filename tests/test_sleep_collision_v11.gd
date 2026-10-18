extends SceneTree
const OUT="res://reports/sleep-collision-v11/"
var checks=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=4) -> void:
	for i in n:await process_frame
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT);Engine.set_meta("integration_seed",271828)
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	var s=w.item_service;var b=s.builds;var p=w.player
	w.environment_view.set_process(false);p.set_physics_process(false)
	while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
	w.set_process(false);w.item_ui.set_process(false)
	for entry in [["wood_bed",false],["wood_bed",true],["straw_mat",false],["straw_mat",true],["sleeping_bag",false]]:
		b.states.clear();b.refresh_all();await frames()
		for i in 40:s.inventory.slots[i]={}
		for item in ["wood","plant_fiber","broad_leaf","sleeping_bag"]:s.inventory.add(item,80 if item!="sleeping_bag" else 3)
		var row={};var label: String=str(entry)
		for y in range(-4,5):
			for x in range(-4,5):
				var at: Vector2=w.generator.spawn+Vector2(x*96,y*64);p.position=at+Vector2(130,85)
				var candidate: Dictionary=b.candidate(entry[0],at,entry[1],true,0)
				if b.reason(candidate).is_empty():row=candidate;break
			if not row.is_empty():break
		check(not row.is_empty(),"valid offset footprint placement "+label)
		if row.is_empty():continue
		check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"place "+label);await frames()
		var id: String=b.states.keys()[0];var node: Node2D=b.visuals[id];var bounds: Rect2=b.footprint_rect(row);var center: Vector2=node.position+bounds.get_center()
		check(node.shape.position==bounds.get_center() and node.shape.shape.size==bounds.size,"live collider matches offset footprint "+label)
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			var edge: Vector2=center+direction*bounds.size*.5
			p.position=edge+direction*12;s.body.energy=30;await physics_frame
			check(not p.test_move(p.transform,-direction),"can stand and step near visible edge "+label+str(direction))
			check(p.test_move(p.transform,-direction*5),"cannot walk through actual facility "+label+str(direction))
			check(preload("res://scripts/world_interaction.gd").in_reach(w.stream,p.position,node),"edge-based unified interaction reachable "+label+str(direction))
			check(s.sleep.start(id).is_empty(),"controller accepts same edge distance "+label+str(direction))
			s.sleep.interrupt()
			if entry[0]=="sleeping_bag":break
		# A real wall between player and nearest edge must still block use.
		if entry[0]!="sleeping_bag":
			var edge: Vector2=center+Vector2(bounds.size.x*.5,0);p.position=edge+Vector2(42,0)
			var wall=StaticBody2D.new();wall.position=edge+Vector2(22,0);var shape=CollisionShape2D.new();var rect=RectangleShape2D.new();rect.size=Vector2(8,40);shape.shape=rect;wall.add_child(shape);w.add_child(wall);await physics_frame;await physics_frame
			check(not preload("res://scripts/world_interaction.gd").in_reach(w.stream,p.position,node) and not s.sleep.start(id).is_empty(),"wall still blocks edge interaction "+label)
			wall.queue_free();await frames()
	var failed=checks.filter(func(c):return not c.pass).size();FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));print("SLEEP COLLISION V11 ",checks.size()," checks; ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames();quit(0 if failed==0 else 1)


