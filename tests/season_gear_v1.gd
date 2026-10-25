extends "res://tests/sleep_v8_fixture.gd"
const Body=preload("res://scripts/body_state.gd")
const Exposure=preload("res://scripts/weather_exposure.gd")
const Catalog=preload("res://scripts/character_catalog.gd")
const GEAR=["wool_sweater","wool_hat","straw_hat","straw_raincoat"]
func condition(temp: float, shade: float=0.0) -> Dictionary:
	return {"rain":0.0,"ambient":temp,"warmth":2.0,"sun_shade":shade,"heat":0.0,"umbrella":false,"shelter":false}
func model(temp: float, shade: float=0.0) -> RefCounted:
	var m=Body.new();m.exposure=condition(temp,shade);return m
func elapse(m: RefCounted, minutes: float, running: bool=false, working: bool=false, moving: bool=false) -> void:
	m.advance(minutes*2.5,minutes,running,working,moving)
func equip(id: String, index: int=0) -> void:
	s.inventory.slots[index]=s.inventory.instance(id);check(s.inventory.equip(index),"equip "+id)
func model_tests() -> void:
	var normal=model(30);elapse(normal,60)
	check(not normal.hot,"peak summer first hour no immediate heat state")
	elapse(normal,480);check(normal.hot,"long unshaded peak summer eventually hot")
	var hat=model(30,2.5);elapse(hat,1440,false,false,true)
	check(not hat.hot and hat.hot_minutes==0,"hat comfortable all-day peak summer walking")
	var sprint=model(30,2.5);elapse(sprint,90,true)
	check(not sprint.hot and sprint.activity_heat>0,"hat normal activity and short running remain gentle")
	elapse(sprint,630,true);check(sprint.hot,"hat permits only very prolonged exertion heat accumulation")
	var labor=model(30,2.5);elapse(labor,90,false,true);check(not labor.hot,"hat ordinary labor period safe")
	var cool=model(22);elapse(cool,480,true);check(not cool.hot,"cool-season running does not trigger summer burden")
	var a=model(30);var z=model(30);a.exposure.warmth=12;elapse(a,540);elapse(z,540)
	check(a.hot==z.hot and is_equal_approx(a.heat_temperature,z.heat_temperature),"wool adds no summer heat penalty")
	check(is_equal_approx(a.energy,z.energy) and is_equal_approx(a.health,z.health) and is_equal_approx(a.stamina,z.stamina),"heat adds no health damage consumption or stamina penalty")
	check(is_equal_approx(a.energy_recovery_factor(),.85) and is_equal_approx(hat.energy_recovery_factor(),1.0),"only hot energy recovery factor exactly 85 percent")
	var sleeper=model(30);sleeper.hot=true;sleeper.hot_minutes=120;sleeper.heat_temperature=32;sleeper.energy=10;sleeper.sleeping=true;sleeper.sleep_duration=240
	var rested=model(30);rested.energy=10;rested.sleeping=true;rested.sleep_duration=240
	elapse(sleeper,1);elapse(rested,1)
	check(is_equal_approx(sleeper.energy-10,(rested.energy-10)*.85),"real sleeping recovery 15 percent lower while hot")
	sprint.exposure=condition(22);elapse(sprint,1);check(sprint.hot,"heat does not vanish instantly on cooling")
	elapse(sprint,240);check(not sprint.hot and sprint.hot_minutes==0,"rest in normal temperatures gradually clears heat")
	var saved=a.serialize();var restored=Body.new();check(restored.restore(saved) and restored.hot==a.hot and restored.hot_minutes==a.hot_minutes,"heat roundtrip persistence")
	var before: Dictionary=restored.serialize();saved.summer_heat.minutes=-1;check(not restored.restore(saved) and before==restored.serialize(),"invalid heat rejects atomically")
	saved=a.serialize();saved.erase("summer_heat");check(restored.restore(saved) and not restored.hot and restored.hot_minutes==0,"old save neutral heat defaults")
	var wet_values: Array=[]
	for protection in [0,.2,.6,.68,1]:
		var wet=model(16);wet.exposure.rain=1.0;wet.exposure.rain_resistance=protection;wet.exposure.umbrella=protection==1;elapse(wet,60);wet_values.append(wet.wetness)
	check(wet_values[0]>wet_values[1] and wet_values[1]>wet_values[2] and wet_values[2]>wet_values[3] and wet_values[3]>wet_values[4],"rain protection naked hat cape combined umbrella strictly ordered")
	var cold=model(0);var wool=model(0);wool.exposure.warmth=12;elapse(cold,180);elapse(wool,180)
	check(wool.cold_level<cold.cold_level and wool.felt_temperature>cold.felt_temperature,"wool improves original cold model")
	var cold_a=model(4);var cold_b=model(4);cold_a.exposure.sun_shade=2.5;elapse(cold_a,120);elapse(cold_b,120)
	check(is_equal_approx(cold_a.felt_temperature,cold_b.felt_temperature) and cold_a.cold_level==cold_b.cold_level,"shade never changes original cold rules")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://reports/season-gear-v1")
	model_tests()
	Engine.set_meta("integration_seed",271828)
	w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
	while not w.started:await process_frame
	s=w.item_service;v=w.environment_view;b=s.builds
	root.size=default_size();root.content_scale_size=root.size
	w.set_process(false);w.player.set_physics_process(false);s.set_process(false);v.set_process(false)
	check(not w.persistent_world,"isolated test world no player writes")
	check(s.database.errors.is_empty() and s.craft_book.errors.is_empty(),"item and recipe validation")
	for i in 40:s.inventory.slots[i]={}
	for id in ["wool","plant_fiber","wood"]:s.inventory.add(id,80)
	for id in GEAR:
		var request: int=s.new_craft_request()
		check(s.craft_book.available().any(func(r):return r.output_id==id),"formal hand recipe "+id)
		check(s.craft("hand_"+id,1,request).is_empty() and s.inventory.count_item(id)==1,"actual atomic craft "+id)
		check(not s.craft("hand_"+id,1,request).is_empty() and s.inventory.count_item(id)==1,"deduplicate craft "+id)
		check(s.database.item(id).durability==null,"no clothing durability "+id)
	equip("wool_sweater");equip("wool_hat",1)
	check(is_equal_approx(Exposure.sample(s).warmth,12),"head and body warmth stacks plus native base")
	equip("straw_raincoat");equip("straw_hat",1);equip("stone_axe",2)
	check(is_equal_approx(Exposure.sample(s).rain_resistance,.68) and s.inventory.has_capability("chop"),"rain set protects 68 percent with free tool hand")
	equip("rain_umbrella",2);check(Exposure.sample(s).umbrella,"umbrella remains superior and functional")
	await integration_checks()
	await visual_tests()
	var failures := checks.filter(func(c):return not c.pass)
	var f=FileAccess.open("res://reports/season-gear-v1/results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failed":failures.size()},"\t"));f.close()
	print("SEASON_GEAR ",checks.size()," checks ",failures.size()," failed")
	w.queue_free();await frames(3);quit(1 if not failures.is_empty() else 0)
