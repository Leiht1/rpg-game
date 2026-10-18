from pathlib import Path
from PIL import Image
import json,hashlib
rows=json.loads(Path('data/items.json').read_text(encoding='utf-8'))
out=Path('prototypes/items-v03/visuals');out.mkdir(exist_ok=True)
for i,row in enumerate(rows):
 for kind,index in [('icon',i+1),('world',i+13)]:
  im=Image.open(f'art/items-v03/processed-01/sheet-{index}.png').convert('RGBA')
  box=im.getbbox(); im=im.crop(box); im.save(out/f'{row["item_id"]}_{kind}.png')
meta=dict(status='pending_user',art_source='host_image via controlled route_media',route='Codex (local CLI)',model='codex-image_gen; underlying model unknown',estimateUsd=0,estimate_basis='subscription quota, no verified per-call price',source='art/items-v03/candidate-01/job.json',processing='art/items-v03/processed-01/pipeline-meta.json',ownership='art/items-v03/ownership.json',files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')})
Path('prototypes/items-v03/provenance.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
