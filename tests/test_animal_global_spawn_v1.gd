extends SceneTree
const OUT="res://reports/animal-global-spawn-v1/"
var checks=[]
func check(ok:bool,label:String)->void:
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func _initialize()->void:call_deferred("run")
func frames(n=3)->void:
 for i in n:await process_frame
func run()->void:
 Engine.set_meta("integration_seed",271828)
 var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 var s=w.item_service;var a=s.animals
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false);s.set_process(false);a.set_physics_process(false)
 while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
 s.save_path=OUT+"isolated.json"
 var verify="--verify-spawn" in OS.get_cmdline_user_args()
 if verify:
  w.persistent_world=true;s.load_state()
  check(s.writable and a.spawning.initialized,"independent process loads scheduler")
  check(a.states.size()==7 and a.spawning.sequence==7,"independent process preserves seven identities")
  check(is_equal_approx(a.clock,10080) and is_equal_approx(a.spawning.next_at,20160),"reload has no offline time and keeps next deadline")
  var before=a.serialize();a.ensure_population();a.seed_chunk(Vector2i(20,20));await frames(10)
  check(a.serialize()==before,"reload/exploration cannot restart initial six")
 else:
  for n in a.visuals.values():n.free()
  a.visuals.clear();a.states.clear();a.generated.clear();a.clock=0;a.spawning={"initialized":false,"sequence":0,"next_at":0.0}
  a.ensure_population()
  check(a.states.size()==6 and a.spawning.sequence==6,"whole map starts with exactly six for fixture seed")
  var chickens=0;var sheep=0;var chunks={}
  for id in a.states:
   var r=a.states[id];var p=a.point(r);chunks[w.stream.chunk_at(p)]=true
   if r.species=="chicken":chickens+=1
   else:sheep+=1
   check(w.generator.biome(p)=="草原" if r.species=="sheep" else w.generator.biome(p) in ["草原","森林"],"biome "+id)
   check(a.clear_at(p),"natural/building clearance "+id)
  check(chickens==3 and sheep==3,"initial three chickens and three sheep")
  check(chunks.size()>1,"global candidates cover separate map chunks")
  var initial=a.serialize()
  for y in 10:
   for x in 10:a.seed_chunk(Vector2i(x,y))
  check(a.serialize()==initial,"one hundred explored chunks add zero animals")
  var duplicate=preload("res://scripts/animals.gd").new();duplicate.service=s;duplicate.ensure_population()
  check(duplicate.states==a.states,"same world seed produces same whole-map roster")
  duplicate.free()
  # Isolate exact scheduling boundaries from unrelated movement and husbandry timers.
  a.clock=10079;a.advance(.5)
  check(a.states.size()==6,"no animal before seven-day deadline")
  a.advance(.5)
  check(a.states.size()==7 and a.spawning.sequence==7,"exact deadline adds one only")
  check(a.spawning.next_at==20160,"next refresh is another seven game days")
  w.persistent_world=true
  check(s.save_state(),"scheduler and roster save in original atomic snapshot")
  var saved=a.serialize();s.load_state()
  check(JSON.parse_string(JSON.stringify(a.serialize()))==JSON.parse_string(JSON.stringify(saved)),"same-process reload keeps scheduler and identities")
  w.persistent_world=false
  a.clock=20159;a.advance(1)
  check(a.states.size()==8 and a.spawning.sequence==8 and a.spawning.next_at==30240,"second interval adds exactly one without block or exploration quotas")
  a.restore(saved)
  var invalid=a.serialize();invalid.spawning.next_at=-1
  check(not a.valid(invalid),"invalid deadline protects source save")
  invalid=a.serialize();invalid.spawning.sequence=.5
  check(not a.valid(invalid),"fractional spawn identity is rejected")
  # Legacy migration reduces only surplus untamed natural animals.
  var legacy=a.serialize();legacy.erase("spawning");legacy.objects={}
  for i in 12:legacy.objects["wild:old:%d"%i]=a.make_row("chicken",w.player.position+Vector2(i*30,0))
  legacy.objects["wild:owned"]=a.make_row("sheep",w.player.position,true)
  legacy.objects["born:1"]=a.make_row("sheep",w.player.position,true,true);legacy.serial=1
  check(a.valid(legacy),"previous animal format remains valid")
  a.restore(legacy)
  check(a.states.size()==8 and a.states.has("wild:owned") and a.states.has("born:1"),"legacy surplus removed while owned animals and baby preserved")
  check(a.spawning.initialized and a.spawning.next_at==a.clock+10080,"legacy migration starts full interval without initial refill")
  var migrated=a.serialize();a.restore(migrated);a.ensure_population()
  check(a.serialize()==migrated,"migration is persistent and idempotent")
  a.restore(saved)
  # Load the real remote birthplace and verify the existing animal renders, without spawning more.
  var id="wild:global:1";var p=a.point(a.states[id]);w.player.position=p+Vector2(60,0)
  w.stream.update_target(w.player.position)
  while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
  a.sync_visuals();await frames(5)
  check(a.visuals.has(id) and a.states.size()==7,"native window installs remote animal without extra spawn")
  if a.visuals.has(id):a.visuals[id].set_physics_process(false)
  check(root.size==Vector2i(1280,720),"project default window size")
  if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png(OUT+"global-spawn.png")
 var failed=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open(OUT+("restart.json" if verify else "native.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"));f.close()
 print("GLOBAL ANIMAL SPAWN: ",checks.size()," checks, ",failed.size()," failed")
 w.free();await process_frame;quit(0 if failed.is_empty() else 1)
