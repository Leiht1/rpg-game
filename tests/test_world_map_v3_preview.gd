extends SceneTree
var checks: Array=[]
func _initialize() -> void:call_deferred('run')
func check(ok: bool,name: String) -> void:
	checks.append({'pass':ok,'name':name})
	if not ok:push_error(name)
func run() -> void:
	Engine.max_fps=60;root.get_node('AudioFX').muted=true
	var resume:=OS.get_cmdline_user_args().has('--resume')
	var w=load('res://scripts/world_map_v3_preview.gd').new();root.add_child(w)
	while not w.started:await process_frame
	if resume:check(not w.environment_view.simulation.paused,"actual preview resumes normal world time")
	w.environment_view.simulation.paused=true
	check(w.item_service.writable and w.map_cells==1536,'actual preview loads 1536 playable world')
	check(w.item_service.save_path=='user://world-map-v3-preview/state.json','actual preview isolated world bundle')
	check(w.environment_view.save_path.is_empty(),'preview never writes formal environment')
	var evidence:='res://reports/world-map-v3/preview-session.json'
	if resume:
		var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(evidence))
		check(w.world_seed==previous.seed and w.world_id==previous.world_id,'actual preview resumes same random identity')
		check(w.player.position.distance_to(Vector2(previous.x,previous.y))<.01,'actual preview resumes saved position')
		check(w.item_service.exploration.serialize().bits==previous.bits,'actual preview resumes exploration')
	else:
		w.player.automated=true;w.player.input_override=Vector2.RIGHT
		for i in 40:await physics_frame
		w.player.input_override=Vector2.ZERO
		check(w.item_service.save_state(),'actual preview saves on original transaction path')
		var x: float=w.player.position.x;var y: float=w.player.position.y
		FileAccess.open(evidence,FileAccess.WRITE).store_string(JSON.stringify({'world_id':w.world_id,'seed':w.world_seed,'x':x,'y':y,'bits':w.item_service.exploration.serialize().bits}))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png('res://reports/world-map-v3/00-playable-world.png')
	var failed:=checks.filter(func(c):return not c.pass).size()
	FileAccess.open('res://reports/world-map-v3/preview-'+('resume' if resume else 'create')+'.json',FileAccess.WRITE).store_string(JSON.stringify({'checks':checks,'failed':failed},'  '));print('ACTUAL PREVIEW ',checks.size(),' checks ',failed,' failures')
	if failed>0:quit(1)
	else:
		w.environment_view.simulation.paused=false
		w._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
