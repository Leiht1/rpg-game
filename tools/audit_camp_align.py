from pathlib import Path
from PIL import Image
import hashlib,json
base=Path('prototypes/camp-align-v1/final')
frames=[]
for i,name in enumerate(['wood_chest','workbench','wood_fence_vertical','fence_gate_vertical'],1):
 im=Image.open(base/f'sheet-{i}.png').convert('RGBA');im=im.crop(im.getbbox());im.save(base/f'{name}.png')
 frames.append({'kind':name,'file':name+'.png','size':list(im.size),'source':f'art/camp-align-v1/candidate-0{2 if i==4 else 1}/generated.png','sha256':hashlib.sha256((base/f'{name}.png').read_bytes()).hexdigest()})
provenance={'status':'pending_user','route':'local:codex-cli','art_source':'host_image','returned_model':'codex-image_gen','date':'2026-10-18','frames':frames,'processing':'prototypes/camp-align-v1/final/pipeline-meta.json','ownership':{'x':[0,627,1254],'y':[0,560,1254]},'note':'Original 16 approved PNGs unchanged. No formal runtime references this candidate directory. Source nominal 2x2 first spill failed; measured empty row band and repacking preserves complete subjects. Candidate02 gate corrects post X alignment; first three retain candidate01.'}
(base/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
original=Path('assets/buildings/v1');approved=json.loads((original/'provenance.json').read_text(encoding='utf-8-sig'));rows=[]
for r in approved['frames']:
 p=original/f"frame-{r['frame']:02}.png";h=hashlib.sha256(p.read_bytes()).hexdigest();im=Image.open(p).convert('RGBA')
 rows.append({'file':str(p),'size':list(im.size),'bbox':list(im.getbbox()),'sha256':h,'matches_approved':h==r['sha256']})
Path('reports/camp-build-fix-v1/art-audit.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print('Approved PNG hash match:',sum(r['matches_approved'] for r in rows),'/',len(rows))
