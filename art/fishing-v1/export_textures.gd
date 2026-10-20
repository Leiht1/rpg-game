extends SceneTree
## prototypes/ is deliberately ignored by the importer. Native compressed textures
## load directly from that candidate folder without enabling import of old prototypes.
func _initialize() -> void:
	for part in ["rod","float","fish","coin","locked_chest"]:
		var base: String="res://prototypes/fishing-v1/art/"+part
		var image := Image.load_from_file(base+".png")
		if image==null: quit(1);return
		var texture := ImageTexture.create_from_image(image)
		var error := ResourceSaver.save(texture,base+".res",ResourceSaver.FLAG_COMPRESS)
		if error!=OK: quit(1);return
	print("FISHING_CANDIDATE_TEXTURES 5 exported")
	quit()
