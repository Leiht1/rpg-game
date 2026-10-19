extends "res://tests/test_ecology_signpost_v1.gd"
func run()->void:
 Engine.set_meta("integration_seed",271828)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.environment_view.set_process(false);w.player.set_physics_process(false);w.set_process(false)
 s=w.item_service;s.set_process(false);b=s.builds;p=w.player
 s.save_path=OUT+"compat-isolated.json";w.persistent_world=true
 s.inventory.add("wood",12)
 var selected={}
 for yy in range(8,30):
  for xx in range(8,30):
   var id="harvest:1:%d:%d:0"%[xx,yy]
   s.resource_hits[id]=1;Dist.preserve_worked(s)
   if s.ore_nodes.has(id) and str(s.ore_nodes[id].kind).begins_with("buried_"):
    selected=s.ore_nodes[id].duplicate(true);break
   s.resource_hits.erase(id);s.ore_nodes.erase(id)
  if not selected.is_empty():break
 check(not selected.is_empty(),"legacy fixture actually resolves to old buried kind")
 if selected.is_empty():await finish("compat-corrected");return
 s.ore_nodes.erase(selected.id)
 var old=s.snapshot();old.resource_version="natural-resources-0.3.2";old.harvest_version="harvest-resources-2.1.0"
 save_json("legacy-buried-corrected-input.json",old);s.load_state(OUT+"legacy-buried-corrected-input.json",true)
 check(s.writable and s.ore_nodes.has(selected.id),"legacy partially dug identity reconstructed during migration")
 check(s.ore_nodes[selected.id]==selected and s.resource_hits[selected.id]==1,"legacy buried kind/position/progress exact")
 check(s.consumed==old.consumed and s.inventory.slots==old.slots,"legacy consumed and inventory unchanged")
 check(s.save_state(),"migration atomic snapshot writes")
 s.load_state();check(s.ore_nodes[selected.id]==selected,"corrected old buried fixture survives reload")
 await finish("compat-corrected")
