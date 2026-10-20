extends SceneTree
const OUT="res://reports/character-hair-v2/"
var checks: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks.append({"pass":ok,"name":label});if not ok:push_error(label)
func frames(n: int=4):
	for i in n:await process_frame
func run():
	Engine.max_fps=60
	var raw=JSON.parse_string(FileAccess.get_file_as_string("res://reports/character-creation-v1/isolated-save.json"))
	var id=raw.player_state_owner
	raw.character_session.characters[id].appearance={"gender":"male","hair_id":"male_parted","skin_id":"skin_2"}
	var path=OUT+"isolated-save.json";var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(raw));file.close()
	var c=load("res://scripts/character_creation.gd").new();c.save_path=path;root.add_child(c)
	while c.busy:await process_frame
	var w=c.world;var p=w.player;var s=w.item_service
	w.environment_view.set_process(false);p.set_physics_process(false)
	check(not c.screen.visible and p.character_look.hair_id=="male_parted","old persisted hairstyle ID resumes with new spiky crop")
	check(w.world_seed==raw.seed and p.position==Vector2(raw.player_position.x,raw.player_position.y),"appearance revision preserves saved world seed and position")
	check(p.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_ON,"world player interpolation stays unchanged")
	var head=p.character.get_node("Visual/Pelvis/Head/Sprite")
	for facing in ["front","back","left","right"]:
		p.facing=facing;p.update_animation()
		var view_name="side" if facing in ["left","right"] else facing
		check(head.get_node("CharacterHairfront").texture==p.look_renderer.tex(c.Catalog.rules().hair.male_parted[view_name].front),"world uses current complete silhouette "+facing)
		check(not head.get_node("CharacterHairrear").visible,"no residual split layer "+facing)
	s.inventory.add("modern_outfit",1)
	var slot=-1
	for i in 40:
		if s.inventory.slots[i].get("item_id")=="modern_outfit":slot=i;break
	check(s.inventory.equip(slot),"original outfit transaction remains functional")
	p.update_animation();check(p.character_look.hair_id=="male_parted","outfit does not reset new hair")
	w.item_ui.update_portrait(0)
	check(w.item_ui.preview_actor.get_node("Visual/Pelvis/Head/Sprite/CharacterHairfront").texture==w.item_ui.portrait_look.tex(c.Catalog.rules().hair.male_parted.front.front),"bag preview uses black updated hairstyle")
	check(s.inventory.unequip(42),"unequip remains functional")
	for skin in c.Catalog.rules().skin:
		p.character_look.skin_id=skin
		s.sleep.head_cover.render(p,{"source":"wood_bed","vertical":false,"id":"render-only"},s.builds)
		var sleeping=p.get_node("SleepHeadCover/HeadPivot/CurrentHead/Sprite")
		check(sleeping.texture==p.look_renderer.tex(c.Catalog.rules().heads.side),"sleep copies corrected side base "+skin)
		var point=sleeping.material.get_shader_parameter("side_eye_center");var expected=c.Catalog.rules().sleep_side_eye_center
		check(point.is_equal_approx(Vector2(expected[0],expected[1])) and sleeping.material.get_shader_parameter("closure")==1.0,"sleep eye closure follows new asset anchor "+skin)
		check(sleeping.material.get_shader_parameter("skin_color")==Color(c.Catalog.rules().skin[skin].color),"sleep skin retained "+skin)
	p.update_animation();check(head.material.get_shader_parameter("closure")==0.0,"sleep duplicate does not close awake character eyes")
	p.facing="right";p.camera.zoom=Vector2.ONE*1.65;p.update_animation();p.camera.reset_smoothing();await frames(12)
	root.get_texture().get_image().save_png(OUT+"world-spiky-crop.png")
	check(s.save_state() and c.valid_session(s.snapshot()),"new hairstyle appearance remains compatible with original atomic save")
	var fails=checks.filter(func(row):return not row.pass)
	file=FileAccess.open(OUT+"world-checks.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"total":checks.size(),"failed":fails.size()},"\t"));file.close()
	print("HAIR WORLD CHECKS ",checks.size()," FAILED ",fails.size());w.persistent_world=false;c.queue_free();await frames();quit(0 if fails.is_empty() else 1)
