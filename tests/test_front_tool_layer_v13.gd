extends SceneTree
const OUT := "res://reports/front-tool-layer-v13/"
var checks: Array=[]
var metrics: Array=[]
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func frames(n: int=2) -> void:
	for i in n: await process_frame
func capture(view: SubViewport) -> Image:
	await frames();await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func diff(a: Color,b: Color) -> bool:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>3.1/255.0
func alpha_at(sprite: Sprite2D,point: Vector2) -> float:
	var local := sprite.to_local(point)-sprite.offset
	if sprite.centered: local+=sprite.texture.get_size()*.5
	var image: Image=sprite.texture.get_image()
	var uv := Vector2i(local)
	if uv.x<0 or uv.y<0 or uv.x>=image.get_width() or uv.y>=image.get_height(): return 0.0
	return image.get_pixelv(uv).a
func copy_sprite(source: Sprite2D,parent: Node) -> Sprite2D:
	var copy := Sprite2D.new();copy.texture=source.texture;copy.centered=source.centered;copy.offset=source.offset
	copy.texture_filter=source.texture_filter;copy.flip_h=source.flip_h;copy.flip_v=source.flip_v
	parent.add_child(copy);copy.global_transform=source.global_transform
	return copy
func pose(p: Node) -> void:
	p.update_animation()
	p.character.position=Vector2(32,32)
func blade_forward(p: Node) -> bool:
	var source: Sprite2D=p.held_tool.rear_tool if p.facing=="back" else p.character.get_node("Visual/Pelvis/ArmR/HeldTool")
	var tip := source.to_global(source.offset+Vector2(128,75))
	var handle := source.to_global(source.offset+Vector2(128,161))
	var wanted: Vector2={"front":Vector2.DOWN,"back":Vector2.UP,"left":Vector2.LEFT,"right":Vector2.RIGHT}[p.facing]
	return handle.direction_to(tip).dot(wanted)>.999
