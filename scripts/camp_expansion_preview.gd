extends "res://scripts/world.gd"
var preview_center := Vector2.ZERO
var demonstration_ids: Array[String]=[]
var volume_label: Label

func load_world_identity(_path: String=WORLD_ID_PATH) -> void:
	world_seed=271828;map_cells=1024;persistent_world=false
	Engine.set_meta("camp_expansion_preview",true)

func save_world_identity(_path: String=WORLD_ID_PATH) -> void:pass

func _ready() -> void:
	super._ready()
	while not started:await get_tree().process_frame
	while not stream.viewport_ready(player.position,Vector2(640,360)):await get_tree().process_frame
	var s: Node=item_service
	for i in 40:s.inventory.slots[i]={}
	for key in ["wood","stone","plant_fiber","flint","copper_parts","copper_plate","metal_connector","silver_ingot"]:s.inventory.add(key,99)
	for key in ["stone_hammer","copper_axe","shears","fishing_rod"]:s.inventory.add(key,1)
	for value in s.inventory.slots:
		if value.get("item_id","") in ["copper_axe","shears","fishing_rod"]:value.durability=20
	for key in ["lake_fish","roasted_fish","carrot_seed","compost_fertilizer"]:s.inventory.add(key,6)
	s.inventory.slots[0]={"item_id":"lake_fish","count":6,"spoilage":1.0}
	for food in ["roasted_fish","smoked_fish"]:
		s.inventory.add_value({"item_id":food,"count":2,"spoilage":1.0})
	# Deterministic exhibition: all registered buildings plus the separate campfire.
	# These are isolated fixtures; never charge construction materials or write player saves.
	var rows := [
		["wood_chest","compost_bin","camp_torch","signpost","copper_lamp","campfire","feed_trough"],
		["reinforced_cabinet","refrigerator","workbench","precision_repair_bench","fuel_supply_box","copper_oven","metal_workbench"],
		["stone_furnace","advanced_smokehouse","wood_bed","straw_mat","sleeping_bag","tilled_soil","wool_carpet"],
		["wood_fence","fence_gate","stone_wall","stone_gate","wood_floor","stone_path"]]
	preview_center=Vector2(roundf(player.position.x/96)*96+48,roundf(player.position.y/64)*64+32)
	for y in rows.size():
		for x in rows[y].size():
			var kind: String=rows[y][x]
			var at := preview_center+Vector2((x-3)*192,(y-1.5)*192)
			if kind=="campfire":
				s.camps.states["comparison-campfire"]={"x":at.x,"y":at.y,"fuel":0.0,"lit":false,"recipe":"","elapsed":0.0,"ready":false}
				s.camps.rebuild();s.camps.install(stream.chunk_at(at))
				add_comparison_label("篝火",at)
				continue
			var candidate: Dictionary=s.builds.candidate(kind,at,false,false,0)
			if kind=="signpost":candidate.text="营地"
			var id := "expansion-demo:"+kind
			s.builds.states[id]=candidate;demonstration_ids.append(id)
			add_comparison_label(str(s.builds.definitions[kind].name),Vector2(candidate.x,candidate.y))
	for id in demonstration_ids:
		var row: Dictionary=s.builds.states[id]
		s.builds.install(stream.chunk_at(Vector2(row.x,row.y)))
	player.position=preview_center+Vector2(0,400)
	player.camera.zoom=Vector2.ONE*.65
	# Frame the exhibition on entry; movement resumes the ordinary following camera.
	player.camera.position=Vector2(0,-400)
	player.camera.reset_smoothing();player.reset_physics_interpolation();stream.update_target(preview_center)
	while not stream.viewport_ready(preview_center,Vector2(960,600)):await get_tree().process_frame
	clear_comparison_scenery()
	s.inventory.changed.emit()
	volume_label=Label.new();volume_label.text="全建筑正视对比 · 候选 · 不写入玩家存档";volume_label.position=Vector2(340,12);volume_label.add_theme_font_size_override("font_size",18);ui.add_child(volume_label)

func add_comparison_label(caption: String, at: Vector2) -> void:
	var label := Label.new();label.text=caption;label.position=at+Vector2(-88,30);label.size=Vector2(176,26);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",19);label.add_theme_color_override("font_color",Color("fff5d5"));label.add_theme_color_override("font_outline_color",Color("253a27"));label.add_theme_constant_override("outline_size",5)
	label.z_index=20;add_child(label)

func clear_comparison_scenery() -> void:
	var area := Rect2(preview_center-Vector2(760,490),Vector2(1520,980))
	for node in object_root.get_children():
		if node.get_script()==preload("res://scripts/scenery_prop.gd") and area.has_point(node.position):
			stream.harvested[node.get_meta("prop_id")]=true
			node.hide()
			for body in node.find_children("*","CollisionObject2D",true,false):
				body.collision_layer=0;body.collision_mask=0
