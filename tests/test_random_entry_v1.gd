extends SceneTree
const OUT="res://reports/random-entry-v1/"
const Gen=preload("res://scripts/world_generator.gd")
var checks=[]
var rows=[]
func check(ok:bool,label:String)->void:
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var biomes={};var positions={}
 for seed in [271828,314159,447349832,12345,1001,1002,1003,1004,1005,1006,1007,1008]:
  var w=preload("res://scripts/world.gd").new()
  w.generator=Gen.new(seed,1024);w.world_seed=seed
  var s=preload("res://scripts/item_service.gd").new();w.item_service=s;s.world=w;s.builds.service=s
  var anchor=w.generator.spawn;var plan=w.generator.plan_snapshot();var lakes=w.generator.lakes.duplicate();var rooms=w.generator.rooms.duplicate(true)
  var p=w.choose_entry_point();var bio=w.generator.biome(p);biomes[bio]=int(biomes.get(bio,0))+1;positions[str(p)]=true
  check(w.generator.can_walk(p,20) and w.generator.sample(p).z<=.03 and w.generator.coast_distance(p)>=160,"safe inland dry start %d"%seed)
  check(s.ground_clear(p,20,s.nearby_props(p)),"tree footprint/root clearance %d"%seed)
  check(w.choose_entry_point()==p,"same Seed stable entry %d"%seed)
  check(w.generator.spawn==anchor and w.generator.lakes==lakes and w.generator.rooms==rooms,"historical terrain anchor/lakes/rooms unchanged %d"%seed)
  var worker=Gen.new(seed,1024,plan)
  check(worker.spawn==anchor and worker.sample(p)==w.generator.sample(p),"worker snapshot terrain unchanged %d"%seed)
  s.builds.states["entry-test"]={"kind":"wood_chest","layer":"furniture","x":p.x,"y":p.y,"vertical":false}
  var alternate=w.choose_entry_point()
  check(alternate.distance_to(p)>24,"saved furniture blocks entry %d"%seed)
  rows.append({"seed":seed,"old_anchor":str(anchor),"old_biome":w.generator.biome(anchor),"entry":str(p),"entry_biome":bio})
  s.free()
  for node in [w.object_root,w.ui,w.title,w.hint,w.debug_label,w.loading_cover,w.loading_label]:node.free()
  w.free()
  await process_frame
 check(biomes.size()>=3 and int(biomes.get("岩石区",0))<12,"multiple Seeds yield varied actual biomes")
 check(positions.size()==12,"different Seeds have different entry positions")
 # Real default window, actual ordinary fixture startup path.
 Engine.set_meta("integration_seed",314159)
 var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false);w.item_service.set_process(false);w.item_service.animals.set_physics_process(false)
 check(w.player.position==w.choose_entry_point(),"real world startup uses new entry selector")
 check(not w.persistent_world,"native test is isolated from player saves")
 for i in 8:await process_frame
 check(root.size==Vector2i(1280,720),"project default native window")
 check(w.stream.has_ground(w.player.position),"actual entry terrain installed")
 root.get_texture().get_image().save_png(OUT+"entry.png")
 w.free();await process_frame
 var failed=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open(OUT+"results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"biomes":biomes,"seeds":rows,"checks":checks},"\t"));f.close()
 print("RANDOM ENTRY: ",checks.size()," checks, ",failed.size()," failed; biomes=",biomes)
 quit(0 if failed.is_empty() else 1)
