extends "res://tests/hat_motion_v2.gd"
const DEST="res://reports/network-integration-v2/sleeve/"
func run() -> void:
 DirAccess.make_dir_recursive_absolute(DEST)
 s=DataOnly.new();root.add_child(s);root.size=default_size();root.content_scale_size=root.size
 var vp:=SubViewport.new();vp.size=default_size();vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 var rigs: Array=[]
 for row in 2:
  for col in 4:
   var cell:=Control.new();cell.position=Vector2(col*320,row*350);cell.size=Vector2(320,350);cell.clip_contents=true;vp.add_child(cell)
   for zoom in [1.0,2.0]:
    var rig=load("res://assets/hero/cartoon/character.tscn").instantiate();cell.add_child(rig);rig.position=Vector2(4 if zoom==1 else 80,105 if zoom==1 else 5);rig.scale=Vector2.ONE*zoom
    rig.get_node("AnimationPlayer").add_animation_library("harvest",load("res://assets/hero/cartoon/harvest_actions.tres"))
    var inv=ItemInventory.new(s.database);inv.equipment.outfit=inv.instance("wool_sweater")
    rig.set_meta("test",{"view":["front","back","left","right"][col],"gender":"male" if row==0 else "female","inventory":inv,"look":preload("res://scripts/character_look.gd").new(),"appearance":preload("res://scripts/equipment_appearance.gd").new()});rigs.append(rig)
 for action in ["breathe","walk","pickup","chop","mine"]:
  for clock in [0.0,.2]:
   for rig in rigs:
    var info=rig.get_meta("test");var facing: String=info.view;var view: String="side" if facing in ["left","right"] else facing
    var anim: AnimationPlayer=rig.get_node("AnimationPlayer");anim.play(("harvest/" if action=="mine" else "")+view+"_"+action);anim.seek(clock,true);anim.pause()
    info.appearance.release_layers();info.look.apply(rig,{"gender":info.gender,"hair_id":"male_natural" if info.gender=="male" else "female_bob","skin_id":"skin_2"},info.inventory,facing)
    info.appearance.apply(rig,info.inventory,facing);info.appearance.apply_layers(rig,info.inventory,facing)
    if facing=="left":rig.get_node("Visual").scale.x=-1;rig.get_node("Visual").position.x=128
    var arm: Sprite2D=rig.get_node("Visual/Pelvis/ArmR/Sprite")
    var image: Image=arm.texture.get_image();var native: Image=load("res://assets/hero/cartoon/art/"+("side" if view=="side" else "front")+"_arm.png").get_image()
    check(image.get_size()==Vector2i(40,100),"broad cuff canvas "+facing+action)
    check(image.get_region(Rect2i(4,86,32,14)).get_data()==native.get_region(Rect2i(0,86,32,14)).get_data(),"exact original hand pixels "+facing+action)
    check(arm.get_rect().position.x+4==-16 and arm.scale==Vector2(.25,.25),"original centered hand anchor and scale "+facing+action)
    check(arm.material.get_shader_parameter("skin_region")==Vector2(.86,1),"wool cloth excluded from skin tint "+facing+action)
   await process_frame;await RenderingServer.frame_post_draw
   vp.get_texture().get_image().save_png(DEST+action+"-"+str(clock)+".png")
 for rig in rigs:
  var info=rig.get_meta("test");info.inventory.equipment.outfit={};info.appearance.release_layers();rig.get_node("AnimationPlayer").seek(.2,true);info.look.apply(rig,{"gender":info.gender,"hair_id":"male_natural","skin_id":"skin_2"},info.inventory,info.view);info.appearance.apply(rig,info.inventory,info.view)
  check(rig.get_node("Visual/Pelvis/ArmR/Sprite").texture.get_width()==32,"unequip restores original arm canvas")
 var failed: Array=checks.filter(func(c):return not c.pass)
 FileAccess.open(DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"\t"))
 print("WOOL_SLEEVE ",checks.size()," checks ",failed.size()," failed")
 vp.queue_free();s.queue_free();await frames();quit(1 if not failed.is_empty() else 0)
