extends "res://tests/sleep_v8_fixture.gd"
const Out="res://reports/weather-layer-v2/"
const C=preload("res://scripts/weather_body_rules.gd")
func motion(at: Vector2,delta:=Vector2.ZERO,held:=false) -> void:
 var e:=InputEventMouseMotion.new();e.position=at;e.global_position=at;e.relative=delta;e.button_mask=MOUSE_BUTTON_MASK_LEFT if held else 0;root.push_input(e,true);await create_timer(.05).timeout;await frames(3)
func button(at: Vector2,pressed: bool) -> void:
 var e:=InputEventMouseButton.new();e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=pressed;root.push_input(e,true);await create_timer(.05).timeout;await frames(3)
func capture_scene(label: String) -> void:
 w.player.reset_physics_interpolation();w.player.character.reset_physics_interpolation();await frames(5);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(Out+label+".png")
func colour_diff(a: Color, d: Color) -> float:return maxf(absf(a.r-d.r),maxf(absf(a.g-d.g),absf(a.b-d.b)))
func rendered(view: SubViewport) -> Image:
 await frames(3);await RenderingServer.frame_post_draw;return view.get_texture().get_image()
func check_canopy_pixels(facing: String) -> void:
 var view:=SubViewport.new();view.size=Vector2i(512,512);view.world_2d=World2D.new();view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var rig: Node2D=w.player.character.duplicate();rig.position=Vector2(100,100);rig.scale=Vector2.ONE*2;rig.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;view.add_child(rig)
	var cover: Sprite2D=rig.find_child("HeldCanopyInFront",true,false)
 var head: Node2D=rig.get_node("Visual/Pelvis/Head/Sprite")
 # Controlled intersection proves the actual head pixels cannot cover the canopy.
 cover.position.y+=24
 var normal: Image=await rendered(view)
 cover.hide();var no_cover: Image=await rendered(view)
 head.hide();var neither: Image=await rendered(view)
 cover.show();var no_head: Image=await rendered(view)
 for child in rig.find_children("*","Sprite2D",true,false):
  if child!=cover:child.hide()
 var canopy_only: Image=await rendered(view)
 var overlap:=0;var errors:=0
 for y in range(0,512,2):
  for x in range(0,512,2):
   if colour_diff(no_cover.get_pixel(x,y),neither.get_pixel(x,y))>.04 and colour_diff(normal.get_pixel(x,y),no_cover.get_pixel(x,y))>.04 and canopy_only.get_pixel(x,y).a>.9999:
    overlap+=1
    if colour_diff(normal.get_pixel(x,y),no_head.get_pixel(x,y))>.02:errors+=1
 check(overlap>10 and errors==0,"GPU head/canopy overlap "+facing+" samples="+str(overlap)+" errors="+str(errors))
 view.queue_free();await frames(2)
