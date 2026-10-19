"""Measure visible alpha overlap using actual exported runtime joint geometry."""
from pathlib import Path
from PIL import Image
import numpy as np,json,math
root=Path(__file__).resolve().parents[2]
out=root/'reports/animals-style-v2';art=root/'prototypes/animals-style-v2/parts'
profile=json.loads((out/'sheep-rig-profile.json').read_text(encoding='utf-8'))
S=6;origin=(-60,-80);canvas=(840,600)
def mask(part,angle=0,asset=None):
 p=profile[part];im=Image.open(art/(asset or p['asset'])).getchannel('A')
 jx,jy=p['joint'];ox,oy=p['offset'];w,h=p['size'];c=math.cos(angle);s=math.sin(angle)
 sx,sy=im.width/w,im.height/h;dx,dy=origin[0]-jx,origin[1]-jy
 coeff=(c*sx/S,s*sx/S,(c*dx+s*dy-ox)*sx,-s*sy/S,c*sy/S,(-s*dx+c*dy-oy)*sy)
 return np.asarray(im.transform(canvas,Image.Transform.AFFINE,coeff,Image.Resampling.BICUBIC))>160
checks=[]
for body in ['sheep_bare.png','sheep_wool.png']:
 torso=mask('Body',asset=body)
 for part in ['Head','Leg0','Leg1','Leg2','Leg3']:
  angles=np.linspace(-.12,.67,17) if part=='Head' else np.linspace(-.38,.38,17)
  areas=[float(np.count_nonzero(torso&mask(part,float(a))))/(S*S) for a in angles]
  minimum=min(areas)
  checks.append({'body':body,'part':part,'sampled_angles':len(angles),'angle_range':[float(angles[0]),float(angles[-1])],'min_overlap_world_squared':minimum,'threshold':.5,'pass':minimum>=.5})
result={'method':'actual runtime exported joint/offset/texture size; alpha >160; 6 samples/world unit; overlap of torso and each joint across full inherited motion envelope','count':len(checks),'pose_samples':sum(c['sampled_angles'] for c in checks),'failed':sum(not c['pass'] for c in checks),'checks':checks,'limits':'Measures overlap, not aesthetic approval; mirror and uniform juvenile scaling preserve topology.'}
(out/'sheep-connection-qa.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
raise SystemExit(1 if result['failed'] else 0)
