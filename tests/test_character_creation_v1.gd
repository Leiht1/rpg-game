extends SceneTree
const OUT="res://reports/character-creation-v1/"
var checks: Array=[]
var c: Node
var before: Dictionary={}
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks.append({"pass":ok,"name":label})
	if not ok:push_error(label)
func frames(n: int=4):
	for i in n:await process_frame
func originals() -> Dictionary:
	var result={}
	for f in DirAccess.get_files_at("user://"):
		if f.ends_with(".json"):result[f]=FileAccess.get_sha256("user://"+f)
	return result
func snap(name: String):
	if DisplayServer.get_name()=="headless":return
	await frames(5);root.get_texture().get_image().save_png(OUT+name+".png")
func click(button: Button):
	await frames(12)
	var at=button.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;Input.parse_input_event(motion)
	for state in [true,false]:
		var e=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=state;Input.parse_input_event(e);await frames(2)
func run():
	Engine.max_fps=60;before=originals()
	var path=OUT+"isolated-save.json"
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	c=load("res://scripts/character_creation.gd").new();c.save_path=path;root.add_child(c);await frames()
	check(c.world==null and not FileAccess.file_exists(path),"creation UI before world or save exists")
	check(c.panel.get_global_rect().end.x<1280 and c.panel.get_global_rect().end.y<720,"compact default 1280x720 UI fits")
	for sex in [0,1]:
		c.select_gender(sex);check(c.hair_ids.size()==4,"four hairstyles gender "+str(sex))
		for id in c.hair_ids:
			c.look.hair_id=id
			for facing in ["front","back","right","left"]:
				c.preview_facing=facing;c.refresh_preview()
				check(c.preview.get_node("Visual/Pelvis/Head/Sprite").texture!=null,"hair head "+id+" "+facing)
	for id in c.Catalog.rules().skin:
		c.look.skin_id=id;c.refresh_preview()
		check(c.renderer.materials.head.get_shader_parameter("skin_color")==Color(c.Catalog.rules().skin[id].color),"skin shader choice "+id)
	c.select_gender(1);c.look.hair_id="female_twintail";c.look.skin_id="skin_5";c.preview_facing="front";c.refresh_preview();await snap("creation-ui")
	var invalid=c.look.duplicate();invalid.hair_id="male_curly";check(not c.Catalog.valid(invalid),"cross gender invalid appearance rejected")
	# Exercise initial-save rollback using a file as the would-be parent directory.
	var blocker=FileAccess.open(OUT+"blocker",FileAccess.WRITE);blocker.store_string("test");blocker.close()
	c.save_path=OUT+"blocker/state.json"
	await c.begin_creation()
	check(c.world==null and not c.busy and not c.enter.disabled and c.look.hair_id=="female_twintail","first save failure restores creation choices and retry")
	check(not FileAccess.file_exists(c.save_path),"failed first save has no committed world")
	c.save_path=path
	await click(c.enter)
	var timeout=0
	while c.busy and timeout<5000:timeout+=1;await process_frame
	check(c.world!=null and not c.screen.visible and not c.busy,"real Enter World button creates playable world")
	if c.world==null:finish();return
	var w=c.world;var s=w.item_service;var p=w.player
	w.environment_view.simulation.paused=true
	check(w.map_cells==1536 and w.generator.VERSION==load("res://scripts/world_generator.gd").VERSION,"original full continent generator")
	check(w.safe_entry(),"safe actual-land spawn after original builds generation")
	check(p.character_look==c.look,"selected look transferred before first visible frame")
	check(s.inventory.slots[8].get("item_id")=="modern_outfit" and s.inventory.equipment.get("outfit",{}).is_empty(),"one outfit in bag, not auto equipped")
	var granted=0
	for row in s.inventory.slots:granted+=row.get("count",0)
	check(granted==1,"no unrelated debug items granted")
	check(c.valid_session(s.snapshot()),"single atomic world and per-player appearance record validates")
	var slot=s.inventory.slots[8].duplicate(true)
	check(s.inventory.equip(8),"original inventory equips candidate outfit")
	p.update_animation();check(s.inventory.equipment.outfit.instance_id==slot.instance_id,"same unique clothing instance preserved")
	for facing in ["front","back","right","left"]:
		p.facing=facing;p.action="";p.moving=false;p.update_animation()
		check(p.character.get_node("Visual/Pelvis/Torso").texture==p.look_renderer.tex("outfit/"+("side" if facing in ["right","left"] else facing)+"_torso.png"),"torso replacement "+facing)
		for name in ["Visual/ArmLBehind","Visual/Pelvis/ArmR/Sprite","Visual/LegL/Sprite","Visual/LegR/Sprite"]:check(p.character.get_node(name).texture!=null,"limb "+facing+" "+name)
	for build in [-1.0,0.0,1.0]:
		load("res://scripts/body_shape.gd").apply(p.character,build)
		check(p.character.get_node("Visual/Pelvis/Torso").scale.y==.25,"outfit body shape keeps height "+str(build))
	# Sample each existing clip at three phases without altering original tracks.
	var held=p.held_tool
	s.inventory.add("stone_axe",1)
	for i in 40:
		if s.inventory.slots[i].get("item_id")=="stone_axe":s.inventory.equip(i);break
	for clip in p.animation_player.get_animation_list():
		for phase in [0.0,.4,.8]:
			held.release_pose();p.animation_player.play(clip);p.animation_player.seek(p.animation_player.get_animation(clip).length*phase,true)
			var facing="back" if "back" in str(clip) else "right" if "side" in str(clip) else "front"
			p.look_renderer.apply(p.character,p.character_look,s.inventory,facing);held.apply(p.character,s.inventory,facing,"chop" if "chop" in str(clip) else "mine" if "mine" in str(clip) else "")
			check(p.character.get_node("Visual/Pelvis/ArmR/Grip").global_position.is_finite(),"native clip grip finite "+str(clip)+" "+str(phase))
	p.action="";p.facing="front";p.moving=false;p.update_animation()
	check(p.character_look==c.look,"outfit and actions preserve appearance IDs")
	w.item_ui.update_portrait(0)
	check(w.item_ui.preview_actor.get_node("Visual/Pelvis/Head/Sprite").texture==w.item_ui.portrait_look.tex("heads/front.png"),"bag uses same real appearance renderer")
	w.item_ui.toggle_bag();await snap("outfit-bag")
	w.item_ui.toggle_bag();p.facing="front";p.update_animation();await snap("outfit-world")
	# Native movement path, original streamed geometry/collision and run rules.
	p.automated=true;p.input_override=Vector2.RIGHT;p.run_override=false
	var start=p.position
	for i in 15:await physics_frame
	check(p.position.distance_to(start)>1,"world character actually moves")
	p.run_override=true
	for i in 10:await physics_frame
	check(p.running,"original run animation and movement path")
	p.input_override=Vector2.ZERO;p.run_override=false
	# Atomic clothing change rollback on disk failure.
	var original_path=s.save_path;s.save_path=OUT+"blocker/failed.json"
	check(not s.inventory.unequip(42) and s.inventory.equipment.outfit.instance_id==slot.instance_id,"unequip save failure rolls back unique equipped instance")
	s.save_path=original_path
	check(s.inventory.unequip(42),"original unequip restores default body parts")
	p.update_animation();check(p.character.get_node("Visual/Pelvis/Torso").texture.resource_path.begins_with("res://assets/hero/cartoon/art/"),"default torso restored by native animation")
	# Use actual bag item-menu button to re-equip.
	var outfit_index=-1
	for i in 40:
		if s.inventory.slots[i].get("item_id")=="modern_outfit":outfit_index=i
	w.item_ui.toggle_bag();w.item_ui.open_item_menu(outfit_index,Vector2(650,320));await click(w.item_ui.equip_button)
	check(s.inventory.equipment.get("outfit",{}).get("instance_id")==slot.instance_id,"real bag menu equip button")
	w.item_ui.close_item_actions();w.item_ui.toggle_bag()
	check(s.save_state(),"world appearance inventory position atomic save")
	var snapshot=s.snapshot()
	check(snapshot.character_session.characters[snapshot.player_state_owner].test_outfit_granted,"one-time grant stored")
	var seed=w.world_seed;var pos=p.position
	w.persistent_world=false;w.queue_free();c.world=null;await frames(5)
	check(await c.open_world(snapshot.character_session,false),"restart restores same isolated snapshot")
	w=c.world;s=w.item_service;p=w.player
	check(w.world_seed==seed and p.position.distance_to(pos)<.1,"same seed and exact saved exit position restored")
	check(p.character_look==c.look and s.inventory.equipment.outfit.instance_id==slot.instance_id,"outfit and selected appearance restored")
	check(c.valid_session(s.snapshot()),"loaded character world ownership validates")
	var count=0
	for row in s.inventory.slots+s.inventory.equipment.values():
		if row.get("item_id")=="modern_outfit":count+=row.count
	check(count==1,"re-entry does not grant clothing again")
	check(originals()==before,"all original player JSON hashes unchanged")
	finish()
func finish():
	var failed=checks.filter(func(row):return not row.pass)
	var f=FileAccess.open(OUT+"checks.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failed":failed.size(),"total":checks.size()},"\t"));f.close()
	print("CHARACTER CHECKS ",checks.size()," FAILED ",failed.size())
	quit(0 if failed.is_empty() else 1)
