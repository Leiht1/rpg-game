extends SceneTree
const OUT="res://reports/chest-volume-render-v2/"
const OPEN="res://assets/buildings/chest-open-v1/wood_chest_open.png"
var checks: Array=[]
func _initialize() -> void:call_deferred("run")
func frames(n: int=4) -> void:
	for i in n:await process_frame
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func files() -> Dictionary:
	var result := {}
	for name_value in DirAccess.get_files_at("user://"):
		if name_value.ends_with(".json") or name_value.ends_with(".tmp"):result[name_value]=FileAccess.get_sha256("user://"+name_value)
	return result
func viewport() -> SubViewport:
	var view := SubViewport.new();view.size=Vector2i(192,160);view.transparent_bg=true;view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view);return view
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT);var before := files()
	Engine.set_meta("camp_expansion_preview",false)
	var manager: RefCounted=load("res://scripts/camp_buildings.gd").new()
	manager.states={"chest":{"kind":"wood_chest","open":false}}
	var actual_view := viewport()
	var node := preload("res://scripts/camp_building.gd").new();node.manager=manager;node.building_id="chest";node.preview=true;node.position=Vector2(96,100);actual_view.add_child(node)
	for opened in [false,true,false,true]:
		manager.states.chest.open=opened;node.queue_redraw();await frames(8);await RenderingServer.frame_post_draw
		var actual := actual_view.get_texture().get_image()
		check(not opened or manager.textures.has(OPEN),"open texture retained beyond draw callback")
		var source: Texture2D=load(OPEN) if opened else node.texture(13)
		var reference := viewport();var painter := Node2D.new();painter.position=node.position;painter.texture_filter=node.texture_filter;reference.add_child(painter)
		var region := Rect2(source.get_image().get_used_rect());var rect := node.volume_rect(source,manager.volume_profile("wood_chest"))
		painter.draw.connect(func():painter.draw_texture_rect_region(source,rect,region));painter.queue_redraw()
		await frames();await RenderingServer.frame_post_draw
		var expected := reference.get_texture().get_image();var differences := 0;var colored := 0
		for y in actual.get_height():
			for x in actual.get_width():
				var a := actual.get_pixel(x,y);var b := expected.get_pixel(x,y)
				if a!=b:differences+=1
				if a.a>.5 and a.r-a.b>.05:colored+=1
		check(differences==0,"open=%s GPU pixels match approved art, differing=%d"%[opened,differences])
		check(colored>150,"open=%s retains painted wood colors instead of white rectangle"%opened)
		actual.save_png(OUT+("open" if opened else "closed")+"-isolated.png")
		reference.free();await frames()
	actual_view.free();await frames()
	var w=load("res://scenes/camp_expansion_preview.tscn").instantiate();root.add_child(w)
	while not w.started or w.volume_label==null:await process_frame
	var s: Node=w.item_service;s.save_path=OUT+"isolated-items.json";var id := "expansion-demo:wood_chest";var row: Dictionary=s.builds.states[id]
	w.player.position=Vector2(row.x,row.y)+Vector2(0,45);w.player.set_physics_process(false);s.set_process(false)
	w.player.camera.position=Vector2.ZERO;w.player.camera.position_smoothing_enabled=false;w.player.camera.zoom=Vector2.ONE;w.player.camera.reset_smoothing();w.player.camera.force_update_scroll();await frames(12)
	check(s.builds.set_chest_open(id,true).is_empty(),"real chest opens through existing save transaction")
	s.storage_ui.open(id);await frames(12)
	check(s.storage_ui.panel.visible and s.builds.textures.has(OPEN),"open grid and persistent lid texture both present")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"open-world.png")
	s.inventory.slots[30]={"item_id":"wood","count":3}
	check(s.builds.transfer(id,0,30,{},s.inventory.get_slot(30).duplicate(true)).is_empty(),"deposit stack succeeds")
	check(s.builds.states[id].contents[0].get("count",0)==3 and s.inventory.get_slot(30).is_empty(),"deposit keeps exact inventory counts")
	check(s.builds.transfer(id,0,30,s.builds.states[id].contents[0].duplicate(true),{}).is_empty(),"withdraw stack succeeds")
	check(s.inventory.get_slot(30).get("count",0)==3 and s.builds.states[id].contents[0].is_empty(),"withdraw keeps exact inventory counts")
	s.storage_ui.close_panel();await frames()
	check(not s.builds.states[id].open and not s.storage_ui.panel.visible,"close restores closed state and hides storage")
	check(not w.persistent_world and s.save_path.begins_with(OUT),"test world disables persistent saves and isolates item path")
	w.free();await frames()
	var after := files()
	FileAccess.open(OUT+"save-observation.json",FileAccess.WRITE).store_string(JSON.stringify({"before":before,"after":after,"unchanged":before==after,"note":"User may have an ordinary game running; test world uses persistent_world=false and report-local save path."},"\t"))
	var failed := checks.filter(func(c):return not c.pass)
	FileAccess.open(OUT+"window.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"))
	print("CHEST VOLUME RENDER: ",checks.size()," checks, ",failed.size()," failed");quit(0 if failed.is_empty() else 1)
