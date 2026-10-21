extends SceneTree
## Same V0.6 generator as the client, executed only on the server.
func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:quit(2);return
	var gen=preload("res://scripts/world_generator.gd").new(int(args[0]),int(args[1]))
	var step:=48
	var width:int=gen.map_cells
	var mask:=PackedByteArray();mask.resize(width*width)
	for y in width:
		for x in width:
			var p:=Vector2((x+.5)*step,(y+.5)*step)
			mask[y*width+x]=1 if gen.sample(p).z<=.03 and gen.coast_distance(p)>=24 else 0
	var out:=FileAccess.open(args[2],FileAccess.WRITE)
	if not out:quit(3);return
	out.store_string(JSON.stringify({"generator":gen.VERSION,"spawn":[gen.spawn.x,gen.spawn.y],"step":step,"width":width,"mask":Marshalls.raw_to_base64(mask)}))
	out.close();quit()
