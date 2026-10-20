extends SceneTree
const OUT="res://reports/camp-formal-drag-v2/"
var checks: Array=[]
var w: Node
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=4) -> void:
	for i in n:await process_frame
func files() -> Dictionary:
	var result := {}
	for name_value in DirAccess.get_files_at("user://"):
		if name_value.ends_with(".json") or name_value.ends_with(".tmp"):result[name_value]=FileAccess.get_sha256("user://"+name_value)
	return result
func motion(at: Vector2,delta: Vector2=Vector2.ZERO,held: bool=false) -> void:
	var event := InputEventMouseMotion.new();event.position=at;event.global_position=at;event.relative=delta
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event);await frames()
func button(at: Vector2,pressed: bool) -> void:
	var event := InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
	Input.parse_input_event(event);await frames()
func drag(from: int,to: int,label: String) -> void:
	var ui: Control=w.item_ui
	var a: Vector2=ui.cells[from].get_global_rect().get_center()
	var b: Vector2=ui.cells[to].get_global_rect().get_center()
	await motion(a);await button(a,true)
	await motion(a+Vector2(18,0),Vector2(18,0),true)
	check(root.gui_is_dragging(),label+" native drag starts")
	var previews := root.find_children("InventoryDragPreview","PanelContainer",true,false)
	check(previews.size()==1,label+" one native preview")
	if previews.size()==1:
		var preview: Control=previews[0]
		await motion(b,b-a-Vector2(18,0),true)
		check(preview.global_position.distance_to(b)<2,label+" preview follows mouse")
		check(preview.z_index>ui.bag.z_index and preview.is_visible_in_tree(),label+" preview draws above bag")
		await frames(14);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+label+".png")
	await button(b,false)
	check(not root.gui_is_dragging(),label+" release ends drag")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var original := files()
	Engine.set_meta("integration_seed",271828);Engine.set_meta("camp_expansion_preview",false)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	var s: Node=w.item_service
	w.environment_view.set_process(false);w.environment_view.simulation.set_process(false);w.player.set_physics_process(false);s.set_process(false);s.animals.set_process(false)
	check(not w.persistent_world and not s.expansion.preview_enabled(),"ordinary behavior in isolated world without candidate flag")
	var provenance: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/camp_expansion/v2/provenance.json"))
	for file in provenance.files:
		check(FileAccess.get_sha256("res://"+file.runtime)==file.sha256 and FileAccess.get_sha256("res://"+file.source)==file.sha256,file.runtime+" byte-identical approved art")
		check(load("res://"+file.runtime) is Texture2D,file.runtime+" imports as runtime texture")
	var recipes: Array=s.camps.build_book.available()
	for kind in s.expansion.KINDS:
		check(recipes.any(func(row):return row.output_id==kind),kind+" visible from start without unlock")
		check(s.database.item(kind).icon.begins_with("res://assets/"),kind+" formal item icon")
		check(s.builds.definitions[kind].art.begins_with("res://assets/"),kind+" formal world art")
	check(s.builds.volume_profile("wood_chest").width==60,"ordinary entry enables compact chest")
	check(s.builds.volume_profile("wool_carpet").width==144,"ordinary entry enables expanded carpet")
	for kind in ["wood_fence","fence_gate","stone_wall","stone_gate","wood_bed","straw_mat"]:
		check(s.builds.volume_profile(kind).is_empty(),kind+" stable connection or sleeping geometry")
	for kind in ["lake_fish","roasted_fish","smoked_fish"]:
		var rotten := {"item_id":kind,"count":1,"spoilage":1.0}
		check(s.stack_texture(rotten,"icon").resource_path=="res://assets/camp_expansion/v2/rotten_"+kind+".png",kind+" whole rotten fish active without preview")
	check(s.database.item("smoked_fish").name=="熏制烤鱼","smoked fish explicit name")
	for i in 40:s.inventory.slots[i]={}
	s.inventory.slots[8]={"item_id":"wood","count":3};s.inventory.slots[0]={"item_id":"stone","count":2}
	w.item_ui.toggle_bag();await frames(20)
	await drag(8,9,"bag-drag")
	check(s.inventory.get_slot(8).is_empty() and s.inventory.get_slot(9).get("count",0)==3,"bag drag transfers exact stack")
	await drag(0,10,"hotbar-drag")
	check(s.inventory.get_slot(0).is_empty() and s.inventory.get_slot(10).get("item_id","")=="stone","hotbar to bag transfers stack")
	await drag(9,1,"bag-to-hotbar")
	check(s.inventory.get_slot(9).is_empty() and s.inventory.get_slot(1).get("count",0)==3,"bag to hotbar transfers stack")
	var before: Array=s.inventory.slots.duplicate(true)
	var a: Vector2=w.item_ui.cells[10].get_global_rect().get_center()
	await motion(a);await button(a,true);await motion(a+Vector2(20,0),Vector2(20,0),true)
	var esc := InputEventKey.new();esc.physical_keycode=KEY_ESCAPE;esc.keycode=KEY_ESCAPE;esc.pressed=true;Input.parse_input_event(esc);await frames()
	await button(a+Vector2(20,0),false)
	check(s.inventory.slots==before,"cancel drag preserves all inventory")
	check(w.item_ui.bag.visible,"drag does not close bag")
	w.free();await frames()
	check(files()==original,"actual player saves unchanged")
	var failed := checks.filter(func(row):return not row.pass)
	var output := FileAccess.open(OUT+"window.json",FileAccess.WRITE);output.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"));output.close()
	print("CAMP FORMAL DRAG V2: ",checks.size()," checks, ",failed.size()," failed")
	quit(0 if failed.is_empty() else 1)
