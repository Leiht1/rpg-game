extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://prototypes/biome-v01/preview.tscn").instantiate()
	root.add_child(scene)
	var layout=load("res://prototypes/biome-v01/layout.gd")
	var a=layout.objects(271828)
	var counts=[0,0,0,0,0]
	var trees=[0,0,0,0,0]
	var rocks=[0,0,0,0,0]
	var clear=true
	var dry=true
	for o in a:
		counts[o.biome]+=1
		if o.kind=="tree":trees[o.biome]+=1
		if o.kind=="rock":rocks[o.biome]+=1
		clear=clear and o.p.distance_to(layout.CENTERS[0])>=230
		dry=dry and layout.lake(o.p)>=1.14
	var checks={"repeatable":a==layout.objects(271828),"seed_changes_props":a!=layout.objects(271829),"spawn_clear":clear,"no_lake_props":dry,"forest_more_trees":trees[1]>trees[4],"mountain_more_rocks":rocks[2]>rocks[0]}
	for i in 5:checks["center_"+str(i)]=layout.biome(layout.CENTERS[i])==i
	var report={"version":layout.VERSION,"checks":checks,"object_counts":counts,"trees":trees,"rocks":rocks}
	FileAccess.open("res://reports/biome-v01-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	for i in range(-1,5):
		scene.focus(i)
		for frame in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/biome-v01-"+("overview" if i<0 else str(i+1))+".png")
	print(JSON.stringify(report))
	quit()
