extends "res://tests/test_ecology_signpost_v1.gd"
const RESULT="res://reports/ore-ground-density-v1/"
func run()->void:
 auto_accept_quit=false
 root.size=Vector2i(1280,720)
 root.title="风栖原野 · 矿石接地专项测试"
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
 s=w.item_service;s.set_process(false);b=s.builds;p=w.player;ui=w.camp_ui
 w.set_process_input(false);w.map_view.set_process_input(false);w.item_ui.set_process_input(false)
 s.save_path=RESULT+"isolated.json";w.persistent_world=true
 var old=GDScript.new()
 old.source_code=FileAccess.get_file_as_string("res://scripts/harvest_distribution.gd").replace("\r\n","\n").replace("var cfg: Dictionary=CONFIG.configuration()\n","var cfg: Dictionary=CONFIG.configuration()\n\tcfg.mineral_generation.attempts=10\n")
 check(old.reload()==OK,"baseline source compiles")
 var totals_before={};var totals_after={};var preserved={};var chunks=0
 for seed_value in [271828,447349832]:
  var gen=Gen.new(seed_value,1024)
  var layer=preload("res://scripts/item_service.gd").new();layer.world={"generator":gen,"Gen":Gen}
  layer.patch_noise.seed=seed_value^87361;layer.patch_noise.frequency=1./float(layer.rules.noise_scale);layer.patch_noise.fractal_octaves=2;layer.prepare_navigation()
  var coords=[]
  for room in gen.rooms:
   var center=Vector2i(room.p/1152)
   for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN]:
    if not coords.has(center+offset):coords.append(center+offset)
  for coord in coords:
   var before=old.build(layer,coord);var after=Dist.build(layer,coord);chunks+=1
   for row in before:
    if str(row.id).begins_with("mineral:2:"):totals_before[row.kind]=int(totals_before.get(row.kind,0))+1
   for row in after:
    if not str(row.id).begins_with("mineral:2:"):continue
    totals_after[row.kind]=int(totals_after.get(row.kind,0))+1
    check(gen.can_walk(Vector2(row.x,row.y),52),"increased mine remains dry "+row.id)
    if seed_value==271828 and preserved.is_empty():preserved=row.duplicate(true)
   await process_frame
  layer.free()
 for kind in ["stone_outcrop","flint_outcrop","copper_outcrop","silver_outcrop","gold_outcrop"]:
  check(int(totals_after.get(kind,0))>int(totals_before.get(kind,0)),"actual sampled increase "+kind)
 stats={"before":totals_before,"after":totals_after,"chunks":chunks}
 if not preserved.is_empty():
  s.resource_hits[preserved.id]=2;s.consumed["mineral:2:0:0:0"]=true
  var slots=s.inventory.slots.duplicate(true)
  check(s.save_state(),"old current-layout progress snapshot saves")
  s.load_state()
  check(s.ore_nodes.has(preserved.id) and s.ore_nodes[preserved.id].kind==preserved.kind and s.resource_hits[preserved.id]==2,"partial mine survives extra candidate arbitration")
  check(s.inventory.slots==slots and s.consumed.has("mineral:2:0:0:0"),"density update retains inventory and consumed")
 var at=Vector2.INF
 for yy in range(1000,48000,384):
  for xx in range(1000,48000,384):
   var pos=Vector2(xx,yy)
   if w.generator.rocky_weight(pos)>.999 and w.generator.coast_distance(pos)>1000 and w.generator.sample(pos).z<.001:at=pos;break
  if at!=Vector2.INF:break
 check(at!=Vector2.INF,"find rocky interior visual scene")
 if at!=Vector2.INF:
  p.position=at+Vector2(0,110);w.stream.update_target(p.position)
  while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
  w.map_view.close_map();root.size=Vector2i(1280,720)
  p.camera.reset_smoothing();await frames(8)
  var nodes=[];var kinds=["stone_outcrop","flint_outcrop","copper_outcrop","silver_outcrop","gold_outcrop"]
  for i in 5:
   var target=at+Vector2((i-2)*140,0)
   var node=s.create_harvest("ore:contact-test:"+str(i),{"kind":kinds[i],"x":target.x,"y":target.y})
   nodes.append(node);node.hit_material.set_shader_parameter("mineral_contact",false)
  await frames(5);await RenderingServer.frame_post_draw
  var before_img=root.get_texture().get_image();before_img.save_png(RESULT+"contact-before.png")
  for node in nodes:node.hit_material.set_shader_parameter("mineral_contact",true)
  await frames(5);await RenderingServer.frame_post_draw
  var after_img=root.get_texture().get_image();after_img.save_png(RESULT+"contact-after.png")
  var changed=0
  for y in before_img.get_height():
   for x in before_img.get_width():
    if before_img.get_pixel(x,y)!=after_img.get_pixel(x,y):changed+=1
  check(changed>10,"GPU contact adaptation visibly changes painted base")
  stats.changed_pixels=changed
  check(nodes.all(func(n):return n.definition.action=="mine" and n.hit_material.get_shader_parameter("mineral_contact")==true),"all five mineral materials use contact fit")
 var failed=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open(RESULT+"window.json",FileAccess.WRITE);f.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"viewport":str(root.size),"count":checks.size(),"failed":failed.size(),"checks":checks,"statistics":stats},"\t"));f.close()
 print("ORE CONTACT DENSITY ",checks.size()," checks ",failed.size()," failed ",stats)
 w.persistent_world=false;w.free();await process_frame;quit(0 if failed.is_empty() else 1)
