extends SceneTree
func _initialize()->void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=2:quit(2);return
	var files:Array=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var pack:=PCKPacker.new()
	if pack.pck_start(args[1])!=OK:quit(3);return
	for path in files:
		if pack.add_file("res://"+path,ProjectSettings.globalize_path("res://"+path))!=OK:quit(4);return
	if pack.flush()!=OK:quit(5);return
	print("CANDIDATE_PACK_FILES ",files.size());quit()
