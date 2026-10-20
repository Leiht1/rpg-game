extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://prototypes/biome-v02/preview.tscn").instantiate();root.add_child(scene)
	scene.save_path="user://biome-v02-save-test.json"
	scene.regenerate(81273,true);scene.seed_value=42;scene.load_seed()
	var restored=scene.seed_value==81273
	DirAccess.remove_absolute(scene.save_path)
	FileAccess.open("res://prototypes/biome-v02/save-check.json",FileAccess.WRITE).store_string(JSON.stringify({"saved_seed_restored":restored,"formal_save_untouched":true},"  "))
	print("saved_seed_restored=",restored);quit()
