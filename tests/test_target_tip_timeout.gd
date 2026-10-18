extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func run() -> void:
	var world = load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(world)
	while not world.started: await process_frame
	world.player.automated = true
	world.player.set_physics_process(false)
	var ui = world.item_ui
	ui.set_process(false)
	ui.bag.hide(); ui.catalog.hide(); ui.modal.hide(); world.map_view.hide()
	var target := Node2D.new()
	root.add_child(target)
	target.set_meta("display_name", "石矿")
	ui.update_target_tip(target, 0.0)
	check(ui.target_tip.visible, "new target shows label")
	ui.update_target_tip(target, 1.9)
	check(ui.target_tip.visible, "label stays briefly")
	target.set_meta("progress", "1/5")
	ui.update_target_tip(target, 0.11)
	check(not ui.target_tip.visible, "progress does not restart two-second timer")
	ui.update_target_tip(target, 10.0)
	check(not ui.target_tip.visible, "standing beside same target does not repeat")
	ui.bag.show(); ui.update_target_tip(target, 0.1)
	ui.bag.hide(); ui.update_target_tip(target, 0.1)
	check(not ui.target_tip.visible, "panel reopen does not restart expired label")
	ui.update_target_tip(null, 0.1)
	check(not ui.target_tip.visible, "leaving clears label")
	ui.update_target_tip(target, 0.1)
	check(ui.target_tip.visible, "returning shows label again")
	var other := Node2D.new(); root.add_child(other)
	ui.update_target_tip(other, 0.1)
	check(ui.target_tip.visible and ui.target_tip_time == 2.0, "switching target starts its own timer")
	other.queue_free(); await process_frame
	ui.update_target_tip(null, 0.1)
	check(not ui.target_tip.visible, "removed target safely hides label")
	target.queue_free()
	print("Target tip checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
