from PIL import Image
import json
from pathlib import Path
p=Path(__file__).parent
im=Image.open(p/'art/source.png')
boxes=[(0,0,490,510),(520,100,850,500),(950,120,1120,490),(1250,120,1450,490),(0,510,490,1024),(550,550,850,1000),(950,570,1120,990),(1250,570,1480,990)]
meta={}
for i,b in enumerate(boxes):
    part=['head','torso','arm','leg'][i%4]; d='front' if i<4 else 'side'
    img=im.crop(b); bb=img.getchannel('A').point(lambda x:255 if x>100 else 0).getbbox(); img=img.crop(bb)
    # Uniform per-part registration shared by both sides, with small authored width variation.
    target={'head':(52,53),'torso':(32,34),'arm':(8,27),'leg':(10,24)}[part]
    if d=='side':target={'head':(50,53),'torso':(25,34),'arm':(8,27),'leg':(12,24)}[part]
    img=img.resize(tuple(v*4 for v in target),Image.Resampling.LANCZOS)
    img.save(p/f'art/{d}_{part}.png')
    if part=='torso':img.crop((0,0,img.width,17*4)).save(p/f'art/{d}_sleeves.png')
    meta[f'{d}_{part}']={'source_region':b,'alpha_crop':bb,'size':target}
(p/'art/registration.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
