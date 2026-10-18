extends SceneTree
const OUT="res://reports/sleep-fit-v10/"
var checks=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=4) -> void:
	for i in n: await process_frame
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT);Engine.set_meta("integration_seed",271828)
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started: await process_frame
	var s=w.item_service;var b=s.builds;w.environment_view.set_process(false);w.player.set_physics_process(false);w.item_ui.set_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)): await process_frame
	w.set_process(false)
	var room: Array=[]
	for entry in [["wood_bed",false],["wood_bed",true],["straw_mat",false],["straw_mat",true],["sleeping_bag",false]]:
		for wall in room: wall.queue_free()
		room.clear();b.states.clear();b.refresh_all();await frames()
		for i in 40:s.inventory.slots[i]={}
		for item in ["wood","plant_fiber","broad_leaf","sleeping_bag"]:s.inventory.add(item,80 if item!="sleeping_bag" else 3)
		var kind: String=entry[0];var vertical: bool=entry[1];var label=kind+str(vertical);var row={}
		for y in range(-4,5):
			for x in range(-4,5):
				var at: Vector2=w.generator.spawn+Vector2(x*96,y*64)
				w.player.position=at+(Vector2(85,0) if vertical else Vector2(0,85))
				var candidate: Dictionary=b.candidate(kind,at,vertical,true,0)
				if b.reason(candidate).is_empty():row=candidate;break
			if not row.is_empty():break
		check(not row.is_empty(),"clear enlarged footprint site "+label)
		if row.is_empty():continue
		var center=Vector2(row.x,row.y);var half: Vector2=b.footprint(row)*.5
		for side in [Vector2(-1,0),Vector2(1,0),Vector2(0,-1),Vector2(0,1)]:
			var wall=Node2D.new();wall.position=center+side*(half+Vector2(18,18));wall.set_meta("building_id","test_wall");wall.set_meta("camp_layer","edge");w.add_child(wall);wall.add_to_group("world_interactables")
			var body=StaticBody2D.new();wall.add_child(body);var shape=CollisionShape2D.new();var rectangle=RectangleShape2D.new();rectangle.size=Vector2(8,half.y*2+44) if side.x else Vector2(half.x*2+44,8);shape.shape=rectangle;body.add_child(shape);room.append(wall)
		await physics_frame;await physics_frame
		check(b.reason(row).is_empty(),"fits tight wall enclosure with real clearance "+label)
		var wall: Node2D=room[0];var previous=wall.position;wall.position=center+Vector2(-half.x+2,0);await physics_frame;await physics_frame
		check(not b.reason(row).is_empty(),"actual wall overlap still rejected "+label)
		wall.position=previous
		# Remove the test room for reach checks; enclosure validation above used live colliders.
		for node in room:node.queue_free()
		room.clear();await frames();check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"enlarged facility places "+label)
		s.body.energy=30;var id: String=b.states.keys()[0]
		check(s.sleep.start(id).is_empty(),"sleep enters "+label)
		var group: Node2D=w.player.get_node("SleepHeadCover");var head: Node2D=group.get_node("HeadPivot");var sprite: Sprite2D=head.get_node("CurrentHead/Sprite")
		check(head.scale==Vector2.ONE and sprite.scale.is_equal_approx(w.player.character.get_node("Visual/Pelvis/Head/Sprite").scale),"original head size retained "+label)
		var identity=head.get_child(0).get_instance_id();var pose=head.transform
		w.player.set_physics_process(true);w.environment_view.set_process(true)
		for i in 30:
			await physics_frame;await process_frame
			check(head.transform.is_equal_approx(pose) and head.get_child(0).get_instance_id()==identity and group.visible and not w.player.character.visible,"live frame head stable "+label+str(i))
		w.environment_view.set_process(false);w.player.set_physics_process(false)
		root.size=Vector2i(1280,720);w.player.camera.zoom=Vector2(1.65,1.65);w.player.camera.position_smoothing_enabled=false;w.player.camera.force_update_scroll();await frames();await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+label+".png")
		s.sleep.interrupt();check(w.player.character.visible and not group.visible,"wake restores character "+label)
	var failed=checks.filter(func(c):return not c.pass).size();FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));print("SLEEP FIT V10 ",checks.size()," checks; ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames();quit(0 if failed==0 else 1)
