extends SceneTree
const OUT="res://reports/ecology-signpost-v1/"
const SAVE=OUT+"isolated-save.json"
const Gen=preload("res://scripts/world_generator.gd")
const Dist=preload("res://scripts/harvest_distribution.gd")
var checks=[]
var stats={}
var w
var s
var b
var p
var ui
func check(ok:bool,label:String)->void:
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func frames(n:int=4)->void:
 for i in n:await process_frame
func _initialize()->void:call_deferred("run")
func save_json(name:String,value)->void:
 var f=FileAccess.open(OUT+name,FileAccess.WRITE);f.store_string(JSON.stringify(value,"\t"));f.close()
func shot(name:String)->void:
 if DisplayServer.get_name()=="headless":return
 await frames(5);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+name+".png")
func find_row()->Dictionary:
 for y in range(-4,5):
  for x in range(-4,5):
   var at:Vector2=w.generator.spawn+Vector2(x*96,y*64)
   p.position=at+Vector2(85,60)
   var row:Dictionary=b.candidate("signpost",at,false,true,0)
   if b.reason(row).is_empty():return row
 return {}
func finish(mode:String)->void:
 var failed=checks.filter(func(c):return not c.pass)
 save_json(mode+".json",{"engine":Engine.get_version_info().string,"viewport":str(root.size),"count":checks.size(),"failed":failed.size(),"checks":checks,"statistics":stats})
 print("ECOLOGY SIGNPOST ",mode,": ",checks.size()," checks, ",failed.size()," failed")
 w.persistent_world=false;w.free();await frames(6)
 if "--diagnose-exit" in OS.get_cmdline_user_args():Node.print_orphan_nodes()
 quit(0 if failed.is_empty() else 1)