func visual_tests() -> void:
	var vp:=SubViewport.new();vp.size=default_size();vp.transparent_bg=false;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
	var db=s.database
	var fixed_transforms: Dictionary={}
	for hair_id in Catalog.rules().hair:
		var rigs: Array=[]
		for row in 4:
			var inv=ItemInventory.new(db)
			inv.equipment.head=inv.instance("wool_hat" if row<2 else "straw_hat")
			inv.equipment.outfit=inv.instance("wool_sweater" if row<2 else "straw_raincoat")
			for col in 4:
				var facing: String=["front","back","left","right"][col]
				for zoom in [1.0,2.0]:
					var rig: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate();vp.add_child(rig)
					rig.position=Vector2(col*320+(4 if zoom==1 else 80),row*175-40 if zoom==2 else row*175+40);rig.scale=Vector2.ONE*zoom
					var anim: AnimationPlayer=rig.get_node("AnimationPlayer");anim.play(("side" if col>=2 else facing)+"_breathe");anim.seek(0,true);anim.pause()
					var look=preload("res://scripts/character_look.gd").new();look.apply(rig,{"gender":"male" if row%2==0 else "female","hair_id":hair_id,"skin_id":"skin_2"},inv,facing)
					var head: Sprite2D=rig.get_node("Visual/Pelvis/Head/Sprite");var hair: Sprite2D=head.get_node("CharacterHairfront");var original: Texture2D=hair.texture
					var appearance=preload("res://scripts/equipment_appearance.gd").new();appearance.apply(rig,inv,facing);appearance.apply_layers(rig,inv,facing)
					check(hair.texture==original and hair.visible,"original hair preserved %s %s %s"%[hair_id,row,facing])
					var hat: Sprite2D=head.get_node("EquipmentVisual_head_0" if row<2 else "EquipmentVisual_head_1")
					var transform_key: String=("wool" if row<2 else "straw")+facing
					if not fixed_transforms.has(transform_key):fixed_transforms[transform_key]=hat.transform
					check(hat.transform==fixed_transforms[transform_key] and is_equal_approx(hat.scale.x,hat.scale.y),"fixed uniform hat size position across all hair and genders "+transform_key)
					if row>=2:
						check(head.get_node("EquipmentVisual_head_0").show_behind_parent and not hat.show_behind_parent,"far brim behind head near brim in front "+facing)
					if col==0:
						check(not rig.get_node("Visual/Pelvis/ArmR").show_behind_parent and rig.get_node("Visual/Pelvis/ClothingFrontArm").visible and not rig.get_node("Visual/ArmLBehind").visible,"front clothing exactly one foreground empty arm and original right "+str(row))
					if row<2:
						check(rig.get_node("Visual/Pelvis/ArmR/Sprite").material.get_shader_parameter("skin_region")==Vector2(.86,1),"wool fabric excluded from skin tint "+facing)
					rig.set_meta("apparel_test",{"hair":hair,"appearance":appearance,"inventory":inv,"facing":facing,"zoom":zoom,"row":row})
					check(hat.get_index()>hair.get_index() and head.is_ancestor_of(hat),"hat follows actual head outside hair %s %s %s"%[hair_id,row,facing])
					if col==2:rig.get_node("Visual").scale.x=-1;rig.get_node("Visual").position.x=128
					rigs.append(rig)
		await frames(3)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("res://reports/season-gear-v1/hair-"+str(hair_id)+".png")
		if DisplayServer.get_name()!="headless":await verify_seams_gpu(vp,rigs,str(hair_id))
		if DisplayServer.get_name()!="headless" and hair_id in ["unisex_bun","unisex_mohawk"]:
			await verify_clip_gpu(vp,rigs,str(hair_id))
		for rig in rigs:
			var info: Dictionary=rig.get_meta("apparel_test");info.inventory.equipment.head={};info.appearance.apply(rig,info.inventory,info.facing)
			check(info.hair.material==null,"unequip restores complete original hair material "+str(hair_id)+info.facing)
			rig.queue_free()
		await frames(2)
	vp.queue_free()

