extends SceneTree
const OUT="res://reports/ponytail-side-v3/"
var checks: Array=[]
func _initialize():call_deferred("run")
func check(ok: bool,label: String):
	checks.append({"pass":ok,"name":label});if not ok:push_error(label)
func frames(n: int=4):
	for i in n:await process_frame
func run():
	Engine.max_fps=60
	var c=load("res://scripts/character_creation.gd").new();c.save_path=OUT+"absent-save.json";root.add_child(c);await frames(15)
	c.gender.select(1);c.select_gender(1);c.look.hair_id="female_ponytail";c.hair.select(3)
	for skin in c.Catalog.rules().skin:
		c.look.skin_id=skin
		for facing in ["left","right"]:
			c.preview_facing=facing;c.refresh_preview();await frames(3)
			var head=c.preview.get_node("Visual/Pelvis/Head/Sprite")
			check(head.get_node("CharacterHairfront").texture==c.renderer.tex("res://prototypes/ponytail-side-v3/female_ponytail-side.png"),"localized patch reused "+skin+facing)
			check(c.preview.get_node("Visual").scale.x==(-1 if facing=="left" else 1),"original mirrored pose "+skin+facing)
	c.look.skin_id="skin_2";c.preview_facing="left";c.refresh_preview();await frames(8);root.get_texture().get_image().save_png(OUT+"left-corrected.png")
	c.preview_facing="right";c.refresh_preview();await frames(8);root.get_texture().get_image().save_png(OUT+"right-corrected.png")
	check(not FileAccess.file_exists(c.save_path) and c.world==null,"render-only check does not create world or alter save")
	var failed=checks.filter(func(x):return not x.pass);var file=FileAccess.open(OUT+"checks.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"total":checks.size(),"failed":failed.size()},"\t"));file.close();print("PONYTAIL CHECKS ",checks.size()," FAILED ",failed.size());c.queue_free();await frames();quit(0 if failed.is_empty() else 1)
