from pathlib import Path
import json
p=Path('data/harvest_resources.json');d=json.loads(p.read_text(encoding='utf8'));v=d['resources']['flint_outcrop']['collision_outline'];v[-1]=[-36,-1];v[-2]=[-18,4];v[-3]=[7,4];p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
