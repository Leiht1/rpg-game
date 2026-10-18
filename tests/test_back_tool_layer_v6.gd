extends SceneTree
const OUT := "res://reports/back-layer-floor-v6/"
var checks: Array=[]
var pixels: Array=[]
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks.append({"name":label,"pass":ok})
	if not ok: push_error(label)
func capture(view: SubViewport) -> Image:
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func different(a: Color,b: Color) -> bool:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))>3.1/255
func run():
	DirAccess.make_dir_recursive_absolute(OUT)
	var view := SubViewport.new();view.size=Vector2i(320,320);view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
	var bg := ColorRect.new();bg.color=Color("8aa956");bg.size=Vector2(320,320);view.add_child(bg)
	var p=preload("res://scripts/player.gd").new()
	p.actor=JSON.parse_string(FileAccess.get_file_as_string("res://assets/hero/cartoon/runtime.json"))
	p.character=load("res://assets/hero/cartoon/character.tscn").instantiate();p.character.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;p.character.position=Vector2(32,0);p.character.scale=Vector2.ONE*2;view.add_child(p.character)
	p.animation_player=p.character.get_node("AnimationPlayer");p.animation_player.add_animation_library("harvest",load("res://assets/hero/cartoon/harvest_actions.tres"));p.animation_player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	p.carried_wood=Sprite2D.new();p.character.add_child(p.carried_wood)
	var inv := ItemInventory.new(ItemDatabase.new());p.equipment_inventory=inv
	var mask := SubViewport.new();mask.size=view.size;mask.world_2d=World2D.new();mask.transparent_bg=true;mask.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(mask)
	var leg_copies: Array=[]
	for path in ["Visual/LegL/Sprite","Visual/LegR/Sprite"]:
		var copy := Sprite2D.new();copy.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;mask.add_child(copy);leg_copies.append(copy)
	var total_repaired := 0
	for row in [["stone_axe","chop",.82],["stone_pickaxe","mine",1.12],["simple_shovel","dig",1.25],["stone_hammer","demolish",1.12]]:
		inv.equipment.main_hand=inv.instance(row[0]);var repaired := 0;var bad := 0;var details: Array=[]
		for fraction in [0.0,.12,.28,.48,.65,.82,.98,-1.0]:
			p.facing="back";p.action=row[1];p.action_clock=float(row[2])*fraction;p.update_animation()
			var source: Sprite2D=p.character.get_node("Visual/Pelvis/ArmR/HeldTool");var rear: Sprite2D=p.held_tool.rear_tool
			var visual: Node2D=p.character.get_node("Visual")
			check(rear.visible and not source.visible and rear.get_meta("item_id")==row[0],"one visible rear tool "+row[0]+str(fraction))
			check(rear.get_parent()==visual and rear.get_index()<visual.get_node("LegL").get_index() and rear.get_index()<visual.get_node("LegR").get_index() and rear.show_behind_parent and rear.z_index==0,"local order behind both legs "+row[0]+str(fraction))
			check(rear.global_transform.is_equal_approx(source.global_transform),"exact animated grip transform "+row[0]+str(fraction))
			if fraction<0:
				# Deliberately cross the leg interior to test every tool's actual GPU occlusion.
				source.global_position=p.character.get_node("Visual/LegL").global_position+Vector2(0,18)
				p.held_tool.show_behind_legs(p.character,source)
			var fixed := await capture(view)
			if fraction==.48: fixed.save_png(OUT+"back-fixed-"+row[0]+".png")
			rear.hide();source.show();var before := await capture(view)
			if fraction==.48: before.save_png(OUT+"back-before-"+row[0]+".png")
			source.hide();var reference := await capture(view)
			for i in 2:
				var original: Sprite2D=p.character.get_node("Visual/"+("LegL" if i==0 else "LegR")+"/Sprite")
				var copy: Sprite2D=leg_copies[i];copy.texture=original.texture;copy.global_transform=original.global_transform;copy.centered=original.centered;copy.offset=original.offset;copy.flip_h=original.flip_h;copy.flip_v=original.flip_v
			var legs := await capture(mask)
			if fraction<0:
				before.save_png(OUT+"stress-before-"+row[0]+".png");fixed.save_png(OUT+"stress-fixed-"+row[0]+".png");legs.save_png(OUT+"stress-legs-"+row[0]+".png")
			for y in range(2,318):
				for x in range(2,318):
					# Exclude antialiased contours: their translucent pixels correctly reveal the tool.
					var solid := true
					for dy in range(-1,2):
						for dx in range(-1,2):
							if legs.get_pixel(x+dx,y+dy).a<.99: solid=false
					if not solid: continue
					var ref := reference.get_pixel(x,y)
					if different(before.get_pixel(x,y),ref):
						if different(fixed.get_pixel(x,y),ref):
							bad+=1;details.append({"x":x,"y":y,"phase":fraction,"mask_alpha":legs.get_pixel(x,y).a,"fixed":str(fixed.get_pixel(x,y)),"reference":str(ref)})
						else: repaired+=1
		check(repaired>0 and bad==0,"GPU leg overlap restored "+row[0]);total_repaired+=repaired
		pixels.append({"tool":row[0],"repaired_leg_pixels":repaired,"remaining_wrong_leg_pixels":bad,"details":details})
		for state in ["","walk","run"]:
			p.action="";p.moving=state!="";p.running=state=="run";p.update_animation()
			check(p.held_tool.rear_tool.visible,"rear idle/movement "+row[0]+state)
		p.moving=false;p.running=false
		for direction in ["front","left","right"]:
			p.facing=direction;p.action=row[1];p.update_animation()
			check(not p.held_tool.rear_tool.visible and p.character.get_node("Visual/Pelvis/ArmR/HeldTool").visible,"other direction restores native tool "+row[0]+direction)
		p.facing="back";p.action="pickup";p.update_animation();check(not p.held_tool.rear_tool.visible,"pickup hides rear tool "+row[0])
		p.action="";inv.equipment.clear();p.update_animation();check(not p.held_tool.rear_tool.visible,"unequip hides rear tool "+row[0])
	check(total_repaired>0,"GPU reproduced and repaired actual overlap")
	var failed: Array=checks.filter(func(v): return not v.pass)
	FileAccess.open(OUT+"back-layer-tests.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed.size(),"pixels":pixels},"  "))
	print("BACK TOOL LAYER: %d checks, %d failed; %d repaired leg pixels"%[checks.size(),failed.size(),total_repaired])
	p.held_tool.clear_strike_layer();p.camera.free();p.free();view.free();mask.free();await process_frame;quit(0 if failed.is_empty() else 1)
