from pathlib import Path
from PIL import Image
import numpy as np,hashlib,json
root=Path(__file__).resolve().parents[2];checks=[]
def check(ok,name):checks.append({'name':name,'pass':bool(ok)})
meta=json.loads((root/'art/animals-style-v2/provenance.json').read_text(encoding='utf-8'))
for name,expected in meta['files'].items():
 p=root/'prototypes/animals-style-v2/parts'/name;im=Image.open(p);a=np.array(im)
 check(hashlib.sha256(p.read_bytes()).hexdigest()==expected,f'candidate provenance SHA {name}')
 check(im.mode=='RGBA' and a[:,:,3].max()==255 and a[:,:,3].min()==0,f'visible opaque part with real alpha {name}')
 key=(a[:,:,0].astype(int)-a[:,:,1]>60)&(a[:,:,2].astype(int)-a[:,:,1]>60)&(a[:,:,3]>127)
 check(not key.any(),f'packaged opaque magenta residue zero {name}')
check(Image.open(root/'prototypes/animals-style-v2/parts/sheep_wool.png').size==Image.open(root/'prototypes/animals-style-v2/parts/sheep_bare.png').size==(690,430),'sheep wool/bare common registered canvas')
formal=root/'assets/animals/v1';old=json.loads((formal/'provenance.json').read_text(encoding='utf-8'))
for name,expected in old['files'].items():
 check(hashlib.sha256((formal/name).read_bytes()).hexdigest()==expected,f'formal animal art remains original {name}')
for p,expected in meta['references'].items():check(hashlib.sha256((root/p).read_bytes()).hexdigest()==expected,f'reference retained {p}')
report={'count':len(checks),'failed':sum(not c['pass'] for c in checks),'checks':checks,'scope':'packaged cutouts, original formal animal SHA, retained source references; not visual approval'}
(root/'reports/animals-style-v2/package-qa.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'count':report['count'],'failed':report['failed']}))
raise SystemExit(1 if report['failed'] else 0)
