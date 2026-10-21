extends SceneTree
const OUT="res://reports/food-v2/"
const SAVE=OUT+"isolated-save.json"
var checks=[]
var w: Node
var s: Node
var events=[]
func check(ok: bool,label: String) -> void:
 checks.append({"name":label,"pass":ok})
 if not ok: push_error(label)
func _initialize() -> void: call_deferred("run")
func frames(n=3) -> void:
 for i in n: await process_frame
func fresh_body():
 var b=preload("res://scripts/body_state.gd").new();b.hunger=50.0;b.busy=true
 return b
func finish(suffix: String) -> void:
 var failed=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open(OUT+suffix+".json",FileAccess.WRITE);f.store_string(JSON.stringify({"count":checks.size(),"failed":failed.size(),"checks":checks},"\t"));f.close()
 print("FOOD V2 ",suffix,": ",checks.size()," checks, ",failed.size()," failed")
 w.persistent_world=false;w.free();await process_frame;quit(0 if failed.is_empty() else 1)
func run() -> void:
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started: await process_frame
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
 s=w.item_service;s.set_process(false)
 while not w.stream.viewport_ready(w.player.position,Vector2(640,360)): await process_frame
 await frames(5)
 s.save_path=SAVE;w.persistent_world=true
 s.item_obtained.connect(func(id,count):events.append([id,count]))
 if "read" in OS.get_cmdline_user_args():
  s.load_state()
  check(s.writable,"fresh process restores atomic save")
  if not s.writable: await finish("restart");return
  check(is_equal_approx(s.body.hallucination_remaining,45.0),"fresh process exact remaining time, no offline advance")
  check(s.consumed.has("food-mushroom-picked"),"pickup remains consumed")
  check(s.camps.states.test.ready and s.camps.states.test.recipe=="herb_mushroom","old paid herb task remains valid")
  var before=s.inventory.count_item("herb_roasted_mushroom")
  check(s.camps.act("test","claim").is_empty(),"restored paid herb task claims")
  check(not s.camps.act("test","claim").is_empty(),"restored repeated claim refused")
  check(s.inventory.count_item("herb_roasted_mushroom")==before+1 and events.size()==1,"restored reward and notification once")
  check(s.planting.stage(s.builds.states.legacy_plot)==2,"old mature crop stays mature after cycle migration")
  check(s.builds.states.legacy_plot.growth_minutes==2880,"cycle migration performed only once")
  await finish("restart");return
 check(s.database.errors.is_empty(),"database validates")
 var expected={"wildflower":1,"wild_berry":2,"wild_carrot":2,"wild_apple":3,"brown_mushroom":2,"roasted_carrot":6,"roasted_mushroom":7,"herb_roasted_mushroom":10,"roasted_fruit_platter":36,"field_harvest_platter":40,"potato":5,"cabbage":6,"roasted_potato":12,"roasted_cabbage":16,"vegetable_soup":24,"stewed_vegetables":36}
 for id in expected:
  var b=fresh_body();var inv=ItemInventory.new(s.database);inv.body=b;inv.add(id,1)
  var slot=0
  for i in 40:
   if inv.slots[i].get("item_id","")==id:slot=i;break
  check(inv.use_slot(slot) and is_equal_approx(b.hunger,50+expected[id]),"actual inventory hunger "+id)
  check(b.health==100 and b.stamina==100 and b.energy==100,"no instant other gains "+id)
  check((b.hallucination_remaining>0)==(id=="brown_mushroom"),"raw mushroom only "+id)
 var b=fresh_body();b.eat({"hunger":2,"hallucination":true})
 check(b.health==100,"raw mushroom no immediate damage")
 for i in 4:
  b.advance(37.5,15,false,false)
  check(is_equal_approx(b.health,100-5*(i+1)),"uniform five health each quarter hour "+str(i))
 check(b.hallucination_remaining==0,"ends at exactly one hour")
 b.advance(150,60,false,false);check(is_equal_approx(b.health,80),"no damage after ending")
 b=fresh_body();b.eat({"hallucination":true});b.advance(75,30,false,false);b.eat({"hallucination":true});b.advance(75,30,false,false)
 check(is_equal_approx(b.health,80) and b.hallucination_remaining==30,"repeat refreshes duration without stacking rate")
 b.eat(s.database.item("roasted_mushroom").effects);check(b.hallucination_remaining==30,"safe cooked mushroom does not cure active effect")
 b.sleeping=true;b.sleep_duration=180;b.advance(75,30,false,false)
 check(is_equal_approx(b.health,70) and b.hallucination_remaining==0,"sleep continues damage at same rate")
 b=fresh_body();b.health=16;b.eat({"hallucination":true});b.advance(150,60,false,false)
 check(b.health>0 and b.down,"low health uses existing safe care")
 b.advance(300,120,false,false);check(not b.down and b.health>=30,"safe care recovers without death")
 b=fresh_body();b.hallucination_remaining=23.5
 var data=b.serialize();var copy=fresh_body();check(copy.restore(data) and copy.hallucination_remaining==23.5,"body exact roundtrip")
 for bad in [-1,61,"bad",INF]:
  data.hallucination_remaining=bad
  check(not copy.restore(data) and copy.hallucination_remaining==23.5,"invalid hallucination rejected atomically "+str(bad))
 data=b.serialize();data.erase("hallucination_remaining");check(copy.restore(data) and copy.hallucination_remaining==0,"old body defaults clear")
 for crop in ["carrot","potato","cabbage"]:
  var rule=s.planting.rules.crops[crop];var days={"carrot":2,"potato":4,"cabbage":6}[crop]
  check(rule.minutes==days*1440,"crop total "+crop)
  for v in [[0,0],[rule.stage_minutes,1],[rule.minutes,2]]:
   check(s.planting.stage({"crop":crop,"growth_minutes":v[0]})==v[1],"static stage "+crop+str(v[1]))
 var c=s.camps;var at=w.player.position+Vector2(0,50)
 c.states.clear();c.states.test={"x":at.x,"y":at.y,"fuel":1200.0,"lit":true,"recipe":"","elapsed":0.0,"ready":false};c.rebuild();c.install(w.stream.chunk_at(at))
 for id in c.rules.recipes:
  var r=c.rules.recipes[id];var mats={}
  for item in r.materials:mats[item]=int(r.materials[item]);s.inventory.add(item,int(r.materials[item])*2)
  check(c.match_materials(mats)==id,"exact material match "+id)
  mats.wood=1;check(c.match_materials(mats).is_empty(),"extra material rejected "+id);mats.erase("wood")
  var before=s.inventory.slots.duplicate(true)
  check(c.act("test","experiment","",mats).is_empty(),"start shared cooking "+id)
  check(not c.act("test","experiment","",mats).is_empty(),"repeat start rejected "+id)
  c.advance(float(r.seconds)-.5);check(not c.states.test.ready,"correct cooking duration "+id)
  c.advance(.5);check(c.states.test.ready and c.known(id),"completion discovers "+id)
  var count=s.inventory.count_item(r.output);var event_count=events.size()
  check(c.act("test","claim").is_empty(),"claim output "+id)
  check(not c.act("test","claim").is_empty() and s.inventory.count_item(r.output)==count+1 and events.size()==event_count+1,"single reward "+id)
 check(c.match_materials({"wildflower":1,"brown_mushroom":2}).is_empty(),"old herb input no longer starts")
 check(c.match_materials({"broad_leaf":2,"brown_mushroom":1})=="herb_mushroom","formal broad leaf used")
 # Real naturally generated candidate and normal world pickup path.
 var found={}
 for core in [w.generator.spawn]+Array(w.generator.region_cores):
  for y in range(-3,4):
   for x in range(-3,4):
    for row in s.entries(w.stream.chunk_at(core)+Vector2i(x,y)):
     if row.item_id=="brown_mushroom":found=row;break
    if not found.is_empty():break
   if not found.is_empty():break
  if not found.is_empty():break
 check(not found.is_empty(),"wild distribution produces mushroom")
 if not found.is_empty():
  check(found.mode=="pickup" and found.natural,"mushroom is natural loose pickup")
  var drop=w.stream.create_item_drop(found);w.player.position=drop.position
  var before=s.inventory.count_item("brown_mushroom")
  check(preload("res://scripts/world_interaction.gd").execute(w.stream,w.player,drop) and s.inventory.count_item("brown_mushroom")==before+1,"actual natural mushroom pickup enters inventory")
  check(s.consumed.has(found.id),"natural id consumed and persisted")
  s.consumed["food-mushroom-picked"]=true
  w.player.position=at-Vector2(0,50)
 # Existing paid old recipe does not reconsume newly changed ingredients.
 c.states.test.recipe="herb_mushroom";c.states.test.elapsed=10.0;c.states.test.ready=true
 var plot=s.builds.candidate("tilled_soil",w.player.position+Vector2(192,128),false,true,0)
 plot.crop="carrot";plot.growth_minutes=360.0;plot.roots=false;s.builds.states.legacy_plot=plot
 var old=s.snapshot();old.erase("planting_cycle_version")
 var f=FileAccess.open(SAVE,FileAccess.WRITE);f.store_string(JSON.stringify(old));f.close();s.load_state()
 check(s.writable and s.planting.stage(s.builds.states.legacy_plot)==2,"legacy mature crop migrates safely")
 s.body.hunger=50;s.body.health=100;s.body.eat({"hallucination":true});s.body.busy=true
 w.environment_view.simulation.paused=false
 w.environment_view.advance_gameplay(37.5)
 check(is_equal_approx(s.body.hallucination_remaining,45) and is_equal_approx(s.body.health,95),"real gameplay clock advances hallucination uniformly")
 check(s.save_state(),"atomic save for fresh process")
 # Visual uses existing world-only grading layer, below all HUD and inventory.
 check(w.environment_view.layer<w.ui.layer,"world shader below HUD/inventory")
 w.environment_view.simulation.paused=true
 w.environment_view._process(2.0)
 check(w.environment_view.hallucination_visual>0,"visual smoothly enters")
 w.item_ui.obtained.set_process(false);w.item_ui.obtained.card.hide()
 w.camp_ui.open("test");w.camp_ui.selected="roast_potato";w.camp_ui.refresh()
 check(w.camp_ui.recipes.size()==w.item_service.camps.rules.recipes.values().filter(func(row):return not row.get("legacy_only",false)).size(),"all nine recipes appear in scrolling book")
 if not DisplayServer.get_name()=="headless":
  await frames(5);await RenderingServer.frame_post_draw
  var distorted=root.get_texture().get_image()
  distorted.save_png(OUT+"hallucination-book.png")
  w.environment_view.material_effect.set_shader_parameter("hallucination",0.0)
  await frames(2);await RenderingServer.frame_post_draw
  var normal=root.get_texture().get_image()
  normal.save_png(OUT+"normal-book.png")
  check(distorted.get_region(Rect2i(150,95,975,505)).get_data()==normal.get_region(Rect2i(150,95,975,505)).get_data(),"GPU book text/panel remains pixel identical")
  check(distorted.get_region(Rect2i(0,220,120,400)).get_data()!=normal.get_region(Rect2i(0,220,120,400)).get_data(),"GPU world actually distorted")
 w.camp_ui.close_panel()
 s.body.hallucination_remaining=0;w.environment_view._process(.5)
 check(w.environment_view.hallucination_visual>0,"visual fades gradually")
 w.environment_view._process(3.0);check(w.environment_view.hallucination_visual==0,"visual clears completely")
 # Preserve the checkpoint with 45 minutes, not the visual test edits.
 w.persistent_world=false
 await finish("window" if DisplayServer.get_name()!="headless" else "headless")
