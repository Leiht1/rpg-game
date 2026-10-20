extends SceneTree
var w: Node2D
var checks: Array=[]
var obtained: Array=[]
const OUT="res://reports/merchant-v1/"
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func frames(count: int=4) -> void:
	for i in count:await process_frame
func files() -> Dictionary:
	var result = {}
	for path in DirAccess.get_files_at("user://"):
		if path.ends_with(".json"):result[path]=FileAccess.get_sha256("user://"+path)
	return result
func fund(s: Node) -> void:
	for key in ["gold_ingot","silver_ingot","copper_parts","wool"]:s.inventory.add(key,90)
	for key in ["roasted_fish","smoked_fish","vegetable_fish_soup"]:s.inventory.add(key,20)
func snap(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await frames(6)
	get_root().get_texture().get_image().save_png(OUT+name+".png")
func click_button(button: Button) -> void:
	await frames(12)
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new();motion.position=at;motion.global_position=at;Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new();event.position=at;event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;Input.parse_input_event(event)
		await frames(2)
func run() -> void:
	Engine.max_fps=60
	var before_files = files()
	Engine.remove_meta("merchant_preview")
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	var s=w.item_service;var m=s.merchant;var l=m.lights;var sim=w.environment_view.simulation
	sim.paused=true
	await frames()
	check(not Engine.has_meta("merchant_preview") and m.enabled,"formal merchant enabled without candidate flag")
	check(m.enabled and m.state.offers.size()==4,"candidate enabled and exactly four offers")
	check(m.valid(m.serialize()),"merchant snapshot validates")
	check(s.database.errors.is_empty(),"candidate definitions satisfy item database contract")
	check(m.rules.dialogue.size()==20,"twenty short dialogue lines")
	check(m.state.remaining==5760,"four game day migration interval")
	check(m.safe_point(Vector2(m.state.x,m.state.y)),"initial global point clear and reachable")
	var templates_ok = true
	for id in m.rules.products:
		for price in m.rules.products[id]:
			templates_ok=templates_ok and price.get("gold_ingot",0)>=2
			for key in price:templates_ok=templates_ok and not s.database.item(key).is_empty()
	check(templates_ok,"all twelve price templates require real gold and official materials")
	var positions: Array=[];var prices = {}
	for i in 8:
		var old = Vector2(m.state.x,m.state.y)
		check(m.migrate(),"migration commits "+str(i))
		check(Vector2(m.state.x,m.state.y).distance_to(old)>=512 and m.safe_point(Vector2(m.state.x,m.state.y)),"migration safely changes position "+str(i))
		positions.append([m.state.x,m.state.y]);prices[JSON.stringify(m.state.offers)]=true
	check(prices.size()>1,"price pools produce varied visits")
	var bounds = Rect2(Vector2(m.state.x,m.state.y),Vector2.ZERO)
	for p in positions:bounds=bounds.expand(Vector2(p[0],p[1]))
	check(bounds.size.x>w.generator.extent*.15 and bounds.size.y>w.generator.extent*.15,"global samples span map independently of player")
	var initial = m.serialize();m.interacting=true;m.state.remaining=0;m.advance(1)
	check(Vector2(m.state.x,m.state.y)==Vector2(initial.x,initial.y) and m.state.remaining==0,"migration deferred while interacting")
	m.interacting=false;m.advance(.01)
	check(m.state.remaining>5759 and Vector2(m.state.x,m.state.y)!=Vector2(initial.x,initial.y),"deferred migration occurs after interaction")
	check(w.get_tree().get_nodes_in_group("world_interactables").filter(func(node):return node.has_meta("interaction_action") and node.get_meta("interaction_action")=="talk").size()==1,"exactly one NPC actor after many migrations")
	w.player.position=Vector2(m.state.x,m.state.y)+Vector2(0,55);w.stream.update_target(w.player.position)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	await frames(10)
	check(is_equal_approx(m.actor.sprite.scale.y*m.actor.sprite.texture.get_height(),138),"merchant enlarged beyond protagonist")
	check(m.actor.backpack_glows.size()==2,"backpack has two blue glow emitters")
	await snap("merchant-scale-glow")
	var sayings = {}
	for i in 20:
		check(preload("res://scripts/world_interaction.gd").execute(w.stream,w.player,m.actor),"E interaction routes to talk "+str(i))
		sayings[m.ui.dialogue.text]=true;m.ui.close_panel()
	check(sayings.size()>1,"reopened dialogue changes lines")
	m.talk();check(w.player.input_blocked and m.ui.trade.visible and not m.ui.goods.visible,"simple dialogue modal and trade button")
	await frames(12)
	check(m.ui.panel.size.x<=440 and m.ui.panel.size.y<230,"single line dialogue uses compact content sized frame")
	await snap("dialogue-compact")
	await click_button(m.ui.trade)
	check(m.ui.goods.visible and m.ui.choices.size()==4,"real mouse trade click displays four rows")
	check(m.ui.choices.solar_flashlight.label.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,"prices vertically centered on product rows")
	if not m.ui.goods.visible:m.ui.show_trade()
	check(m.buy("solar_flashlight")=="身上的东西不够，带齐了再来吧","exact insufficient material notice")
	fund(s);s.item_obtained.connect(func(id,count):obtained.append([id,count]))
	# Full bag with affordable ingredients: no partial consumption or stock changes.
	var saved_slots=s.inventory.slots.duplicate(true)
	for i in range(8,40):
		if s.inventory.slots[i].is_empty():s.inventory.slots[i]={"item_id":"stone","count":99}
	var full=s.inventory.slots.duplicate(true)
	check(not m.buy("solar_flashlight").is_empty() and s.inventory.slots==full and m.state.offers.solar_flashlight.stock==1,"full bag purchase preserves materials and stock")
	s.inventory.slots=saved_slots
	var savepath: String=s.save_path
	w.persistent_world=true;s.save_path="user://merchant-intentionally-missing-dir/state.json"
	var failed_slots=s.inventory.slots.duplicate(true);var failed_state=m.serialize()
	check(m.buy("solar_flashlight")=="保存失败，交易已回滚","save failure reports rollback")
	check(s.inventory.slots==failed_slots and m.serialize()==failed_state and obtained.is_empty(),"save rollback restores stock inventory and emits no reward")
	var rng_before: int=m.rng.state
	check(not m.migrate() and m.serialize()==failed_state and m.rng.state==rng_before,"failed relocation preserves RNG and position")
	w.persistent_world=false;s.save_path=savepath
	for id in m.rules.products:
		var costs: Dictionary=m.price(id);var counts = {}
		for key in costs:counts[key]=s.inventory.count_item(key)
		await click_button(m.ui.choices[id].button)
		check(m.ui.selected==id,"real mouse selects "+id)
		await click_button(m.ui.purchase)
		check(m.ui.status.text=="交易完成","real mouse purchases "+id)
		var exact = true
		for key in costs:exact=exact and s.inventory.count_item(key)==counts[key]-costs[key]
		check(exact and s.inventory.count_item(id)==1 and m.state.offers[id].stock==0,"exact exchange and stock decrement "+id)
		check(not m.buy(id).is_empty(),"sold out blocks repeat "+id)
	check(obtained.size()==4,"exactly four existing item obtained signals")
	await click_button(m.ui.content.get_child(0).get_child(1))
	check(not m.interacting and not m.ui.visible and not w.player.input_blocked,"real mouse close restores gameplay input")
	var index = -1
	for i in 40:
		if s.inventory.slots[i].get("item_id")=="solar_flashlight":index=i
	var torch: Dictionary=s.inventory.slots[index]
	check(l.valid(torch.state) and torch.state.energy==100 and not torch.state.on,"flashlight has independent valid state")
	w.item_ui.open_item_menu(index,Vector2(600,300))
	check(w.item_ui.equip_button.visible and w.item_ui.use_button.text=="打开","bag menu equips and opens flashlight")
	w.item_ui.use_button.pressed.emit();check(torch.state.on,"right click toggle switches on")
	var drag := {"inventory":s.inventory,"slot":index,"item_id":"solar_flashlight","count":1,"snapshot":torch.duplicate(true)}
	l.evolve(torch.state,1,false,true,true,false)
	check(w.item_ui.valid_drag(drag),"passive battery discharge does not invalidate drag")
	var replacement=drag.snapshot.duplicate(true);replacement.instance_id="replacement"
	check(not preload("res://scripts/food_freshness.gd").matches(torch,replacement),"different flashlight instance still invalidates snapshot")
	w.item_ui.open_item_menu(index,Vector2(600,300));l.evolve(torch.state,1,false,true,true,false)
	await click_button(w.item_ui.use_button)
	check(not torch.state.on,"real mouse closes bag flashlight after passive discharge")
	w.item_ui.open_item_menu(index,Vector2(600,300));await click_button(w.item_ui.use_button)
	check(torch.state.on,"real mouse reopens bag flashlight")
	w.item_ui.open_item_menu(index,Vector2(600,300));check(w.item_ui.use_button.text=="关闭","context label follows switch state");w.item_ui.close_item_actions()
	w.item_ui.open_item_menu(index,Vector2(600,300));l.evolve(torch.state,1,false,true,true,false)
	await click_button(w.item_ui.equip_button)
	check(s.inventory.equipment.get("main_hand",{}).get("item_id")=="solar_flashlight","real mouse equips switched on flashlight after discharge")
	var equip_index: int=s.inventory.equipment_slots.find(s.inventory.equipment_slots.filter(func(row):return row.id=="main_hand")[0])+40
	w.item_ui.open_item_menu(equip_index,Vector2(600,300));check(w.item_ui.use_button.visible,"equipped slot retains switch action");w.item_ui.close_item_actions()
	await frames();check(w.item_ui.body_ui.lamp.visible,"equipped flashlight shows existing energy HUD")
	var equipped: Dictionary=s.inventory.equipment.main_hand
	equipped.state.on=false;await frames();check(not w.item_ui.body_ui.lamp.visible,"off flashlight has no energy HUD")
	equipped.state.on=true;await frames();check(w.item_ui.body_ui.lamp.visible,"on flashlight restores energy HUD")
	await frames(20);check(w.item_ui.body_ui.lamp.modulate.a>.95,"energy HUD finishes fade without per frame visibility resets")
	var sample=l.fresh();sample.energy=50;sample.on=true
	l.evolve(sample,48,false,true,true,false);check(is_equal_approx(sample.energy,40),"handheld consumes ten percent in 48 game minutes without charging")
	sample=l.fresh();sample.energy=50;l.evolve(sample,36,true,true,true,false);check(is_equal_approx(sample.energy,60),"clear daytime ground charges ten percent per 36 minutes")
	for test in [[false,true,true],[true,false,true],[true,true,false]]:
		sample=l.fresh();sample.energy=50;l.evolve(sample,36,test[0],test[1],test[2],false);check(sample.energy==50,"no charge unless grounded daylight dry "+str(test))
	sample=l.fresh();sample.energy=2;sample.on=true;l.evolve(sample,48,false,false,true,false);check(sample.energy==0 and not sample.on,"exhausted battery auto off, item remains")
	sample=l.fresh();sample.energy=50;sample.on=true;l.evolve(sample,0,false,true,true,true);check(not sample.on and sample.energy==50,"dawn closes switch without clearing energy")
	m.ui.close_panel();sim.minute=1300;sim.current_weather=0;sim.target_weather=0;sim.blend=Vector3(1,0,0)
	for direction in ["front","back","left","right"]:
		w.player.facing=direction;w.player.update_animation();l.render();await frames()
		if direction=="back" and DisplayServer.get_name()!="headless":
			w.player.set_physics_process(false)
			await frames(8)
			var lit=root.get_texture().get_image()
			var mask=l.player_mask.get_texture().get_image()
			var center: Vector2=w.get_viewport().get_canvas_transform()*w.player.global_position
			equipped.state.on=false;await frames(8)
			var dark=root.get_texture().get_image()
			var tested := 0;var difference := 0.0
			for y in range(int(center.y)-76,int(center.y)-45):
				for x in range(int(center.x)-18,int(center.x)+18):
					var interior := true
					for offset in [Vector2i.ZERO,Vector2i(-4,0),Vector2i(4,0),Vector2i(0,-4),Vector2i(0,4)]:
						if mask.get_pixelv(Vector2i(x,y)+offset).a<.95:interior=false
					if not interior:continue
					tested+=1
					var a=lit.get_pixel(x,y);var b=dark.get_pixel(x,y)
					difference=maxf(difference,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
			print("HAIR MASK pixels=",tested," max change=",difference)
			check(tested>50 and difference<.06,"GPU rear hair stays dark while beam passes behind player")
			var ground=Vector2i(center+Vector2(15,-180))
			check(lit.get_pixelv(ground).g-dark.get_pixelv(ground).g>.1,"GPU forward ground still illuminated")
			equipped.state.on=true;await frames(8)
			w.player.set_physics_process(true)
		check(torch.state.facing==direction and l.beams.size()==1 and l.beams[0].direction==l.DIRECTIONS[direction],"held cone follows "+direction)
		await snap("held-"+direction)
	check(l.toggle(equip_index) and not torch.state.on,"equipped switch closes")
	check(l.toggle(equip_index) and torch.state.on,"equipped switch opens")
	w.player.facing="right";l.render();torch.state.energy=62
	check(s.inventory.unequip(equip_index),"unequip preserves instance")
	index=-1
	for i in 40:
		if s.inventory.slots[i].get("item_id")=="solar_flashlight":index=i
	check(s.discard(index),"ordinary discard creates persistent flashlight")
	var entry: Dictionary={}
	for row in s.loose.values():
		if row.item_id=="solar_flashlight":entry=row
	check(not entry.is_empty() and entry.instance.state=={"energy":62,"on":true,"facing":"right"},"drop preserves energy switch and throw facing")
	await frames(30);l.render();check(l.beams.size()==1,"ground torch emits cone")
	check(not w.item_ui.body_ui.lamp.visible,"ground torch has no energy HUD")
	sim.minute=1301;m.state.last_time=1300;l.advance(48);check(entry.instance.state.energy<62,"ground on continues draining at night")
	await snap("ground-night")
	# Explicit real disk roundtrip through the full original snapshot loader.
	w.persistent_world=true;s.save_path="user://merchant-v1-test-only.json"
	check(s.save_state(),"atomic dedicated snapshot written")
	var saved=m.serialize();var saved_torch=entry.instance.state.duplicate(true)
	m.state.remaining=1;m.state.offers.solar_flashlight.template=0;entry.instance.state.energy=1
	s.load_state(s.save_path);check(s.writable and m.serialize()==saved,"reload restores position countdown templates stock and RNG")
	var restored: Dictionary=s.loose[entry.id]
	check(restored.instance.state==saved_torch,"disk reload restores loose flashlight direction switch energy")
	check(s.inventory.count_item("modern_outfit")==1 and s.inventory.count_item("frequency_blade")==1 and s.inventory.count_item("unknown_alloy")==1,"other three goods survive disk load")
	w.persistent_world=false;s.save_path=savepath
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://merchant-v1-test-only.json"))
	restored.instance.state.on=true;restored.instance.state.energy=50;sim.minute=299;m.state.last_time=299
	sim.minute=300;l.advance(0.1);check(not restored.instance.state.on and restored.instance.state.energy>=50,"actual dawn clock edge closes ground lamp and starts solar charge")
	var drop: Node2D
	for node in w.stream.drops:
		if node.get_meta("drop_id")==entry.id:drop=node
	check(s.pickup(drop),"ground torch pickup succeeds")
	var picked: Dictionary={}
	for row in s.inventory.slots:
		if row.get("item_id")=="solar_flashlight":picked=row
	check(picked.get("state")==restored.instance.state,"pickup preserves current live state")
	var corrupt=s.snapshot().duplicate(true)
	corrupt.merchant.remaining=-1
	check(not m.valid(corrupt.merchant),"invalid merchant countdown rejected")
	check(not l.valid({"energy":INF,"on":true,"facing":"front"}) and not l.valid({"energy":50,"on":true,"facing":"invalid"}),"invalid battery and direction rejected")
	check(files()==before_files,"player json files unchanged by isolated test")
	m.talk();m.ui.show_trade();await snap("trade")
	var file = FileAccess.open(OUT+"results.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"positions":positions,"pass":checks.filter(func(row):return row.pass).size(),"failed":checks.filter(func(row):return not row.pass).size()},"  "));file.close()
	print("MERCHANT CHECKS ",checks.size()," FAILED ",checks.filter(func(row):return not row.pass).size())
	w.queue_free();await frames(5);quit(1 if checks.any(func(row):return not row.pass) else 0)

