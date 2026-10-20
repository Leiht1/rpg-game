import json,pathlib
r=pathlib.Path('.')
items=json.loads((r/'data/items.json').read_text(encoding='utf-8'))
ids=['solar_flashlight','modern_outfit','frequency_blade','unknown_alloy']
names=['太阳能手电筒','时髦服装','高频切割刃','未知合金']
desc=['现代太阳能手电筒。主手装备后按朝向照明；晴朗白天地面充电，天亮自动关闭。','来自另一边的现代夹克。本版仅供收藏与交换，尚不能穿戴。','精密高频切割器。本版仅供收藏与交换，尚未开放切割或战斗用途。','带着冷色光泽的未知材料。本版尚无制作用途。']
rows=[]
for i,id in enumerate(ids):
 d=dict(items[0]);d.update(item_id=id,name=names[i],category='tool' if i==0 else 'outfit' if i==1 else 'material',description=desc[i],icon=f'res://prototypes/merchant-v1/final/{id}.png',world_visual=f'res://prototypes/merchant-v1/final/{id}.png',max_stack=1,usable=i==0,use_action='solar_light' if i==0 else '',consumable=False,tags=['dimensional'],rarity='rare',drop_rules={},effects={},world_size=30,equippable=i==0,equip_slot='main_hand' if i==0 else '',equipment_type='tool' if i==0 else '',capabilities=[],action_id='',visual_id='tool:solar_flashlight' if i==0 else '',stats={},durability=None)
 d.pop('food_kind',None);rows.append(d)
(r/'data/merchant_items.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
amounts=[[[2,4,8,3],[2,3,10,2],[3,2,8,2]],[[2,8,2,2],[2,10,6,3],[3,6,2,2]],[[4,5,10,2],[4,4,12,2],[5,3,10,4]],[[3,4,8,1],[3,3,10,3],[4,2,6,2]]]
materials=[[['gold_ingot','silver_ingot','copper_parts','roasted_fish'],['gold_ingot','silver_ingot','copper_parts','smoked_fish'],['gold_ingot','silver_ingot','copper_parts','vegetable_fish_soup']],[['gold_ingot','wool','silver_ingot','smoked_fish'],['gold_ingot','wool','copper_parts','roasted_fish'],['gold_ingot','wool','silver_ingot','vegetable_fish_soup']],[['gold_ingot','silver_ingot','copper_parts','smoked_fish'],['gold_ingot','silver_ingot','copper_parts','vegetable_fish_soup'],['gold_ingot','silver_ingot','copper_parts','roasted_fish']],[['gold_ingot','silver_ingot','copper_parts','smoked_fish'],['gold_ingot','silver_ingot','copper_parts','roasted_fish'],['gold_ingot','silver_ingot','wool','vegetable_fish_soup']]]
request=pathlib.Path(r'C:\Users\HT\.codex\attachments\553aeaa8-ed3d-44bb-b685-8998827d47ac\已粘贴的文本.txt').read_text(encoding='utf-8')
import re
lines=re.findall(r'\d+\. “([^”]+)”',request)
rules={'version':1,'migration_minutes':5760,'capacity':100.0,'discharge_minutes':480.0,'charge_minutes':360.0,'sunrise':300,'sunset':1020,'beam_length':360,'beam_half_angle':0.38,'dialogue':lines[:20],'products':{id:[dict(zip(m,n)) for m,n in zip(materials[i],amounts[i])] for i,id in enumerate(ids)}}
assert len(rules['dialogue'])==20
for pools in rules['products'].values():
 for pool in pools:
  assert all(any(x['item_id']==key for x in items) for key in pool)
(r/'data/merchant_v1.json').write_text(json.dumps(rules,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
