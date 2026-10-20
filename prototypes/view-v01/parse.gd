extends SceneTree
func _initialize()->void:
	var scene=load("res://prototypes/view-v01/preview.tscn")
	print("PREVIEW_PARSE ",scene!=null)
	quit()
