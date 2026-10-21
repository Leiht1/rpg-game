extends "res://tests/test_ecology_signpost_v1.gd"
func run()->void:
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_clean_camp_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
 s=w.item_service;s.set_process(false);b=s.builds;p=w.player;ui=w.camp_ui
 s.save_path=OUT+"revision-isolated.json";w.persistent_world=true
 var point=Vector2.INF
 var counts={}
 for seed_value in [271828,447349832,1671081329]:
  var gen=Gen.new(seed_value,1024)
  var clone=Gen.new(seed_value,1024,gen.plan_snapshot())
  var families={};var rock_count=0;var pure_count=0;var not_old_mud=0;var sample_count=0
  for yy in range(128,49152,384):
   for xx in range(128,49152,384):
    var at=Vector2(xx,yy);var v=gen.sample(at)
    if v.z>.03:continue
    families[gen.biome(at)]=true
    if gen.rocky_weight(at)>.95:
     rock_count+=1
     if maxf(v.x,maxf(v.y,v.w))<.05:pure_count+=1
     if gen.macro_weights(at).y<.5:not_old_mud+=1
     if seed_value==271828 and point==Vector2.INF and s.ecology(at).shore<.001:point=at
    if sample_count<1:
     check(gen.sample(at).is_equal_approx(clone.sample(at)) and is_equal_approx(gen.rocky_weight(at),clone.rocky_weight(at)),"worker shares four-territory field "+str(seed_value)+" "+str(sample_count))
     sample_count+=1
  check(families.has("岩石区") and families.has("泥地") and families.has("草原") and families.has("森林"),"all four standalone land territories "+str(seed_value))
  check(rock_count>30 and pure_count==rock_count,"rock interiors exclude mud/forest/grass "+str(seed_value))
  counts[str(seed_value)]={"rock_interior_cells":rock_count,"pure":pure_count,"outside_old_mud":not_old_mud}
 stats=counts
 s.inventory.add("wood",30);s.inventory.add("plant_fiber",20)
 while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
 var row=find_row();var before=s.inventory.slots.duplicate(true)
 check(not row.is_empty(),"loaded clear site exists for signpost")
 if row.is_empty():await finish("revision");return
 ui.begin_build("build_signpost");ui.paint_at(Vector2(row.x,row.y));await frames()
 check(ui.sign_dialog.borderless,"paper title stays inside frame without native decoration")
 check(ui.sign_dialog.visible and ui.sign_dialog.get_theme_stylebox("panel") is StyleBoxTexture,"naming reuses paper frame")
 check(ui.sign_dialog.get_theme_stylebox("embedded_border") is StyleBoxTexture,"window border uses paper, no default dark shadow")
 ui.sign_input.text="北方岩石区";await shot("revision-naming-paper");ui.cancel_sign()
 check(s.inventory.slots==before and b.map_signposts().is_empty(),"paper dialog cancel remains free")
 ui.begin_build("build_signpost");ui.paint_at(Vector2(row.x,row.y));ui.sign_input.text="北方岩石区";ui.confirm_sign();await frames()
 check(b.map_signposts().size()==1,"paper dialog confirm builds")
 w.map_view.open_map()
 while w.map_view.row<w.map_view.resolution:await process_frame
 w.map_view.zoom=1;await shot("revision-map-regions")
 w.map_view.zoom=16;w.map_view.center=Vector2(row.x,row.y);await shot("revision-map-text");w.map_view.close_map()
 if point!=Vector2.INF:
  p.position=point;w.stream.update_target(p.position)
  while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
  p.camera.reset_smoothing();await frames(10);await shot("revision-rocky-region")
  var eco=s.ecology(point)
  check(eco.rocky>.95 and eco.mountain<.05 and eco.forest<.05,"natural ecology matches exclusive rock interior")
 await finish("revision-final-window")
