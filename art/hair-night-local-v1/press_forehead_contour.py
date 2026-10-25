from PIL import Image,ImageOps
from pathlib import Path
import numpy as np,json
base=Path('art/hair-night-local-v1');out=Path('prototypes/bun-contour-v5');out.mkdir(exist_ok=True)
src=Image.open('prototypes/bun-forehead-v4/side.png').convert('RGBA');a=np.array(src);result=src.copy()
anchors_x=[180,190,205,220,235,250,262]
anchors_drop=[0,4,10,12,10,4,0]
columns=[]
for x in range(181,262):
    visible=np.where(a[:,x,3]>16)[0]
    if not len(visible):continue
    top=int(visible.min());bottom=int(visible.max())+1
    drop=round(float(np.interp(x,anchors_x,anchors_drop)))
    drop=min(drop,max(0,bottom-top-3))
    if not drop:continue
    # Compress the complete existing front-cap column around its fixed hairline.
    # The ear/back/bun region is outside this range; no painted patch or new pixels.
    part=src.crop((x,top,x+1,bottom)).resize((1,bottom-top-drop),Image.Resampling.LANCZOS)
    result.paste((0,0,0,0),(x,top,x+1,bottom));result.paste(part,(x,top+drop))
    columns.append({'x':x,'top_before':top,'top_after':top+drop,'hairline_bottom_fixed':bottom})
result.save(out/'side.png');result.save(out/'right.png');ImageOps.mirror(result).save(out/'left.png')
after=np.array(result)
qa={'source':'prototypes/bun-forehead-v4/side.png','method':'compress original front-cap columns about fixed lower hairline','max_top_drop':max([c['top_after']-c['top_before'] for c in columns]),'unchanged_ear_back_region':bool(np.array_equal(a[:,:180],after[:,:180])),'columns':columns}
h=np.array(Image.open('prototypes/character-hair-v2/heads/side.png').convert('RGBA'))
ear=(h[96:153,47:105,:3].max(2)<120)&(h[96:153,47:105,3]>100)
qa['ear_ink_covered']=int(((after[226:283,115:173,3]>127)&ear).sum())
qa['forehead_gaps']=[]
for x in range(235,271):
    hair_y=np.where(after[135:230,x,3]>127)[0];skull_y=np.where(h[:,x-68,3]>127)[0]
    if len(hair_y) and len(skull_y):
        gap=int(skull_y.min()+130-hair_y.max()-135-1)
        if gap>0:qa['forehead_gaps'].append([x,gap])
qa['pass']=qa['unchanged_ear_back_region'] and qa['ear_ink_covered']==0 and not qa['forehead_gaps']
(base/'forehead-contour-v5.json').write_text(json.dumps(qa,indent=2),encoding='utf-8',newline='\n')
print({k:v for k,v in qa.items() if k!='columns'})
