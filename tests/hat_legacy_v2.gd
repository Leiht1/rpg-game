extends "res://tests/hat_motion_v2.gd"
func run() -> void:
 s=DataOnly.new();root.add_child(s);root.size=default_size();root.content_scale_size=root.size
 var vp:=SubViewport.new();vp.size=default_size();vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 var rigs: Array=[]
 for row in 2:
  var inv=ItemInventory.new(s.database);inv.equipment.head=inv.instance("wool_hat" if row==0 else "straw_hat")
  for col in 4:
   var facing: String=["front","back","left","right"][col]
   var rig: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate();vp.add_child(rig);rig.position=Vector2(col*320+60,row*300+45);rig.scale=Vector2.ONE*2
   var anim: AnimationPlayer=rig.get_node("AnimationPlayer");anim.play(("side" if col>=2 else facing)+"_breathe");anim.seek(0,true);anim.pause()
   var source: Sprite2D=rig.get_node("Visual/Pelvis/Head/Sprite");var original: Texture2D=source.texture
   var appearance=preload("res://scripts/equipment_appearance.gd").new();appearance.apply(rig,inv,facing)
   if facing=="left":rig.get_node("Visual").scale.x=-1;rig.get_node("Visual").position.x=128
   rig.set_meta("apparel_test",{"hair":source,"appearance":appearance,"inventory":inv,"facing":facing,"zoom":1.0,"row":row*2})
   check(source.texture==original,"legacy original head texture preserved "+facing)
   rigs.append(rig)
 await frames(3);await RenderingServer.frame_post_draw;vp.get_texture().get_image().save_png("res://reports/hat-motion-v2/legacy-heads.png")
 await verify_clip_gpu(vp,rigs,"legacy")
 await verify_seams_gpu(vp,rigs,"legacy")
 for rig in rigs:
  var info: Dictionary=rig.get_meta("apparel_test");info.inventory.equipment.head={};info.appearance.apply(rig,info.inventory,info.facing)
  check(info.hair.material==null,"legacy head restored after unequip "+info.facing);rig.queue_free()
 vp.queue_free();s.queue_free();await frames()
 var failed: Array=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open("res://reports/hat-motion-v2/legacy-results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"\t"));f.close()
 print("HAT_LEGACY ",checks.size()," checks ",failed.size()," failed");quit(1 if not failed.is_empty() else 0)