func run()->void:
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
 s=w.item_service;s.set_process(false);b=s.builds;p=w.player;ui=w.camp_ui
 while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
 await frames(5);s.save_path=SAVE;w.persistent_world=true
 if "read" in OS.get_cmdline_user_args():
  s.load_state();await frames()
  check(s.writable,"fresh process save remains writable")
  check(b.map_signposts().size()==1 and b.map_signposts()[0].text=="北方铜矿入口","fresh process name and position restored")
  check(s.consumed.has("mineral:2:3:4:0") and s.consumed.has("natural:031:2:3:0:0"),"fresh process consumed identities retained")
  check(s.inventory.count_item("wood")>0,"fresh process inventory retained")
  check(s.ore_nodes.has("mineral:2:8:8:0") and s.resource_hits["mineral:2:8:8:0"]==2,"fresh process old worked mineral retained")
  await finish("restart");return
 check(s.database.errors.is_empty() and s.camps.build_book.errors.is_empty(),"item and building recipe validation")
 check(int(s.camps.build_book.recipe("build_signpost").materials.wood)==3 and int(s.camps.build_book.recipe("build_signpost").materials.plant_fiber)==2,"signpost official menu cost")
 for value in [""," ","七个字路标内容","a\nb","前后空格 "]:
  check(not b.valid_sign_text(value),"reject invalid name "+JSON.stringify(value))
 for value in ["铜矿","北方铜矿入口","ABC123","路😀标"]:check(b.valid_sign_text(value),"accept Unicode name "+value)
 s.inventory.add("wood",60);s.inventory.add("plant_fiber",40)
 var row=find_row();check(not row.is_empty(),"find real legal placement")
 if row.is_empty():await finish("failed");return
 var before:Array=s.inventory.slots.duplicate(true);var count=b.states.size()
 check(not b.place(row,before).is_empty() and b.states.size()==count and s.inventory.slots==before,"empty name cannot place or consume")
 ui.begin_build("build_signpost");ui.paint_at(Vector2(row.x,row.y));await frames()
 check(ui.sign_dialog.visible and p.input_blocked and b.states.size()==count,"legal click opens naming before commit; actor blocked")
 ui.sign_input.text="1234567";check(ui.sign_input.text.length()==6,"native input caps at six characters")
 ui.cancel_sign();await frames()
 check(b.states.size()==count and s.inventory.slots==before,"cancel naming has no object or material cost")
 ui.begin_build("build_signpost");ui.paint_at(Vector2(row.x,row.y));await frames()
 ui.sign_input.text="北方铜矿入口";await shot("naming-dialog");ui.confirm_sign();await frames()
 check(b.map_signposts().size()==1 and s.inventory.count_item("wood")==57 and s.inventory.count_item("plant_fiber")==38,"confirmation commits one sign and exact cost")
 var id:String=""
 for key in b.states:
  if b.states[key].kind=="signpost":id=key
 if id.is_empty():await finish("failed");return
 var sign:Dictionary=b.states[id].duplicate(true)
 var node:Node2D=b.visuals[id]
 p.position=Vector2(sign.x,sign.y)+Vector2(0,60);await frames()
 check(node.get_meta("display_name")=="北方铜矿入口","nearby hint shows saved text")
 node.perform_interaction("inspect",p)
 check(b.states[id]==sign,"inspection cannot edit immutable name")
 var saved=b.serialize();var invalid=saved.duplicate(true);invalid.objects[id].text="七个字路标内容"
 check(not b.validate(invalid,{}),"save rejects overlong sign name")
 check(b.validate(saved,{}),"save accepts official sign state")
 # Main transaction also revalidates the location, inventory and save success.
 var row2=find_row();row2.text="失败路标"
 before=s.inventory.slots.duplicate(true);var badpath=s.save_path;s.save_path="res://reports/ecology-signpost-v1/missing/blocked.json"
 check(not b.place(row2,before).is_empty() and s.inventory.slots==before and b.map_signposts().size()==1,"save failure rolls back name/object/materials")
 s.save_path=badpath
 var changed=before.duplicate(true);changed[0]={"item_id":"wood","count":999}
 check(not b.place(row2,changed).is_empty(),"stale inventory refused")
 row2.x=-100
 check(not b.place(row2,before).is_empty() and s.inventory.slots==before,"illegal placement consumes nothing")
 # A map query reads states while the chunk visual is absent.
 var coord:Vector2i=w.stream.chunk_at(Vector2(sign.x,sign.y))
 b.unload(coord);await frames();check(b.map_signposts().size()==1 and not b.visuals.has(id),"unloaded chunk sign remains on map")
 b.install(coord);await frames();node=b.visuals[id]
 w.map_view.open_map();await frames()
 for z in [1.0,4.0,16.0]:
  w.map_view.zoom=z;w.map_view.center=Vector2(sign.x,sign.y);w.map_view.queue_redraw();await frames()
  check(b.map_signposts()[0].text==sign.text,"map scale retains source data "+str(z))
 await shot("map-signpost");w.map_view.close_map()
 # Legacy migration fixture retains containers/equipment, histories and partially worked ores.
 s.consumed["mineral:2:3:4:0"]=true;s.consumed["natural:031:2:3:0:0"]=true
 s.resource_hits["mineral:2:8:8:0"]=2
 var old=s.snapshot() if s.has_method("snapshot") else {}
 # Obtain the actual serialized original atomic snapshot through save.
 check(s.save_state(),"write isolated state")
 old=JSON.parse_string(FileAccess.get_file_as_string(SAVE));old.resource_version="natural-resources-0.3.2";old.harvest_version="harvest-resources-2.1.0"
 save_json("legacy-input.json",old);s.load_state(OUT+"legacy-input.json",true);await frames()
 check(s.writable and b.states[id].text==sign.text and s.inventory.slots==before,"legacy migration retains buildings/name/inventory")
 check(s.consumed==old.consumed and s.resource_hits==old.resource_hits,"legacy migration retains exact depletion/progress dictionaries")
 check(s.ore_nodes.has("mineral:2:8:8:0"),"old partially worked mineral pinned in original ore state")
 var preserved:Dictionary=s.ore_nodes["mineral:2:8:8:0"].duplicate(true)
 s.save_state();s.load_state();check(s.ore_nodes["mineral:2:8:8:0"]==preserved,"preserved mineral stable across reload")
 # Real hammer removal uses original wear, refunds and persistence path.
 s.inventory.add("stone_hammer",1)
 for i in 40:
  if s.inventory.slots[i].get("item_id","")=="stone_hammer":s.inventory.equip(i);break
 p.position=Vector2(sign.x,sign.y)+Vector2(0,60);await frames(5);node=b.visuals[id]
 check(b.strike(id,node),"hammer first hit accepted");check(b.strike(id,node),"hammer second hit demolishes")
 check(not b.states.has(id) and b.map_signposts().is_empty(),"demolition removes same map source immediately")
 await frames();s.load_state();check(b.map_signposts().is_empty(),"demolished sign stays absent after reload")
 # Rebuild one surviving marker for the fresh-process persistence check.
 row=find_row();row.text="北方铜矿入口";check(b.place(row,s.inventory.slots.duplicate(true)).is_empty(),"rebuild after demolition")
 await frames();s.save_state();await shot("signpost-world")
 await ecology_checks()
 await finish("headless" if DisplayServer.get_name()=="headless" else "window")
