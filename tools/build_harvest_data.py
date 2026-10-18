import json
from pathlib import Path
p=Path('data/harvest_resources.json')
rows={
 'stone_outcrop':dict(name='普通石矿点',action='mine',hits=3,width=67,collision=[23,11],range=74,weights=[.14,.72,.26],drops={'stone':5},frames=[1,2,3]),
 'flint_outcrop':dict(name='燧石矿点',action='mine',hits=4,width=64,collision=[22,10],range=74,weights=[.06,.42,.08],drops={'flint':3,'stone':2},frames=[4,5,6]),
 'buried_root':dict(name='半埋根茎',action='dig',hits=2,width=37,collision=[0,0],range=58,weights=[.20,.03,.36],drops={'wild_carrot':2},frames=[9,10,11]),
 'buried_bone':dict(name='半埋骨片',action='dig',hits=3,width=42,collision=[0,0],range=58,weights=[.08,.16,.08],drops={'bone_fragment':2},frames=[13,14,15]),
 'buried_supply':dict(name='半埋补给包',action='dig',hits=3,width=43,collision=[0,0],range=58,weights=[.055,.045,.055],drops={'supply_pouch':1,'relic_fragment':1},frames=[17,18,19])}
for k,r in rows.items():
 r['textures']=[f'res://assets/harvest/v05/frame-{i:02}.png' for i in r.pop('frames')]
 r['spacing']=160 if r['action']=='mine' else 140
p.write_text(json.dumps(dict(version='harvest-resources-1.0.0',cell_size=768,attempts=4,resources=rows),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=Path('data/items.json');data=[r for r in json.loads(p.read_text('utf-8-sig')) if r['item_id'] not in ['bone_fragment','relic_fragment','supply_pouch']]
for id,name,desc,frame,usable in [
 ('bone_fragment','骨片','从半埋骨骸中挖出的旧骨片，可收集的材料。',7,False),
 ('relic_fragment','遗物碎片','带有旧纹样的铜质碎片，来自埋藏遗物。',8,False),
 ('supply_pouch','小型补给包','旧帆布补给包。使用后获得野胡萝卜×2、燧石×1、遗物碎片×2；空间不足时保持原样。',12,True)]:
 r=dict(item_id=id,name=name,category='material',description=desc,icon=f'res://assets/harvest/v05/frame-{frame:02}.png',world_visual=f'res://assets/harvest/v05/frame-{frame:02}.png',max_stack=10 if usable else 50,usable=usable,use_action='unpack' if usable else '',consumable=usable,tags=['excavated'],rarity='common',drop_rules={'source':'埋藏物挖掘'},world_size=25 if usable else 22,equippable=False,equip_slot='',equipment_type='',capabilities=[],action_id='',visual_id='',stats={},durability=None)
 if usable:r['contents']={'wild_carrot':2,'flint':1,'relic_fragment':2}
 data.append(r)
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
