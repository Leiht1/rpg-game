extends SceneTree
const Fresh=preload("res://scripts/food_freshness.gd")
var w: Node
var s: Node
var failures:=0
var checks:=0
var original: Dictionary={}
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1;push_error(label)
 print("CHECK ",ok," ",label)
func files() -> Dictionary:
 var result: Dictionary={}
 for name in DirAccess.get_files_at("user://"):
  if name.ends_with(".json") or name.ends_with(".tmp"):result[name]=FileAccess.get_sha256("user://"+name)
 return result
func _initialize() -> void:call_deferred("run")
func run() -> void:
 original=files()
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.set_process(false);w.environment_view.set_process(false);w.player.set_physics_process(false)
 s=w.item_service;s.set_process(false);s.animals.set_process(false)
 while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
 for i in 40:s.inventory.slots[i]={}
 for id in ["wood","stone","flint","plant_fiber"]:s.inventory.add(id,80)
 s.inventory.add("lake_fish",2);s.inventory.add("roasted_fish",2)
 var snapshot: Array=s.inventory.slots.duplicate(true)
 for stack in s.inventory.slots:Fresh.advance(s.database,stack,120)
 check(snapshot!=s.inventory.slots,"aging reproduces old exact snapshot mismatch")
 check(Fresh.matches_slots(s.inventory.slots,snapshot),"passive aging accepted")
 var mutated: Array=s.inventory.slots.duplicate(true)
 mutated[8].count-=1
 check(not Fresh.matches_slots(mutated,snapshot),"material count change rejected")
 mutated=s.inventory.slots.duplicate(true);var temp: Dictionary=mutated[8];mutated[8]=mutated[9];mutated[9]=temp
 check(not Fresh.matches_slots(mutated,snapshot),"slot movement rejected")
 check(not Fresh.matches_slots([{item_id="stone_hammer",count=1,instance_id="new",durability=90}],[{item_id="stone_hammer",count=1,instance_id="old",durability=90}]),"tool identity change rejected")
 check(not Fresh.matches_slots([{item_id="stone_hammer",count=1,durability=89}],[{item_id="stone_hammer",count=1,durability=90}]),"tool wear change rejected")
 check(not Fresh.matches_slots([{item_id="lake_fish",count=1}], [{item_id="roasted_fish",count=1}]),"item replacement rejected")
 var origin: Vector2=w.player.position
 var reasons: Dictionary={}
 var at:=Vector2.ZERO
 for y in range(-450,451,24):
  if at!=Vector2.ZERO:break
  for x in range(-450,451,24):
   var point: Vector2=origin+Vector2(x,y)
   w.player.position=point+Vector2(0,75)
   var issue: String=s.camps.placement_reason(point)
   reasons[issue]=int(reasons.get(issue,0))+1
   if w.generator.can_walk(w.player.position,16) and issue.is_empty():at=point;break
 print("SITE REASONS ",reasons)
 check(at!=Vector2.ZERO,"legal campfire site found")
 w.camp_ui.begin_build("hand_simple_campfire")
 for stack in s.inventory.slots:Fresh.advance(s.database,stack,120)
 w.camp_ui._process(.01)
 check(not w.camp_ui.placement_tip.text.contains("背包已变化"),"campfire preview accepts continuing freshness")
 w.camp_ui.cancel_placement()
 s.save_path="res://reports/build-freshness-v1/isolated-save.json";w.persistent_world=true
 var current: Array=s.inventory.slots.duplicate(true)
 s.save_path="res://reports/build-freshness-v1/missing/save.json"
 var before: Dictionary=s.camps.states.duplicate(true)
 check(s.camps.build(at,"hand_simple_campfire",snapshot).begins_with("保存失败"),"campfire reaches save and fails safely")
 check(s.inventory.slots==current and s.camps.states==before,"campfire rollback preserves current freshness and materials")
 s.save_path="res://reports/build-freshness-v1/isolated-save.json"
 check(s.camps.build(at,"hand_simple_campfire",snapshot).is_empty(),"campfire builds despite aged food")
 var aged: Array=s.inventory.slots.filter(func(v):return v.get("item_id","")=="lake_fish")
 check(aged.size()==1 and aged[0].spoilage>0,"successful build keeps current fish freshness")
 for kind in ["wood_floor","wood_chest","wood_fence"]:
  var row: Dictionary={}
  for y in range(-400,401,48):
   if not row.is_empty():break
   for x in range(-400,401,48):
    var point: Vector2=origin+Vector2(x,y)
    w.player.position=point+Vector2(0,75)
    var candidate: Dictionary=s.builds.candidate(kind,point,false,true,0)
    if s.builds.reason(candidate).is_empty():row=candidate;break
  check(not row.is_empty(),kind+" legal site")
  if row.is_empty():continue
  snapshot=s.inventory.slots.duplicate(true)
  for stack in s.inventory.slots:Fresh.advance(s.database,stack,20)
  current=s.inventory.slots.duplicate(true)
  s.inventory.slots[8].count-=1
  check(s.builds.place(row,snapshot).begins_with("背包已变化"),kind+" real inventory change rejected")
  s.inventory.slots=current
  var buildings: Dictionary=s.builds.states.duplicate(true)
  s.save_path="res://reports/build-freshness-v1/missing/save.json"
  check(s.builds.place(row,snapshot).begins_with("保存失败"),kind+" aged snapshot reaches save")
  check(s.inventory.slots==current and s.builds.states==buildings,kind+" rollback exact")
  s.save_path="res://reports/build-freshness-v1/isolated-save.json"
  check(s.builds.place(row,snapshot).is_empty(),kind+" builds with food aging")
 check(s.save_state(),"isolated snapshot saves")
 var saved: Array=s.inventory.slots.duplicate(true)
 s.load_state()
 var equal: bool=Fresh.matches_slots(s.inventory.slots,saved)
 for i in saved.size():
  if saved[i].has("spoilage"):equal=equal and absf(float(saved[i].spoilage)-float(s.inventory.slots[i].spoilage))<0.0000001
 check(equal,"saved freshness and remaining materials reload")
 check(files()==original,"player save hashes unchanged")
 w.persistent_world=false;w.free();await process_frame
 print("RESULT ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
