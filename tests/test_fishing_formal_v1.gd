extends SceneTree
## Runs the exact F6 scene and its real input adapter; all state remains disposable.
const OUT := "res://reports/fishing-formal-v1/"
var checks: Array[Dictionary]=[]
var w: Node2D
var f: Node2D
var rewards: Array=[]
var save_before: Dictionary
var formal_before: Dictionary
var capture_enabled := false

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)

func frames(count: int=2) -> void:
	for i in count: await process_frame

func player_files() -> Dictionary:
	var values := {}
	for name in DirAccess.get_files_at("user://"):
		if name.ends_with(".json") or name.ends_with(".tmp"):
			values[name]=FileAccess.get_sha256("user://"+name)
	return values

func formal_files() -> Dictionary:
	var values := {}
	for path in ["Start-Playtest.cmd","project.godot","data/items.json","data/held_tools.json","assets/industry/v1/fishing_rod.png","assets/hero/cartoon/character.tscn","assets/hero/cartoon/harvest_actions.tres","scripts/world.gd","scripts/player.gd","scripts/item_service.gd","scripts/world_interaction.gd"]:
		values[path]=FileAccess.get_sha256("res://"+path)
	return values

func key(code: Key, echo: bool=false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code;event.keycode=code;event.pressed=true;event.echo=echo
	Input.parse_input_event(event)
	await frames(1)
	# Keep ordinary-fish assertions deterministic; rare catches are forced and
	# verified separately below, while production uses its independent loot RNG.
	if code==KEY_E and is_instance_valid(f) and f.state=="cast": f.catch_id=f.FISH_ID
	event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=false
	Input.parse_input_event(event)
	await frames(1)

func render_state() -> void:
	if f.state!="idle": f.pose();f.update_line()
	f.update_ui();f.queue_redraw()
	await frames()

func capture(name: String) -> void:
	await render_state()
	if capture_enabled:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+name+".png")

func advance_to_game() -> void:
	f.advance(.9);f.advance(f.wait_time+.02);f.advance(.67)
	await render_state()

func hit() -> void:
	f.input_cooldown=0
	f.bar.marker=f.bar.safe_center
	await key(KEY_SPACE)

func miss() -> void:
	f.input_cooldown=0;f.bar.marker=0
	await key(KEY_SPACE)

func reset_shore() -> void:
	if f.state!="idle": f.finish("")
	for spot in f.spots: spot.remaining=6;spot.respawn_minutes=0.0
	w.item_ui.close_panels()
	w.player.position=f.spots[0].stand
	w.player.reset_physics_interpolation();w.player.camera.reset_smoothing()
	await frames()

