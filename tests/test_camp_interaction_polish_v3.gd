extends SceneTree
const OUT="res://reports/camp-interaction-polish-v3/"
var w: Node
var s: Node
var checks: Array=[]
var notices: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func frames(n: int=5) -> void:
	for i in n:await process_frame
func near(kind: String) -> String:
	var id := "expansion-demo:"+kind;var row: Dictionary=s.builds.states[id]
	w.player.position=Vector2(row.x,row.y)+Vector2(65,35);w.player.camera.position=Vector2.ZERO;w.player.camera.position_smoothing_enabled=false;w.player.camera.reset_smoothing();await frames()
	return id
func capture(name_value: String) -> void:
	await frames(14);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+name_value+".png")
func clear_slots() -> void:
	for i in 40:s.inventory.slots[i]={}
	s.inventory.equipment={};s.inventory.hotbar_equipment={}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	w=load("res://scenes/camp_expansion_preview.tscn").instantiate();root.add_child(w)
	while not w.started or w.volume_label==null:await process_frame
	s=w.item_service;s.save_path=OUT+"isolated.json";s.set_process(false);s.animals.set_process(false);w.player.set_physics_process(false);w.environment_view.set_process(false);w.environment_view.simulation.set_process(false)
	s.notice.connect(func(message):notices.append(message))
	var ui: Control=s.expansion_ui
	var supply: String=await near("fuel_supply_box");clear_slots();s.inventory.slots[0]={"item_id":"wood","count":20}
	ui.open(supply);await frames()
	check(ui.panel.size==Vector2(420,220),"supply compact frame")
	check(ui.choices.get_child_count()==1 and ui.choices.get_child(0).text=="投入材料","supply main only has deposit action")
	check("0 / 99" in ui.stored.get_child(0).text,"supply displays total separately")
	var before: Array=s.inventory.slots.duplicate(true)
	ui.open_fuel_window();await frames();check(ui.fuel_window.visible and ui.fuel_cards.get_child_count()>1,"secondary fuel selector opens")
	check(ui.fuel_cards.get_child(0).icon!=null,"fuel selector uses real icon")
	check(s.inventory.slots==before,"opening selector consumes nothing")
	ui.fuel_window.hide();check(s.inventory.slots==before,"cancel selector consumes nothing");await create_timer(.2).timeout
	ui.open_fuel_window()
	var wood_card: Button
	for card in ui.fuel_cards.get_children():
		if card.get_meta("fuel_id")=="wood":wood_card=card
	wood_card.pressed.emit();check(ui.selected_fuel=="wood","material card selects wood")
	wood_card.pressed.emit();check(ui.selected_fuel.is_empty(),"selected material toggles off")
	wood_card.pressed.emit();await frames()
	await create_timer(.2).timeout
	var editor: LineEdit=ui.fuel_amount.get_line_edit();editor.grab_focus();await frames();editor.select_all()
	var digit := InputEventKey.new();digit.keycode=KEY_7;digit.physical_keycode=KEY_7;digit.unicode=55;digit.pressed=true
	ui.fuel_window.push_input(digit);await frames()
	check(editor.text=="7","secondary quantity accepts native keyboard input")
	ui.fuel_confirm.pressed.emit();await create_timer(.2).timeout;await frames()
	check(not ui.fuel_window.visible and s.builds.states[supply].expansion.fuel_items.wood==7,"secondary confirm deposits chosen quantity")
	check(s.inventory.count_item("wood")==13 and "7 / 99" in ui.stored.get_child(0).text,"inventory and material total update together")
	check(ui.stored.find_children("*","TextureRect",true,false).size()==1,"stored fuel has icon and text")
	before=s.inventory.slots.duplicate(true);var old: Dictionary=s.builds.states[supply].duplicate(true)
	check(not s.expansion.act(supply,"withdraw",-1,{},"wood",1).is_empty(),"backend rejects withdrawal")
	check(s.inventory.slots==before and s.builds.states[supply]==old,"withdraw rejection preserves stock and inventory")
	w.persistent_world=true;s.save_path=OUT+"missing/file.json"
	check(s.expansion.act(supply,"deposit",-1,{},"wood",2).begins_with("保存失败"),"deposit save failure reported")
	check(s.inventory.slots==before and s.builds.states[supply]==old,"failed deposit rolls back")
	w.persistent_world=false;s.save_path=OUT+"isolated.json"
	await capture("supply")
	ui.open_fuel_window();await capture("supply-selector");ui.close_panel()
	var repair: String=await near("precision_repair_bench");ui.open(repair);await frames();ui.close_panel()
	var compost: String=await near("compost_bin");clear_slots()
	for i in 40:s.inventory.slots[i]={"item_id":"plant_fiber","count":46}
	ui.open(compost);await frames(12)
	check(ui.panel.size==Vector2(420,232),"compost frame stays compact after wide repair UI")
	for button in ui.choices.get_children():check(button.size.x<=ui.scroll.size.x and button.get_global_rect().end.x<=ui.panel.get_global_rect().end.x,"compost button stays inside right edge")
	check(ui.scroll.get_v_scroll_bar().max_value>ui.scroll.size.y,"long compost list scrolls vertically")
	await capture("compost")
	for i in 40:s.inventory.slots[i]={"item_id":"smoked_fish","count":4,"spoilage":1.0}
	ui.fingerprint="";ui.refresh();await frames()
	check(ui.choices.get_child(0).size.x<=ui.scroll.size.x,"long rotten item name cannot expand scroll width")
	var point: Vector2=ui.scroll.get_global_rect().get_center();var wheel := InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;wheel.position=point;Input.parse_input_event(wheel);await frames()
	check(ui.scroll.scroll_vertical>0,"native wheel scrolls compost choices inside frame")
	ui.close_panel()
	var smoke: String=await near("advanced_smokehouse");ui.open(smoke);await frames()
	check(not ui.status.visible,"smokehouse has no description under name")
	check(ui.panel.size==Vector2(420,144),"smokehouse shrinks after description removal")
	check(ui.choices.get_child(0).text=="开始熏制：烤鱼 ×1、木材 ×1","smoking button information unchanged")
	await capture("smokehouse");ui.close_panel()
	var feed: String=await near("feed_trough");s.builds.states[feed].machine.feed={"plant_fiber":3};s.industry_ui.open(feed);await frames()
	check(s.industry_ui.feed_summary.visible,"trough shows material summary")
	var icons: Array=s.industry_ui.feed_summary.find_children("*","TextureRect",true,false)
	check(icons.size()==1 and icons[0].texture!=null and icons[0].custom_minimum_size==Vector2(24,24),"trough summary has small icon")
	check("3" in s.industry_ui.feed_summary.find_children("*","Label",true,false)[0].text,"trough summary retains name and quantity")
	await capture("trough");s.industry_ui.close_panel()
	for kind in ["feed_trough","compost_bin"]:check(s.camps.build_book.recipe("build_"+kind).category=="种植",kind+" in planting category")
	var plot: String=await near("tilled_soil");clear_slots();s.inventory.slots[0]={"item_id":"compost_fertilizer","count":2}
	var row: Dictionary=s.builds.states[plot];row.crop="carrot";row.growth_minutes=0.0;row.roots=false;row.erase("fertilized")
	var target: Node2D=s.builds.visuals[plot]
	w.player.position=target.position+Vector2(0,34);await frames()
	var e := InputEventAction.new();e.action="interact";e.pressed=true;Input.parse_input_event(e);await frames();check(w.player.action=="fertilize","E interaction starts fertilizer action")
	check(not ui.visible and not s.planting_ui.visible,"fertilizing opens no UI")
	check(s.inventory.count_item("compost_fertilizer")==2,"fertilizer not consumed before gesture contact")
	w.player.action_clock=.2;w.player.update_animation()
	check(str(w.player.animation_player.current_animation).ends_with("_pickup"),"fertilizing reuses bending hand gesture")
	w.player._physics_process(.2);await frames()
	check(s.builds.states[plot].get("fertilized",false) and s.inventory.count_item("compost_fertilizer")==1,"gesture applies fertilizer exactly once")
	check("肥料 -1" in notices,"successful fertilizer shows minus one")
	check(target.modulate.g>1,"crop briefly glows after successful save")
	w.player._physics_process(.2);check(s.inventory.count_item("compost_fertilizer")==1,"remaining animation cannot double consume")
	w.player.cancel_action();s.builds.states[plot].erase("fertilized")
	before=s.inventory.slots.duplicate(true);w.persistent_world=true;s.save_path=OUT+"missing/file.json";notices.clear()
	check(not s.planting.fertilize(plot,target),"fertilizer save failure rejected")
	check(s.inventory.slots==before and not s.builds.states[plot].get("fertilized",false) and "肥料 -1" not in notices,"failed fertilizer restores crop and inventory without success notice")
	w.persistent_world=false;s.save_path=OUT+"isolated.json"
	check(not w.persistent_world and s.save_path.begins_with(OUT),"isolated test cannot write player save")
	w.free();await frames()
	var failed := checks.filter(func(c):return not c.pass)
	FileAccess.open(OUT+"window.json",FileAccess.WRITE).store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"))
	print("CAMP INTERACTION POLISH: ",checks.size()," checks, ",failed.size()," failed");quit(0 if failed.is_empty() else 1)