func verify_clip_gpu(vp: SubViewport, rigs: Array, hair_id: String) -> void:
	for rig in rigs:rig.hide()
	vp.transparent_bg=true
	for rig in rigs:
		var info: Dictionary=rig.get_meta("apparel_test")
		if info.zoom!=1.0 or int(info.row)%2!=0:continue
		var hair: Sprite2D=info.hair
		var probe:=Sprite2D.new();probe.texture=hair.texture;probe.material=hair.material;probe.position=Vector2(640,360);vp.add_child(probe)
		await frames(2);await RenderingServer.frame_post_draw
		var rendered: Image=vp.get_texture().get_image()
		var original: Image=hair.texture.get_image()
		var mask: Image=hair.material.get_shader_parameter("hat_mask").get_image()
		var size: Vector2=hair.material.get_shader_parameter("hat_size")
		var offset: Vector2=hair.material.get_shader_parameter("hat_position")
		var removed:=0;var remaining:=0;var checked:=0
		for y in range(0,original.get_height(),3):
			for x in range(0,original.get_width(),3):
				var point:=Vector2(x,y)-Vector2(original.get_size())*.5
				if point.y>=float(hair.material.get_shader_parameter("clip_below"))-3 or original.get_pixel(x,y).a<.99:continue
				var uv: Vector2=(point-offset)/size+Vector2(.5,.5)
				var outside: bool=uv.x<0 or uv.x>1 or uv.y<0 or uv.y>1
				var q:=Vector2i(uv*Vector2(mask.get_size()))
				if uv.x>=0 and uv.x<=1:
					var join: Image=hair.material.get_shader_parameter("hat_join").get_image()
					if uv.y>=join.get_pixel(clampi(q.x,0,join.get_width()-1),0).r-.01:continue
				if not outside:
					if q.x<2 or q.y<2 or q.x>=mask.get_width()-2 or q.y>=mask.get_height()-2:continue
					outside=true
					for dy in [-2,0,2]:
						for dx in [-2,0,2]:
							if mask.get_pixel(q.x+dx,q.y+dy).a>.001:outside=false
				if not outside:continue
				checked+=1
				if rendered.get_pixel(x+640-original.get_width()/2,y+360-original.get_height()/2).a<.02:removed+=1
				else:remaining+=1
		check((checked>0 or hair_id!="unisex_bun") and remaining==0,"GPU hair beyond fixed hat contour clipped %s %s row%s pixels%s"%[hair_id,info.facing,info.row,removed])
		probe.queue_free();await frames(1)
	vp.transparent_bg=false

