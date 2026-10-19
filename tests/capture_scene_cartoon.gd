extends SceneTree
func _initialize()->void:call_deferred("run")
func shot(path:String)->void:
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(path)
func run()->void:
 var w=load("res://scenes/world.tscn").instantiate();root.add_child(w)
 var p=w.player;p.automated=true;p.set_physics_process(false)
 while not w.started:await process_frame
 p.camera.reset_smoothing()
 await shot("res://reports/scene-cartoon-v2.png")
 var tree:Node2D
 for n in get_nodes_in_group("trees"):
  if n.get_meta("prop_id")=="clearing:0":tree=n
 p.position=tree.position-Vector2(44,0)
 p.camera.reset_smoothing();await physics_frame;p.try_interact()
 for i in 49:p._physics_process(1.0/60);await physics_frame
 print("CHOP OCCLUSION ",tree.faded)
 await shot("res://reports/scene-cartoon-chop.png")
 for i in 53:p._physics_process(1.0/60);await physics_frame
 var drop=w.stream.drops[0]
 p.position=drop.position+Vector2(-18,12)
 p.camera.reset_smoothing();await physics_frame;p.try_interact()
 for i in 76:p._physics_process(1.0/60);await physics_frame
 await shot("res://reports/scene-cartoon-pickup.png")
 quit()
