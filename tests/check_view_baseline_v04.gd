extends SceneTree
func _initialize()->void:
	var original=load("res://prototypes/view-v01/formal_v03.gd").new(271828,1024)
	var candidate=load("res://prototypes/view-v01/generator.gd").new(271828,1024)
	var ok=original.lakes.size()==284 and candidate.lakes.size()==133
	var scene=load("res://prototypes/view-v01/preview.tscn")
	ok=ok and scene!=null
	print("VIEW_BASELINE_COMPATIBLE ",ok," original=",original.lakes.size()," candidate=",candidate.lakes.size())
	quit(0 if ok else 1)
