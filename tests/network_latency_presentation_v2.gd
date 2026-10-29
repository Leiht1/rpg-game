extends SceneTree
var samples: Dictionary={}
var progress_samples: Array=[]
var finishes:=0
func _initialize() -> void:run.call_deferred()
func run() -> void:
 Engine.set_meta("integration_seed",271828)
 var w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 while not w.started:await process_frame
 w.set_process(false);w.environment_view.set_process(false);w.player.set_physics_process(false)
 var s=w.item_service;s.set_process(false)
 while not w.stream.viewport_ready(w.player.position,Vector2(640,360)):await process_frame
 w.set_meta("network_game",true)
 var b=s.builds
 var row: Dictionary=b.candidate("fence_gate",w.player.position+Vector2(80,0),false,false,0)
 b.states["latency-door"]=row;b.refresh_all()
 await process_frame
 var old: Node=b.visuals["latency-door"]
 var closed_angle: float=old.gate_angle
 var state: Dictionary=s.snapshot().duplicate(true)
 state.buildings.objects["latency-door"].open=true
 s.load_state("",false,state)
 var door: Node=b.visuals["latency-door"]
 var angles: Array=[]
 for i in 18:
  angles.append(door.gate_angle)
  if i==6 and OS.get_environment("WINDREST_AUDIT_PHASE")=="after" and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://reports/.tmp/network-door-mid-v2.png"))
  await create_timer(.016).timeout
 samples={"same_door_node":old==door,"closed_angle":closed_angle,"angles":angles,"initial_jump":absf(float(angles[0])-closed_angle),"final_angle":door.gate_angle}
 if OS.get_environment("WINDREST_AUDIT_PHASE")=="after":
  s.load_state("",false,state)
  assert(b.visuals["latency-door"]==door,"Repeated snapshot rebuilt door")
  state.buildings.objects["latency-door"].open=false
  s.load_state("",false,state)
  var close_start: float=door.gate_angle
  await create_timer(.08).timeout
  assert(absf(door.gate_angle)>0.01 and absf(door.gate_angle)<absf(close_start),"Close did not animate")
  await create_timer(.3).timeout
  assert(absf(door.gate_angle-closed_angle)<.001,"Close did not finish")
  samples.close_animation=true
  w.item_ui.craft_panel.set_mode(true)
  w.item_ui.craft_panel.finish_craft("hand_leaf_fiber",1,"")
  assert(w.item_ui.craft_panel.status.text.begins_with("制作成功"),"Build panel broke craft completion")
  samples.craft_completion_after_build_panel=true
 var controller=load("res://tests/network_priority_world_v1.gd").new();controller.item_service=s
 var slots_before: Array=s.inventory.slots.duplicate(true)
 s.craft_job={"recipe_id":"hand_stone_axe","batches":1,"elapsed":0.0,"duration":1.5,"serial":991,"station_id":""}
 s.craft_progress.connect(func(value: float):progress_samples.append(value))
 s.craft_finished.connect(func(_id,_count,_reason):finishes+=1)
 if controller.has_method("render_craft_progress"):
  for i in 30:
   controller.render_craft_progress(.016)
   await create_timer(.016).timeout
  controller.render_craft_progress(10.0)
 samples.craft_progress=progress_samples
 samples.craft_authority_elapsed=s.craft_job.elapsed
 samples.craft_finished=finishes
 samples.craft_inventory_unchanged=s.inventory.slots==slots_before
 if OS.get_environment("WINDREST_AUDIT_PHASE")=="after":
  assert(samples.same_door_node and samples.initial_jump<.01,"Door snapped or rebuilt")
  assert(absf(float(samples.angles[6])-samples.closed_angle)>.05 and absf(float(samples.angles[6])-samples.final_angle)>.05,"No intermediate door angle")
  assert(progress_samples.size()==31 and progress_samples[15]>progress_samples[1],"Craft progress did not animate")
  assert(progress_samples[-1]<1.0 and finishes==0 and samples.craft_inventory_unchanged and s.craft_job.elapsed==0,"Client committed craft")
 controller.free();s.craft_job={}
 var phase: String=OS.get_environment("WINDREST_AUDIT_PHASE")
 var folder: String="res://reports/network-latency-v2/"+phase
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 FileAccess.open(folder+"/presentation.json",FileAccess.WRITE).store_string(JSON.stringify(samples,"  "))
 print("DOOR_PRESENTATION ",JSON.stringify(samples))
 w.queue_free();await process_frame;quit()