func run() -> void:
	Engine.max_fps=60
	var expected := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width",1280),ProjectSettings.get_setting("display/window/size/viewport_height",720))
	check(root.content_scale_size==expected,"application uses default project resolution only")
	# Isolated GPU material/occlusion sampling; no application resolution changes.
	var view := SubViewport.new();view.size=Vector2i(320,320);view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var bg := ColorRect.new();bg.color=Color("8aa956");bg.size=Vector2(320,320);view.add_child(bg)
	var p=preload("res://scripts/player.gd").new()
	p.actor=JSON.parse_string(FileAccess.get_file_as_string("res://assets/hero/cartoon/runtime.json"))
	p.character=load("res://assets/hero/cartoon/character.tscn").instantiate();p.character.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;p.character.position=Vector2(32,0);p.character.scale=Vector2.ONE*2;view.add_child(p.character)
	p.animation_player=p.character.get_node("AnimationPlayer");p.animation_player.add_animation_library("harvest",load("res://assets/hero/cartoon/harvest_actions.tres"));p.animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	p.carried_wood=Sprite2D.new();p.character.add_child(p.carried_wood)
	p.animation_player.add_animation_library("camp",load("res://assets/hero/cartoon/campfire_throw.tres"))
	Engine.set_meta("industry_preview",false)
	var inv := ItemInventory.new(ItemDatabase.new());p.equipment_inventory=inv
	var arm: Node2D=p.character.get_node("Visual/Pelvis/ArmR")
	var hand: Sprite2D=arm.get_node("Sprite")
	var torso: Sprite2D=p.character.get_node("Visual/Pelvis/Torso")
	var reference := SubViewport.new();reference.size=view.size;reference.world_2d=World2D.new();reference.render_target_update_mode=SubViewport.UPDATE_ALWAYS;reference.transparent_bg=true;root.add_child(reference)
	var overlays := Node2D.new();reference.add_child(overlays)
	var total_repaired := 0
	for row in [["stone_axe","chop",.82],["stone_pickaxe","mine",1.12],["simple_shovel","dig",1.25],["stone_hammer","demolish",1.12],["copper_axe","chop",.82],["copper_pickaxe","mine",1.12],["copper_shovel","dig",1.25],["copper_hammer","demolish",1.12],["shears","shear",.72]]:
		inv.equipment.main_hand=inv.instance(row[0]);p.facing="front"
		for phase in [0.0,.2,.48,.7,.98]:
			p.action=row[1];p.action_clock=float(row[2])*phase;pose(p)
			var tool: Sprite2D=arm.get_node("HeldTool")
			if row[0]=="shears": check(blade_forward(p),"shears front blade forward "+str(phase))
			check(not arm.show_behind_parent and arm.z_index==0 and tool.z_index==0 and hand.z_index==0,"local front layer after native animation "+row[0]+str(phase))
			check(arm.get_index()>torso.get_index() and tool.get_index()>hand.get_index() and tool.visible and hand.visible,"shirt then original palm then tool "+row[0]+str(phase))
			check(not is_instance_valid(p.held_tool.strike_layer) or not p.held_tool.strike_layer.visible,"front does not add world sorting layer "+row[0]+str(phase))
			var free_arm: Node2D=p.character.get_node("Visual/Pelvis/ArmL")
			check(free_arm.rotation>=.079 and free_arm.rotation<=.241,"empty palm stays outward of work grip "+row[0]+str(phase))
			check(p.held_tool.front_free_hand.visible and not p.character.get_node("Visual/ArmLBehind").visible,"one visible front free arm "+row[0]+str(phase))
			check(alpha_at(torso,arm.global_position)>.98 and alpha_at(hand,arm.global_position)>.98,"held shoulder has opaque contact with shirt "+row[0]+str(phase))
			check(alpha_at(torso,free_arm.global_position)>.98 and alpha_at(p.held_tool.front_free_hand,free_arm.global_position)>.98,"free shoulder has opaque contact with shirt "+row[0]+str(phase))
		# Check the real, unmodified pose: the free arm must change visible GPU pixels.
		p.action_clock=float(row[2])*.48;pose(p)
		var both_arms: Image=await capture(view);both_arms.save_png(OUT+"natural-"+row[0]+".png")
		p.held_tool.front_free_hand.hide();var hidden_free: Image=await capture(view);p.held_tool.front_free_hand.show()
		var free_pixels := 0
		for y in 320:
			for x in 320:
				if diff(both_arms.get_pixel(x,y),hidden_free.get_pixel(x,y)): free_pixels+=1
		check(free_pixels>0,"GPU free hand actually visible in natural pose "+row[0])
		for child in overlays.get_children(): overlays.remove_child(child);child.free()
		var grip_tool := copy_sprite(arm.get_node("HeldTool"),overlays)
		var tool_mask: Image=await capture(reference)
		grip_tool.hide()
		copy_sprite(hand,overlays)
		var hand_mask: Image=await capture(reference)
		var grip_samples := 0;var grip_wrong := 0
		for y in 320:
			for x in 320:
				var tc := tool_mask.get_pixel(x,y)
				if tc.a>.99 and hand_mask.get_pixel(x,y).a>.99 and diff(tc,hand_mask.get_pixel(x,y)):
					grip_samples+=1
					if diff(both_arms.get_pixel(x,y),tc): grip_wrong+=1
		check(grip_samples>0 and grip_wrong==0,"GPU tool covers original hand at natural grip "+row[0])
		for child in overlays.get_children(): overlays.remove_child(child);child.free()
		var free_copy := copy_sprite(p.held_tool.front_free_hand,overlays)
		var free_mask: Image=await capture(reference)
		var palm_pixels := {}
		var texture_size: Vector2=free_copy.texture.get_size()
		for sy in range(int(texture_size.y*.74),int(texture_size.y)):
			for sx in range(int(texture_size.x)):
				var point := Vector2i(free_copy.to_global(Vector2(sx,sy)-texture_size*.5))
				if point.x<0 or point.y<0 or point.x>=320 or point.y>=320: continue
				var color: Color=free_mask.get_pixelv(point)
				if color.a>.99 and not diff(both_arms.get_pixelv(point),color): palm_pixels[point]=true
		check(palm_pixels.size()>=4,"GPU empty palm itself visible, not only sleeve "+row[0])
		# Force an overlap at the chest to test actual occlusion, with original transforms otherwise.
		p.action_clock=float(row[2])*.48;pose(p)
		var tool: Sprite2D=arm.get_node("HeldTool")
		var original_arm_transform: Transform2D=arm.transform
		arm.global_position+=torso.global_position-hand.global_position
		for child in overlays.get_children(): overlays.remove_child(child);child.free()
		var hand_copy := copy_sprite(hand,overlays);var tool_copy := copy_sprite(tool,overlays)
		var mask: Image=await capture(reference)
		var fixed: Image=await capture(view)
		arm.show_behind_parent=true;var old: Image=await capture(view)
		arm.show_behind_parent=false
		var repaired := 0;var wrong := 0;var samples := 0
		for y in range(1,319):
			for x in range(1,319):
				var color: Color=mask.get_pixel(x,y)
				if color.a<.999: continue
				if diff(old.get_pixel(x,y),color):
					samples+=1
					if diff(fixed.get_pixel(x,y),color): wrong+=1
					else: repaired+=1
		check(repaired>0 and wrong==0,"GPU tool/palm visible over shirt "+row[0])
		metrics.append({"tool":row[0],"repaired":repaired,"wrong":wrong,"samples":samples});total_repaired+=repaired
		old.save_png(OUT+row[0]+"-before.png");fixed.save_png(OUT+row[0]+"-after.png")
		arm.transform=original_arm_transform
		pose(p);var sampled_behind: bool=p.held_tool.front_arm_was_behind
		var original_right: Vector2=p.held_tool.front_arm_position;var original_left: Vector2=p.held_tool.front_free_arm_position;var original_free_rotation: float=p.held_tool.front_free_arm_rotation
		p.held_tool.release_pose()
		check(arm.show_behind_parent==sampled_behind,"release restores original sampled arm layer "+row[0])
		check(arm.position==original_right and p.character.get_node("Visual/Pelvis/ArmL").position==original_left and is_equal_approx(p.character.get_node("Visual/Pelvis/ArmL").rotation,original_free_rotation) and not p.held_tool.front_free_hand.visible and p.character.get_node("Visual/ArmLBehind").visible,"release restores both mounts and original rear free arm "+row[0])
		for direction in ["back","left","right"]:
			p.facing=direction;pose(p)
			if row[0]=="shears": check(blade_forward(p),"shears blade forward on turn "+direction)
			check(p.held_tool.front_arm==null,"front override removed on turn "+row[0]+direction)
			check(tool.get_index()<hand.get_index(),"turn restores hand above tool "+row[0]+direction)
			if direction=="back": check(p.held_tool.rear_tool.visible and not tool.visible,"back retains tool behind legs "+row[0])
		p.facing="front";p.action="pickup";pose(p);check(not tool.visible and p.held_tool.front_arm==null,"pickup restores native layers and hides tool "+row[0])
		p.action="";inv.equipment.clear();pose(p);check(not tool.visible and p.held_tool.front_arm==null,"unequip clears front override "+row[0])
	# Synthetic future registration uses existing art only in the fixture, no per-ID workaround.
	var future: Dictionary=inv.database.item("simple_shovel");future.item_id="fixture_future_tool";future.visual_id="fixture:future_tool";inv.database.definitions[future.item_id]=future
	p.held_tool.definitions[future.visual_id]=p.held_tool.definitions["tool:simple_shovel"].duplicate(true)
	inv.equipment.main_hand=inv.instance(future.item_id);p.facing="front";p.action="";pose(p)
	p.held_tool.release_pose();arm.show_behind_parent=true;p.held_tool.apply(p.character,inv,"front","future_work")
	check(not arm.show_behind_parent and arm.get_node("HeldTool").visible,"new ID and new action inherit default front layering")
	p.held_tool.release_pose();check(arm.show_behind_parent,"future tool layer also restores on release")
	check(total_repaired>0,"rendered overlap reproduced and repaired")
	var idle_sheet := Image.create(1920,1280,false,Image.FORMAT_RGBA8)
	var idle_tools := ["copper_axe","copper_pickaxe","copper_shovel","copper_hammer","fishing_rod","shears"]
	for column in idle_tools.size():
		inv.equipment.main_hand=inv.instance(idle_tools[column]);p.action=""
		for direction in 4:
			p.facing=["front","back","left","right"][direction];pose(p)
			var held: Sprite2D=arm.get_node("HeldTool")
			check((held.get_index()>hand.get_index())==(direction==0),"idle tool order follows view "+idle_tools[column]+p.facing)
			idle_sheet.blit_rect(await capture(view),Rect2i(0,0,320,320),Vector2i(column*320,direction*320))
	idle_sheet.save_png(OUT+"candidate-idle-four-views.png")
	p.held_tool.clear_strike_layer();p.camera.free();p.free();view.free();reference.free()
	# Formal world uses the same component after real Player.update_animation sampling.
	Engine.set_meta("integration_seed",271828)
	var world: Node=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(world)
	while not world.started: await process_frame
	world.player.set_physics_process(false);world.environment_view.simulation.paused=true
	world.player.camera.position_smoothing_enabled=false
	for row in [["stone_axe","chop"],["stone_pickaxe","mine"],["simple_shovel","dig"],["stone_hammer","demolish"]]:
		world.item_service.inventory.equipment.main_hand=world.item_service.inventory.instance(row[0]);world.player.equipment_inventory=world.item_service.inventory
		world.player.facing="front";world.player.action=row[1];world.player.action_clock=.4;world.player.update_animation()
		check(not world.player.character.get_node("Visual/Pelvis/ArmR").show_behind_parent,"formal world front action "+row[0])
		if DisplayServer.get_name()!="headless":
			await frames();await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"world-"+row[0]+".png")
	world.player.cancel_action();world.player.update_animation()
	check(world.player.held_tool.front_arm!=null,"idle held front also uses same safe layering")
	var failed := checks.filter(func(c):return not c.pass).size()
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"pixels":metrics},"  "))
	print("FRONT TOOL LAYER: ",checks.size()," checks; ",failed," failures; ",total_repaired," repaired pixels")
	world.item_service.dirty=false;world.queue_free();await frames(6);quit(0 if failed==0 else 1)



