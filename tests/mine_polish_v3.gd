extends "res://tests/mine_playable_preview.gd"
var checks: Array=[]
var captures: Array=[]
var labels: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("POLISH_CHECK ",ok," ",label)
	if not ok:push_error(label)
func move_to(at: Vector2) -> void:
	w.player.position=at;w.player.camera.position_smoothing_enabled=false;w.player.reset_physics_interpolation();w.stream.update_target(at)
	while not w.stream.viewport_ready(at,Vector2(640,360)):await process_frame
	await create_timer(.15).timeout
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	captures.append(root.get_texture().get_image());labels.append(label)
func settled() -> void:
	var limit: int=Time.get_ticks_msec()+12000
	while w.item_service.chapter_view.transition.active and Time.get_ticks_msec()<limit:await process_frame
	check(not w.item_service.chapter_view.transition.active,"transition completes")
func smoke() -> void:
	var s=w.item_service;var m=s.chapter.mine;var view=s.chapter_view.get_node("MineView");var transition=s.chapter_view.transition
	w.environment_view.simulation.paused=true;s.combat.state.boars.clear()
	m.state.recipe=true;m.state.investigated=true;m.state.phase="open";m.state.fuse_remaining_seconds=0.0;m.state.fuse_due=s.chapter.now();m.state.opened_at=s.chapter.now()
	await move_to(m.at()+Vector2(0,115));await capture("00-before")
	var slots: Array=s.inventory.slots.duplicate(true);var serial: int=m.travel.serial
	w.player.facing="back";w.player.try_interact()
	check(transition.active and not m.travel.inside,"real E starts fade before teleport")
	await create_timer(.08).timeout;await capture("01-enter-fade")
	check(not m.travel.inside,"outgoing scene retained while fading")
	for stage_wait in 600:
		if m.travel.inside:break
		await process_frame
	print("ENTER_WAIT ",transition.active," ",m.travel," ",w.player.input_blocked)
	check(transition.curtain.modulate.a>=.999,"entry position switches only behind full black")
	w.player.try_interact();check(int(m.travel.serial)==serial+1,"repeated E during entry cannot double transition")
	await capture("02-enter-black")
	check(transition.caption.text=="进入矿洞…" and transition.content.visible,"entry curtain contains cave icon and concise caption")
	await settled();await capture("03-inside")
	check(view.interior.visible and not transition.curtain.visible,"interior ready before reveal completes")
	check(w.stream.viewport_ready(w.player.position,Vector2(640,360)),"entry destination ready")
	check(s.inventory.slots==slots,"entry preserves inventory")
	# Force a cold surface return and delay chunk installation under the curtain.
	for coord in w.stream.loaded.keys():w.stream.unload_chunk(coord)
	await move_to(m.origin()+Vector2(0,340));w.stream.set_process(false)
	w.player.facing="front";w.player.try_interact()
	for stage_wait in 600:
		if not m.travel.inside:break
		await process_frame
	print("EXIT_WAIT ",transition.active," ",m.travel," ",w.player.input_blocked)
	check(transition.curtain.modulate.a>=.999,"exit position switches only behind full black")
	await create_timer(.5).timeout;await capture("04-exit-cold-black")
	check(transition.active and transition.curtain.modulate.a>=.999,"black is held while actual surface chunks are unavailable")
	check(not w.stream.viewport_ready(w.player.position,Vector2(640,360)),"cold-return fixture really has unloaded surface")
	check(transition.caption.text=="返回地表…" and transition.progress.value<1.0,"return caption and progress do not report done before loading")
	w.stream.set_process(true);await settled();await capture("05-surface")
	check(not m.travel.inside and w.stream.viewport_ready(w.player.position,Vector2(640,360)),"cold surface ready before reveal")
	check(m.travel.serial==serial+2 and s.inventory.slots==slots,"exit preserves own inventory and one transition")
	var old_path: String=s.save_path;w.persistent_world=true;s.save_path="res://reports/mine-polish-v3/missing/sub/save.json"
	await move_to(m.at()+Vector2(0,115));w.player.facing="back";w.player.try_interact()
	await settled();w.persistent_world=false;s.save_path=old_path
	check(not m.travel.inside and m.travel.serial==serial+2 and not transition.active,"save failure returns to original scene and unlocks curtain")
	# Render the complete explosion with a fixed camera and shared 2D ground root.
	await move_to(m.at()+Vector2(0,115));view.blast.start(m.at()+Vector2(0,35))
	var sprite_position: Vector2=view.blast.sprite.position;var origin: Vector2=view.blast.position
	var blend_seen:=false;var fixed:=true;var i:=0
	while view.blast.active:
		await RenderingServer.frame_post_draw
		fixed=fixed and view.blast.sprite.position==sprite_position and view.blast.position==origin
		var blend: float=view.blast.blend_material.get_shader_parameter("frame_blend")
		blend_seen=blend_seen or (blend>.05 and blend<.95)
		if i%3==0:
			captures.append(root.get_texture().get_image());labels.append("fx-%03d"%i)
		i+=1
	check(fixed,"sprite root and scale remain fixed throughout every painted phase")
	check(blend_seen,"premultiplied temporal blending is active between registered frames")
	check(not view.blast.active,"aligned explosion ends cleanly")
	for j in captures.size():captures[j].save_png("res://reports/mine-polish-v3/"+labels[j]+".png")
	var failures: int=checks.filter(func(c):return not c.pass).size()
	FileAccess.open("res://reports/mine-polish-v3/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":labels},"  "))
	print("MINE POLISH V3 ",checks.size()," failures=",failures)
	w.queue_free();await process_frame;quit(1 if failures else 0)