func ecology_checks()->void:
 var cfg:Dictionary=preload("res://scripts/harvest_node.gd").configuration()
 var totals={"rocky":0,"other":0,"mud":0,"rare_outside":0,"rocky_cells":0,"land_cells":0}
 var rocky_point=Vector2.INF
 for seed_value in [271828,447349832,1671081329]:
  var gen=Gen.new(seed_value,1024)
  var cells={};var mineral_count=0;var rocky_count=0
  # Regular sample spacing is analysis only, never a resource placement grid.
  for y in range(128,49152,256):
   for x in range(128,49152,256):
    var at=Vector2(x,y)
    if gen.sample(at).z>.03:continue
    totals.land_cells+=1
    if gen.rocky_weight(at)>.55:
     cells[Vector2i(x/256,y/256)]=true;totals.rocky_cells+=1
     if seed_value==271828 and rocky_point==Vector2.INF and gen.rocky_weight(at)>.95:rocky_point=at
  var connected=0
  for c in cells:
   if cells.has(c+Vector2i.RIGHT) or cells.has(c+Vector2i.DOWN):connected+=1
  check(cells.size()>20 and float(connected)/maxi(1,cells.size())>.85,"continuous rocky regions seed "+str(seed_value))
  for y in range(0,64):
   for x in range(0,64):
    for attempt in 10:
     var salt=29093+attempt*73
     var at=(Vector2(x,y)+Vector2(gen.random_at(x,y,salt),gen.random_at(x,y,salt+1)))*768
     if not gen.can_walk(at,52):continue
     var rocky=Dist.rocky_region(gen,at)
     var kind=Dist.mineral_kind(cfg,gen,Vector2i(x,y),attempt,rocky)
     if kind.is_empty():continue
     mineral_count+=1
     if rocky:totals.rocky+=1;rocky_count+=1
     else:
      totals.other+=1
      if Dist.dirt_region(gen,at):totals.mud+=1
      if kind not in ["stone_outcrop","flint_outcrop"]:totals.rare_outside+=1
  check(float(rocky_count)/maxi(1,mineral_count)>.7,"mineral candidates predominantly rocky seed "+str(seed_value))
 stats=totals
 check(totals.rare_outside==0,"rare metals remain in rocky interior")
 check(totals.other>0,"occasional basic minerals outside rocky areas")
 check(s.rules.biomes.meadow.weights.has("flint") and s.rules.biomes.forest.weights.has("flint"),"early direct flint available outside rocky")
 check(s.rules.biomes.shore.density<=2.5 and not s.rules.biomes.shore.weights.has("stone"),"sparse wet plants along shore")
 if rocky_point!=Vector2.INF:
  p.position=rocky_point;w.stream.update_target(p.position);
  while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
  await frames(10)
  var mines=[]
  for node in get_nodes_in_group("world_interactables"):
   if node.get("kind")!=null and str(node.kind).ends_with("outcrop") and node.position.distance_to(p.position)<600:mines.append(node)
  if not mines.is_empty():p.position=mines[0].position+Vector2(0,75)
  p.camera.position=Vector2.ZERO;p.camera.reset_smoothing()
  await shot("rocky-world")
  check(not mines.is_empty(),"actual streamed rocky terrain has harvestable minerals")
  if not mines.is_empty():
   var target:Node2D=mines[0];var resource_id:String=target.resource_id
   var definition:Dictionary=target.definition
   s.inventory.add("stone_pickaxe",1)
   for i in 40:
    if s.inventory.slots[i].get("item_id","")=="stone_pickaxe":s.inventory.equip(i);break
   await frames(5)
   var hits=0
   for i in int(definition.hits):
    if s.harvest_hit(target,"mine"):hits+=1
   check(hits==int(definition.hits) and s.consumed.has(resource_id),"actual rocky mine reaches original hit count and consumed state")
   var rewards=[]
   for key in s.loose:
    if key.begins_with(resource_id+":loot:"):rewards.append(s.loose[key])
   check(not rewards.is_empty(),"actual rocky mine uses original loose reward path")
   var mine_coord:Vector2i=w.stream.chunk_at(target.position)
   s.install_chunk(mine_coord);await frames()
   var resurrected=false
   for n in get_nodes_in_group("world_interactables"):
    if n.get_meta("ore_id","")==resource_id and not n.get_meta("spent",false):resurrected=true
   check(not resurrected,"consumed mineral does not respawn when chunk installs again")
   # Save/reload preserves depleted mine and exact original reward quantities.
   s.save_state();s.load_state();check(s.consumed.has(resource_id),"real mineral depletion survives save reload")
   if not rewards.is_empty():
    var reward:Dictionary=rewards[0];var drop:Node2D=null
    for n in w.stream.drops:
     if is_instance_valid(n) and n.get_meta("drop_id","")==reward.id:drop=n;break
    if drop:
     await create_timer(.6).timeout
     check(s.pickup(drop),"mined loose reward still picked up through original inventory")
  # Restore survivor and compatibility fixture for the independent restart process.
  s.save_state()
