extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("CHECK ",ok," ",label)
	if not ok:failures+=1
func run() -> void:
	var w=load("res://scripts/network_game_host_world.gd").new()
	w.bootstrap={"id":"animal-motion-isolated","seed":271828,"map_cells":128}
	root.add_child(w);current_scene=w
	while not w.started:await process_frame
	w.set_process(false);w.player.set_physics_process(false)
	w.item_service.set_process(false);w.environment_view.set_process(false)
	while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
	w.stream.set_process(false);w.item_service.animals.set_physics_process(false)
	w.item_service.combat_view.set_process(false)
	w.set_meta("network_rules_host",false);w.set_meta("network_game",true)
	var manager=w.item_service.animals
	for species in ["chicken","sheep"]:
		var at: Vector2=w.player.position+Vector2(-110 if species=="chicken" else 100,30)
		manager.states[species]=manager.make_row(species,at)
	manager.sync_visuals()
	for species in ["chicken","sheep"]:
		check(manager.visuals.has(species),"real animal instantiated "+species)
		var actor=manager.visuals[species];actor.set_physics_process(false)
		var original: Vector2=actor.position;var previous: Vector2=original
		var maximum:=0.0;var stopped:=0
		for frame in 270:
			manager.states[species].x=original.x+floori(frame/45.0)*27
			actor._physics_process(1.0/60)
			if frame>90:
				var step: float=actor.position.distance_to(previous)
				maximum=maxf(maximum,step)
				if step<.01:stopped+=1
			previous=actor.position
		check(maximum<1.0 and stopped<3,"real actor continuous "+species)
		check(actor.position.x<=float(manager.states[species].x),"drawing never predicts past authority "+species)
		print("METRIC ",species," max_step=",maximum," stopped_frames=",stopped)
		# A repeated restore must preserve the visual's interpolation history.
		var node=actor
		manager.restore(manager.serialize())
		check(manager.visuals[species]==node,"restore retains motion history "+species)
	# The actual player must not move in an unconfirmed attack gap, then get
	# pulled back by authority. Exercise held movement across late acceptance.
	var combat=w.item_service.combat
	combat.personal.phase="alive";combat.personal.attack={}
	combat.begin_attack_preview(Vector2.RIGHT)
	combat.attack_preview_started=Time.get_ticks_msec()-2000
	w.player.automated=true;w.player.input_override=Vector2.DOWN
	w.player.collision_mask=0
	var start: Vector2=w.player.position
	for i in 15:w.player._physics_process(1.0/60)
	check(w.player.position.is_equal_approx(start),"real player remains stationary before late acceptance")
	combat.personal.attack=combat.attack_preview.duplicate(true);combat.confirm_attack_preview(true)
	for i in 15:w.player._physics_process(1.0/60)
	check(w.player.position.is_equal_approx(start),"real player has no acceptance relock jump")
	combat.personal.attack={}
	check(combat.attack_state().is_empty(),"completion clears real player movement fence")
	await process_frame
	await process_frame
	if not DisplayServer.get_name()=="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/animal-scene.png")
	print("FAILURES ",failures)
	w.queue_free();await process_frame;quit(1 if failures else 0)
