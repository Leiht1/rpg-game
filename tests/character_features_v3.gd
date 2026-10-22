extends SceneTree
const OUT="res://reports/.tmp/character-features-v3/"
var checks:=0
func _initialize():run.call_deferred()
func verify(ok:bool):
	assert(ok);checks+=1
func frames():
	for i in 5:await process_frame
func run():
	DirAccess.make_dir_recursive_absolute(OUT)
	var c=load("res://scripts/character_creation.gd").new();c.selection_only=true
	root.add_child(c);await frames()
	var catalog=c.Catalog.rules()
	var original_transforms:={}
	for part in c.renderer.PARTS:original_transforms[part]=c.preview.get_node(c.renderer.PARTS[part]).transform
	for sex in [0,1]:
		c.gender.select(sex);c.select_gender(sex);verify(c.hair_ids.size()==8)
		for hair in c.hair_ids:
			c.look.hair_id=hair;verify(c.Catalog.valid(c.look))
			for facing in ["front","back","right","left"]:
				c.preview_facing=facing;c.refresh_preview();await frames()
				var head=c.preview.get_node(c.renderer.PARTS.head)
				var view="side" if facing in ["right","left"] else facing
				var heads=catalog.get("gender_heads",{}).get(c.look.gender,catalog.heads)
				verify(head.texture==c.renderer.tex(heads[view]))
				verify(head.get_node("CharacterHairfront").position==Vector2.ZERO)
		c.look.hair_id="male_natural";c.hair.select(0);c.preview_facing="front";c.refresh_preview();await frames()
		root.get_texture().get_image().save_png(OUT+str(c.look.gender)+"-short.png")
		c.look.hair_id="female_bob";c.select_gender(1-sex);verify(c.look.hair_id=="female_bob")
	var invalid=c.look.duplicate();invalid.hair_id="unknown";verify(not c.Catalog.valid(invalid))
	var inv=ItemInventory.new(ItemDatabase.new());c.Catalog.enable_candidate(inv.database);inv.add("modern_outfit",1);verify(inv.equip(8))
	c.gender.select(1);c.select_gender(1);c.look.hair_id="male_natural";c.hair.select(0)
	for facing in ["front","right","back"]:
		c.preview_facing=facing;c.refresh_preview();c.renderer.apply(c.preview,c.look,inv,facing);await frames()
		verify(c.renderer.materials.torso.get_shader_parameter("blue_outfit"))
		verify(not c.renderer.materials.head.get_shader_parameter("blue_outfit"))
		root.get_texture().get_image().save_png(OUT+"blue-outfit-"+facing+".png")
	for skin in catalog.skin:
		c.look.skin_id=skin;c.refresh_preview();verify(c.renderer.materials.head.get_shader_parameter("skin_color")==Color(catalog.skin[skin].color))
	verify(c.world==null)
	c.queue_free();await frames();print("CHARACTER_FEATURES_V3_PASS ",checks);quit()
