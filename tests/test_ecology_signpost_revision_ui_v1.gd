extends "res://tests/test_ecology_signpost_v1.gd"
func run()->void:
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_clean_camp_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
 s=w.item_service;s.set_process(false);b=s.builds;p=w.player;ui=w.camp_ui
 s.save_path=OUT+"revision-ui-isolated.json";w.persistent_world=true
 s.inventory.add("wood",30);s.inventory.add("plant_fiber",20)
 while not w.stream.viewport_ready(p.position,Vector2(640,360)):await process_frame
 var row=find_row();check(not row.is_empty(),"loaded clear site exists for signpost")
 if row.is_empty():await finish("revision-ui");return
 ui.begin_build("build_signpost");ui.paint_at(Vector2(row.x,row.y));await frames()
 ui.sign_input.text="北方岩石区";await frames()
 var title:Control=ui.sign_input.get_parent().get_child(0)
 check(title.get_global_rect().end.y<ui.sign_input.get_global_rect().position.y,"paper title and input do not overlap")
 await shot("revision-naming-paper")
 ui.confirm_sign();check(b.map_signposts().size()==1,"paper dialog confirmation unchanged")
 w.map_view.open_map()
 while w.map_view.row<w.map_view.resolution:await process_frame
 w.map_view.zoom=1;await shot("revision-map-regions")
 w.map_view.zoom=16;w.map_view.center=Vector2(row.x,row.y);await shot("revision-map-text");w.map_view.close_map()
 var selected={}
 for yy in range(8,30):
  for xx in range(8,30):
   var id="harvest:1:%d:%d:0"%[xx,yy];s.resource_hits[id]=1;Dist.preserve_worked(s,true)
   if s.ore_nodes.has(id) and str(s.ore_nodes[id].kind).begins_with("buried_"):
    selected=s.ore_nodes[id].duplicate(true);break
   s.resource_hits.erase(id);s.ore_nodes.erase(id)
  if not selected.is_empty():break
 check(not selected.is_empty(),"previous ecology fixture resolves")
 if not selected.is_empty():
  s.ore_nodes.erase(selected.id)
  var old=s.snapshot();old.erase("ecology_layout_version")
  save_json("revision-legacy-input.json",old);s.load_state(OUT+"revision-legacy-input.json")
  check(s.ore_nodes.get(selected.id,{})==selected and s.resource_hits.get(selected.id,0)==1,"previous ecology layout migrates partial buried kind/position/hits")
  check(s.inventory.slots==old.slots and s.consumed==old.consumed,"layout migration retains inventory and consumed")
  check(s.save_state() and s.snapshot().ecology_layout_version==2,"layout migration persists in same original snapshot")
 await finish("revision-ui-compat-window")
