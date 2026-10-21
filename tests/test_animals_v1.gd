extends SceneTree
const OUT="res://reports/animals-v1/"
var w: Node
var s: Node
var a: Node
var checks=[]
func check(ok: bool, label: String) -> void:
 checks.append({"name":label,"pass":ok})
 if not ok:push_error(label)
func _initialize() -> void:call_deferred("run")
func frames(n=3) -> void:
 for i in n:await process_frame
func run() -> void:
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
 s=w.item_service;s.set_process(false);a=s.animals;a.set_physics_process(false)
 while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
 await frames(6)
 check(s.database.errors.is_empty(),"item definitions valid")
 check(s.craft_book.validate(s.craft_book.recipe("workbench_shears")).is_empty(),"metal shears recipe validates")
 check(s.craft_book.recipe("workbench_shears").materials.copper_ore==3 and s.craft_book.recipe("workbench_shears").materials.silver_ore==1 and s.craft_book.recipe("workbench_shears").materials.wood==2,"moderate copper/silver/wood recipe")
 check(s.craft_check("workbench_shears",1)=="需要靠近并使用对应加工台制作","shears require workbench")
 for id in a.visuals.keys():a.visuals[id].free()
 a.visuals.clear();a.states.clear();a.generated.clear()
 a.spawning={"initialized":false,"sequence":0,"next_at":0.0}
 var p=w.player.position
 for y in range(-2,3):
  for x in range(-2,3):
   var c=w.stream.chunk_at(p)+Vector2i(x,y)
   if w.stream.valid_chunk(c):a.seed_chunk(c)
 check(a.states.size()>0,"stable whole-map natural animals generated")
 var roster=a.states.duplicate(true);var bins=a.generated.duplicate()
 for key in bins:
  var parts=key.split(":");a.seed_chunk(Vector2i(int(parts[0]),int(parts[1])))
 check(a.states==roster,"repeated chunk install never respawns")
 var chickens=0;var sheep=0
 for id in a.states:
  var r=a.states[id];var bio=w.generator.biome(a.point(r))
  check((bio=="草原" if r.species=="sheep" else bio in ["草原","森林"]),"spawn biome "+id)
  check(w.generator.can_walk(a.point(r),12) and w.generator.sample(a.point(r)).z<=.08,"spawn dry walkable "+id)
  check(s.ground_clear(a.point(r),12,s.nearby_props(a.point(r)),false),"spawn avoids rock/tree geometry "+id)
  if r.species=="chicken":chickens+=1
  else:sheep+=1
 check(chickens>0 and sheep>0,"both species found in ecological sample")
 a.states.clear();a.spawning.next_at=1e12
 var at=a.find_near(p,35,62)
 check(at!=Vector2.INF,"safe interaction location")
 a.states.c=a.make_row("chicken",at);a.sync_visuals();await frames()
 var c=a.visuals.c;c.set_physics_process(false)
 s.inventory.slots[0]={"item_id":"wild_berry","count":20};s.inventory.selected=0
 check(a.feed("c",0,s.inventory.slots[0].duplicate(true)).is_empty(),"first feed consumes one and nods")
 check(a.states.c.trust==1 and not a.states.c.tamed and c.feedback>0,"partial trust and feedback")
 check(not a.feed("c",0,s.inventory.slots[0].duplicate(true)).is_empty() and s.inventory.slots[0].count==19,"immediate repeated feed refused")
 a.advance(30);check(a.feed("c",0,s.inventory.slots[0].duplicate(true)).is_empty(),"second chicken feed after cooldown")
 a.advance(30);check(a.feed("c",0,s.inventory.slots[0].duplicate(true)).is_empty() and a.states.c.tamed,"third feed tames chicken")
 s.inventory.selected=1
 check(a.interact("c",c) and a.states.c.mode=="follow","E switches follow")
 check(a.interact("c",c) and a.states.c.mode=="stay","E switches stay")
 check(a.stage(a.states.c)==2,"wild adults start adult")
 a.states.c.fed_until=a.clock+10000
 a.advance(720)
 check(a.egg_count("c")==1,"adult healthy chicken produces egg")
 var egg_key=""
 for id in s.loose:
  if s.loose[id].get("origin")=="animal:c":egg_key=id
 check(not egg_key.is_empty(),"egg uses persistent ground drop")
 a.advance(2160);check(a.egg_count("c")==3,"uncollected egg cap three")
 # Lifetime sequence may exceed live cap and remains valid.
 var drop:Node2D
 for d in w.stream.drops:
  if is_instance_valid(d) and d.get_meta("drop_id","")==egg_key:drop=d
 if is_instance_valid(drop):
  w.player.position=drop.position+Vector2(15,0)
  check(s.pickup(drop),"existing pickup collects egg")
 else:check(false,"egg visual installed")
 a.advance(720);check(a.egg_count("c")==3 and a.states.c.eggs>3,"pickup frees cap and new identity is unique")
 check(a.valid(a.serialize()),"lifetime egg count validates beyond live cap")
 a.states.c.fed_until=a.clock;a.states.c.product=0
 a.advance(1440);check(a.states.c.product==0 and not a.states.c.departed,"unfed tame pauses production and never disappears")
 # Sheep first yield requires complete healthy cycle; shear is atomic with wear.
 w.player.position=p;a.states.s=a.make_row("sheep",at);a.sync_visuals();await frames()
 var sh=a.visuals.s;sh.set_physics_process(false)
 s.inventory.selected=0;s.inventory.slots[0]={"item_id":"broad_leaf","count":20}
 for i in 5:
  if i>0:a.advance(30)
  check(a.feed("s",0,s.inventory.slots[0].duplicate(true)).is_empty(),"sheep trust feed "+str(i))
  check(a.states.s.tamed==(i==4),"sheep harder to tame "+str(i))
 s.inventory.equipment.main_hand=s.inventory.instance("shears")
 check(a.action("s")=="shear" and not a.interact("s",sh),"held shears expose action but newly tamed sheep cannot yield immediately")
 a.states.s.fed_until=a.clock+10000;a.advance(2880)
 check(a.action("s")=="shear","healthy mature sheep ready after two days")
 var instance=s.inventory.equipment.main_hand.instance_id
 check(a.interact("s",sh),"shearing succeeds")
 check(not a.states.s.wool and a.states.s.product==0 and s.inventory.count_item("wool")==2,"shear rewards two wool and switches shorn")
 check(s.inventory.equipment.main_hand.instance_id==instance and s.inventory.equipment.main_hand.durability==99,"shearing uses original instance durability")
 check(a.action("s")=="shear" and not a.interact("s",sh) and s.inventory.count_item("wool")==2 and s.inventory.equipment.main_hand.durability==99,"repeat shearing refused without reward or wear")
 a.advance(2879);check(not a.states.s.wool,"regrowth does not complete early")
 a.advance(1);check(a.states.s.wool and a.states.s.product==2880,"regrows wool once at boundary")
 a.states.s.fed_until=a.clock;a.states.s.wool=false;a.states.s.product=0;a.advance(3000)
 check(not a.states.s.wool and a.states.s.product==0,"unfed sheep pauses regrowth")
 # Pair, growth and population cap.
 a.states.c.fed_until=0;a.states.s.fed_until=0
 var bpos=a.find_near(at,35,70)
 a.states.p1=a.make_row("chicken",at,true);a.states.p2=a.make_row("chicken",bpos,true)
 a.advance(179);check(a.serial==0,"no premature birth")
 a.advance(1);check(a.serial==1 and a.states.has("born:1"),"one automatic baby per pair")
 if not a.states.has("born:1"):
  w.free();quit(1);return
 check(a.states["born:1"].tamed and a.stage(a.states["born:1"])==0,"baby inherits ownership and small stage")
 check(a.states.p1.cooldown==2880 and a.states.p2.cooldown==2880,"both parents receive cooldown")
 var baby=a.states["born:1"];baby.fed_until=a.clock+10000
 a.states.p1.fed_until=0;a.states.p2.fed_until=0
 a.advance(1439);check(a.stage(baby)==0 and a.egg_count("born:1")==0,"young baby has no products")
 a.advance(1);check(a.stage(baby)==1,"half-grown at day one")
 a.advance(2880);check(a.stage(baby)==2,"adult at day three")
 check(a.egg_count("born:1")==0,"no accumulated adult products during childhood")
 # Validation and atomic reload.
 var saved=a.serialize();check(a.valid(saved),"animal schema validates full states")
 for field in ["x","age","feed_at","cooldown"]:
  var bad=saved.duplicate(true);bad.objects.c[field]=NAN;check(not a.valid(bad),"reject nonfinite "+field)
 var bad=saved.duplicate(true);bad.version=99;check(not a.valid(bad),"unknown future version protects save")
 var savepath=OUT+"isolated-save.json";s.save_path=savepath;w.persistent_world=true
 check(s.save_state(),"full atomic animal snapshot writes isolated save")
 var expected=a.serialize();a.states.clear();a.generated.clear();a.clock=0;s.load_state()
 check(s.writable and JSON.stringify(JSON.parse_string(JSON.stringify(a.serialize())))==JSON.stringify(JSON.parse_string(JSON.stringify(expected))),"atomic reload restores exact timers/positions/IDs/tombstones")
 check(a.egg_count("c")==3,"reload cannot duplicate eggs")
 if "window" in OS.get_cmdline_user_args():
  a.sync_visuals();await frames(8)
  root.get_texture().get_image().save_png(OUT+"window.png")
 var failed=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open(OUT+("window" if "window" in OS.get_cmdline_user_args() else "logic")+".json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"));f.close()
 print("ANIMALS V1: ",checks.size()," checks, ",failed.size()," failed")
 w.persistent_world=false;w.free();await process_frame;quit(0 if failed.is_empty() else 1)
