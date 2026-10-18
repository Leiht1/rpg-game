extends "res://tests/capture_world_v06.gd"
const OUT="res://reports/scenery-occlusion-v02/"
func shot(label:String)->void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+label+".png")
func run()->void:
 Engine.set_meta("integration_seed",447349832)
 w=load("res://tests/world_v06_formal_fixture.gd").new();root.add_child(w)
 w.player.automated=true;w.player.camera.position_smoothing_enabled=false;await settle()
 var tree:Node2D
 for p in get_nodes_in_group("trees"):
  if p.variant_id=="tree_01" and (tree==null or p.position.distance_to(w.player.position)<tree.position.distance_to(w.player.position)):tree=p
 check(tree!=null,"formal slender tree available")
 w.set_process(false)
 var ratio:float=tree.display_size.x/256.
 for sample in [{"name":"diagonal-clear","offset":Vector2(70,-150)*ratio,"faded":false},{"name":"front-clear","offset":Vector2(0,35),"faded":false},{"name":"behind-whole-tree","offset":Vector2(0,-45)*ratio,"faded":true}]:
  w.player.position=tree.position+sample.offset
  w.player.reset_physics_interpolation();w.player.camera.reset_smoothing();await settle()
  tree.update_occlusion(w.player.position)
  check(tree.faded==sample.faded,"formal "+sample.name)
  await shot(sample.name)
 var failures:=checks.filter(func(c):return not c.pass).size()
 FileAccess.open(OUT+"formal.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 w.queue_free();await process_frame
 print("FORMAL_OCCLUSION ",checks.size()," FAILURES ",failures);quit(1 if failures else 0)
