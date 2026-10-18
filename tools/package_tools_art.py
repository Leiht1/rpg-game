from pathlib import Path
from PIL import Image
import json, hashlib
source=Path('art/tools-v04/processed')
root=Path('prototypes/tools-v04')
ids=['stone_axe','stone_pickaxe','simple_shovel']
provenance=json.loads((root/'provenance.json').read_text('utf-8'))
frames=[]
for i in range(6):
    image=Image.open(source/f'tool-{i+1}.png').convert('RGBA')
    box=image.getbbox()
    # Alpha bbox includes every visible pixel; add eight transparent source pixels.
    visible=image.crop(box)
    packed=Image.new('RGBA',(visible.width+16,visible.height+16),(0,0,0,0))
    packed.paste(visible,(8,8))
    name=ids[i%3]+('_icon.png' if i<3 else '_world.png')
    path=root/'visuals'/name
    packed.save(path)
    frames.append({'file':'visuals/'+name,'source':f'../../art/tools-v04/processed/tool-{i+1}.png','alpha_bbox':box,'padding':8,'rotation':0,'nonuniform_scale':False,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
provenance['files']=frames
provenance['notes'].append('Final PNGs remove empty transparent margins only, then add eight source-pixel safe padding. No visible pixels removed, no new scaling/rotation. Runtime adds its existing AtlasTexture safety margin.')
(root/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n','utf-8')
