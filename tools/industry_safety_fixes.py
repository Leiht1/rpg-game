from pathlib import Path
import json
R=Path(__file__).resolve().parents[1]
def edit(p,fn):
 f=R/p;f.write_text(fn(f.read_text(encoding='utf-8')),encoding='utf-8')
# Existing lanterns are carried rather than equipped. The upgraded lantern uses
# the same burn/switch/render service and the existing main-hand identity system.
p=R/'data/items.json';items=json.loads(p.read_text(encoding='utf-8'))
for r in items:
 if r['item_id']=='silver_lantern':r.update(equippable=True,equip_slot='main_hand',equipment_type='tool',capabilities=[],action_id='',visual_id='tool:silver_lantern',durability=None)
p.write_text(json.dumps(items,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=R/'data/held_tools.json';held=json.loads(p.read_text(encoding='utf-8'));held['tool:silver_lantern']={'texture':'res://prototypes/industry-v1/final/silver_lantern.png','grip_px':[128,40],'scale':.18,'rotation_degrees':0,'hand_offset':[0,-2.75],'stance_degrees':{'front':0,'back':0,'side':0}};p.write_text(json.dumps(held,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def inventory(s):
 s=s.replace('return {"item_id":id,"count":1,"instance_id":str(ResourceUID.create_id()),"state":{},"durability":database.item(id).get("durability")}','''var value := {"item_id":id,"count":1,"instance_id":str(ResourceUID.create_id()),"state":{},"durability":database.item(id).get("durability")}
	if database.item(id).get("use_action","")=="light":value.lamp_id=value.instance_id;value.fuel=float(database.item(id).get("lamp_lifetime",1800.0))
	return value''')
 s=s.replace('if current==null: value.durability=int(maximum);return true','if current==null: value.durability=int(maximum);return true')
 s=s.replace('if index < 0 or index >= slots.size() or get_slot(index).is_empty():','if index < 0 or index >= SLOT_COUNT+equipment_slots.size() or get_slot(index).is_empty():')
 s=s.replace('if index<8 and database.item(id).get("equippable",false): return equip(index)','if index<8 and database.item(id).get("equippable",false) and not slots[index].is_empty(): return equip(index)')
 return s
edit('scripts/item_inventory.gd',inventory)
def service(s):
 s=s.replace('for slot in inventory.slots:\n\t\tif slot.get("lamp_id"','for slot in inventory.slots+inventory.equipment.values():\n\t\tif slot.get("lamp_id"')
 s=s.replace('var slot: Dictionary=inventory.slots[index]\n\tif not slot.has("lamp_id")','var slot: Dictionary=inventory.get_slot(index)\n\tif slot.is_empty() or database.item(slot.item_id).get("use_action","")!="light":return\n\tif not slot.has("lamp_id")')
 s=s.replace('active_lamp="";inventory.changed.emit()','''for key in inventory.equipment.keys():
				if inventory.equipment[key].get("lamp_id","")==active_lamp:
					var expired: String=inventory.equipment[key].get("instance_id","")
					inventory.equipment.erase(key)
					for link in inventory.hotbar_equipment.keys():
						if inventory.hotbar_equipment[link]==expired:inventory.hotbar_equipment.erase(link)
			active_lamp="";inventory.changed.emit()''')
 s=s.replace('var lamp_entries: Array=staged.slots.duplicate()','var lamp_entries: Array=staged.slots.duplicate()+staged.equipment.values()')
 s=s.replace('staged.slots[i]=drop.get_meta("instance",inventory.instance(item_id)).duplicate(true);left=0;break','staged.slots[i]=loose.get(id,{}).get("instance",drop.get_meta("instance",inventory.instance(item_id))).duplicate(true);left=0;break')
 s=s.replace('if left==count: notice.emit','if left==count: notice.emit')
 s=s.replace('var count := int(drop.get_meta("count",1))','var count := int(loose.get(id,{}).get("count",drop.get_meta("count",1)))')
 # Guard old loose foods and normalize their state before applying any loaded data.
 s=s.replace('if value.has("animals") and not animals.valid', '''for entry in value.loose.values():
		if preload("res://scripts/food_freshness.gd").cooked(database,entry.item_id):
			if not entry.has("instance"):entry.instance={"item_id":entry.item_id,"count":entry.count}
			if not entry.instance is Dictionary or entry.instance.get("item_id")!=entry.item_id or entry.instance.get("count")!=entry.count or not preload("res://scripts/food_freshness.gd").normalize(database,entry.instance):writable=false;return
	if value.has("animals") and not animals.valid''')
 return s
edit('scripts/item_service.gd',service)
edit('scripts/industry_service.gd',lambda s:s.replace('elif r.output=="silver_lantern":output=', 'elif r.output=="silver_lantern":output='))
# Cooked stack snapshots can age while menus or drags are open; compare identity
# and quantity while copying the live metadata on commit.
F='preload("res://scripts/food_freshness.gd")'
edit('scripts/item_ui.gd',lambda s:s.replace('service.inventory.get_slot(modal_index)==modal_stack',F+'.matches(service.inventory.get_slot(modal_index),modal_stack)').replace('data.get("snapshot",slot)==slot',F+'.matches(data.get("snapshot",slot),slot)').replace('modal_stack.item_id=="field_lantern"','service.database.item(modal_stack.item_id).get("use_action","")=="light"'))
edit('scripts/camp_buildings.gd',lambda s:s.replace('contents[chest_index]!=expected_chest or inv.get_slot(player_index)!=expected_player','not '+F+'.matches(contents[chest_index],expected_chest) or not '+F+'.matches(inv.get_slot(player_index),expected_player)').replace('contents[source]!=expected or expected.is_empty()','not '+F+'.matches(contents[source],expected) or expected.is_empty()').replace('var before: Array=contents.duplicate(true)','expected=contents[source].duplicate(true)\n\tvar before: Array=contents.duplicate(true)'))
edit('scripts/camp_storage_ui.gd',lambda s:s.replace('contents(action_index)!=action_snapshot','not '+F+'.matches(contents(action_index),action_snapshot)'))
# Whole-stack ground throws are managed by the ordinary discard path above.
edit('scripts/sleep_controller.gd',lambda s:s.replace('w.item_ui.close_panels();w.camp_ui.close_panel()','w.item_ui.close_panels();w.camp_ui.close_panel()\n\tif is_instance_valid(service.industry_ui):service.industry_ui.close_panel()'))
# Freshness for completed campfire products starts at completion, never at claim.
def camp(s):
 s=s.replace('if row.recipe.is_empty():\n', '''if row.has("output"):
			if not row.output is Dictionary or row.output.get("item_id")!=rules.recipes.get(row.recipe,{}).get("output","") or row.output.get("count")!=1 or not preload("res://scripts/food_freshness.gd").normalize(service.database,row.output):return false
		if row.recipe.is_empty():
''',1)
 s=s.replace('else: row.recipe=recipe;row.elapsed=0.0;row.ready=false','else: row.erase("output");row.recipe=recipe;row.elapsed=0.0;row.ready=false')
 s=s.replace('staged.add(str(rules.recipes[row.recipe].output),1)','staged.add_value(row.get("output",{"item_id":str(rules.recipes[row.recipe].output),"count":1}))')
 s=s.replace('row.recipe="";row.elapsed=0.0;row.ready=false','row.erase("output");row.recipe="";row.elapsed=0.0;row.ready=false')
 s=s.replace('discovered[row.recipe]=true\n\t\t\t\tcompleted=true','discovered[row.recipe]=true\n\t\t\t\trow.output={"item_id":rules.recipes[row.recipe].output,"count":1,"spoilage":0.0}\n\t\t\t\tcompleted=true')
 return s
edit('scripts/campfire_service.gd',camp)
# No unsolicited instructions in the existing cooking panel.
edit('scripts/campfire_ui.gd',lambda s:s.replace('feedback.text="将快捷栏或背包的可燃物拖到火堆上续燃；燃时显示在火堆下方。"','feedback.text=""'))
