from pathlib import Path
import json,copy
R=Path(__file__).resolve().parents[1]
def read(p):return json.loads((R/p).read_text(encoding='utf-8-sig'))
def write(p,v):(R/p).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
items=read('data/items.json')
print(type(items).__name__)
rows=items['items'] if isinstance(items,dict) else items
for ident,label,hunger in [('small_hodgepodge','小杂烩',6),('large_hodgepodge','大杂烩',12)]:
 base=next(copy.deepcopy(x) for x in rows if x['item_id']=='egg_vegetable_bake')
 base.update(item_id=ident,name=label,description='',effects={'hunger':hunger},icon=f'res://prototypes/industry-v1/final/{ident}.png',world_visual=f'res://prototypes/industry-v1/final/{ident}.png')
 rows[:]=[x for x in rows if x['item_id']!=ident];rows.append(base)
write('data/items.json',items)
rules=read('data/industry_rules.json')
rules['fallback_recipes']={f'oven_{size}_hodgepodge':{'station':'copper_oven','materials':{},'output':f'{size}_hodgepodge','count':1,'seconds':seconds} for size,seconds in [('small',12),('large',18)]}
write('data/industry_rules.json',rules)
