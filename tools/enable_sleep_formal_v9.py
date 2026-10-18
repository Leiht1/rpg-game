from pathlib import Path
import json
for filename,ids in [('recipes.json',['bench_sleeping_bag']),('buildings.json',['build_straw_mat','build_wood_bed'])]:
 p=Path('data')/filename;rows=json.loads(p.read_text(encoding='utf8'))
 for row in rows:
  if row['recipe_id'] in ids: row['default_unlocked']=True
 p.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
p=Path('data/items.json');rows=json.loads(p.read_text(encoding='utf8'))
for row in rows:
 if row['item_id']=='sleeping_bag': row['icon']='res://assets/sleep/v1/sleeping_bag.png';row['world_visual']=row['icon']
p.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
p=Path('scripts/sleep_head_cover.gd');s=p.read_text(encoding='utf8');a=s.index('\tvar path :=');b=s.index('\tif path.is_empty():',a)
s=s[:a]+'\tvar path := "res://assets/sleep/occupied-v9/"+name_value+".png"\n\tif source=="forced" or not ResourceLoader.exists(path): path=""\n'+s[b:];p.write_text(s,encoding='utf8')
p=Path('scripts/sleep_controller.gd');s=p.read_text(encoding='utf8').replace('return "res://prototypes/sleep-v1/final/"+name_value+".png" if Engine.get_meta("sleep_preview",false) else ""','return ""');p.write_text(s,encoding='utf8')
p=Path('scripts/item_service.gd');s=p.read_text(encoding='utf8');a=s.index('\tif Engine.get_meta("sleep_preview",false):');b=s.index('\tif Engine.get_meta("camp_build_preview",false):',a);s=s[:a]+s[b:];p.write_text(s,encoding='utf8')