func run() -> void:
 # Keep unrelated physical pointer motion from racing the injected native GUI events.
 DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 s=w.item_service;v=w.environment_view;b=s.builds
 w.set_process(false);w.player.set_physics_process(false);s.set_process(false);v.set_process(false);s.combat_view.set_process(false)
 root.size=default_size();root.content_scale_size=root.size
 while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
 check(not w.persistent_world,"isolated default window")
 b.states.clear();b.refresh_all();stock();s.inventory.add("broad_leaf",40)
 var p=w.player
 s.inventory.equipment.main_hand=s.inventory.instance("rain_umbrella");p.position=w.generator.spawn+Vector2(-240,0)
 for facing in ["front","back","left","right"]:
  p.facing=facing
  for t in [0.0,.18,.36,.52,.68]:
   p.action="pickup";p.action_clock=t;p.action_succeeded=true;p.update_animation()
   var l: Node2D=p.character.get_node("Visual/Pelvis/ArmL")
   var r: Node2D=p.character.get_node("Visual/Pelvis/ArmR")
   var tool: Sprite2D=l.get_node("HeldTool")
   check(p.held_tool.canopy.visible and tool.visible and tool.get_meta("item_id")=="rain_umbrella","left umbrella persists "+facing+str(t))
   check(p.character.get_node("Visual/ArmLBehind").visible and (not is_instance_valid(p.held_tool.front_free_hand) or not p.held_tool.front_free_hand.visible),"no extra arm "+facing+str(t))
   var a: Animation=p.animation_player.get_animation(("side" if facing in ["left","right"] else facing)+"_pickup")
   var index: int=a.find_track(NodePath("Visual/Pelvis/ArmR:rotation"),Animation.TYPE_VALUE)
   check(is_equal_approx(r.rotation,a.value_track_interpolate(index,t)),"native right pickup unchanged "+facing+str(t))
   check(p.carried_wood.get_parent()==r.get_node("Grip"),"native right carry parent "+facing+str(t))
   if is_equal_approx(t,.36):
    await capture_scene("left-umbrella-pickup-"+facing)
    await check_canopy_pixels(facing)
  p.cancel_action();p.update_animation()
 # Actual unchanged right-hand pickup commits exactly once while left keeps sheltering.
 p.input_blocked=false;p.automated=true;p.facing="right"
 var drop_id:="layer-v2:real-pickup";var point: Vector2=p.position+Vector2(16,0)
 var drop_row: Dictionary={"id":drop_id,"item_id":"wood","count":1,"x":point.x,"y":point.y,"mode":"pickup"}
 s.loose[drop_id]=drop_row;var drop: Node2D=w.stream.create_item_drop(drop_row);await frames(2)
 var wood_before: int=s.inventory.count_item("wood")
 p.action="pickup";p.action_target=drop;p.action_clock=0;p.action_committed=false;p.action_succeeded=false;p.harvesting=false
 for i in 6:p._physics_process(.13)
 check(s.inventory.count_item("wood")==wood_before+1 and s.consumed.has(drop_id),"actual right-hand pickup commits once")
 check(p.action.is_empty() and p.held_tool.canopy.visible,"actual pickup ends still holding left umbrella")
 # Real native GUI drag: world pose stays unchanged throughout the drag.
 p.action="";w.item_ui.toggle_bag();await frames(10)
 for item in ["stone_axe","rain_umbrella","stone_axe","rain_umbrella"]:
  s.inventory.equipment.main_hand=s.inventory.instance(item);p.update_animation();await frames(4)
  s.inventory.slots[8]={"item_id":"wood","count":5};s.inventory.slots[9]={};w.item_ui.cells[8].refresh();w.item_ui.cells[9].refresh();await frames(4)
  var arm: Node2D=p.character.get_node("Visual/Pelvis/ArmL" if item=="rain_umbrella" else "Visual/Pelvis/ArmR")
  var tool: Sprite2D=arm.get_node("HeldTool");var before: Transform2D=tool.global_transform;var rotation: float=arm.rotation
  var canopy_before: Transform2D=p.held_tool.canopy.global_transform
  var from: Vector2=w.item_ui.cells[8].get_global_rect().get_center();var to: Vector2=w.item_ui.cells[9].get_global_rect().get_center()
  await motion(from);await button(from,true);await motion(from+Vector2(18,0),Vector2(18,0),true)
  check(root.gui_is_dragging(),"real drag starts "+item)
  check(tool.global_transform.is_equal_approx(before) and is_equal_approx(arm.rotation,rotation),"drag begin no held pose jump "+item)
  await motion(to,to-from-Vector2(18,0),true);await frames(8)
  var active_drag=root.gui_get_drag_data()
  print("DRAG BEFORE DROP ",item," target=",to," mouse=",root.get_mouse_position()," hovered=",root.gui_get_hovered_control().get_path() if root.gui_get_hovered_control()!=null else "null"," valid=",w.item_ui.valid_drag(active_drag)," accepts=",w.item_ui.cells[9]._can_drop_data(Vector2.ZERO,active_drag))
  check(tool.global_transform.is_equal_approx(before) and tool.visible,"held item stable during drag "+item)
  if item=="rain_umbrella":check(p.held_tool.canopy.visible and p.held_tool.canopy.global_transform.is_equal_approx(canopy_before),"canopy stays visible and fixed during real drag")
  await button(to,false)
  print("DRAG RESULT ",item," source=",s.inventory.slots[8]," target=",s.inventory.slots[9]," dragging=",root.gui_is_dragging())
  check(not root.gui_is_dragging() and s.inventory.slots[9].get("count",0)==5,"real drag commits once "+item)
 if "--drag-only" in OS.get_cmdline_user_args():
  print("DRAG CHECK FINISHED");w.queue_free();await frames(4);quit();return
 w.item_ui.close_panels();await frames(8);stock();s.inventory.add("broad_leaf",40)
 # Find a valid shelter site, then reject actual tilled soil under its poles.
 var site: Dictionary={}
 for yy in range(-3,4):
  for xx in range(-3,4):
   var at: Vector2=w.generator.spawn+Vector2(xx*96,yy*64);p.position=at+Vector2(0,120)
   var candidate: Dictionary=b.candidate("rain_shelter",at,false,true,0)
   if b.reason(candidate).is_empty():site=candidate;break
  if not site.is_empty():break
 check(not site.is_empty(),"real shelter placement site")
 if site.is_empty():quit(1);return
 var origin:=Vector2(site.x,site.y)
 var first: Array=C.data.shelter_posts[0]
 var soil: Dictionary=b.candidate("tilled_soil",origin+Vector2(first[0],first[1]),false,true,0)
 b.states["test-soil"]=soil
 check(b.reason(site)=="雨棚柱子不能建在耕地上","reject shelter pillar on existing tilled soil")
 var before_slots: Array=s.inventory.slots.duplicate(true)
 check(b.place(site,before_slots).contains("耕地") and s.inventory.slots==before_slots and b.states.size()==1,"reject placement without material loss")
 b.states.erase("test-soil")
 check(b.place(site,s.inventory.slots.duplicate(true)).is_empty(),"normal shelter still builds")
 await frames(4)
 var id: String=b.states.keys()[0];var node: Node2D=b.visuals[id];var renderer=node.shelter_view
 check(node.y_sort_enabled and renderer.parts.size()==4 and is_equal_approx(renderer.roof.modulate.a,1),"new roof opaque and four separately sorted poles")
 check(b.reason(soil)=="耕地不能覆盖雨棚柱子","reverse order soil cannot cover pole")
 renderer.update_occlusion(origin+Vector2(0,180));await create_timer(.2).timeout
 check(renderer.roof.modulate.a==1,"outside shelter keeps roof opaque")
 renderer.update_occlusion(origin);await create_timer(.2).timeout
 check(is_equal_approx(renderer.roof.modulate.a,float(C.data.shelter_roof_occluded_alpha)) and renderer.parts.all(func(part):return part.modulate.a==1),"only canopy fades when blocking player")
 renderer.update_occlusion(origin+Vector2(150,-10));await create_timer(.2).timeout
 check(renderer.roof.modulate.a<1 and not preload("res://scripts/weather_exposure.gd").covered(s,origin+Vector2(150,-10)),"visual eaves occlusion independent of gameplay rain coverage")
 renderer.update_occlusion(origin+Vector2(0,170));await create_timer(.2).timeout
 check(is_equal_approx(renderer.roof.modulate.a,1),"roof recovers opacity after leaving")
 # GPU: use real shelter renderer in its own Y-sorted world and a depth probe.
 var view:=SubViewport.new();view.size=Vector2i(512,420);view.world_2d=World2D.new();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.transparent_bg=true;root.add_child(view)
 var scene:=Node2D.new();scene.y_sort_enabled=true;view.add_child(scene)
 var shelter=load("res://scripts/camp_building.gd").new();shelter.manager=b;shelter.building_id=id;shelter.position=Vector2(256,200);scene.add_child(shelter)
 var baseline: Image=await rendered(view)
 shelter.shelter_view.update_occlusion(Vector2(256,200));await create_timer(.2).timeout
 var faded_caps: Image=await rendered(view)
 for cap in [Vector2(58,18),Vector2(580,18),Vector2(26,190),Vector2(615,190)]:
  var pixel:=Vector2i(Vector2(88,200+shelter.shelter_view.top)+cap*.525)
  check(colour_diff(baseline.get_pixelv(pixel),faded_caps.get_pixelv(pixel))<.01,"actual wooden pole cap stays opaque "+str(cap))
 shelter.shelter_view.update_occlusion(Vector2(256,380));await create_timer(.2).timeout
 s.camps.states["gpu-fire"]={"x":256.0,"y":200.0,"fuel":1200.0,"lit":true,"hits":0,"recipe":"","elapsed":0.0,"ready":false}
 var actual_fire=load("res://scripts/campfire.gd").new();actual_fire.manager=s.camps;actual_fire.camp_id="gpu-fire";actual_fire.position=Vector2(256,200);scene.add_child(actual_fire)
 var with_fire: Image=await rendered(view);var roof_errors:=0;var roof_samples:=0
 for y in range(100,178):
  for x in range(220,292):
   if baseline.get_pixel(x,y).a>.9999:
    roof_samples+=1
    if colour_diff(baseline.get_pixel(x,y),with_fire.get_pixel(x,y))>.02:roof_errors+=1
 check(roof_samples>1000 and roof_errors==0,"GPU actual fuelled campfire stays below canopy")
 actual_fire.queue_free();s.camps.states.erase("gpu-fire");await frames(2)
 var marker:=Node2D.new();marker.position=Vector2(256,220);scene.add_child(marker);marker.draw.connect(func():marker.draw_rect(Rect2(-22,-300,44,300),Color.RED))
 var behind: Image=await rendered(view)
 check(colour_diff(behind.get_pixel(256,120),baseline.get_pixel(256,120))<.01,"GPU canopy covers objects physically below roof")
 marker.position.y=340;var front: Image=await rendered(view)
 check(colour_diff(front.get_pixel(256,120),Color.RED)<.01,"GPU foreground objects draw above roof")
 marker.queue_free();await frames(2)
 for i in 4:
  var pole: Array=C.data.shelter_posts[i]
  var sample_point:=Vector2i(256+int(pole[0]),200+int(pole[1])-24)
  var probe:=Node2D.new();probe.position=Vector2(sample_point.x,200+float(pole[1])-8);scene.add_child(probe);probe.draw.connect(func():probe.draw_rect(Rect2(-8,-40,16,40),Color.RED))
  var under: Image=await rendered(view)
  check(colour_diff(under.get_pixelv(sample_point),Color.RED)>.05,"GPU pole occludes object behind foot "+str(i))
  probe.position.y+=24;var over: Image=await rendered(view)
  check(colour_diff(over.get_pixelv(sample_point),Color.RED)<.01,"GPU foreground object occludes pole "+str(i))
  probe.queue_free();await frames(2)
 view.queue_free();await frames(2)
 # Actual buildings, not only probes: back wall, bed, fire and foreground person.
 var bed: Dictionary=b.candidate("wood_bed",origin+Vector2(0,45),false,true,0);b.states["test-bed"]=bed
 var wall: Dictionary=b.candidate("stone_wall",origin+Vector2(0,-80),false,true,0);b.states["test-wall"]=wall
 var ground: Dictionary=b.candidate("wood_floor",origin,false,true,0);b.states["test-floor"]=ground
 var crop: Dictionary=b.candidate("tilled_soil",origin+Vector2(0,70),false,true,0);b.states["test-crop"]=crop
 b.refresh_all();await frames(4)
 s.camps.states["test-fire"]={"x":origin.x+60,"y":origin.y-20,"fuel":1200.0,"lit":true,"hits":0,"recipe":"","elapsed":0.0,"ready":false};s.camps.rebuild()
 var fire=load("res://scripts/campfire.gd").new();fire.manager=s.camps;fire.camp_id="test-fire";fire.position=origin+Vector2(60,-20);s.camps.visuals["test-fire"]=fire;w.object_root.add_child(fire)
 p.position=origin+Vector2(0,150);p.facing="front";p.action="";p.update_animation();b.visuals[id].update_occlusion(p.position)
 await create_timer(.2).timeout;await capture_scene("shelter-opaque-exterior")
 p.position=origin;p.update_animation();b.visuals[id].update_occlusion(p.position)
 await create_timer(.2).timeout;await capture_scene("shelter-player-interior")
 p.position=origin+Vector2(150,115);p.update_animation();b.visuals[id].update_occlusion(p.position)
 await create_timer(.2).timeout;await capture_scene("shelter-foreground-pole")
 var failures: int=checks.filter(func(c):return not c.pass).size()
 FileAccess.open(Out+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"\t"));print("WEATHER LAYER V2 ",checks.size()," checks ",failures," failures")
 w.queue_free();await frames(4);quit(1 if failures else 0)
