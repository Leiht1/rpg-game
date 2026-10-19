extends SceneTree
var checks=[]
var samples=[]
func check(ok,label):
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func _initialize():call_deferred("run")
func count_rows(s,coords):
 s.raw_cells.clear();s.chunk_cache.clear();s.prop_cache.clear()
 var counts={}
 for c in coords:
  for row in s.entries(c):counts[row.item_id]=counts.get(row.item_id,0)+1
 return counts
func run():
 for seed_value in [271828,447349832,1671081329]:
  Engine.set_meta("integration_seed",seed_value)
  var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
  w.stream.set_process(false);w.set_process(false);w.player.set_physics_process(false)
  var s=w.item_service;s.set_process(false)
  var coords=[]
  for p in [w.generator.spawn]+Array(w.generator.region_cores):
   var c=w.stream.chunk_at(p)
   for y in range(-2,3):
    for x in range(-2,3):
     if not coords.has(c+Vector2i(x,y)):coords.append(c+Vector2i(x,y))
  var current=s.rules.duplicate(true)
  s.rules.biomes.forest.weights.brown_mushroom=25
  s.rules.biomes.shore.weights.brown_mushroom=6
  var before=count_rows(s,coords)
  s.rules=current
  var after=count_rows(s,coords)
  samples.append({"seed":seed_value,"chunks":coords.size(),"before":before,"after":after})
  check(after.get("brown_mushroom",0)>before.get("brown_mushroom",0),"modest mushroom increase %s"%seed_value)
  check(s.rules.biomes.meadow==current.biomes.meadow,"meadow unchanged")
  if seed_value==271828:
   s.consumed["natural:031:test:consumed"]=true
   s.inventory.add("brown_mushroom",2)
   s.body.hallucination_remaining=30.0
   var snap=JSON.parse_string(JSON.stringify(s.snapshot()))
   s.save_path="res://reports/.tmp/mushroom-032.json"
   DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/.tmp"))
   w.persistent_world=true
   for version in [s.PREVIOUS_RESOURCE_VERSION,s.LEGACY_RESOURCE_VERSION]:
    var old=snap.duplicate(true);old.resource_version=version
    var path="res://reports/.tmp/mushroom-old.json"
    var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(old));f.close()
    var original=FileAccess.get_file_as_string(path)
    s.consumed={};s.body.hallucination_remaining=0
    s.load_state(path,true)
    check(s.consumed.has("natural:031:test:consumed"),"consumed retained "+version)
    check(s.body.hallucination_remaining==30.0,"hallucination retained "+version)
    var saved=JSON.parse_string(FileAccess.get_file_as_string(s.save_path))
    check(saved!=null and saved.resource_version==s.RESOURCE_VERSION and saved.slots==old.slots,"atomic migrated bag "+version)
    check(FileAccess.get_file_as_string(path)==original,"source preserved "+version)
   for path in [s.save_path,"res://reports/.tmp/mushroom-old.json"]:DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
   w.persistent_world=false
  w.free();await process_frame
 var failed=checks.filter(func(c):return not c.pass)
 FileAccess.open("res://reports/mushroom-density-v2/results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed.size(),"samples":samples},"\t"))
 print("MUSHROOM DENSITY ",checks.size()," checks, ",failed.size()," failed; ",JSON.stringify(samples))
 quit(0 if failed.is_empty() else 1)
