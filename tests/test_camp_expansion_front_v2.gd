extends SceneTree
const OUT="res://reports/camp-expansion-front-v2/"
const SAVE=OUT+"isolated-save.json"
const Fresh=preload("res://scripts/food_freshness.gd")
var w: Node
var s: Node
var checks: Array=[]
var original: Dictionary={}
var events: Array=[]
var home := Vector2.ZERO
var ids := {}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
	print("CHECK ",ok," ",label)
func files() -> Dictionary:
	var result := {}
	for n in DirAccess.get_files_at("user://"):
		if n.ends_with(".json") or n.ends_with(".tmp"):result[n]=FileAccess.get_sha256("user://"+n)
	return result
func frames(n: int=3) -> void:
	for i in n:await process_frame
func near(id: String) -> void:
	var row: Dictionary=s.builds.states[id]
	w.player.position=Vector2(row.x,row.y)+Vector2(0,70);w.player.camera.reset_smoothing();w.stream.update_target(w.player.position)
	await frames(4)
func legal(kind: String) -> Dictionary:
	for y in range(-400,401,32):
		for x in range(-500,501,32):
			var p := home+Vector2(x,y)
			w.player.position=p+Vector2(0,72)
			if not w.generator.can_walk(w.player.position,12):continue
			var row: Dictionary=s.builds.candidate(kind,p,false,false,0)
			if s.builds.reason(row).is_empty():return row
	return {}
func fill() -> void:
	for i in 40:s.inventory.slots[i]={}
	s.inventory.equipment={};s.inventory.hotbar_equipment={}
	for id in ["wood","stone","flint","plant_fiber","copper_parts","copper_plate","metal_connector","silver_ingot"]:s.inventory.add(id,99)
func capture(name_value: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name_value+".png")
func run() -> void:
	original=files();Engine.set_meta("integration_seed",271828);Engine.set_meta("camp_expansion_preview",true)
	if "preview" in OS.get_cmdline_user_args():
		w=load("res://scenes/camp_expansion_preview.tscn").instantiate();root.add_child(w)
		while not w.started or w.volume_label==null:await process_frame
		s=w.item_service
		check(not w.persistent_world,"candidate preview disables all player save IO")
		check(w.demonstration_ids.size()==26,"preview places all twenty-six registered buildings")
		check(s.builds.validate(s.builds.serialize(),{}),"preview building records validate")
		check(s.camps.states.has("comparison-campfire"),"separate campfire is included")
		for kind in s.builds.definitions:
			check(w.demonstration_ids.any(func(id):return s.builds.states[id].kind==kind),"exhibition includes "+kind)
		check(s.inventory.count_item("carrot_seed")==6,"preview crop supplies")
		await frames(25)
		for id in w.demonstration_ids:
			check(s.builds.visuals[id].is_visible_in_tree(),"building is visible: "+s.builds.states[id].kind)
		check(s.camps.visuals["comparison-campfire"].is_visible_in_tree(),"campfire is visible")
		await capture("overview")
		w.environment_view.set_process(false);w.player.set_physics_process(false);s.set_process(false);s.animals.set_process(false)
		for demo_id in w.demonstration_ids:
			var row: Dictionary=s.builds.states[demo_id];var node: Node2D=s.builds.visuals[demo_id]
			if row.kind in s.expansion.KINDS:
				await near(demo_id)
				check(node.shape.shape.size==s.builds.footprint_rect(row).size,"candidate "+row.kind+" collider matches its individual base")
				check(node.perform_interaction("open",w.player) and s.expansion_ui.visible,"candidate "+row.kind+" opens through world interaction")
				await frames(8);await capture(row.kind+"-ui");s.expansion_ui.close_panel()
			if row.kind in ["wood_bed","straw_mat"]:
				await near(demo_id);s.body.energy=70
				check(s.sleep.start(demo_id).is_empty() and s.body.sleep_active(),row.kind+" still accepts sleep in candidate camp")
				s.sleep.interrupt();check(not s.body.sleep_active() and s.builds.states[demo_id].sleep_state=="PLACED",row.kind+" wakes with original lifecycle")
		w.item_ui.toggle_build();w.item_ui.craft_panel.select_recipe("build_advanced_smokehouse");await frames(8)
		check(w.item_ui.craft_panel.recipe_buttons.has("build_advanced_smokehouse"),"V panel contains candidate smokehouse from start")
		await capture("build-list");w.item_ui.close_panels()
		await finish("preview");return
func finish(suffix: String) -> void:
	w.persistent_world=false;w.free();await frames(2)
	check(files()==original,"all actual player save hashes unchanged")
	var failed := checks.filter(func(c):return not c.pass)
	var file := FileAccess.open(OUT+suffix+".json",FileAccess.WRITE);file.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"));file.close()
	print("CAMP EXPANSION V2: ",checks.size()," checks, ",failed.size()," failed")
	quit(0 if failed.is_empty() else 1)