func run() -> void:
	Engine.max_fps=60
	capture_enabled="capture" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless"
	save_before=player_files();formal_before=formal_files()
	w=load("res://scenes/fishing_preview.tscn").instantiate();root.add_child(w)
	var deadline := Time.get_ticks_msec()+90000
	while not w.fishing_ready and w.preview_error.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(w.fishing_ready,"direct preview.tscn initializes with three lakeshore fish spots")
	if not w.fishing_ready:
		finish_report();w.free();quit(1);return
	var old_fishing: Node2D=w.fishing
	var points: Array[Dictionary]=old_fishing.spots.duplicate(true)
	for i in points.size(): points[i].merge({"id":"fixture-%d"%i,"lake":i,"remaining":6,"respawn_minutes":0.0})
	w.item_service.fishing_population.candidates=points.duplicate(true)
	w.item_service.fishing_population.spots.assign(points)
	points=w.item_service.fishing_population.spots
	old_fishing.free()
	f=load("res://scripts/fishing.gd").new();w.add_child(f);f.configure(w,points)
	f.set_process(false)
	var formal_rod: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/held_tools.json"))["tool:fishing_rod"]
	check(is_equal_approx(float(f.registration.scale),float(formal_rod.scale)) and Vector2(f.registration.canvas[0],f.registration.canvas[1])==load(formal_rod.texture).get_size(),"candidate rod uses original 256 canvas and original 0.24 held size")
	w.player.update_animation()
	check(is_instance_valid(f.fish_texture) and is_instance_valid(f.float_texture) and is_instance_valid(load(formal_rod.texture)),"all formal fishing textures imported and loaded")
	w.environment_view.simulation.paused=true
	w.item_service.item_obtained.connect(func(id: String,count: int): rewards.append([id,count]))
	await frames(12)
	check(root.content_scale_size==Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),ProjectSettings.get_setting("display/window/size/viewport_height")),"uses project default 1280x720 only")
	check(not w.persistent_world and w.environment_view.save_path.is_empty(),"world/environment save paths disabled before initialization")
	check(not w.item_service.database.item(f.FISH_ID).is_empty() and not ItemDatabase.new().item(f.FISH_ID).is_empty(),"fish definition is local to preview database")
	check(w.item_service.inventory.has_capability("fishing_ready"),"starts with one equipped rod in original inventory")
	for i in f.spots.size():
		var spot: Dictionary=f.spots[i]
		check(w.fish_water_clearance(spot.water),"whole school footprint stays in water %d"%i)
		var dry_vertices := 0
		for phase_index in 24:
			var phase := float(phase_index)/24
			for ring in [{"at":spot.water,"radius":26+phase*26},{"at":spot.water+Vector2(-14,6),"radius":13+phase*16}]:
				for segment in f.water_ring_segments(ring.at,ring.radius):
					for vertex in segment:
						if w.generator.sample(vertex).z<.8: dry_vertices+=1
		check(dry_vertices==0,"all ripple phases clipped to water %d"%i)
		check(w.generator.sample(spot.water).z>=.8,"fish spot %d is actual water"%i)
		check(w.generator.can_walk(spot.stand,20) and spot.stand.distance_to(spot.water)<140,"fish spot %d is near safe walkable shore"%i)
		w.player.position=spot.stand
		check(f.nearest_spot()==i,"same selector finds near fish spot %d"%i)
	await reset_shore()
	await capture("01-lakeshore")
	var original: Vector2=w.player.position
	w.player.position=original+Vector2(-500,0)
	check(f.nearest_spot()==-1 and not f.try_start(),"far from fish cannot interact")
	w.player.position=original
	var held: Dictionary=w.item_service.inventory.equipment.main_hand.duplicate(true)
	w.item_service.inventory.equipment.main_hand={}
	check(not f.try_start(),"without equipped fishing rod cannot begin")
	w.item_service.inventory.equipment.main_hand=held
	w.item_ui.toggle_bag()
	check(not f.try_start(),"open inventory prevents accidental fishing start")
	w.item_ui.close_panels();await frames()
	# Real input starts a new, side-only cast and consumes the E event.
	await key(KEY_E)
	check(f.state=="cast" and w.player.facing=="right","E turns to existing right-side rig and starts cast")
	check(not w.player.is_physics_processing() and w.player.action.is_empty(),"fishing owns movement without leaking a generic tool action")
	f.clock=.30;f.pose()
	var rear_tip: Vector2=f.rod_tip()
	await capture("02-cast-back")
	f.clock=.52;f.pose()
	check(rear_tip.distance_to(f.rod_tip())>35,"side cast changes from backswing to forward delivery")
	await capture("03-cast-forward")
	# Left mirror uses the same rig and keys, with feet/root fixed.
	var arm: Node2D=w.player.character.get_node("Visual/Pelvis/ArmR")
	var rig: Node2D=w.player.character.get_node("Visual")
	var root_position: Vector2=w.player.position
	for facing in ["left","right"]:
		w.player.facing=facing
		for sample in [0.0,.30,.52,.84]:
			f.clock=sample;f.pose()
			check(w.player.animation_player.current_animation=="side_breathe" and w.player.facing in ["left","right"],"side-only native rig "+facing+str(sample))
			check(w.player.position==root_position and rig.scale.x==(-1 if facing=="left" else 1),"fixed feet and native mirror "+facing+str(sample))
			var grip: Vector2=arm.to_global(arm.get_node("Grip").position+Vector2(0,-2.75))
			var source_grip: Vector2=f.rod.to_global(f.rod.offset+Vector2(f.registration.grip_px[0],f.registration.grip_px[1]))
			check(grip.distance_to(source_grip)<.01,"rod remains registered at original hand "+facing+str(sample))
	w.player.facing="right"
	f.advance(.02);await render_state()
	check(f.state=="wait","cast automatically enters waiting")
	check(f.line_points.size()==13 and f.line_points[0].distance_to(f.rod_tip())<.01,"runtime line starts exactly at registered rod tip")
	check(f.line_points[-1].distance_to(f.bobber_position+Vector2(0,-9))<.01,"runtime line terminates at float top")
	check(f.bobber_position.distance_to(f.spots[f.selected].water)<1.1,"float stays on selected water target")
	await capture("04-wait-line-float")
	# World actions, menus, repeats and hotbar keys cannot interrupt the session.
	for code in [KEY_E,KEY_B,KEY_M,KEY_C,KEY_V,KEY_1,KEY_W,KEY_SHIFT]: await key(code)
	check(f.state=="wait" and not w.map_view.visible and not w.item_ui.bag.visible and w.player.position==root_position,"active input consumes menu, movement, E and hotbar keys")
	await key(KEY_SPACE,true)
	check(f.hits==0,"echo cannot submit a timing attempt")
	f.advance(f.wait_time+.02);await render_state()
	check(f.state=="bite" and f.bite_mark.visible and not f.game.visible,"float disappears and large bite cue precedes minigame")
	await capture("05-bite")
	f.advance(.67);await render_state()
	check(f.state=="game" and f.game.visible,"bite opens lightweight timing bar")
	var initial_marker: float=f.bar.marker
	f.advance(.35)
	check(not is_equal_approx(initial_marker,f.bar.marker),"circle marker moves across the bar")
	await capture("06-timing-game")
	var first_safe: float=f.bar.safe_center
	await hit()
	check(f.hits==1 and f.state=="game" and absf(f.bar.safe_center-first_safe)>=.119,"first Space success randomizes safe region")
	await key(KEY_SPACE)
	check(f.hits==1,"rapid repeated Space cannot count as second success")
	f.advance(.30);await hit()
	check(f.state=="success" and f.hits==2,"two successful Space inputs enter success sequence")
	f.advance(.43);await render_state()
	check(not f.game.visible and f.jumping_fish_position().y<Vector2(f.spots[f.selected].water).y-20 and not f.splashes.is_empty(),"success hides bar, lifts fish above water and draws splash")
	await capture("07-fish-jump")
	f.advance(.75)
	check(w.item_service.inventory.count_item(f.FISH_ID)==1 and rewards==[[f.FISH_ID,1]],"successful catch gives exactly one fish through original obtained signal")
	f.commit_reward();f.advance(.01)
	check(w.item_service.inventory.count_item(f.FISH_ID)==1 and rewards.size()==1,"reward has once-only guard")
	await frames();await capture("08-obtained")
	check(w.item_ui.obtained.card.visible and w.item_ui.obtained.caption.text.contains("湖鱼"),"existing obtained FIFO displays real fish icon/name/count")
	f.advance(.8);await render_state()
	check(f.state=="idle" and w.player.is_physics_processing() and not f.blocker.visible,"success restores movement and releases UI")
	# Failure through real keys, then separate timeout path.
	await reset_shore();await key(KEY_E);await advance_to_game()
	for i in 3: await miss()
	check(f.state=="failure" and f.misses==3,"three misses fail")
	check(w.item_service.inventory.count_item(f.FISH_ID)==1 and rewards.size()==1,"failure gives no fish or obtained notification")
	await capture("09-failure")
	f.advance(.8);await key(KEY_E);await advance_to_game()
	for i in 3: f.advance(4.6)
	check(f.state=="failure" and f.misses==3,"three expired rounds fail without trapping player")
	f.advance(.8)
	await key(KEY_E);f.advance(.9);await key(KEY_ESCAPE)
	check(f.state=="idle" and not w.player.input_blocked and f.line_points.is_empty(),"Esc cancels waiting and clears line/lock")
	await key(KEY_E);await advance_to_game();await key(KEY_ESCAPE)
	check(f.state=="idle" and rewards.size()==1,"Esc cancels minigame with no reward")
	await key(KEY_E)
	w.item_service.inventory.equipment.main_hand={};f.advance(.01)
	check(f.state=="idle" and w.player.is_physics_processing(),"equipment loss cancels safely")
	w.item_service.inventory.equipment.main_hand=held;w.item_service.inventory.changed.emit()
	await key(KEY_E);f.set_process(true);f._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);f.set_process(false)
	check(f.state=="idle" and w.player.is_physics_processing(),"losing focus cancels safely")
	# Capacity rejection must not create a phantom reward or alternate inventory.
	var saved_slots: Array=w.item_service.inventory.slots.duplicate(true)
	for i in 40: w.item_service.inventory.slots[i]={"item_id":"stone","count":999}
	await key(KEY_E);await advance_to_game();await hit();f.advance(.30);await hit();f.advance(1.2)
	check(f.reward_committed and f.message.contains("背包已满") and rewards.size()==1,"full inventory releases fish, emits no obtained result")
	f.advance(.8);w.item_service.inventory.slots.assign(saved_slots);w.item_service.inventory.changed.emit()
	# New preview revision: legal random regions, shoreline masking and rare loot.
	var centres := {}
	var zones_valid := true
	for i in 200:
		var previous: float=f.bar.safe_center
		f.randomize_safe_zone()
		zones_valid=zones_valid and f.bar.safe_center>=.16 and f.bar.safe_center<=.84 and absf(f.bar.safe_center-previous)>=.119
		centres[snappedf(f.bar.safe_center,.001)]=true
	check(zones_valid and centres.size()>40 and is_equal_approx(f.bar.safe_width,.21),"200 randomized narrower safe zones stay legal and varied")
	var clipped: Array=f.water_ring_segments(Vector2(f.spots[0].water).lerp(f.spots[0].stand,.5),70)
	var masked_count := 0
	var masked_ok := true
	for segment in clipped:
		masked_count+=segment.size()
		for point in segment: masked_ok=masked_ok and w.generator.sample(point).z>=.8
	check(masked_ok and masked_count>0 and masked_count<222,"ring crossing real irregular shoreline drops land sections")
	var distribution := {f.FISH_ID:0,f.COIN_ID:0,f.CHEST_ID:0}
	for i in 10000: distribution[f.catch_for_roll(float(i)/10000)]+=1
	check(distribution[f.FISH_ID]==9850 and distribution[f.COIN_ID]==100 and distribution[f.CHEST_ID]==50,"loot thresholds exactly fish 98.5 percent coin 1 percent chest 0.5 percent")
	for id in [f.COIN_ID,f.CHEST_ID]:
		check(not ItemDatabase.new().item(id).is_empty() and not w.item_service.database.item(id).is_empty(),"rare item registered formally "+id)
		check(w.item_service.database.item(id).usable==false and is_instance_valid(f.catch_textures[id]),"rare item has candidate texture and no use action "+id)
		await reset_shore();await key(KEY_E);await advance_to_game();f.catch_id=id
		var before_count: int=w.item_service.inventory.count_item(id)
		var before_rewards := rewards.size()
		await hit();f.advance(.30);await hit();f.advance(.43)
		await capture("10-rare-"+id)
		f.advance(.75);f.commit_reward();await frames()
		check(w.item_service.inventory.count_item(id)==before_count+1 and rewards.size()==before_rewards+1 and rewards[-1]==[id,1],"rare success gives exactly one through obtained FIFO "+id)
		check(w.item_ui.obtained.pending.any(func(entry: Dictionary): return str(entry.get("id",""))==id) or w.item_ui.obtained.caption.text.contains(str(w.item_service.database.item(id).name)),"rare result appears in existing obtained UI "+id)
		f.advance(.8)
		await key(KEY_E);await advance_to_game();f.catch_id=id
		for attempt in 3: await miss()
		check(w.item_service.inventory.count_item(id)==before_count+1 and rewards.size()==before_rewards+1,"rare failure gives no loot "+id)
		f.advance(.8)
	check(w.item_service.database.item(f.COIN_ID).description=="闪闪发光，看起来很值钱。","coin description matches requested text")
	# Actual selector also accepts the left-facing branch in a local mirrored test target.
	var old_spot: Dictionary=f.spots[0].duplicate(true)
	f.spots[0].water=w.player.position+Vector2(-112,0)
	check(f.try_start() and w.player.facing=="left","automatic facing selects left, never front/back")
	f.finish("");f.spots[0]=old_spot
	# Exercise real atomic persistence using a test-only destination, then reload it.
	await reset_shore();await key(KEY_E);await advance_to_game();await hit();f.advance(.30);await hit()
	var old_path: String=w.item_service.save_path
	w.item_service.save_path="user://fishing-formal-test.json"
	w.persistent_world=true
	var before_save: int=w.item_service.inventory.count_item(f.FISH_ID)
	f.advance(1.2)
	check(w.item_service.inventory.count_item(f.FISH_ID)==before_save+1,"formal reward commits before notification")
	var saved=JSON.parse_string(FileAccess.get_file_as_string(w.item_service.save_path))
	var restored := ItemInventory.new(w.item_service.database)
	check(restored.restore(saved.slots) and restored.count_item(f.FISH_ID)==before_save+1,"reward survives serialized inventory reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(w.item_service.save_path))
	w.persistent_world=false;w.item_service.save_path=old_path;f.finish("")
	await reset_shore();await key(KEY_E);await advance_to_game();await hit();f.advance(.30);await hit()
	var rollback_slots: Array=w.item_service.inventory.slots.duplicate(true)
	var rollback_rewards := rewards.size()
	w.item_service.save_path="user://missing-fishing-test-dir/invalid.json";w.persistent_world=true
	f.advance(1.2)
	check(w.item_service.inventory.slots==rollback_slots and rewards.size()==rollback_rewards,"save failure rolls back reward and suppresses obtained notice")
	f.commit_reward()
	check(w.item_service.inventory.slots==rollback_slots,"save failure cannot retry into duplicate reward")
	w.persistent_world=false;w.item_service.save_path=old_path;f.finish("")
	var generated_population=load("res://scripts/fishing_population.gd").new()
	generated_population.configure(w.generator)
	var generated: Array[Dictionary]=generated_population.spots
	check(generated.size()>0 and generated.size()<=generated_population.max_schools,"formal lake points respect current sparse population cap")
	var valid := true
	for spot in generated:
		valid=valid and w.generator.can_walk(spot.stand,20) and w.fish_water_clearance(spot.water) and spot.stand.distance_to(spot.water)<175
	check(valid,"formal generated points have walkable banks and full water footprint")
	check(not FileAccess.get_file_as_string("res://scripts/fishing.gd").contains("res://prototypes/"),"formal controller has no candidate dependency")
	check(w.item_service.save_state(),"preview save request is a successful no-op")
	w._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	w.environment_view.save_state()
	check(player_files()==save_before,"all existing player JSON/tmp names and hashes unchanged after play and explicit save/close")
	check(formal_files()==formal_before,"formal entry, configuration, original rod, native rig and production scripts unchanged")
	var phase_history: Array=f.phase_history.duplicate()
	w.free();await frames()
	check(player_files()==save_before,"teardown also leaves player saves untouched")
	var formal_world: Node2D=load("res://tests/world_v06_formal_fixture.gd").new()
	root.add_child(formal_world)
	await frames(4)
	var live_fishing=formal_world.get_node_or_null("Fishing")
	check(live_fishing!=null and live_fishing.spots.size()>0,"ordinary world automatically initializes fishing without preview flag")
	check(formal_world.item_service.inventory.count_item("fishing_rod")==0,"ordinary world does not inject test rods or rewards")
	if live_fishing!=null:
		check(not live_fishing.status_panel.visible,"ordinary idle world has no global fishing tutorial")
	formal_world.free();await frames()
	check(player_files()==save_before,"ordinary-world isolated fixture also preserves player files")
	finish_report(phase_history)
	quit(1 if checks.any(func(row: Dictionary): return not row.pass) else 0)

func finish_report(history: Array=[]) -> void:
	var report := {"engine":Engine.get_version_info().string,"resolution":[1280,720],"display":DisplayServer.get_name(),"checks":checks,"pass":checks.filter(func(row: Dictionary): return row.pass).size(),"fail":checks.filter(func(row: Dictionary): return not row.pass).size(),"player_save_files_compared":save_before.size(),"formal_hashes":formal_before,"phases":history,"captured":capture_enabled}
	var file := FileAccess.open(OUT+("window-results.json" if capture_enabled else "headless-results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("FISHING_PREVIEW ",report.pass," pass / ",report.fail," fail; saves compared ",save_before.size())
