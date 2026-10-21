extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var fade=root.get_node("UIFade")
	for opening in [true,false]:
		var window:=PopupPanel.new()
		root.add_child(window)
		fade.watch(window)
		if opening:
			fade.window_open(window)
		else:
			fade.entries[window.get_instance_id()].visible=true
			fade.window_changed(window)
		var id:=window.get_instance_id()
		window.free()
		await process_frame
		assert(not fade.entries.has(id),"freed window must leave no fade entry")
	print("FREED_WINDOW_DEFERRED_FADE_PASS 2")
	quit()
