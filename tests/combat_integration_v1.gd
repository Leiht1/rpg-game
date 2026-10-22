extends Node
class TestWorld extends "res://scripts/world.gd":
	func load_world_identity(_path: String=WORLD_ID_PATH) -> void:
		persistent_world=false;world_seed=271828;map_cells=1536;world_id="combat-v1-isolated"
	func parse_arguments() -> void:pass
var checks:=0
func check(ok: bool, text: String) -> void:
	if not ok:push_error("COMBAT FAIL "+text);get_tree().quit(1)
	assert(ok,text);checks+=1;print("PASS ",text)
func _ready() -> void:run.call_deferred()
func run() -> void:
	var world:=TestWorld.new();add_child(world)
	for i in 1800:
		await get_tree().process_frame
		if world.started:break
	check(world.started,"formal world startup")
	world.set_process(false);world.player.set_physics_process(false);world.environment_view.set_process(false)
	var service=world.item_service;service.set_process(false)
	var combat=service.combat;var inv=service.inventory
	if "--combat-restore" in OS.get_cmdline_user_args():
		var file: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/.tmp/combat-v1/roundtrip.json"))
		service.load_state("",false,file)
		check(service.writable and combat.personal.phase=="dying","new process restores death phase")
		check(combat.state.relics.size()==1 and inv.count_item("wood")==0,"new process no duplicate transfer")
		combat.advance(3.1,false);combat.advance(1.1,false)
		check(service.body.health==100 and combat.state.relics.size()==1,"new process respawns once")
		print("COMBAT_CROSS_PROCESS_PASS ",checks);get_tree().quit();return
	combat.personal.phase="alive";world.player.input_blocked=false
	check(service.database.errors.is_empty(),"item definitions")
	check(service.craft_book.errors.is_empty(),"craft recipes")
	check(service.combat_view.portal.scale==Vector2.ONE*2.0,"portal is twice original size")
	check(service.builds.reason(service.builds.candidate("wood_chest",combat.spawn_point(),false,false,0))=="请保留传送门入口","building cannot obstruct portal entry")
	check(service.builds.reason(service.builds.candidate("wood_floor",combat.spawn_point(),false,false,0))!="请保留传送门入口","portal reservation allows paving layer")
	var animals_before: Dictionary=service.animals.serialize().duplicate(true)
	combat.state.boars={};combat.state.population_initialized=false;combat.advance_boars(.01)
	check(combat.state.boars.size()>0 and combat.state.boars.size()<=int(combat.rules.boar.population),"bounded natural boar population")
	var identities: Array=combat.state.boars.keys();combat.advance_boars(.01)
	check(combat.state.boars.keys()==identities,"population does not duplicate on subsequent ticks")
	for row in combat.state.boars.values():
		var home:=Vector2(row.home_x,row.home_y);var habitat: Dictionary=service.ecology(home)
		check(home.distance_to(combat.spawn_point())>=float(combat.rules.boar.safe_radius) and maxf(habitat.forest,habitat.rocky)>=.5,"natural boar habitat and spawn clearance")
	check(service.animals.serialize()==animals_before,"boars do not alter chickens or sheep")
	var fresh=preload("res://scripts/food_freshness.gd")
	var raw: Dictionary={"item_id":"boar_meat","count":1,"spoilage":0.0};var chilled: Dictionary=raw.duplicate(true)
	fresh.advance(service.database,raw,1440,false);fresh.advance(service.database,chilled,1440,true)
	check(raw.spoilage==1.0 and absf(chilled.spoilage-1.0/7)<.00001,"raw pork spoils and refrigerator preserves")
	check(service.stack_texture(raw,"icon").resource_path.ends_with("boar_meat_rotten.png"),"own rotten pork art")
	for item in ["cured_pork","smoked_meatballs"]:
		var value: Dictionary={"item_id":item,"count":1,"spoilage":0.0};fresh.advance(service.database,value,1440)
		check(absf(value.spoilage-1.0/30)<.00001,"smoked food preservation "+item)
	for direction in ["front","back","left","right"]:
		for item in ["unarmed","wood_club","tusk_club"]:
			inv.equipment={} if item=="unarmed" else {"main_hand":inv.instance(item)}
			combat.personal.attack={"weapon":combat.rules.weapons[item],"elapsed":combat.rules.weapons[item].windup,"direction":{"x":1,"y":0},"targets":{}}
			world.player.facing=direction;world.player.combat_render_state={};world.player.update_animation()
			var view: String="side" if direction in ["left","right"] else direction
			check(str(world.player.animation_player.current_animation)=="combat/"+view+"_"+str(combat.rules.weapons[item].animation),"native attack rig "+direction+" "+item)
			if direction=="front":check(not world.player.character.get_node("Visual/Pelvis/ArmR").show_behind_parent and world.player.held_tool.front_free_hand.visible,"front hands connected and visible "+item)
	combat.personal.attack={};inv.equipment={};world.player.facing="right";world.player.combat_render_state={}
	var at: Vector2=world.player.position+Vector2(38,0)
	combat.state.boars={"fixture":{"x":at.x,"y":at.y,"home_x":at.x,"home_y":at.y,"health":4.0,"mode":"patrol","clock":0.0,"hit":0.0,"generation":0}}
	inv.equipment={};service.body.stamina=100
	check(combat.attack(Vector2.RIGHT).is_empty(),"unarmed attack begins")
	combat.advance(.17,false);check(combat.state.boars.fixture.health==4,"no damage before active time")
	combat.advance(.02,false);check(combat.state.boars.fixture.health==0,"active frame hits boar")
	var drop_size: int=service.loose.size()
	combat.advance(.02,false);check(service.loose.size()==drop_size and drop_size==2,"one boar drop per identity")
	combat.advance(.6,false)
	combat.state.boars.fixture.health=45;combat.state.boars.fixture.hit=0;combat.state.boars.fixture.mode="attack";combat.state.boars.fixture.clock=.37;combat.state.boars.fixture.struck=false
	service.body.health=100;combat.advance_boars(.02)
	check(service.body.health==88,"boar uses shared damage")
	service.body.health=1;service.body.advance(.1,.01,false,false)
	check(not service.body.down,"one health can act")
	for i in 40:inv.slots[i]={}
	inv.add("wood",9);inv.add("plaster",2);inv.add("boar_tusk",2)
	var held: Dictionary=inv.instance("wood_club");inv.equipment.main_hand=held
	check(combat.attack(Vector2.RIGHT).is_empty(),"weapon attack starts")
	check(not combat.attack(Vector2.RIGHT).is_empty(),"repeat attack rejected")
	combat.advance(.8,false);check(combat.personal.attack.is_empty(),"recovery finishes")
	inv.equipment.main_hand=inv.instance("stone_axe")
	check(not combat.attack(Vector2.RIGHT).is_empty(),"tool attack rejected")
	inv.equipment.main_hand=held
	service.body.health=10;service.body.hunger=51;service.body.energy=62;service.body.stamina=67
	check(combat.damage(12,world.player.position+Vector2.LEFT),"lethal damage accepted")
	check(combat.state.relics.size()==1 and combat.personal.phase=="dying","one relic and death")
	check(not combat.damage(12,Vector2.ZERO),"duplicate death damage ignored")
	check(inv.count_item("wood")==0 and inv.count_item("plaster")==2 and inv.count_item("boar_tusk")==2,"configuration retention")
	check(inv.equipment.main_hand==held,"same weapon instance retained")
	var id: String=combat.state.relics.keys()[0];var relic: Dictionary=combat.state.relics[id]
	check(relic.contents[0].count==9,"exact resource transfer")
	var saved: Dictionary=service.snapshot().duplicate(true)
	DirAccess.make_dir_recursive_absolute("res://reports/.tmp/combat-v1")
	var roundtrip:=FileAccess.open("res://reports/.tmp/combat-v1/roundtrip.json",FileAccess.WRITE);roundtrip.store_string(JSON.stringify(saved));roundtrip.close()
	check(combat.valid(saved.combat_world,saved.combat_personal),"combat save validates")
	if DisplayServer.get_name()!="headless":
		combat.advance(1,false)
		await get_tree().process_frame
		world.player.update_animation()
		await get_tree().create_timer(.15).timeout
		get_viewport().get_texture().get_image().save_png("res://reports/.tmp/combat-v1/death.png")
	combat.advance(3.1,false);check(combat.personal.phase=="entering" and service.body.health==100,"portal respawn")
	check(service.body.hunger==51 and service.body.energy==62 and service.body.stamina==67,"other attributes unchanged")
	combat.advance(1.1,false);check(combat.personal.phase=="alive","entry unlocks")
	for i in 2:await get_tree().process_frame
	check(service.combat_view.relics.has(id),"relic installed in loaded chunk")
	var original_at:=Vector2(relic.x,relic.y)
	var offset: float=world.Gen.CHUNK_PX*(world.stream.keep_radius+4)
	var remote_at:=original_at+Vector2(offset if original_at.x+offset<world.generator.extent-100 else -offset,0)
	world.stream.update_target(remote_at)
	for i in 2:await get_tree().process_frame
	check(not service.combat_view.relics.has(id) and combat.state.relics[id].contents[0].count==9,"chunk unload preserves relic state")
	world.stream.update_target(original_at)
	for i in 1200:
		await get_tree().process_frame
		if world.stream.viewport_ready(original_at,Vector2(640,360)):break
	for i in 2:await get_tree().process_frame
	check(service.combat_view.relics.has(id) and combat.state.relics.size()==1 and combat.state.relics[id].contents[0].count==9,"chunk reload reinstalls one same relic")
	if DisplayServer.get_name()!="headless":
		world.player.update_animation();world.item_ui.bag.show();service.body.health=80
		await get_tree().create_timer(.1).timeout
		service.body.health=70
		await get_tree().create_timer(.15).timeout
		get_viewport().get_texture().get_image().save_png("res://reports/.tmp/combat-v1/hit-over-bag.png")
		world.item_ui.bag.hide()
	world.player.position=Vector2(relic.x,relic.y)
	service.combat_view.open_relic(id)
	check(service.combat_view.relic_list.get_child_count()==1,"relic UI displays authoritative content")
	check(combat.claim(id,0,relic.contents[0].duplicate(true)).is_empty(),"claim relic")
	for i in 2:await get_tree().process_frame
	check(service.combat_view.relic_list.get_child_count()==0,"relic UI refreshes after authoritative claim")
	service.combat_view.relic_panel.hide()
	check(inv.count_item("wood")==9 and relic.contents.is_empty(),"claim conserves resources")
	check(not combat.claim(id,0,{"item_id":"wood","count":9}).is_empty(),"duplicate claim rejected")
	service.body.health=20
	for i in 40:
		if inv.slots[i].get("item_id")=="plaster":check(inv.use_slot(i),"medical use");break
	check(service.body.health==35 and inv.count_item("plaster")==1,"plaster heal and consume")
	check(service.database.item("boar_meat").usable==false,"raw pork inedible")
	check(not service.expansion.rules.smoking_recipes.has("carrot_pork"),"stir fry never smokeable")
	var old_world: Dictionary=combat.state.duplicate(true)
	var before: Dictionary=service.snapshot().duplicate(true)
	world.persistent_world=true;service.save_path="res://reports/.tmp/combat-v1/missing-directory/fail.json"
	check(not combat.damage(1000,world.player.position+Vector2.LEFT),"failed death commit rejected")
	check(inv.slots==before.slots and combat.state==old_world and service.body.health==35,"failed death rolls everything back")
	world.persistent_world=false
	if DisplayServer.get_name()!="headless":
		combat.personal.phase="alive";combat.personal.attack={};service.body.health=80;service.body.down=false;service.guide_stage=2
		world.item_ui.message_time=0.0;service.combat_view.hit_clock=0
		for node in world.player.get_children():
			if node.get_script()==preload("res://scripts/combat_hit_overlay.gd"):node.remaining=0;node.previous_health=80
		world.player.position=service.combat.spawn_point()+Vector2(-110,70)
		combat.state.boars.fixture.x=service.combat.spawn_point().x+85;combat.state.boars.fixture.y=service.combat.spawn_point().y+55;combat.state.boars.fixture.hit=0;combat.state.boars.fixture.mode="patrol"
		await get_tree().process_frame;world.player.update_animation()
		await get_tree().create_timer(.25).timeout
		get_viewport().get_texture().get_image().save_png("res://reports/.tmp/combat-v1/portal-boar-v2.png")
	service.load_state("",false,saved)
	check(service.writable and combat.personal.phase=="dying" and combat.state.relics.size()==1,"death snapshot restores")
	print("COMBAT_INTEGRATION_PASS ",checks)
	get_tree().quit()
