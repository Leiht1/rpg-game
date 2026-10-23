extends SceneTree
var failed := false
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failed=true
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	w.set_process(false);w.player.set_physics_process(false);w.item_service.set_process(false);w.environment_view.set_process(false)
	var s=w.item_service;var p=w.player
	s.combat_view.set_process(false)
	while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
	var at: Vector2=p.position+Vector2(60,0)
	var row: Dictionary=s.builds.candidate("camp_torch",at,false,true,0)
	s.builds.states["test-torch"]=row
	var node=load("res://scripts/camp_building.gd").new();node.manager=s.builds;node.building_id="test-torch";node.position=at
	s.builds.visuals["test-torch"]=node;w.object_root.add_child(node)
	await physics_frame;await process_frame
	check(not s.camps.fuel_lit("test-torch") and row.fuel==0,"new torch starts empty")
	check(s.camps.target_at(at)=="test-torch","drag targets building torch")
	s.inventory.slots[0]={"item_id":"wood","count":10}
	var stack: Dictionary=s.inventory.slots[0].duplicate(true)
	check(s.camps.feed_check("test-torch",0,stack).is_empty(),"torch accepts campfire fuel reach checks")
	check(not s.camps.feed("test-torch",0,stack,0).is_empty() and row.fuel==0,"zero amount rejected")
	check(s.camps.feed("test-torch",0,stack,2).is_empty(),"shared feed transaction")
	var fuel: float=2*float(s.camps.rules.fuel_items.wood)
	check(row.fuel==fuel and s.inventory.slots[0].count==8 and s.camps.fuel_lit("test-torch"),"fuel inventory and ignition commit together")
	check(not s.camps.feed("test-torch",0,stack,1).is_empty(),"stale inventory rejected")
	check(s.builds.protected_reason("test-torch")=="火把中还有燃料","fuel blocks demolition")
	s.camps.advance(1,1,1)
	check(is_equal_approx(row.fuel,fuel-s.camps.burn_multiplier(1,1)),"shared storm burn multiplier")
	var saved: Dictionary=s.builds.serialize()
	check(s.builds.validate(saved,{}),"torch fuel snapshot validates")
	check(saved.objects["test-torch"].fuel==row.fuel and saved.objects["test-torch"].lit,"fuel survives serialization")
	var bad: Dictionary=saved.duplicate(true);bad.objects["test-torch"].fuel=-1
	check(not s.builds.validate(bad,{}),"negative fuel rejected")
	bad=saved.duplicate(true);bad.objects["test-torch"].fuel=s.camps.rules.max_fuel+1
	check(not s.builds.validate(bad,{}),"over capacity rejected")
	bad=saved.duplicate(true);bad.objects["test-torch"].erase("fuel");bad.objects["test-torch"].erase("lit")
	check(s.builds.validate(bad,{}),"old torch without fuel loads empty")
	var old_path: String=s.save_path;s.save_path="user://missing-torch-test-folder/no-save.json";w.persistent_world=true
	stack=s.inventory.slots[0].duplicate(true);var before: float=row.fuel
	check(not s.camps.feed("test-torch",0,stack,1).is_empty(),"save failure reported")
	check(row.fuel==before and s.inventory.slots[0]==stack,"failed save rolls back fuel and inventory")
	w.persistent_world=false;s.save_path=old_path
	s.camps.advance(100000)
	check(row.fuel==0 and not s.camps.fuel_lit("test-torch"),"fuel exhaustion extinguishes torch")
	node._process(0)
	check(node.torch_flame.material.get_shader_parameter("lit")==false and node.fuel_bar.value==0,"flame and bar follow empty state")
	s.inventory.slots[0]={"item_id":"wood","count":10};stack=s.inventory.slots[0].duplicate(true)
	check(s.camps.feed("test-torch",0,stack,1).is_empty(),"refuel relights")
	p.action="";s.inventory.equipment={};s.combat.personal.attack={}
	stack=s.inventory.slots[0].duplicate(true);before=row.fuel
	check(p.camp_throw.start(p,"test-torch",0,stack,2).is_empty(),"original throw starts for torch")
	p.camp_throw.advance(.69)
	check(row.fuel==before and s.inventory.slots[0]==stack,"throw waits for impact")
	p.camp_throw.render();p.camp_throw.advance(.02)
	check(p.camp_throw.committed and row.fuel==before+2*float(s.camps.rules.fuel_items.wood),"throw impact commits requested quantity")
	p.camp_throw.advance(.3)
	check(p.action.is_empty(),"throw finishes normally")
	var disk: String="res://reports/.tmp/torch-v6-snapshot.json"
	var file=FileAccess.open(disk,FileAccess.WRITE);file.store_string(JSON.stringify(s.builds.serialize()));file.close()
	var restored: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(disk))
	check(s.builds.validate(restored,{}) and restored.objects["test-torch"].fuel==row.fuel,"JSON disk roundtrip preserves torch fuel")
	s.builds.states=restored.objects;row=s.builds.states["test-torch"]
	s.inventory.slots[1]={"item_id":"stone","count":1}
	check(not s.camps.feed_check("test-torch",1,s.inventory.slots[1]).is_empty(),"non fuel rejected")
	var player_at: Vector2=p.position;p.position+=Vector2(1000,0)
	check(not s.camps.feed_check("test-torch",0,s.inventory.slots[0]).is_empty(),"distant fuel rejected")
	p.position=player_at
	var book=load("res://scripts/craft_book.gd").new(s.database)
	var recipe: Dictionary=book.recipe("combat_wood_club")
	check(recipe.materials.wood==10 and recipe.materials.plant_fiber==5 and recipe.materials.size()==2 and recipe.conditions.is_empty(),"wood club field materials")
	check(book.categories().has("武器") and book.available("武器").any(func(r):return r.output_id=="wood_club"),"field weapons category exposes wood club")
	check(not book.available("武器").any(func(r):return r.output_id=="tusk_club"),"tusk club remains workbench only")
	s.inventory.equipment={};p.facing="back";p.combat_render_state={}
	for t in [.18,.22,.26]:
		s.combat.personal.attack={"weapon":s.combat.rules.weapons.unarmed,"elapsed":t,"direction":{"x":0,"y":-1},"targets":{}}
		p.update_animation()
		var arm: Node2D=p.character.get_node("Visual/Pelvis/ArmR")
		var palm: Vector2=arm.to_global(Vector2(0,18.25))-arm.global_position
		print("POSE ",p.animation_player.current_animation," ",arm.rotation," ",palm)
		check(palm.y<0 and absf(palm.x)<absf(palm.y)*.1,"back fist strikes forward "+str(t))
		if t==.18:
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/.tmp/torch-v6-back-hit.png")
	s.combat.personal.attack={};p.update_animation()
	check(is_equal_approx(p.character.get_node("Visual/Pelvis/ArmR").scale.y,1),"attack ends restoring arm scale")
	await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/.tmp/torch-v6-window.png")
	print("CHECKS ",checks," FAILED ",failed)
	w.queue_free();await process_frame;quit(1 if failed else 0)
