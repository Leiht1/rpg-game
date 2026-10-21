extends SceneTree

func _initialize() -> void:
	boot.call_deferred()

func boot() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--regression-script="):
			path = arg.trim_prefix("--regression-script=")
	var script = load(path)
	if script == null or not script.can_instantiate():
		quit(1)
		return
	set_script(script)
	call_deferred("_initialize")
