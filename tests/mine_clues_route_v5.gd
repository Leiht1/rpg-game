extends "res://tests/sleep_v8_fixture.gd"
const DEST="res://reports/mine-clues-route-v5/"
var view: Node2D
func go(at: Vector2) -> void:
	w.player.position=at;w.player.reset_physics_interpolation();w.player.camera.reset_smoothing();await frames(3)
func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	w.item_ui.message_time=0;await create_timer(.2).timeout;await frames(3);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(DEST+name+".png")
func lamp(i: int) -> void:
	await go(s.chapter.puzzle.point("lamps",i)+Vector2(0,48));w.player.input_blocked=false;w.player.facing="back";w.player.try_interact();view._process(0)
func wheel(up: bool) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN;event.pressed=true;root.push_input(event,true);await frames(2)
func page_fits() -> bool:
	var rect: Rect2=s.chapter_view.panel.get_global_rect()
	return rect.position.x>=15 and rect.position.y>=15 and rect.end.x<=root.size.x-15 and rect.end.y<=root.size.y-15
func run() -> void:
	Engine.set_meta("integration_seed",271828);w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w);current_scene=w
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;w.set_process(false);s.set_process(false);v.set_process(false);w.player.set_physics_process(false);w.player.automated=true;w.player.camera.position_smoothing_enabled=false
	s.guide_stage=2;s.combat.state.boars.clear();s.combat.personal.phase="alive";root.size=default_size();root.content_scale_size=root.size
	var q=s.chapter;var m=q.mine;var p=q.puzzle;var ui=s.chapter_view
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/.tmp/mine-ready.json"))
	q.state=q.migrate(source.exploration_chapter);m.state.phase="open";m.state.entered=true;m.state.fuse_remaining_seconds=0.0;m.travel={"inside":true,"serial":1};m.state.puzzle=p.initial()
	for i in 40:s.inventory.slots[i]={}
	s.body.health=100;s.body.energy=100;s.body.hunger=100
	await go(m.origin()+Vector2(-30,20));await frames(10);view=ui.get_node("PuzzleView");view.set_process(false);view._process(0)
	check(view.targets.size()==9 and not view.targets.has("inscription"),"only four lamps four wall clues and chest remain")
	var before: Dictionary=q.serialize()
	check(not m.interact("inscription").is_empty() and q.serialize()==before,"removed inscription command cannot open content or advance state")
	check(p.point("carvings",0)!=m.origin()+Vector2(-440,-320),"wall identities shuffled within existing four hotspots")
	for i in 4:
		var node: Sprite2D=view.targets["carving:"+str(i)].get_node("WallEtching")
		check(node.texture.resource_path.ends_with("glyph-%d.png"%i),"original abstract wall glyph preserved "+str(i))
		await go(p.point("carvings",i)+Vector2(0,38));w.player.input_blocked=false;w.player.facing="back";w.player.try_interact()
		check(ui.carving.visible and ui.words.text==p.OBSERVATIONS[i],"actual E displays exact revised observation "+str(i))
		check(not ui.words.text.contains("春") and not ui.words.text.contains("夏") and not ui.words.text.contains("秋") and not ui.words.text.contains("冬"),"observation "+str(i)+" does not give season answer")
		check(ui.words.position.y>=310,"description stays below symbol "+str(i))
		await snap("01-clue-"+str(i));ui.close_page()
		check(q.serialize()==before,"repeatable investigation changes no world progress "+str(i))
	await go(m.origin()+Vector2(0,20));await snap("02-room-no-inscription")
	# No read-all gate; fourth-light judgement remains exactly the existing mechanism.
	for id in [2,0,3]:await lamp(id)
	check(p.state.order==[2,0,3] and not p.state.solved,"wrong first three retained without early judgement")
	await lamp(1);check(p.state.order.is_empty() and not p.state.solved,"wrong fourth still resets")
	for id in [0,1,2,3]:await lamp(id)
	check(p.state.solved,"unchanged correct order solves")
	await go(m.origin()+Vector2(120,20));view._process(.8);view._process(0);await snap("03-original-collapse")
	view._process(1.7);view._process(0);await frames(4)
	check(view.ores.size()==3 and view.targets.chest.visible and not view.rubble.visible,"original collapse reveals three ores and unique chest")
	await go(p.point("chest")+Vector2(0,45));w.player.input_blocked=false;w.player.facing="back";w.player.try_interact();view._process(0)
	check(p.state.claimed and not p.state.read and s.inventory.count_item(p.RECORD)==1,"original chest grants same ID once and does not auto-read")
	var hint: Dictionary=p.route_hint.resolve(s)
	check(not hint.is_empty() and hint.precision=="coarse_terrain_area" and not hint.target_generated,"route is a real coarse area without generated ruin")
	var area: Dictionary=hint.search_area;var center:=Vector2(area.center.x,area.center.y)
	check(w.generator.can_walk(center,24) and w.generator.sample(center).z<=.12,"hint samples actual safe land")
	check(center.distance_to(m.at())>=800,"hint is outside the mine neighborhood")
	check(preload("res://scripts/mine_route_hint.gd").new().resolve(s)==hint,"new resolver produces stable identical seed/site hint")
	if int(hint.terrain_link)>=0:
		var link: Dictionary=w.generator.links[int(hint.terrain_link)]
		var expected: Vector2=w.generator.region_cores[int(link.a)].lerp(w.generator.region_cores[int(link.b)],float(hint.terrain_fraction))
		check(expected.distance_to(center)<.01,"coarse area actually belongs to existing narrow terrain link")
	var expected_north: Vector2=Vector2(hint.bearing.x,hint.bearing.y).rotated(float(hint.north_rotation))
	check(expected_north.distance_to(Vector2.UP)<.0001,"paper travel-up frame matches actual direction via north mark")
	check(q.use_item(p.RECORD) and ui.route_visible and p.state.read,"inventory opens actual painted route and keeps original read transaction")
	check(not ui.words.visible and not ui.paper.visible and ui.route_paper.visible,"route is full artwork rather than title/body overlay")
	check(ui.reading_layer.layer>w.item_ui.obtained.layer,"reward toast cannot cover the illustrated start or annotations")
	check(ui.route_paper.picture.texture.resource_path.ends_with("mine-route-v5/route-paper.png") and ui.route_paper.north.texture.resource_path.ends_with("north.png"),"full generated paper and painted compass loaded")
	check(page_fits(),"normal paper fits default window")
	await snap("04-route-1280")
	var due: float=p.state.next_due;var read_at: float=p.state.read_at;var camera_zoom: Vector2=w.player.camera.zoom;var scale_before: Vector2=ui.panel.scale
	await wheel(true);await wheel(true);await wheel(true)
	check(ui.panel.scale.x>scale_before.x and ui.panel.scale.x==ui.panel.scale.y and page_fits(),"wheel enlarges whole paper proportionally without cropping")
	check(w.player.camera.zoom==camera_zoom,"paper wheel does not zoom world camera")
	await snap("05-route-zoomed")
	root.push_input(key(KEY_ESCAPE),true);await frames(3);check(not ui.panel.visible and not w.player.input_blocked,"close restores original controls")
	check(q.use_item(p.RECORD) and p.state.next_due==due and p.state.read_at==read_at and s.inventory.count_item(p.RECORD)==1,"reread preserves unique reward and original deadline")
	ui.close_page()
	var saved: Dictionary=s.snapshot().duplicate(true);s.load_state("",false,JSON.parse_string(JSON.stringify(saved)));await frames(4)
	check(s.writable and s.inventory.count_item(p.RECORD)==1 and p.state.next_due==due,"saved existing item and deadline reload")
	check(q.use_item(p.RECORD) and ui.route_visible and ui.route_paper.hint==hint,"same paper meaning after save reload")
	for size in [Vector2i(960,540),Vector2i(1600,900)]:
		root.size=size;root.content_scale_size=size;ui.route_zoom=1.0;ui.layout_page();await frames(4)
		check(page_fits(),"whole paper fits focused readability size "+str(size))
		await snap("06-route-"+str(size.x))
	root.size=default_size();root.content_scale_size=root.size;ui.close_page()
	# Previous paper views must retain their own normal size and contents.
	for id in [q.MAP,q.NOTE,q.BOTTLE]:
		s.inventory.add(id,1);check(q.use_item(id) and not ui.route_visible and ui.panel.size.x==560 and ui.paper.visible,"existing paper reader retained "+id);ui.close_page()
	check(m.state.phase=="open" and p.state.solved and q.valid(q.serialize()),"existing chapter state remains valid")
	FileAccess.open(DEST+"route-hint.json",FileAccess.WRITE).store_string(JSON.stringify(hint,"  "));FileAccess.open(DEST+"ready.json",FileAccess.WRITE).store_string(JSON.stringify(s.snapshot()))
	var failed: int=checks.filter(func(row):return not row.pass).size();FileAccess.open(DEST+"window.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "));print("MINE CLUES ROUTE V5 ",checks.size()," checks ",failed," failures")
	w.persistent_world=false;s.dirty=false;w.queue_free();await frames(6);quit(1 if failed else 0)
