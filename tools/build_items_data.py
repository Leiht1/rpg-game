import json
from pathlib import Path
ids=['wild_berry','brown_mushroom','wild_carrot','wild_apple','wood','branch','stone','plant_fiber','flint','broad_leaf','pine_cone','wildflower']
names=['野生浆果','棕蘑菇','野胡萝卜','野苹果','木材','树枝','石块','植物纤维','燧石','宽叶','松果','野花']
desc=['酸甜的小浆果，采自草地和林缘的低矮浆果灌木。','林下落叶间长出的棕色食用蘑菇。','草地中生长的野胡萝卜，拔起后可食用。','林缘野苹果树附近的成熟落果，略带酸味。','从树干收集的短木料，适合作为基础材料。','自然脱落的小树枝，可用作未来工具的柄材。','散落在地面的普通小石块，与不可采集的大岩石不同。','从草本植株中整理出的柔韧纤维。','岩石附近偶见的锐边燧石，未来可作石制工具材料。','从宽叶植物上采下的完整叶片。','树下掉落的成熟松果，保留未来种植用途。','从原野花丛采集的小野花。']
rules=[('meadow_edge',.18,'浆果灌木'),('forest',.18,'林下菌簇'),('meadow',.12,'胡萝卜植株'),('apple_source',.35,'野苹果来源点的落果'),('chop',0,'砍树掉落'),('tree',.30,'树旁枯枝'),('rock',.45,'岩石附近散石'),('meadow',.20,'纤维草本'),('rock',.09,'岩石附近少量燧石'),('forest_edge',.16,'宽叶植物'),('tree',.20,'树下松果'),('meadow',.14,'自然花丛')]
rows=[]
for i,id in enumerate(ids):
 habitat,chance,source=rules[i]
 rows.append(dict(item_id=id,name=names[i],category='food' if i<4 else 'material' if i<9 else 'natural',description=desc[i],icon=f'res://prototypes/items-v03/visuals/{id}_icon.png',world_visual=f'res://prototypes/items-v03/visuals/{id}_world.png',max_stack=30 if i<4 else 99 if i<9 else 50,usable=i<4,use_action='eat' if i<4 else '',consumable=i<4,tags=[['food','wild'],['wood','craft'],['plant','collect']][0 if i<4 else 1 if i<9 else 2],rarity='uncommon' if id=='flint' else 'common',drop_rules=dict(habitat=habitat,chance=chance,source=source),effects=dict(comfort=1,future_restore={}) if i<4 else {},world_size=[42,27,30,20,27,26,18,30,15,35,18,32][i]))
Path('data/items.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
