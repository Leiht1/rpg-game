import json, copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(p): return json.loads((ROOT/p).read_text(encoding='utf-8'))
def write(p,v): (ROOT/p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
items=read('data/items.json'); by={r['item_id']:r for r in items}
names={'stone_furnace':'石制熔炉','metal_workbench':'金属加工台','copper_oven':'铜制烤箱','copper_lamp':'铜制立灯','reinforced_cabinet':'加固储物柜','feed_trough':'动物饲料槽','refrigerator':'冰箱','wool_carpet':'羊毛地毯','copper_ingot':'铜锭','silver_ingot':'银锭','gold_ingot':'金锭','copper_plate':'铜板','copper_parts':'铜制零件','metal_connector':'金属连接件','copper_axe':'铜斧','copper_pickaxe':'铜镐','copper_shovel':'铜铲','copper_hammer':'铜锤','silver_lantern':'银质反光提灯','fishing_rod':'钓鱼竿','egg_vegetable_bake':'蛋蔬焗盘'}
costs={'stone_furnace':{'stone':16,'wood':6,'flint':3},'metal_workbench':{'copper_ingot':3,'wood':12,'stone':6},'copper_oven':{'copper_plate':4,'copper_parts':2,'stone':8,'wood':4},'copper_lamp':{'copper_ingot':6,'copper_parts':2,'wood':3},'reinforced_cabinet':{'wood':18,'copper_plate':3,'metal_connector':2},'feed_trough':{'wood':8,'metal_connector':1},'refrigerator':{'copper_plate':5,'copper_parts':3,'wood':12},'wool_carpet':{'wool':3,'plant_fiber':2}}
held=read('data/held_tools.json')
for id,name in names.items():
 if id in by: continue
 source={'copper_axe':'stone_axe','copper_pickaxe':'stone_pickaxe','copper_shovel':'simple_shovel','copper_hammer':'stone_hammer','silver_lantern':'field_lantern','fishing_rod':'stone_axe'}.get(id,'workbench')
 r=copy.deepcopy(by[source]);r.update(item_id=id,name=name,description='',icon=f'res://prototypes/industry-v1/final/{id}.png',world_visual=f'res://prototypes/industry-v1/final/{id}.png',industry_candidate=True)
 if id not in costs and source=='workbench':r.update(category='material',max_stack=99,tags=['metal'],effects={})
 if id.startswith('copper_') and source in ['stone_axe','stone_pickaxe','simple_shovel','stone_hammer'] or id=='fishing_rod':
  r.update(visual_id='tool:'+id,durability=250 if id!='fishing_rod' else 150,stats={'labor_speed':1.35} if id!='fishing_rod' else {},capabilities=r['capabilities'] if id!='fishing_rod' else ['fishing_ready'],action_id=r['action_id'] if id!='fishing_rod' else '')
  h=copy.deepcopy(held['tool:'+source]);h.update(texture=r['icon'],grip_px=[128,190],scale=.24,rotation_degrees=0);held['tool:'+id]=h
 if id=='silver_lantern':r.update(lamp_lifetime=3600.0,light_radius=390.0,expire_remove=True)
 if id=='egg_vegetable_bake':
  r=copy.deepcopy(by['stewed_vegetables']);r.update(item_id=id,name=name,description='',icon=f'res://prototypes/industry-v1/final/{id}.png',world_visual=f'res://prototypes/industry-v1/final/{id}.png',effects={'hunger':40},industry_candidate=True)
 items.append(r);by[id]=r
camp=read('data/campfire_rules.json')
cooked={r['output'] for r in camp['recipes'].values()}|{'egg_vegetable_bake'}
for r in items:
 if r['item_id'] in cooked:r.update(food_kind='cooked',shelf_days=2.5)
 elif r.get('use_action')=='eat':r['food_kind']='raw'
camp['recipes']['egg_vegetable_bake']={'name':'蛋蔬焗盘','materials':{'chicken_egg':2,'potato':1,'cabbage':1},'output':'egg_vegetable_bake','seconds':36,'default_unlocked':False,'industry_candidate':True}
# Resolve actual egg identity from the existing animal rules.
egg=next((r['item_id'] for r in items if 'egg' in r['item_id'] and r['item_id']!='egg_vegetable_bake'),None)
camp['recipes']['egg_vegetable_bake']['materials'].pop('chicken_egg')
camp['recipes']['egg_vegetable_bake']['materials'][egg]=2
rules={'version':1,'max_fuel':2400.0,'queue_limit':12,'trough_range':180.0,'trough_capacity':99,'rotten_hunger_ratio':.25,'rotten_damage':5.0,'discomfort_seconds':3.0,'fuel_items':{'wood':120.0,'branch':30.0,'plant_fiber':15.0,'pine_cone':45.0},'recipes':{}}
for metal in ['copper','silver','gold']:
 ore=next(r['item_id'] for r in items if metal in r['item_id'] and 'ore' in r['item_id'])
 rules['recipes']['smelt_'+metal]={'station':'stone_furnace','materials':{ore:2},'output':metal+'_ingot','count':1,'seconds':24 if metal=='copper' else 32 if metal=='silver' else 40}
for id,mat in {'copper_plate':{'copper_ingot':1},'copper_parts':{'copper_ingot':1},'metal_connector':{'copper_ingot':1},'copper_axe':{'copper_ingot':2,'wood':2,'plant_fiber':2},'copper_pickaxe':{'copper_ingot':3,'wood':2,'plant_fiber':2},'copper_shovel':{'copper_plate':2,'wood':2},'copper_hammer':{'copper_ingot':3,'wood':2},'silver_lantern':{'silver_ingot':2,'copper_parts':2,'plant_fiber':2},'fishing_rod':{'wood':2,'plant_fiber':2,'wool':1,'copper_parts':1}}.items():
 rules['recipes']['metal_'+id]={'station':'metal_workbench','materials':mat,'output':id,'count':2 if id in ['copper_parts','metal_connector'] else 1,'seconds':8 if id in ['copper_plate','copper_parts','metal_connector'] else 15}
defs=read('data/camp_buildings.json');builds=read('data/buildings.json')
for id,mat in costs.items():
 defs[id]={'name':names[id],'layer':'overlay' if id=='wool_carpet' else 'free','cost':mat,'hits':3,'frame':0,'industry_candidate':True,'art':f'res://prototypes/industry-v1/final/{id}.png'}
 if id in ['reinforced_cabinet','refrigerator']:defs[id]['storage_slots']=24 if id=='reinforced_cabinet' else 12
 if not any(b['output_id']==id for b in builds):
  builds.append({'recipe_id':'build_'+id,'output_id':id,'output_count':1,'materials':mat,'category':'生活' if id not in ['stone_furnace','metal_workbench','copper_oven'] else '加工','conditions':[],'default_unlocked':False,'description':'','industry_candidate':True})
write('data/items.json',items);write('data/held_tools.json',held);write('data/campfire_rules.json',camp);write('data/camp_buildings.json',defs);write('data/buildings.json',builds);write('data/industry_rules.json',rules)
