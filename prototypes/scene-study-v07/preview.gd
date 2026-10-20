extends "res://scripts/world.gd"
# Fixed-view art review only: original world builds the exact same prop layout/colliders.
var ready_for_review:=false
var revised:=true
var plate:Sprite2D
var original_textures:Dictionary={}
var review_textures:Array[Texture2D]=[]
var review_props:Array[Node2D]=[]
var original_ground:Texture2D
var revised_ground:Texture2D
func image_texture(path:String)->Texture2D:
	return ImageTexture.create_from_image(Image.load_from_file(path))
func _ready()->void:
	super._ready()
	player.automated=true
	player.set_physics_process(false)
	player.camera.position_smoothing_enabled=false
	while not started:await get_tree().process_frame
	for i in 8:await get_tree().process_frame
	player.position=generator.spawn
	player.camera.reset_smoothing()
	ui.hide()
	original_ground=image_texture("res://prototypes/ground-study-v06/ground-A.png")
	revised_ground=image_texture("res://prototypes/scene-study-v07/ground.png")
	plate=Sprite2D.new()
	plate.position=generator.spawn
	plate.z_index=-1
	plate.scale=Vector2(1280.0/revised_ground.get_width(),720.0/revised_ground.get_height())
	plate.texture=revised_ground
	add_child(plate)
	for name in ["tree_0","tree_1","rock_0","rock_1","flowers","leaves"]:
		review_textures.append(image_texture("res://prototypes/scene-study-v07/"+name+".png"))
	for entry in stream.loaded.values():
		entry.terrain.hide()
		entry.ground.hide()
	for prop in object_root.get_children():
		if prop.get("kind")==null:continue
		review_props.append(prop)
		original_textures[prop]=prop.texture
		prop.candidate_mode=1
	apply_art(true)
	ready_for_review=true
func apply_art(next:bool)->void:
	revised=next
	plate.texture=revised_ground if revised else original_ground
	plate.scale=Vector2(1280.0/plate.texture.get_width(),720.0/plate.texture.get_height())
	for prop in review_props:
		if prop.kind<4:
			prop.texture=review_textures[prop.kind] if revised else original_textures[prop]
		else:
			# Reuse existing decoration coordinates and size. No extra scatter grid.
			prop.visible=revised and prop.position.distance_to(generator.spawn)>160
			prop.texture=review_textures[4+posmod(prop.kind,2)] if revised else original_textures[prop]
		prop.queue_redraw()
func _unhandled_input(event:InputEvent)->void:
	if not ready_for_review:return
	if event is InputEventKey and event.pressed:
		if event.physical_keycode==KEY_1:apply_art(false)
		if event.physical_keycode==KEY_2:apply_art(true)
