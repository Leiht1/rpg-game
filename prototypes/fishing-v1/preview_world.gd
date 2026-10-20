extends "res://tests/world_v06_formal_fixture.gd"
## Run this scene directly or with F6. This fixture never loads or writes player saves.
var fishing: Node2D
var fishing_ready := false
var preview_error := ""

func load_world_identity(_path: String=WORLD_ID_PATH) -> void:
	world_seed=271828
	map_cells=1024
	persistent_world=false

func _ready() -> void:
	Engine.max_fps=60
	set_process(false)
	call_deferred("initialize_preview")

func initialize_preview() -> void:
	Engine.set_meta("fishing_preview_fixture",true)
	super._ready()
	Engine.remove_meta("fishing_preview_fixture")
	set_process(true)
	DisplayServer.window_set_title("风栖原野 · 钓鱼 V1 候选预览 · 不保存")
	call_deferred("arrange_fishing")

func arrange_fishing() -> void:
	player.input_blocked=true
	player.set_physics_process(false)
	var spots := find_shore_spots()
	if spots.size()<3:
		preview_error="未找到足够的安全湖岸"
		loading_label.text=preview_error
		push_error(preview_error)
		return
	player.position=spots[0].stand
	player.facing="right" if spots[0].water.x>player.position.x else "left"
	stream.update_target(player.position)
	while not stream.viewport_ready(player.position,get_viewport_rect().size/(player.camera.zoom*2)):
		await get_tree().process_frame
	# Clear only the test shoreline; never edit generated terrain or formal resources.
	for prop in object_root.get_children():
		if prop==player: continue
		for spot in spots:
			if prop is Node2D and prop.position.distance_to(spot.stand)<145:
				prop.hide()
				prop.set_meta("spent",true);prop.set_meta("collected",true)
				if prop is CollisionObject2D: prop.collision_layer=0
				for body_node in prop.find_children("*","CollisionObject2D",true,false): body_node.collision_layer=0
				break
	# Candidate overrides exist only in this ItemDatabase instance.
	var rod: Dictionary=item_service.database.item("fishing_rod")
	rod.icon="res://prototypes/fishing-v1/art/rod.res"
	rod.world_visual=rod.icon
	item_service.database.definitions.fishing_rod=rod
	var fish: Dictionary=item_service.database.item("wild_berry")
	fish.merge({"item_id":"preview_lake_fish","name":"湖鱼（候选）","description":"钓鱼预览收获，仅本次临时世界保留。","icon":"res://prototypes/fishing-v1/art/fish.res","world_visual":"res://prototypes/fishing-v1/art/fish.res","usable":false,"use_action":"","consumable":false,"category":"material","tags":["fishing_preview"]},true)
	item_service.database.definitions.preview_lake_fish=fish
	for extra in [{"id":"preview_gold_coin","name":"金币","description":"闪闪发光，看起来很值钱。","art":"coin"},{"id":"preview_locked_chest","name":"密码锁宝箱","description":"带着密码锁的宝箱。","art":"locked_chest"}]:
		var definition: Dictionary=fish.duplicate(true)
		definition.merge({"item_id":extra.id,"name":extra.name,"description":extra.description,"icon":"res://prototypes/fishing-v1/art/"+extra.art+".res","world_visual":"res://prototypes/fishing-v1/art/"+extra.art+".res"},true)
		item_service.database.definitions[extra.id]=definition
	var registration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://prototypes/fishing-v1/art/registration.json"))
	player.held_tool.definitions["tool:fishing_rod"]={"texture":rod.icon,"grip_px":registration.grip_px,"scale":registration.scale,"rotation_degrees":0,"hand_offset":[0,-2.75],"stance_degrees":{"side":-30,"front":-20,"back":-20}}
	item_ui.portrait_held_tool.definitions["tool:fishing_rod"]=player.held_tool.definitions["tool:fishing_rod"].duplicate(true)
	item_service.inventory.slots[0]=item_service.inventory.instance("fishing_rod")
	item_service.inventory.equip(0)
	item_service.inventory.changed.emit()
	player.moving=false;player.running=false;player.update_animation()
	player.camera.offset=Vector2(110 if player.facing=="right" else -110,-10)
	player.reset_physics_interpolation();player.camera.reset_smoothing()
	# Keep the approved daylight/water renderer. No new terrain art or lake geometry.
	environment_view.simulation.set_time(10.0)
	fishing=preload("res://prototypes/fishing-v1/fishing_preview.gd").new()
	add_child(fishing)
	fishing.configure(self,spots)
	title.text="钓鱼 V1 · 候选预览 · 不保存"
	title.add_theme_font_size_override("font_size",22)
	hint.hide()
	player.input_blocked=false;player.set_physics_process(true)
	fishing_ready=true
	print("FISHING_PREVIEW_SCENE ready: 3 shoreline points; persistent_world=",persistent_world)

func find_shore_spots() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	# Search the western bank first, keeping three points in one walkable neighbourhood.
	for lake in generator.lakes:
		var center := Vector2(lake.x,lake.y)
		for step in 25:
			var angle := PI+(float(step)-12.0)*.045
			var outward := Vector2.from_angle(angle)
			var previous_water := false
			for radius in range(80,2200,8):
				var point := center+outward*float(radius)
				var is_water := generator.sample(point).z>.56
				if previous_water and not is_water:
					var stand := point+outward*40
					if not generator.can_walk(stand,20): break
					var water := Vector2.ZERO
					var found_water := false
					# Search around the local shoreline, then test the whole effect footprint.
					# Centre-only tests fail on coves, tips and irregular shallow edges.
					for depth in range(64,121,8):
						for tangent in [0,-16,16,-32,32]:
							var candidate := point-outward*depth+outward.orthogonal()*float(tangent)
							if stand.distance_to(candidate)<172 and fish_water_clearance(candidate):
								water=candidate;found_water=true;break
						if found_water: break
					if not found_water: break
					var separate := true
					for old in result:
						if old.water.distance_to(water)<140 or old.stand.distance_to(stand)>650: separate=false
					if separate: result.append({"stand":stand,"water":water})
					break
				previous_water=is_water
			if result.size()==3: return result
		# Do not mix distant lakes into this compact preview.
		result.clear()
	return result

func fish_water_clearance(at: Vector2) -> bool:
	# Includes the largest 52x16 ripple, offset secondary ring, splash and margin.
	for y in range(-24,25,8):
		for x in range(-60,61,8):
			if generator.sample(at+Vector2(x,y)).z<.8: return false
	return true
