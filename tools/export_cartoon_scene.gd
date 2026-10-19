extends SceneTree
func _initialize() -> void:
 var rig=load("res://art/scene_cartoon_v2/source_rig.tscn").instantiate()
 var ap: AnimationPlayer=rig.get_node("AnimationPlayer")
 ap.autoplay=""
 var lib=ap.get_animation_library("")
 for name in lib.get_animation_list():
  if str(name).ends_with("_wave"):
   lib.remove_animation(name)
   continue
  var clip=lib.get_animation(name)
  for i in range(clip.get_track_count()-1,-1,-1):
   var path=str(clip.track_get_path(i))
   if "Tree" in path or "Fruit" in path: clip.remove_track(i)
 for path in ["Visual/Tree","Visual/Fruit"]:
  rig.get_node(path).free()
 # Keep all parts on the player's Y-sorted canvas layer in the world.
 for node in rig.find_children("*","CanvasItem",true,false):
  node.show_behind_parent=node.z_index<0
  node.z_index=0
 var visual=rig.get_node("Visual")
 visual.move_child(visual.get_node("LegL"),0)
 visual.move_child(visual.get_node("LegR"),1)
 for name in lib.get_animation_list():
  var clip=lib.get_animation(name)
  for i in clip.get_track_count():
   var path=str(clip.track_get_path(i))
   if path.ends_with(":z_index"):
    clip.track_set_path(i,NodePath(path.replace(":z_index",":show_behind_parent")))
    for k in clip.track_get_key_count(i):
     clip.track_set_key_value(i,k,int(clip.track_get_key_value(i,k))<0)
 rig.get_node("Visual/Pelvis/ArmR/Grip/Axe").position.x=8.5
 rig.get_node("Visual/Pelvis/ArmR/Grip/Axe").texture=load("res://assets/environment/cartoon_v2/axe.png")
 var packed=PackedScene.new()
 packed.pack(rig)
 var result=ResourceSaver.save(packed,"res://assets/hero/cartoon/character.tscn")
 print("EXPORT ",result)
 rig.free()
 quit(result)
