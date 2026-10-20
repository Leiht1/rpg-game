extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=load("res://prototypes/scene-study-v07/preview.tscn").instantiate()
	root.add_child(w)
	while not w.ready_for_review:await process_frame
	var props_before=[]
	for p in w.review_props:props_before.append([p.position,p.display_size,p.get_meta("prop_id")])
	for key in ["before","after"]:
		w.apply_art(key=="after")
		for i in 4:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://prototypes/scene-study-v07/"+key+".png")
	var unchanged:=true
	for i in w.review_props.size():
		var p=w.review_props[i]
		unchanged=unchanged and props_before[i]==[p.position,p.display_size,p.get_meta("prop_id")]
	var result={"engine":Engine.get_version_info().string,"seed":w.world_seed,"viewport":str(root.size),"same_positions_sizes_ids":unchanged,"props":w.review_props.size(),"player_at_spawn":w.player.position==w.generator.spawn,"no_player_processing":not w.player.is_physics_processing(),"static_review":true,"status":"pending_user"}
	FileAccess.open("res://prototypes/scene-study-v07/runtime-checks.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print(JSON.stringify(result))
	quit()
