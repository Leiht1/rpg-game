from pathlib import Path
from PIL import Image
import json, hashlib
p=Path(__file__).parent
im=Image.open(p/'art/source.png').convert('RGBA')
# Regions contain separately generated components, not cuts of a complete body.
regions=[(0,0,540,500),(550,0,860,500),(900,0,1130,500),(1200,0,1500,500),
         (0,510,540,1024),(550,510,860,1024),(900,510,1130,1024),(1200,510,1500,1024)]
meta={}
for i,region in enumerate(regions):
    direction='front' if i<4 else 'side'
    part=['head','torso','arm','leg'][i%4]
    source=Image.open(p/'art/pant_fix_source.png').convert('RGBA') if i==3 else im
    component=source.crop(region)
    bbox=component.getchannel('A').point(lambda a:255 if a>100 else 0).getbbox()
    component=component.crop(bbox)
    size={'head':(56,45),'torso':(24 if direction=='front' else 20,24),'arm':(8,25),'leg':(9,27)}[part]
    # Premultiplied resizing preserves transparent edges without dark RGB fringes.
    component=component.convert('RGBa').resize(tuple(n*4 for n in size),Image.Resampling.LANCZOS).convert('RGBA')
    filename=f'{direction}_{part}.png'
    component.save(p/'art'/filename)
    meta[filename]={'source_file':'pant_fix_source.png' if i==3 else 'source.png','source_region':region,'alpha_crop':bbox,'logical_size':size,'density':4,'sha256':hashlib.sha256((p/'art'/filename).read_bytes()).hexdigest()}
(p/'art/registration.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
