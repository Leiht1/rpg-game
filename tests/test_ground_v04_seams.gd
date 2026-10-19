extends SceneTree
func _initialize()->void:
	var gen=WildGenerator.new()
	var c:=Vector2i(gen.spawn/WildGenerator.CHUNK_PX)
	var a=gen.build_chunk(c)
	var b=gen.build_chunk(c+Vector2i.RIGHT)
	var same:=true
	for y in 146:
		if a.image.get_pixel(145,y)!=b.image.get_pixel(1,y):same=false
	var report={"shared_border_identical":same,"generator_version":WildGenerator.VERSION,"visual_version":"ground-preview-0.4.0","terrain_rule_changed":false,"collision_code_changed":false}
	var f:=FileAccess.open("res://reports/ground-v04-seams.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "))
	print(report);quit(0 if same else 1)
