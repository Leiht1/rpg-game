"""Check real PNG coverage at every joint in captured idle/walk frames."""
from pathlib import Path
import json, math, sys, re
from PIL import Image
import numpy as np

root=Path(__file__).resolve().parents[1]
report_name=sys.argv[1] if len(sys.argv)>1 else 'wolf-parts-v5'
assert re.fullmatch(r'wolf-parts-v[0-9]+',report_name)
output_name=sys.argv[2] if len(sys.argv)>2 else report_name
assert re.fullmatch(r'wolf-[a-z]+-v[0-9]+',output_name)
frames=json.loads((root/f'reports/.tmp/{report_name}/rig-frames.json').read_text())
cache={}
SCALE=3

def bounds(p):
    c,s=math.cos(p['angle']),math.sin(p['angle'])
    corners=[(p['x']+c*x-s*y,p['y']+s*x+c*y) for x in [-p['ax']*p['w'],(1-p['ax'])*p['w']] for y in [-p['ay']*p['h'],(1-p['ay'])*p['h']]]
    return [math.floor(min(v[0] for v in corners)*SCALE),math.floor(min(v[1] for v in corners)*SCALE),math.ceil(max(v[0] for v in corners)*SCALE),math.ceil(max(v[1] for v in corners)*SCALE)]

def alpha(p,box):
    path=p['src']
    if path not in cache:cache[path]=Image.open(root/'prototypes/boss-beasts-v1'/path).getchannel('A')
    im=cache[path]
    c,s=math.cos(p['angle']),math.sin(p['angle'])
    sx,sy=im.width/p['w'],im.height/p['h']
    dx,dy=box[0]/SCALE-p['x'],box[1]/SCALE-p['y']
    affine=(c*sx/SCALE,s*sx/SCALE,(c*dx+s*dy)*sx+p['ax']*im.width,-s*sy/SCALE,c*sy/SCALE,(-s*dx+c*dy)*sy+p['ay']*im.height)
    return np.array(im.transform((box[2]-box[0],box[3]-box[1]),Image.Transform.AFFINE,affine,resample=Image.Resampling.BILINEAR))>32

def overlap(a,b):
    ba,bb=bounds(a),bounds(b)
    box=[max(ba[0],bb[0]),max(ba[1],bb[1]),min(ba[2],bb[2]),min(ba[3],bb[3])]
    if box[0]>=box[2] or box[1]>=box[3]:return 0
    return int(np.count_nonzero(alpha(a,box)&alpha(b,box)))/SCALE**2

minimum={};failures=[];checks=0
for f in frames:
    parts=f['parts']
    torso=next(p for p in parts if p['src'].endswith('/torso.png'))
    tail=next(p for p in parts if p['src'].endswith('/tail.png'))
    pairs=[('tail/torso',tail,torso)]
    hips=[p for p in parts if p['src'].endswith('/hip.png')]
    fronts=[p for p in parts if p['src'].endswith('/fore_upper.png')]
    for i,hip in enumerate(hips):
        lower=[p for p in parts if p['src'].endswith('/hind_lower.png')][i]
        ankle=[p for p in parts if p['src'].endswith('/hind_ankle.png')][i]
        paw=[p for p in parts if p['src'].endswith('/hind_paw.png')][i]
        pairs += [(f'rear{i}/root',hip,torso),(f'rear{i}/knee',hip,lower),(f'rear{i}/hock',lower,ankle),(f'rear{i}/heel',ankle,paw)]
    for i,upper in enumerate(fronts):
        lower=[p for p in parts if p['src'].endswith('/fore_lower.png')][i]
        paw=[p for p in parts if p['src'].endswith('/fore_paw.png')][i]
        pairs += [(f'front{i}/root',upper,torso),(f'front{i}/elbow',upper,lower),(f'front{i}/wrist',lower,paw)]
    for name,a,b in pairs:
        coverage=overlap(a,b);checks+=1
        minimum[name]=min(minimum.get(name,float('inf')),coverage)
        if coverage<1:failures.append({'action':f['action'],'phase':f['phase'],'joint':name,'overlap_pixels':coverage})
result={'checks':checks,'failures':failures,'minimum_overlap_pixels':minimum,'description':'Actual antialiased PNG alpha intersections at 3x sample density; coverage is a connectivity check, not aesthetic approval.'}
(root/f'reports/{output_name}').mkdir(parents=True,exist_ok=True)
(root/f'reports/{output_name}/alpha-joints.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'checks':checks,'failures':len(failures),'minimum':minimum}))
if failures:print(json.dumps(failures[:12]));raise SystemExit(1)
