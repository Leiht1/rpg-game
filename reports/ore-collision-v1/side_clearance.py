from pathlib import Path
import json
p=Path('data/harvest_resources.json');d=json.loads(p.read_text(encoding='utf8'))
for row in d['resources'].values():
 if 'collision_outline' in row:
  for point in row['collision_outline']:point[0]+=10 if point[0]>0 else -10
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
