from PIL import Image
from pathlib import Path
import json
root=Path('prototypes/biome-v02'); out=root/'materials';out.mkdir(exist_ok=True)
im=Image.open(root/'material-generation/generated.png').convert('RGB');w,h=im.size
names=['forest','highland','open_field','shore']
boxes=[(0,0,w//2,h//2),(w//2,0,w,h//2),(0,h//2,w//2,h),(w//2,h//2,w,h)]
for name,box in zip(names,boxes): im.crop(box).save(out/(name+'.png'))
(root/'material-processing.json').write_text(json.dumps({'source_size':im.size,'crop_boxes':dict(zip(names,boxes)),'alpha':'opaque terrain textures','status':'pending_user','route':'local:codex-cli','model':'codex-image_gen; exact underlying model unknown','cost':'subscription quota; monetary cost unknown'},indent=2),encoding='utf-8')
p=Path('assets/map_library/catalog.json');data=json.loads(p.read_text(encoding='utf-8'))
for name in names:
 data['entries']=[entry for entry in data['entries'] if entry['id']!=name+'__ground__blend_material__v02']
 data['entries'].append({'id':name+'__ground__blend_material__v02','biome':name,'category':'ground','slot':'blend_material','status':'pending_user','source':'res://prototypes/biome-v02/materials/'+name+'.png','art_source':'host_image','provenance':'res://prototypes/biome-v02/material-generation/job.json','transition':'world-coordinate continuous weights; forest edge / talus / sediment / shallows'})
p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

