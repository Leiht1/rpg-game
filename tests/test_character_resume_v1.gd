extends SceneTree
const OUT="res://reports/character-creation-v1/"
var checks: Array=[]
var c: Node
func _initialize():call_deferred("run")
func check(ok: bool,text_value: String):
	checks.append({"pass":ok,"name":text_value});if not ok:push_error(text_value)
func frames(n: int=4):
	for i in n:await process_frame
func run():
	Engine.max_fps=60
	c=load("res://scripts/character_creation.gd").new();c.save_path=OUT+"isolated-save.json";root.add_child(c)
	while c.busy:await process_frame
	var w=c.world;var s=w.item_service;var p=w.player
	w.environment_view.set_process(false);w.environment_view.simulation.paused=true
	p.set_physics_process(false)
	check(w!=null and not c.screen.visible,"independent process directly resumes without creation UI")
	var raw=JSON.parse_string(FileAccess.get_file_as_string(c.save_path));var active=raw.character_session.characters[raw.player_state_owner]
	check(w.world_seed==raw.seed and p.position==Vector2(raw.player_position.x,raw.player_position.y),"fresh process restores recorded seed and last position")
	check(p.character_look==active.appearance,"fresh process restores all appearance IDs")
	var consumed="--consumed" in OS.get_cmdline_user_args()
	if consumed:
		var count=0
		for row in s.inventory.slots+s.inventory.equipment.values():
			if row.get("item_id")=="modern_outfit":count+=row.count
		check(count==0 and active.test_outfit_granted,"destroyed clothing stays absent, one-time grant remains true")
		await finish("consumed");return
	check(s.inventory.equipment.get("outfit",{}).get("item_id")=="modern_outfit","fresh process restores equipped outfit")
	# Move and run through all four actual input paths on the loaded continent.
	while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
	var movement_origin=p.position
	p.automated=true
	for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.DOWN,Vector2.UP]:
		p.position=movement_origin;p.input_override=direction;p.run_override=false
		for i in 12:p._physics_process(1.0/60)
		check(p.position.distance_to(movement_origin)>1 and p.moving,"actual walking input "+str(direction))
		p.run_override=true
		for i in 8:p._physics_process(1.0/60)
		check(p.running,"actual running input "+str(direction))
	p.position=movement_origin;p.input_override=Vector2.ZERO;p.run_override=false
	var session=raw.character_session.duplicate(true)
	var event=InputEventKey.new();event.physical_keycode=KEY_N;event.pressed=true;w._unhandled_input(event)
	check(w.world_seed==session.seed,"legacy N shortcut cannot corrupt assigned character world")
	for bad in [null,{}, {"character_session":{}}, {"character_session":raw.character_session,"equipment":[]}, {"character_session":raw.character_session,"equipment":{"outfit":3}}]:check(not c.valid_session(bad),"invalid session rejected "+str(bad))
	var malformed=raw.duplicate(true);malformed.character_session.characters[malformed.player_state_owner].appearance.skin_id="unknown"
	check(not c.valid_session(malformed),"unknown skin rejected")
	malformed=raw.duplicate(true);malformed.character_session.characters[malformed.player_state_owner].world_id="other"
	check(not c.valid_session(malformed),"world ownership mismatch rejected")
	# Verify the modified sleep head renderer, with all six skin settings and both orientations.
	for skin in c.Catalog.rules().skin:
		p.character_look.skin_id=skin
		for vertical in [true,false]:
			s.sleep.head_cover.render(p,{"source":"wood_bed","vertical":vertical,"id":"render-fixture"},s.builds)
			var head=p.get_node("SleepHeadCover/HeadPivot/CurrentHead/Sprite")
			check(head.material.get_shader_parameter("skin_color")==Color(c.Catalog.rules().skin[skin].color) and head.material.get_shader_parameter("closure")==1.0,"sleep skin and closed eyes "+skin+str(vertical))
	if DisplayServer.get_name()!="headless":
		await frames(5);root.get_texture().get_image().save_png(OUT+"sleep-current-head.png")
	p.character_look=active.appearance.duplicate(true);p.update_animation()
	# Functional single mine/dig hit in four directions using the ORIGINAL action simulation.
	var origin=p.position
	for action in ["mine","dig"]:
		var tool="stone_pickaxe" if action=="mine" else "simple_shovel"
		s.inventory.add(tool,1)
		for i in 40:
			if s.inventory.slots[i].get("item_id")==tool:s.inventory.equip(i);break
		for direction in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
			var id="char-fixture:"+action+str(direction)
			var at=origin+direction*45
			var row={"kind":"stone_outcrop" if action=="mine" else "buried_root","x":at.x,"y":at.y}
			s.ore_nodes[id]=row
			var target=s.create_harvest(id,row)
			check(target!=null,"functional target exists "+action+str(direction))
			if target==null:continue
			p.position=origin;p.action=action;p.action_target=target;p.action_clock=0;p.action_committed=false;p.action_contact=false;p.hold_chop=false
			p.facing="front" if direction==Vector2.DOWN else "back" if direction==Vector2.UP else "right" if direction==Vector2.RIGHT else "left"
			for i in 45:p._physics_process(1.0/60)
			check(p.action_committed and p.action_succeeded and int(s.resource_hits.get(id,0))==1,"original timed hit succeeds "+action+str(direction))
			p.cancel_action();target.queue_free();await frames()
			s.ore_nodes.erase(id);s.resource_hits.erase(id)
	p.position=origin;p.update_animation()
	check(s.inventory.unequip(42),"unequip in fresh process")
	var index=-1
	for i in 40:
		if s.inventory.slots[i].get("item_id")=="modern_outfit":index=i
	check(index>=0 and s.inventory.destroy_slot(index),"destroy clothing through original inventory")
	check(s.save_state(),"consumed clothing saved with grant flag")
	# Corrupt item snapshot must protect source, including after partial world bootstrap.
	var protected_path=OUT+"corrupt-save.json";var corrupt=raw.duplicate(true);corrupt.version=999
	var file=FileAccess.open(protected_path,FileAccess.WRITE);file.store_string(JSON.stringify(corrupt));file.close()
	var hash=FileAccess.get_sha256(protected_path)
	var other=load("res://scripts/character_creation.gd").new();other.save_path=protected_path;root.add_child(other)
	while other.busy:await process_frame
	check(other.protected_save and other.world==null and other.enter.disabled,"corrupt item version blocks world and protects source")
	check(FileAccess.get_sha256(protected_path)==hash,"corrupt source not overwritten")
	other.queue_free();await frames()
	await finish("resume")
func finish(tag: String):
	var fails=checks.filter(func(row):return not row.pass)
	var file=FileAccess.open(OUT+tag+"-checks.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"total":checks.size(),"failed":fails.size()},"\t"));file.close()
	print(tag.to_upper()," CHECKS ",checks.size()," FAILED ",fails.size())
	if c.world!=null:c.world.persistent_world=false
	c.queue_free();await frames(8);quit(0 if fails.is_empty() else 1)
