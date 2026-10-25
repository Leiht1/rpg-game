extends "res://tests/sleep_v8_fixture.gd"
const Out="res://reports/local-polish-v1/"
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
func capture_view(label: String) -> void:
 await create_timer(.25).timeout;await frames(4);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(Out+label+".png")
 if "hat" in label:
  var vp:=SubViewport.new();vp.size=Vector2i(512,512);vp.world_2d=World2D.new();vp.transparent_bg=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
  var copy: Node2D=w.player.character.duplicate();copy.position=Vector2(115,105);copy.scale=Vector2.ONE*2;copy.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;vp.add_child(copy)
  await frames(3);await RenderingServer.frame_post_draw;vp.get_texture().get_image().save_png(Out+label+"-rig.png");vp.queue_free()
func build(id: String,kind: String,at: Vector2) -> void:
 var row: Dictionary=b.candidate(kind,at,false,false,0);row.id=id;b.states[id]=row
 b.install(w.stream.chunk_at(at))
func run() -> void:
 DirAccess.make_dir_recursive_absolute(Out)
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 s=w.item_service;v=w.environment_view;b=s.builds
 w.loading_cover.hide();w.loading_label.hide();w.item_ui.guide.hide()
 root.size=default_size();root.content_scale_size=root.size
 w.set_process(false);w.player.set_physics_process(false);s.set_process(false);v.set_process(false);s.combat_view.set_process(false)
 while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
 check(not w.persistent_world,"isolated no player saves")
 var p=w.player
 s.inventory.equipment.main_hand=s.inventory.instance("rain_umbrella")
 for hat in ([] if "--surface-only" in OS.get_cmdline_user_args() else ["wool_hat","straw_hat"]):
  s.inventory.equipment.head=s.inventory.instance(hat)
  for legacy in [false,true]:
   p.character_look={} if legacy else preload("res://scripts/character_catalog.gd").default_look()
   for facing in ["front","back","left","right"]:
    p.facing=facing
    for time in [0.0,.18,.36,.52]:
     p.action="pickup";p.action_clock=time;p.action_succeeded=true;p.update_animation()
     await frames(1)
     check(p.held_tool.canopy.visible,"first-frame canopy "+hat+str(legacy)+facing+str(time))
    await capture_view(hat+"-"+str(legacy)+"-"+facing)
    await check_canopy_pixels(hat+str(legacy)+facing)
 p.cancel_action();s.inventory.equipment.main_hand={};p.update_animation()
 b.states.clear();b.refresh_all();await frames()
 s.storage_ui.close_panel()
 var at: Vector2=p.position+Vector2(160,-48)
 build("chest","wood_chest",at);await frames()
 await capture_view("chest-closed")
 b.states.chest.open=true;b.visuals.chest.queue_redraw();await capture_view("chest-open")
 s.storage_ui.close_panel()
 var chest=b.visuals.chest;var closed: Texture2D=chest.texture(13)
 var opened: Texture2D=load("res://assets/buildings/chest-open-v1/wood_chest_open.png")
 var rect: Rect2=chest.volume_rect(closed,b.volume_profile("wood_chest"))
 check(rect.size.x>50 and opened.get_width()>0,"closed body dimensions retained")
 b.states.clear();b.refresh_all();await frames()
 for kind in ["stone_furnace","copper_oven"]:
  build(kind,kind,p.position+Vector2(-70,-25));await frames()
  b.states[kind].machine=s.industry.initial(kind)
  s.inventory.add("wood",40);s.industry_ui.open(kind);s.industry_ui.open_fuel_window();s.industry_ui.choose_fuel("wood");await frames()
  check(s.industry_ui.fuel_limit.text=="可投放数量：16" and s.industry_ui.amount.max_value==16,"fuel room quantity "+kind)
  await capture_view(kind+"-fuel")
  b.states[kind].machine.fuel=1990;s.industry_ui.refresh()
  check(s.industry_ui.fuel_confirm.disabled and s.industry_ui.fuel_limit.text=="可投放数量：0","full fuel rejection "+kind)
  s.industry_ui.close_panel();b.states.erase(kind);b.refresh_all();await frames()
 var ui=s.expansion_ui
 ui.layout_for("advanced_smokehouse")
 check(ui.scroll.size.y>=5*48+4*8,"smokehouse five complete choices")
 var old_camps: Dictionary=s.camps.states.duplicate(true)
 s.camps.states={"heat":{"x":p.position.x,"y":p.position.y,"fuel":1200.0,"lit":true}}
 check(preload("res://scripts/season_surface.gd").heat(s,p.position+Vector2(300,0))>0,"doubled melt radius")
 s.camps.states.heat.fuel=100.0
 check(preload("res://scripts/season_surface.gd").heat(s,p.position)==0,"small fire stops melting")
 s.camps.states=old_camps
 v.simulation.day=23;v.simulation.snow=1.0
 build("soil","tilled_soil",p.position+Vector2(180,30));await frames(12)
 check(b.visuals.soil.material==null,"soil excludes snow cap and crops stay unshaded")
 await capture_view("winter-soil")
 # Real soil and crop draw isolation, including old blocked saves.
 v.simulation.building_snow.soil={"amount":1.0,"blocked":true}
 check(not preload("res://scripts/season_surface.gd").blocked(s,"soil"),"legacy soil snow cannot block farming")
 var flecks=w.get_node("SeasonFlecks");flecks.set_process(false);flecks.atmosphere.hide()
 flecks._process(0);await frames(4)
 check(b.visuals.soil.has_node("WinterSoil"),"soil has separate tint sprite")
 check(b.visuals.soil.get_node("WinterSoil").material.get_shader_parameter("snow_amount")==1.0,"soil light frost amount")
 b.states.soil.crop="carrot";b.states.soil.growth_minutes=0.0;b.visuals.soil.queue_redraw()
 await capture_view("winter-soil-frost")
 var soil_probe:=SubViewport.new();soil_probe.size=Vector2i(512,256);soil_probe.transparent_bg=true;soil_probe.world_2d=World2D.new();soil_probe.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(soil_probe)
 var soil_copy: Node2D=b.visuals.soil.duplicate();soil_copy.manager=b;soil_copy.building_id="soil";soil_copy.preview=true
 for group in soil_copy.get_groups():soil_copy.remove_from_group(group)
 soil_copy.position=Vector2(256,160);soil_copy.scale=Vector2.ONE*3;soil_probe.add_child(soil_copy)
 await frames(4);await RenderingServer.frame_post_draw;soil_probe.get_texture().get_image().save_png(Out+"soil-crop-detail.png");soil_probe.queue_free()
 # Compare actual GPU terrain with and without heat. Freeze atmosphere to exclude flakes.
 await RenderingServer.frame_post_draw
 var cold: Image=root.get_texture().get_image()
 s.camps.states={"heat":{"x":p.position.x,"y":p.position.y,"fuel":1200.0,"lit":true}}
 flecks.update_clock=0;flecks._process(0);await frames(8);await RenderingServer.frame_post_draw
 var warm: Image=root.get_texture().get_image();var changed:=0
 for y in range(180,500):
  for x in range(360,900):
   if colour_diff(cold.get_pixel(x,y),warm.get_pixel(x,y))>.025:changed+=1
 check(changed>100,"GPU ground snow melts around full fire pixels="+str(changed))
 await capture_view("winter-ground-melt")
 s.camps.states.heat.fuel=100.0;flecks.update_clock=0;flecks._process(0);await frames(8)
 for packet in w.stream.loaded.values():check(packet.terrain.material.get_shader_parameter("snow_heat_count")==0,"small fire removed from terrain melt")
 s.camps.states=old_camps
 # Five real recipe rows, without clipping the fifth option.
 b.states.clear();b.refresh_all();await frames()
 for i in 40:s.inventory.slots[i]={}
 for i in 6:s.inventory.slots[i]={"item_id":"roasted_fish","count":1}
 s.inventory.slots[6]={"item_id":"wood","count":10}
 build("smoke","advanced_smokehouse",p.position+Vector2(60,-20));b.states.smoke.expansion=s.expansion.initial();await frames()
 ui.open("smoke");await capture_view("smoke-five-choices")
 check(ui.choices.get_child_count()==6 and ui.scroll.size.y>=272,"six recipes scroll after five visible rows")
 ui.close_panel();b.states.clear();b.refresh_all();await frames()
 s.animals.set_physics_process(false)
 var animal_id="polish:sheep";s.animals.states[animal_id]=s.animals.make_row("sheep",p.position+Vector2(42,0));s.animals.sync_visuals();await frames()
 s.animals.visuals[animal_id].set_physics_process(false);s.inventory.add("broad_leaf",3);s.inventory.add("wild_carrot",2)
 check(w.item_ui.feed_ui.open(animal_id),"real animal food picker opens")
 await capture_view("animal-hotbar-frame")
 check(w.item_ui.feed_ui.grid.get_child_count()==2,"two food choices retain original feeding flow")
 w.item_ui.feed_ui.close_panel()
 var failed:=checks.filter(func(c):return not c.pass).size()
 FileAccess.open(Out+("surface-checks.json" if "--surface-only" in OS.get_cmdline_user_args() else "checks.json"),FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
 print("LOCAL_POLISH ",checks.size()," checks ",failed," failed")
 quit(1 if failed else 0)
