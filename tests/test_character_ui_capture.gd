extends SceneTree
func _initialize():call_deferred("run")
func run():
	var c=load("res://scripts/character_creation.gd").new();c.save_path="res://reports/character-creation-v1/absent-ui-save.json";root.add_child(c)
	for i in 10:await process_frame
	root.get_texture().get_image().save_png("res://reports/character-creation-v1/creation-ui.png")
	quit()
