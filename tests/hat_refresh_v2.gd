extends "res://tests/hat_motion_v2.gd"
func run() -> void:
 var db=ItemDatabase.new()
 for id in ["wool_hat","straw_hat"]:
  var inv=ItemInventory.new(db);inv.equipment.head=inv.instance(id)
  var rig: Node2D=load("res://assets/hero/cartoon/character.tscn").instantiate();root.add_child(rig)
  var look=preload("res://scripts/character_look.gd").new();var appearance=preload("res://scripts/equipment_appearance.gd").new()
  for facing in ["front","back","left","right"]:
   var anim: AnimationPlayer=rig.get_node("AnimationPlayer");anim.play(("side" if facing in ["left","right"] else facing)+"_breathe");anim.seek(0,true);anim.pause()
   look.apply(rig,Catalog.default_look(),inv,facing);appearance.apply(rig,inv,facing)
   var cap: Node=rig.get_node("Visual/Pelvis/Head/Sprite/EquipmentVisual_head_0");var original: int=cap.get_instance_id()
   inv.equipment.main_hand=inv.instance("stone_axe");appearance.apply(rig,inv,facing)
   check(rig.get_node("Visual/Pelvis/Head/Sprite/EquipmentVisual_head_0").get_instance_id()==original,"main-hand equip retains actual hat node "+id+facing)
   for durability in [99,98,97]:
    inv.equipment.main_hand.durability=durability;appearance.apply(rig,inv,facing)
    check(rig.get_node("Visual/Pelvis/Head/Sprite/EquipmentVisual_head_0").get_instance_id()==original,"tool-use durability update retains actual hat node "+id+facing+str(durability))
  rig.queue_free();await frames()
 var failed: Array=checks.filter(func(c):return not c.pass)
 var f=FileAccess.open("res://reports/hat-motion-v2/refresh-results.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failed":failed.size()},"\t"));f.close()
 print("HAT_REFRESH ",checks.size()," checks ",failed.size()," failed");quit(1 if not failed.is_empty() else 0)
