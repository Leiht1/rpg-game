from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
out=Path('assets/exploration/coastal-route-v7');out.mkdir(parents=True,exist_ok=True)
source=Path('art/coastal-route-v7/generated/generated.png');im=Image.open(source).convert('RGBA')
a=np.array(im);rgb=a[:,:,:3].astype(float);excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
alpha=1-np.clip(excess/255,0,1);alpha[excess<12]=1;alpha[excess>150]=0
for c,key in [(0,255),(1,0),(2,255)]:a[:,:,c]=np.clip((rgb[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255).astype('uint8')
a[:,:,3]=(alpha*255).astype('uint8');a[alpha==0]=0
paper=Image.fromarray(a);bbox=paper.getbbox();assert bbox;paper=paper.crop(bbox);paper.save(out/'route-paper.png')
icon=paper.copy();icon.thumbnail((116,116),Image.Resampling.LANCZOS);cv=Image.new('RGBA',(128,128));cv.alpha_composite(icon,((128-icon.width)//2,(128-icon.height)//2));cv.save(out/'route-icon.png')
prov={'art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','estimateUsd':0,'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'processing':'Soft chroma matte; full original paper ratio retained. Text and compass removed by image edit; no patching over annotations with UI rectangles.','paper_bbox':bbox,'annotations':[],'compass':False,'symbols':['two flat stone patches','winding dotted route','circled coastal platform','broken columns','circular stone seat','shoreline','shell drawing'],'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')}}
(out/'provenance.json').write_text(json.dumps(prov,ensure_ascii=False,indent=2),encoding='utf-8')
Path('art/coastal-route-v7/processing.json').write_text(json.dumps({'source_size':im.size,'paper_size':paper.size,'paper_bbox':bbox},indent=2),encoding='utf-8')
p=Path('data/exploration_items.json');rows=json.loads(p.read_text(encoding='utf-8-sig'))
for row in rows:
 if row['item_id']=='ancient_mine_record':row.update(icon='res://assets/exploration/coastal-route-v7/route-icon.png',world_visual='res://assets/exploration/coastal-route-v7/route-icon.png')
p.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
