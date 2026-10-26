"""Extract complete generated components; trim transparent margins only."""
from pathlib import Path
import sys, json, hashlib, shutil
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path.home()/'.codex/skills/generate2dsprite/scripts'))
from forge_core import connected_components, dilate_square

root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1])
lower = len(sys.argv)>2 and sys.argv[2]=='lower'
art = root/'art/wolf-parts-v5'
out = root/'prototypes/boss-beasts-v1/assets/wolf/side-v5'
art.mkdir(parents=True, exist_ok=True)
out.mkdir(parents=True, exist_ok=True)
shutil.copy2(source, art/('generated-lower.png' if lower else 'generated.png'))
im = Image.open(source).convert('RGBA')
data = np.array(im)
components = connected_components(im, threshold=8, min_area=500, with_masks=True)
assert len(components) == (3 if lower else 6), [(c['area'], c['bbox']) for c in components]
records = []
for c in components:
    x0,y0,x1,y1 = c['bbox']
    cx,cy = (x0+x1)/2,(y0+y1)/2
    name = (['fore_lower','hind_lower','hind_ankle'][int(cx//512)] if lower else (('torso' if cx<850 else 'tail') if cy<400 else (('fore_upper' if cx<850 else 'hip') if cy<840 else ('fore_paw' if cx<850 else 'hind_paw'))))
    assert not c['touches_edge'], name
    ownership = np.zeros(data.shape[:2], dtype=bool)
    ownership[y0:y1,x0:x1] = c['mask']
    ownership = dilate_square(ownership, 3)
    x0,y0,x1,y1 = max(0,x0-3),max(0,y0-3),min(im.width,x1+3),min(im.height,y1+3)
    part = data[y0:y1,x0:x1].copy()
    part[~ownership[y0:y1,x0:x1]] = 0
    # A transparent two-pixel safety margin retains every painted edge pixel.
    saved = Image.new('RGBA', (x1-x0+4,y1-y0+4))
    saved.paste(Image.fromarray(part), (2,2))
    dest = out/(name+'.png')
    saved.save(dest)
    records.append({'part':name, 'bbox':c['bbox'], 'area':c['area'], 'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(), 'size':saved.size})
assert len({r['part'] for r in records}) == (3 if lower else 6)
manifest={'route':'host_image:imagegen','art_source':'host_image','approval':'pending_user','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'processing':'native alpha; complete connected components identified at alpha>8; ownership expanded 3px to retain antialiasing; remote alpha<=8 speckles discarded; no art clipping or repaint by code','parts':records}
manifest_name='provenance-lower.json' if lower else 'provenance.json'
(out/manifest_name).write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(art/manifest_name).write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(records,ensure_ascii=False))
