extends "res://tests/season_gear_v1.gd"
class DataOnly extends Node:
 var database=ItemDatabase.new()
func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://reports/hat-motion-v2")
 s=DataOnly.new();root.add_child(s);root.size=default_size();root.content_scale_size=root.size
 await motion_tests()
 await visual_tests()
 var failed: Array=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open("res://reports/hat-motion-v2/results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"\t"));f.close()
 print("HAT_MOTION ",checks.size()," checks ",failed.size()," failed")
 s.queue_free();await frames();quit(1 if not failed.is_empty() else 0)
func visual_tests() -> void:
 var vp:=SubViewport.new();vp.size=default_size();vp.transparent_bg=false;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 var db=s.database
 var fixed_transforms: Dictionary={}
 for hair_id in Catalog.rules().hair:
  var rigs: Array=[]
  for row in 4:
   var inv=ItemInventory.new(db)
   inv.equipment.head=inv.instance("wool_hat" if row<2 else "straw_hat")
   inv.equipment.outfit=inv.instance("wool_sweater" if row<2 else "straw_raincoat")
   for col in 4:
    var facing: String=["front","back","left","right"][col]
    var cell:=Control.new();cell.position=Vector2(col*320,row*175);cell.size=Vector2(320,175);cell.clip_contents=true;vp.add_child(cell)
    for zoom in [1.0,2.0]:
     var rig: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate();cell.add_child(rig)
     rig.position=Vector2(4 if zoom==1 else 80,-34 if zoom==2 else 40);rig.scale=Vector2.ONE*zoom
     var anim: AnimationPlayer=rig.get_node("AnimationPlayer");anim.play(("side" if col>=2 else facing)+"_breathe");anim.seek(0,true);anim.pause()
     var look=preload("res://scripts/character_look.gd").new();look.apply(rig,{"gender":"male" if row%2==0 else "female","hair_id":hair_id,"skin_id":"skin_2"},inv,facing)
     var head: Sprite2D=rig.get_node("Visual/Pelvis/Head/Sprite");var hair: Sprite2D=head.get_node("CharacterHairfront");var original: Texture2D=hair.texture
     var appearance=preload("res://scripts/equipment_appearance.gd").new();appearance.apply(rig,inv,facing);appearance.apply_layers(rig,inv,facing)
     check(hair.texture==original and hair.visible,"original hair preserved %s %s %s"%[hair_id,row,facing])
     var hat: Sprite2D=head.get_node("EquipmentVisual_head_0" if row<2 else "EquipmentVisual_head_1")
     var transform_key: String=("wool" if row<2 else "straw")+facing
     if not fixed_transforms.has(transform_key):fixed_transforms[transform_key]=hat.transform
     check(hat.transform==fixed_transforms[transform_key] and is_equal_approx(hat.scale.x,hat.scale.y),"fixed uniform hat size position across all hair and genders "+transform_key)
     if row>=2:
      check(head.get_node("EquipmentVisual_head_0").show_behind_parent and not hat.show_behind_parent,"far brim behind head near brim in front "+facing)
     if col==0:
      check(not rig.get_node("Visual/Pelvis/ArmR").show_behind_parent and rig.get_node("Visual/Pelvis/ClothingFrontArm").visible and not rig.get_node("Visual/ArmLBehind").visible,"front clothing exactly one foreground empty arm and original right "+str(row))
     if row<2:
      check(rig.get_node("Visual/Pelvis/ArmR/Sprite").material.get_shader_parameter("skin_region")==Vector2(.86,1),"wool fabric excluded from skin tint "+facing)
     rig.set_meta("apparel_test",{"hair":hair,"appearance":appearance,"inventory":inv,"facing":facing,"zoom":zoom,"row":row})
     check(hat.get_index()>hair.get_index() and head.is_ancestor_of(hat),"hat follows actual head outside hair %s %s %s"%[hair_id,row,facing])
     if col==2:rig.get_node("Visual").scale.x=-1;rig.get_node("Visual").position.x=128
     rigs.append(rig)
  await frames(3)
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   vp.get_texture().get_image().save_png("res://reports/hat-motion-v2/hair-"+str(hair_id)+".png")
  if DisplayServer.get_name()!="headless":await verify_seams_gpu(vp,rigs,str(hair_id))
  if DisplayServer.get_name()!="headless" :
   await verify_clip_gpu(vp,rigs,str(hair_id))
  for rig in rigs:
   var info: Dictionary=rig.get_meta("apparel_test");info.inventory.equipment.head={};info.appearance.apply(rig,info.inventory,info.facing)
   check(info.hair.material==null,"unequip restores complete original hair material "+str(hair_id)+info.facing)
   rig.queue_free()
  await frames(2)
 vp.queue_free()
func verify_seams_gpu(vp: SubViewport, rigs: Array, hair_id: String) -> void:
 for rig in rigs:rig.hide()
 vp.transparent_bg=true
 for rig in rigs:
  var info: Dictionary=rig.get_meta("apparel_test")
  if info.zoom!=1.0 or int(info.row)%2!=0:continue
  var original: Sprite2D=rig.get_node("Visual/Pelvis/Head/Sprite")
  var probe: Sprite2D=original.duplicate();probe.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;probe.position=Vector2(640,360);probe.scale=Vector2.ONE;vp.add_child(probe);probe.reset_physics_interpolation()
  await frames(2);await RenderingServer.frame_post_draw
  var rendered: Image=vp.get_texture().get_image()
  var base: Image=original.texture.get_image()
  var mat: ShaderMaterial=info.hair.material
  var cap: Image=mat.get_shader_parameter("hat_mask").get_image()
  var size: Vector2=mat.get_shader_parameter("hat_size")
  var offset: Vector2=mat.get_shader_parameter("hat_position")
  var columns:=0;var gap_columns:=0;var max_gap:=0
  for x in range(-90,91,2):
   var bx: int=x+base.get_width()/2
   var top:=-1000
   for y in base.get_height():
    if base.get_pixel(bx,y).a>.9:top=y-base.get_height()/2;break
   var cx: int=int(((float(x)-offset.x)/size.x+.5)*cap.get_width())
   if top==-1000 or top>0 or cx<0 or cx>=cap.get_width():continue
   var bottom:=-1000.0
   for y in range(cap.get_height()-1,-1,-1):
    if cap.get_pixel(cx,y).a>.9:bottom=(float(y)/cap.get_height()-.5)*size.y+offset.y;break
   if bottom==-1000:continue
   columns+=1
   var run:=0;var longest:=0
   for y in range(int(floor(bottom)),top+1):
    if rendered.get_pixel(x+640,y+360).a<.1:run+=1;longest=maxi(longest,run)
    else:run=0
   max_gap=maxi(max_gap,longest)
   if longest>=2:gap_columns+=1
  if hair_id=="male_natural" or gap_columns>0:rendered.save_png("res://reports/hat-motion-v2/seam-"+str(info.row)+info.facing+".png")
  check(columns>0 and gap_columns==0,"GPU hat-head seam no transparent gap %s %s row%s columns%s max%s"%[hair_id,info.facing,info.row,columns,max_gap])
  probe.queue_free();await frames(1)
 vp.transparent_bg=false

func verify_clip_gpu(vp: SubViewport, rigs: Array, hair_id: String) -> void:
 for rig in rigs:rig.hide()
 vp.transparent_bg=true
 for rig in rigs:
  var info: Dictionary=rig.get_meta("apparel_test")
  if info.zoom!=1.0 or int(info.row)%2!=0:continue
  var hair: Sprite2D=info.hair
  var probe:=Sprite2D.new();probe.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;probe.texture=hair.texture;probe.material=hair.material;probe.position=Vector2(640,360);vp.add_child(probe)
  await frames(2);await RenderingServer.frame_post_draw
  var rendered: Image=vp.get_texture().get_image();var image: Image=hair.texture.get_image()
  var join: Image=hair.material.get_shader_parameter("hat_join").get_image()
  var size: Vector2=hair.material.get_shader_parameter("hat_size");var pos: Vector2=hair.material.get_shader_parameter("hat_position")
  var tested:=0;var leaked:=0
  for y in range(0,image.get_height(),3):
   for x in range(0,image.get_width(),3):
    if image.get_pixel(x,y).a<.99:continue
    var p:=Vector2(x+.5,y+.5)-Vector2(image.get_size())*.5;var uv: Vector2=(p-pos)/size+Vector2(.5,.5)
    var upper: bool=p.y<float(hair.material.get_shader_parameter("clip_below"))-6
    if uv.x>=0 and uv.x<=1:upper=uv.y<join.get_pixel(clampi(int(uv.x*join.get_width()),0,join.get_width()-1),0).r-6.0/size.y
    if not upper:continue
    tested+=1
    if rendered.get_pixel(int(x+640-image.get_width()/2),int(y+360-image.get_height()/2)).a>.01:leaked+=1
  check(tested>0 and leaked==0,"GPU entire upper hair tucked (including far-brim crown) %s %s row%s samples%s leaks%s"%[hair_id,info.facing,info.row,tested,leaked])
  probe.queue_free();await frames(1)
 vp.transparent_bg=false

func motion_tests() -> void:
 var vp:=SubViewport.new();vp.size=default_size();vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 var old_ratios: Array=[];var new_ratios: Array=[]
 for id in ["wool_hat","straw_hat"]:
  var rigs: Array=[];var renderers: Array=[];var looks: Array=[]
  var inv=ItemInventory.new(s.database);inv.equipment.head=inv.instance(id)
  for i in 2:
   var rig: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate();rig.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_ON;rig.position=Vector2(240+i*500,220);rig.scale=Vector2.ONE*2;vp.add_child(rig)
   rig.get_node("AnimationPlayer").add_animation_library("harvest",load("res://assets/hero/cartoon/harvest_actions.tres"))
   rigs.append(rig);looks.append(preload("res://scripts/character_look.gd").new())
   renderers.append(load("res://reports/.tmp/hat-motion-before/appearance.gd").new() if i==0 and FileAccess.file_exists("res://reports/.tmp/hat-motion-before/appearance.gd") else preload("res://scripts/equipment_appearance.gd").new())
  var step:=0
  for action in ["breathe","walk","run","pickup","chop","mine","dig"]:
   for facing in ["front","back","right","left","front","right","back","left"]:
    await physics_frame
    for i in 2:
     var rig: Node2D=rigs[i];var anim: AnimationPlayer=rig.get_node("AnimationPlayer")
     var view: String="side" if facing in ["left","right"] else facing
     var clip: String=("harvest/" if action in ["mine","dig"] else "")+view+"_"+action
     anim.play(clip);anim.seek(.2,true);anim.pause()
     looks[i].apply(rig,{"gender":"male","hair_id":"unisex_bun","skin_id":"skin_2"},inv,facing)
     renderers[i].apply(rig,inv,facing)
     var v: Node2D=rig.get_node("Visual");var sx: float=-1 if facing=="left" else 1
     if v.scale.x!=sx:v.scale.x=sx;v.position.x=128 if facing=="left" else 0;v.reset_physics_interpolation()
     for cap in rig.find_children("EquipmentVisual_head*","Sprite2D",true,false):
      var color:=ShaderMaterial.new();color.shader=load("res://tests/hat_motion_probe.gdshader");cap.material=color
    for frame in 3:
     await process_frame;await RenderingServer.frame_post_draw
     var pixels: Image=vp.get_texture().get_image()
     for i in 2:
      var head: Sprite2D=rigs[i].get_node("Visual/Pelvis/Head/Sprite")
      var hat: Sprite2D=head.get_node("EquipmentVisual_head_0" if id=="wool_hat" else "EquipmentVisual_head_1")
      var rect: Rect2=hat.get_rect();var transform: Transform2D=hat.global_transform
      var corners: Array[Vector2]=[transform*rect.position,transform*Vector2(rect.end.x,rect.position.y),transform*rect.end,transform*Vector2(rect.position.x,rect.end.y)]
      var lo: float=corners.map(func(p):return p.x).min();var hi: float=corners.map(func(p):return p.x).max()
      var left:=1280;var right:=-1
      for y in range(0,600,2):
       for x in range(i*640,(i+1)*640,2):
        var c: Color=pixels.get_pixel(x,y)
        if c.r>.8 and c.g<.2 and c.b>.8:left=mini(left,x);right=maxi(right,x)
      var ratio: float=float(right-left+2)/(hi-lo) if right>=left else 0
      if i==0:old_ratios.append(ratio)
      else:
       new_ratios.append(ratio);check(ratio>.72 and ratio<1.08,"rendered hat size stable first frames %s %s %s frame%s ratio%.5f"%[id,facing,action,frame,ratio])
     if step<8:vp.get_texture().get_image().save_png("res://reports/hat-motion-v2/motion-"+id+"-%02d-%s.png"%[step,frame])
    step+=1
  for rig in rigs:rig.queue_free()
  await frames(2)
 var f=FileAccess.open("res://reports/hat-motion-v2/motion-metrics.json",FileAccess.WRITE);f.store_string(JSON.stringify({"baseline_available":FileAccess.file_exists("res://reports/.tmp/hat-motion-before/appearance.gd"),"before_max_ratio":old_ratios.max(),"after_max_ratio":new_ratios.max(),"before_min_ratio":old_ratios.min(),"after_min_ratio":new_ratios.min(),"samples_each":new_ratios.size()},"\t"));f.close()
 vp.queue_free()
