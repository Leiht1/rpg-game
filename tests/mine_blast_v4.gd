extends "res://tests/mine_playable_preview.gd"
func smoke() -> void:
	var s=w.item_service;var m=s.chapter.mine;var view=s.chapter_view.get_node("MineView");var fx=view.blast
	w.environment_view.simulation.paused=true;s.combat.state.boars.clear()
	w.player.position=m.at()+Vector2(0,150);w.player.camera.position_smoothing_enabled=false;w.player.reset_physics_interpolation();w.stream.update_target(w.player.position)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	await create_timer(.3).timeout
	m.state.phase="open";view.last_phase="open"
	var checks: Array=[]
	fx.start(m.at()+view.BLAST_OFFSET);fx.active=false
	var previous: Array=[]
	for stone in fx.stones:previous.append(stone.position.x)
	var no_reverse:=true;var fades:=true;var alpha:=1.0
	for step in range(1,241):
		fx.sample_at(float(step)*.02)
		for i in fx.stones.size():
			var x: float=fx.stones[i].position.x
			if absf(x)+.001<absf(previous[i]):no_reverse=false
			previous[i]=x
		if step>30:
			if fx.smoke[0].modulate.a>alpha+.0001:fades=false
			alpha=fx.smoke[0].modulate.a
	checks.append({"name":"every stone travels outward without lateral reversal","pass":no_reverse})
	checks.append({"name":"smoke alpha decreases continuously after flash","pass":fades})
	fx.sample_at(1.5)
	checks.append({"name":"painted residual smoke persists after flash and stones","pass":not fx.sprite.visible and fx.smoke[0].modulate.a>.1 and fx.stones[0].modulate.a==0})
	fx.sample_at(4.81);checks.append({"name":"tail ends cleanly","pass":not fx.visible})
	var pictures: Array=[]
	fx.start(m.at()+view.BLAST_OFFSET)
	var last:=-1
	while fx.active:
		await process_frame
		var tick:=int(fx.clock*20)
		if tick!=last:
			last=tick
			await RenderingServer.frame_post_draw
			var picture:=root.get_texture().get_image();picture.resize(768,432);pictures.append(picture)
	for i in pictures.size():pictures[i].save_png("res://reports/mine-blast-v4/fx-%03d.png"%i)
	var f=FileAccess.open("res://reports/mine-blast-v4/checks.json",FileAccess.WRITE);f.store_string(JSON.stringify(checks,"  "));f.close()
	print("V4_CHECKS ",checks," CAPTURES ",pictures.size())
	quit(0 if no_reverse and fades else 1)