func integration_checks() -> void:
	w.player.character_look=Catalog.default_look()
	for outfit in ["wool_sweater","straw_raincoat"]:
		equip(outfit)
		for tool in ["stone_axe","stone_pickaxe","simple_shovel","rain_umbrella"]:
			equip(tool,2)
			w.player.set_equipment(s.inventory)
			for facing in ["front","back","left","right"]:
				w.player.facing=facing;w.player.action="";w.player.update_animation()
				var rig: Node2D=w.player.character
				if facing=="front":
					var original: Sprite2D=rig.get_node("Visual/ArmLBehind")
					var a: Sprite2D=rig.get_node_or_null("Visual/Pelvis/ClothingFrontArm")
					var t: Sprite2D=rig.get_node_or_null("Visual/Pelvis/FrontFreeArm")
					check(not original.visible and ((a!=null and a.visible) != (t!=null and t.visible)),"exactly one foreground left arm with clothing and "+tool)
					check(not rig.get_node("Visual/Pelvis/ArmR").show_behind_parent,"original right hand before clothing "+tool)
				if tool!="rain_umbrella":
					w.player.action={"stone_axe":"chop","stone_pickaxe":"mine","simple_shovel":"dig"}[tool];w.player.action_clock=.2;w.player.update_animation()
					check(rig.get_node("Visual/Pelvis/ArmR/Sprite").texture.resource_path.contains("wool_sweater") if outfit=="wool_sweater" else not rig.get_node("Visual/Pelvis/ArmR/Sprite").texture.resource_path.contains("wool_sweater"),"animated right sleeve follows actual tool pose "+outfit+tool+facing)
				w.player.action="";w.player.update_animation()
	w.player.facing="front";w.item_ui.update_portrait(0)
	check(w.item_ui.preview_actor.get_node("Visual/Pelvis/ClothingFrontArm").visible,"inventory portrait uses front clothing layers")
	var body_before: Dictionary=s.body.serialize();s.body.hot=true;s.body.cold_level=0
	w.item_ui.body_ui.overlay.show();w.item_ui.body_ui.refresh()
	check(w.item_ui.body_ui.weather_summary.text.contains("炎热") and w.item_ui.body_ui.details.text.contains("精力恢复降低15%"),"heat reuses existing body text UI")
	w.item_ui.body_ui.overlay.hide();check(s.body.restore(body_before),"UI probe body restored atomically")
	for look in [{},Catalog.default_look()]:
		w.player.character_look=look
		var renderer=preload("res://scripts/sleep_head_cover.gd").new()
		renderer.render(w.player,{"source":"wood_bed","id":"isolated-head","vertical":false},b)
		var head: Sprite2D=w.player.get_node("SleepHeadCover/HeadPivot/CurrentHead/Sprite")
		check(head.get_node_or_null("EquipmentVisual_head_1")!=null and head.material.get_shader_parameter("closure")==1.0,"sleep preserves closed-eye head and fixed layered hat "+str(look.is_empty()))
	w.player.character_look=Catalog.default_look();w.player.update_animation()

func verify_seams_gpu(vp: SubViewport, rigs: Array, hair_id: String) -> void:
	for rig in rigs:rig.hide()
	vp.transparent_bg=true
	for rig in rigs:
		var info: Dictionary=rig.get_meta("apparel_test")
		if info.zoom!=1.0 or int(info.row)%2!=0:continue
		var original: Sprite2D=rig.get_node("Visual/Pelvis/Head/Sprite")
		var probe: Sprite2D=original.duplicate();probe.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;probe.position=Vector2(640,360);probe.scale=Vector2.ONE;vp.add_child(probe);probe.reset_physics_interpolation()
		await frames(2);await RenderingServer.frame_post_draw
		var rendered: Image=vp.get_texture().get_image()
		var base: Image=original.texture.get_image()
		var mat: ShaderMaterial=info.hair.material
		var cap: Image=mat.get_shader_parameter("hat_mask").get_image()
		var size: Vector2=mat.get_shader_parameter("hat_size")
		var offset: Vector2=mat.get_shader_parameter("hat_position")
		var columns:=0;var gap_columns:=0;var max_gap:=0
		for x in range(-90,91,2):
			var bx: int=x+base.get_width()/2
			var top:=-1000
			for y in base.get_height():
				if base.get_pixel(bx,y).a>.9:top=y-base.get_height()/2;break
			var cx: int=int(((float(x)-offset.x)/size.x+.5)*cap.get_width())
			if top==-1000 or top>0 or cx<0 or cx>=cap.get_width():continue
			var bottom:=-1000.0
			for y in range(cap.get_height()-1,-1,-1):
				if cap.get_pixel(cx,y).a>.9:bottom=(float(y)/cap.get_height()-.5)*size.y+offset.y;break
			if bottom==-1000:continue
			columns+=1
			var run:=0;var longest:=0
			for y in range(int(floor(bottom)),top+1):
				if rendered.get_pixel(x+640,y+360).a<.1:run+=1;longest=maxi(longest,run)
				else:run=0
			max_gap=maxi(max_gap,longest)
			if longest>=2:gap_columns+=1
		if hair_id=="male_natural" or gap_columns>0:rendered.save_png("res://reports/season-gear-v1/seam-"+str(info.row)+info.facing+".png")
		check(columns>0 and gap_columns==0,"GPU hat-head seam no transparent gap %s %s row%s columns%s max%s"%[hair_id,info.facing,info.row,columns,max_gap])
		probe.queue_free();await frames(1)
	vp.transparent_bg=false
