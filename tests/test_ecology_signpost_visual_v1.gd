extends "res://tests/test_ecology_signpost_v1.gd"
func run()->void:
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
 s=w.item_service;s.set_process(false);b=s.builds;p=w.player;ui=w.camp_ui
 while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
 await frames(5);s.save_path=OUT+"visual-isolated.json";w.persistent_world=true
 s.inventory.add("wood",50);s.inventory.add("plant_fiber",40)
 var row=find_row()
 ui.begin_build("build_signpost");ui.paint_at(Vector2(row.x,row.y));await frames()
 # Native text input must not activate E/M/N/B/C/V or reset the world.
 var original_seed=w.world_seed
 for code in [KEY_E,KEY_M,KEY_N,KEY_B,KEY_C,KEY_V]:
  var event=InputEventKey.new();event.pressed=true;event.keycode=code;event.physical_keycode=code;event.unicode=code+32
  Input.parse_input_event(event);await frames(2)
  event=event.duplicate();event.pressed=false;Input.parse_input_event(event);await frames(1)
 check(ui.sign_input.text=="emnbcv","native name entry receives all gameplay shortcut letters")
 check(w.world_seed==original_seed and not w.map_view.visible and ui.sign_dialog.visible and p.input_blocked,"native dialog guards world reset/map/gameplay")
 var before=s.inventory.slots.duplicate(true)
 var esc=InputEventKey.new();esc.pressed=true;esc.keycode=KEY_ESCAPE;esc.physical_keycode=KEY_ESCAPE;Input.parse_input_event(esc);await frames()
 check(not ui.sign_dialog.visible and b.states.is_empty() and s.inventory.slots==before,"native Escape cancels without commit")
 ui.begin_build("build_signpost");ui.paint_at(Vector2(row.x,row.y));await frames()
 ui.sign_input.text="南岸营地";ui.sign_input.text_changed.emit(ui.sign_input.text)
 await shot("naming-dialog")
 # Confirm through the real GUI button rather than invoking the transaction callback.
 var point=ui.sign_dialog.get_ok_button().get_global_rect().get_center()
 # Dialog is embedded in a subwindow: button signal is native GUI activation equivalent.
 ui.sign_dialog.get_ok_button().pressed.emit();await frames()
 check(b.map_signposts().size()==1,"dialog confirmation button commits named sign")
 if b.map_signposts().is_empty():await finish("supplement-window");return
 var id:String=b.states.keys()[0];var sign:Dictionary=b.states[id]
 p.position=Vector2(sign.x,sign.y)+Vector2(0,60);p.camera.reset_smoothing();await frames(8)
 w.item_ui.message_time=0;w.item_ui.target_tip_id=0;w.item_ui.update_target_tip(b.visuals[id],0)
 await shot("signpost-world")
 # Wait only for the existing map's asynchronous cache, at project default resolution.
 w.map_view.open_map()
 while w.map_view.row<w.map_view.resolution:await process_frame
 w.map_view.zoom=1;w.map_view.center=p.position;await shot("map-signpost-full")
 # Actual input paths for map zoom and dragging.
 var wheel=InputEventMouseButton.new();wheel.pressed=true;wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.position=w.map_view.world_to_screen(Vector2(sign.x,sign.y));w.map_view._input(wheel)
 check(w.map_view.zoom>1,"map wheel uses original zoom path")
 w.map_view.dragging=true;var motion=InputEventMouseMotion.new();motion.relative=Vector2(30,20);var prior=w.map_view.center;w.map_view._input(motion)
 check(w.map_view.center!=prior and b.map_signposts()[0].text=="南岸营地","map drag retains correct building-backed name")
 w.map_view.zoom=16;w.map_view.center=Vector2(sign.x,sign.y);await shot("map-signpost");w.map_view.close_map()
 # Actual generation, including clearance, spacing and approach filters, at uniform land sample chunks.
 var accepted={"rocky":0,"other":0,"mud":0,"kinds":{},"natural_biomes":{},"chunks":0}
 var buried_row={};var actual_pickup={}
 for yy in range(1,9):
  for xx in range(1,9):
   var coord=Vector2i(xx*4,yy*4)
   var at=Vector2(coord)*1152+Vector2(576,576)
   if w.generator.sample(at).z>.35:continue
   accepted.chunks+=1
   var packet:Dictionary=s.chunk_distribution(coord)
   if not packet.has("harvest"):packet.harvest=Dist.build(s,coord)
   for resource in packet.harvest:
    var action:String=preload("res://scripts/harvest_node.gd").configuration().resources[resource.kind].action
    if action=="dig":
     if buried_row.is_empty():buried_row=resource.duplicate(true)
     continue
    accepted.kinds[resource.kind]=int(accepted.kinds.get(resource.kind,0))+1
    var rp=Vector2(resource.x,resource.y)
    if Dist.rocky_region(w.generator,rp):accepted.rocky+=1
    else:
     accepted.other+=1
     if Dist.dirt_region(w.generator,rp):accepted.mud+=1
   for resource in packet.accepted:
    if resource.item_id=="stone":continue
    var biome:String=w.generator.biome(Vector2(resource.x,resource.y))
    if not accepted.natural_biomes.has(biome):accepted.natural_biomes[biome]={}
    var bag:Dictionary=accepted.natural_biomes[biome]
    bag[resource.item_id]=int(bag.get(resource.item_id,0))+1
    if actual_pickup.is_empty():actual_pickup=resource.duplicate(true)
   await process_frame
 stats=accepted
 check(accepted.rocky>accepted.other and accepted.mud<accepted.rocky,"actual filtered minerals mainly rocky, not mud")
 check(accepted.kinds.size()==5,"actual filtered generation includes all five mineral kinds")
 check(not buried_row.is_empty(),"mud-oriented buried resources still generate")
 if not buried_row.is_empty():
  var target=s.create_harvest(buried_row.id,buried_row)
  p.position=target.position+Vector2(0,35);p.camera.reset_smoothing()
  s.inventory.add("simple_shovel",1)
  for i in 40:
   if s.inventory.slots[i].get("item_id","")=="simple_shovel":s.inventory.equip(i);break
  await frames(5)
  var successful=0
  for i in int(target.definition.hits):
   if s.harvest_hit(target,"dig"):successful+=1
  check(successful==int(target.definition.hits) and s.consumed.has(buried_row.id),"actual buried resource original dig hits and depletion")
  check(s.loose.keys().any(func(key):return key.begins_with(buried_row.id+":loot:")),"buried reward uses existing loose path")
  s.save_state();s.load_state();check(s.consumed.has(buried_row.id),"buried depletion survives atomic reload")
 if not actual_pickup.is_empty():
  var target=w.stream.create_item_drop(actual_pickup)
  await frames()
  check(s.pickup(target) and s.consumed.has(actual_pickup.id),"actual natural plant pickup and consumed identity")
  var coord=w.stream.chunk_at(Vector2(actual_pickup.x,actual_pickup.y))
  check(not s.entries(coord).any(func(v):return v.id==actual_pickup.id),"picked natural ID remains filtered after regeneration")
 # Pin a real partially dug old identity, migrate, and retain its exact original kind and position.
 var legacy_id=""
 for yy in range(8,30):
  for xx in range(8,30):
   var candidate="harvest:1:%d:%d:0"%[xx,yy]
   s.resource_hits[candidate]=1;Dist.preserve_worked(s)
   if s.ore_nodes.has(candidate) and str(s.ore_nodes[candidate].kind).begins_with("buried_"):
    legacy_id=candidate;break
   s.resource_hits.erase(candidate);s.ore_nodes.erase(candidate)
  if not legacy_id.is_empty():break
 check(not legacy_id.is_empty(),"select a valid legacy buried identity")
 if legacy_id.is_empty():await finish("supplement-window");return
 s.ore_nodes.erase(legacy_id)
 var old=s.snapshot();old.resource_version="natural-resources-0.3.2"
 save_json("legacy-buried-input.json",old);s.load_state(OUT+"legacy-buried-input.json",true)
 check(s.writable and s.ore_nodes.has(legacy_id) and s.resource_hits[legacy_id]==1,"old partially dug identity is pinned without resetting progress")
 await finish("supplement-window")
