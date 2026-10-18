extends "res://tests/test_sleep_occupied_v6.gd"
## Final art-only revision: one facility, current project window, no broad rerun.
func run() -> void:
	capture=true;Engine.set_meta("sleep_preview",true);Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started: await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds;v.set_process(false);v.simulation.paused=false;w.player.set_physics_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)): await process_frame
	stock();var row := find_site("wood_bed",true)
	check(not row.is_empty(),"vertical bed real placement site")
	check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"place vertical bed")
	await frames();var id: String=b.states.keys()[0];s.body.energy=30
	w.player.position=Vector2(row.x,row.y)+Vector2(0,85)
	check(s.sleep.start(id).is_empty(),"instant sleep with revised quilt")
	var group: Node2D=w.player.get_node("SleepHeadCover");var quilt: Sprite2D=group.get_node("Quilt")
	check(quilt.texture.resource_path=="res://prototypes/sleep-occupied-v6/final/wood_bed-vertical.png","revised vertical quilt actually rendered")
	root.size=default_size();root.content_scale_size=root.size;w.player.camera.zoom=Vector2(2.5,2.5);w.player.camera.position_smoothing_enabled=false;w.player.camera.force_update_scroll()
	var head: Node2D=group.get_node("HeadPivot");var before: Transform2D=head.transform
	v.advance_gameplay(.9)
	check(head.transform.is_equal_approx(before),"head stays fixed during quilt breathing")
	await shot("wood_bed-vertical-detail")
	s.sleep.interrupt()
	check(not group.visible and b.visuals[id].visible and w.player.character.visible,"wake restores original facility and character")
	check(root.size==default_size(),"only project default window used")
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"final-art-checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("FINAL VERTICAL ART ",checks.size()," checks; ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(0 if failed==0 else 1)
