from PIL import Image
from pathlib import Path
import json
p=Path(__file__).parent
im=Image.open(p/'art/source.png')
boxes=[(0,0,560,508),(570,150,930,510),(950,100,1170,510),(1230,90,1510,510),(0,508,560,1024),(600,550,920,1024),(950,540,1170,1024),(1230,540,1536,1024)]
meta={}
for i,b in enumerate(boxes):
 part=['head','torso','arm','leg'][i%4]; d='front' if i<4 else 'side'
 img=im.crop(b)
 if part=='torso':
  source=Image.open(p/'art/torso_source.png');mid=source.width//2
  b=(0,0,mid,source.height) if d=='front' else (mid,0,source.width,source.height)
  img=source.crop(b)
 bb=img.getchannel('A').point(lambda x:255 if x>100 else 0).getbbox();img=img.crop(bb)
 target={'head':(52,49),'torso':(28,28),'arm':(12,31),'leg':(14,31)}[part]
 if d=='side' and part=='torso':target=(23,28)
 img=img.resize(tuple(v*4 for v in target),Image.Resampling.LANCZOS)
 img.save(p/f'art/{d}_{part}.png')
 meta[f'{d}_{part}']={'source_file':'torso_source.png' if part=='torso' else 'source.png','source_region':b,'alpha_crop':bb,'logical_size':target,'density':4,'construction':'arm includes sleeve; leg includes shorts tube; torso has hip band only; head no neck'}
(p/'art/registration.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
