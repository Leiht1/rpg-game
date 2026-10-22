extends SceneTree
const OUT="res://reports/character-hair-v2/"
var checks: Array=[]
var c: Node
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks.append({"pass":ok,"name":label});if not ok:push_error(label)
func frames(n: int=4):
	for i in n:await process_frame
func snap(name_value: String):
	await frames(12);root.get_texture().get_image().save_png(OUT+name_value+".png")
func click(button: Button):
	await frames(8)
	var at=button.get_global_rect().get_center();var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;Input.parse_input_event(motion)
	for state in [true,false]:
		var e=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=state;Input.parse_input_event(e);await frames(2)
func save_hashes() -> Dictionary:
	var result={}
	for path in DirAccess.get_files_at("user://"):
		if path.ends_with(".json"):result[path]=FileAccess.get_sha256("user://"+path)
	var path="user://character-preview-v1/state.json"
	if FileAccess.file_exists(path):result[path]=FileAccess.get_sha256(path)
	return result
func run():
	Engine.max_fps=60;var before=save_hashes()
	c=load("res://scripts/character_creation.gd").new();c.save_path=OUT+"absent-save.json";root.add_child(c);await frames(20)
	check(c.preview.physics_interpolation_mode==Node.PHYSICS_INTERPOLATION_MODE_OFF,"creation rig interpolation disabled without changing world player")
	await click(c.gender);await frames(12)
	check(c.gender.get_popup().visible,"real gender dropdown opens")
	check(c.gender.get_popup().get_theme_stylebox("panel") is StyleBoxTexture,"gender popup uses paper texture")
	await snap("gender-paper-menu");c.gender.get_popup().hide();await frames(12)
	await click(c.hair);await frames(12)
	check(c.hair.get_popup().visible,"real hairstyle dropdown opens")
	check(c.hair.get_popup().get_theme_stylebox("panel") is StyleBoxTexture,"hair popup uses paper texture")
	check(c.hair.get_popup().get_theme_color("font_color")==Color("4b4437"),"popup has unified dark text")
	check(c.hair.get_item_text(2)=="美式前刺","spiky crop name replaces parted while ID remains compatible")
	await snap("hair-paper-menu");c.hair.get_popup().hide();await frames(12)
	# Another OptionButton inherits the same common theme, including its Window popup.
	var other=OptionButton.new();other.add_item("纸布选项");c.screen.add_child(other);other.position=Vector2(20,20)
	check(other.get_popup().get_theme_stylebox("panel") is StyleBoxTexture,"common theme covers unrelated OptionButton popups too")
	other.queue_free();await frames()
	for sex in [0,1]:
		c.gender.select(sex);c.select_gender(sex)
		for id in c.hair_ids:
			c.look.hair_id=id
			for facing in ["front","back","right","left"]:
				c.preview_facing=facing;c.refresh_preview()
				await RenderingServer.frame_post_draw
				var first: PackedByteArray=c.view.get_texture().get_image().get_data();var stable=true
				for i in 5:
					await process_frame;await RenderingServer.frame_post_draw
					stable=stable and c.view.get_texture().get_image().get_data()==first
				check(stable,"zero transient pixels after direction switch "+id+" "+facing)
				var head=c.preview.get_node("Visual/Pelvis/Head/Sprite")
				check(not head.get_node("CharacterHairrear").visible and head.get_node("CharacterHairfront").visible,"complete hair silhouette, no hard split "+id+" "+facing)
				if facing in ["left","right"]:
					var heads=c.Catalog.rules().get("gender_heads",{}).get(c.look.gender,c.Catalog.rules().heads)
					check(head.texture==c.renderer.tex(heads.side),"correct side base "+id+" "+facing)
				check(c.preview.get_node("Visual").scale.x==(-1 if facing=="left" else 1),"mirror orientation "+id+" "+facing)
				check(c.preview.position==Vector2(3,-4),"fixed character root "+id+" "+facing)
	c.gender.select(0);c.select_gender(0);c.look.hair_id="male_parted";c.hair.select(2);c.preview_facing="right";c.refresh_preview();await snap("spiky-crop-creation")
	check(not FileAccess.file_exists(c.save_path) and c.world==null,"appearance and popup tests never create a world or save")
	check(before==save_hashes(),"formal and current user preview save hashes unchanged")
	var failed=checks.filter(func(row):return not row.pass)
	var file=FileAccess.open(OUT+"runtime-checks.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"total":checks.size(),"failed":failed.size()},"\t"));file.close()
	print("HAIR UI CHECKS ",checks.size()," FAILED ",failed.size());c.queue_free();await frames();quit(0 if failed.is_empty() else 1)
