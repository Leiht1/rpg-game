extends SceneTree
const OUT="res://reports/planting-formal-v1/"
var checks=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok:push_error(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.set_meta("integration_seed",271828)
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
	var s=w.item_service;var p=w.player;var b=s.builds
	while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
	check(not Engine.get_meta("planting_preview",false) and s.camps.build_book.recipe("build_tilled_soil").default_unlocked,"formal startup exposes farming without preview switch")
	check(s.planting.art("soil").begins_with("res://assets/planting/v2/") and s.planting.art("carrot_0").begins_with("res://assets/planting/v3/"),"formal runtime uses approved soil and crop paths")
	check(s.craft_book.errors.is_empty() and s.camps.build_book.errors.is_empty(),"craft and building recipes validate")
	var seed_events=[];s.item_obtained.connect(func(id,count):seed_events.append([id,count]))
	for i in 40:s.inventory.slots[i]={}
	for i in range(8,40):s.inventory.slots[i]={"item_id":"stone","count":99}
	var entry={"id":"planting-dependency-drop","item_id":"stone","count":5,"x":p.position.x,"y":p.position.y,"mode":"pickup"}
	s.loose[entry.id]=entry.duplicate(true)
	var drop: Node2D=w.stream.create_item_drop(entry)
	check(not s.pickup(drop) and drop.get_meta("count")==5,"existing full-bag pickup keeps ground item")
	s.inventory.slots[8].count=97
	check(s.pickup(drop) and drop.get_meta("count")==3 and s.loose[entry.id].count==3,"existing partial pickup persists exact remainder")
	check(seed_events==[["stone",2]],"partial pickup reports actual received quantity")
	for i in 40:s.inventory.slots[i]={}
	p.action=""
	var at: Vector2=p.position
	var ore: Node2D=s.create_harvest("planting-dependency-ore",{"kind":"stone_outcrop","x":at.x+34,"y":at.y})
	s.inventory.equipment.main_hand=s.inventory.instance("stone_pickaxe")
	check(s.harvest_hit(ore,"mine") and s.resource_hits["planting-dependency-ore"]==1,"existing pickaxe mining still commits")
	check(s.inventory.equipment.main_hand.durability==99,"existing mining wear unchanged")
	s.inventory.equipment.main_hand=s.inventory.instance("simple_shovel")
	check(not s.harvest_hit(ore,"mine") and s.resource_hits["planting-dependency-ore"]==1,"shovel cannot mine ore")
	var buried: Node2D=s.create_harvest("planting-dependency-root",{"kind":"buried_root","x":at.x+30,"y":at.y+10})
	check(s.harvest_hit(buried,"dig") and s.resource_hits["planting-dependency-root"]==1,"existing shovel excavation still commits")
	check(s.inventory.equipment.main_hand.durability==99,"existing excavation wear unchanged")
	# Equipment refresh preserves a committed recovery but still cancels an invalid windup.
	p.action="mine";p.action_target=ore;p.action_committed=false;p.set_equipment(s.inventory)
	check(p.action.is_empty(),"wrong tool still cancels uncommitted mining")
	p.action="mine";p.action_target=ore;p.action_committed=true;p.set_equipment(s.inventory)
	check(p.action=="mine","committed recovery survives inventory refresh")
	p.cancel_action()
	var before: Array=s.inventory.slots.duplicate(true)
	var floor_row: Dictionary=b.candidate("wood_floor",at,false,true,0)
	check(not b.place(floor_row,before).is_empty() and s.inventory.slots==before,"existing invalid or insufficient-material build has no consumption")
	# Default game collection now grants the confirmed seed reward without a preview switch.
	var natural=Node2D.new();natural.position=p.position;w.object_root.add_child(natural)
	for key in {"drop_id":"planting-formal-natural","item_id":"wild_carrot","count":1,"natural":true}:natural.set_meta(key,{"drop_id":"planting-formal-natural","item_id":"wild_carrot","count":1,"natural":true}[key])
	var count: int=seed_events.size()
	check(s.pickup(natural) and seed_events.size()==count+2 and seed_events[count]==["wild_carrot",1] and seed_events[count+1][1]==2,"formal collection grants produce and seeds through unified feedback")
	w.persistent_world=false;s.dirty=false
	var failed=checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"dependencies.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("PLANTING DEPENDENCIES ",checks.size()," checks; ",failed," failures")
	w.queue_free();await process_frame;await process_frame;quit(0 if failed==0 else 1)
