from PIL import Image,ImageOps
from pathlib import Path
import numpy as np,json
base=Path('art/hair-night-local-v1');out=Path('prototypes/bun-forehead-v4');out.mkdir(exist_ok=True)
h=np.array(Image.open('prototypes/character-hair-v2/heads/side.png').convert('RGBA'))
# The model redrew the fitting skull. Reject that output and register the accepted
# generated forelock against the ACTUAL head's contour. This moves whole existing
# columns of the front lock; it paints/fills no pixels and changes no ear/bun pixels.
source=np.array(Image.open('prototypes/bun-exact-fit-v3/side.png').convert('RGBA'))
registered=np.zeros_like(source);shifts={};last_shift=0
for x in range(source.shape[1]):
    shift=0
    if 230<=x<270:
        hair_y=np.where(source[135:230,x,3]>127)[0]
        skull_y=np.where(h[:,x-68,3]>127)[0]
        if len(hair_y) and len(skull_y):
            shift=max(0,int(skull_y.min()+130+3-(hair_y.max()+135)))
            last_shift=shift
        elif source[:,x,3].max()>0 and last_shift>0:shift=last_shift
    if shift:registered[shift:,x]=source[:-shift,x];shifts[str(x)]=shift
    else:registered[:,x]=source[:,x]
canvas=Image.fromarray(registered,'RGBA')
canvas.save(out/'side.png');canvas.save(out/'right.png');ImageOps.mirror(canvas).save(out/'left.png')
def metrics(path):
    alpha=np.array(Image.open(path).convert('RGBA'))[:,:,3]
    ear_mask=(h[96:153,47:105,:3].max(2)<120)&(h[96:153,47:105,3]>100)
    ear_covered=int(((alpha[226:283,115:173]>127)&ear_mask).sum())
    gaps=[]
    for x in range(235,271):
        hair_y=np.where(alpha[135:230,x]>127)[0]
        skull_y=np.where(h[:,x-68,3]>127)[0]
        if len(hair_y) and len(skull_y):
            gap=int(skull_y.min()+130-(hair_y.max()+135)-1)
            if gap>0:gaps.append({'x':x,'gap':gap})
    rear=0
    for y in range(50,151):
        x=int(np.where(h[y,:,3]>127)[0].min())+68
        rear+=bool(alpha[y+130,x]>127)
    return {'ear_ink_total':int(ear_mask.sum()),'ear_ink_covered':ear_covered,'rear_covered_rows':rear,'rear_test_rows':101,'forehead_gaps':gaps,'max_forehead_gap':max([g['gap'] for g in gaps],default=0)}
qa={'before':metrics('prototypes/bun-exact-fit-v3/side.png'),'after':metrics(out/'side.png'),'registration':'actual-skull contour forelock registration; move existing columns only, no painted fill','column_displacement':shifts,'rejected_generation':'bun-forehead-generated: changed fitting-skull forehead shape'}
qa['pass']=qa['after']['max_forehead_gap']==0 and qa['after']['ear_ink_covered']==0 and qa['after']['rear_covered_rows']==101
(base/'forehead-fit-qa.json').write_text(json.dumps(qa,indent=2),encoding='utf-8',newline='\n')
print(json.dumps(qa))
