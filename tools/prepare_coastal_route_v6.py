from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
out=Path('assets/exploration/coastal-route-v6');out.mkdir(parents=True,exist_ok=True)
source=Path('art/coastal-route-v6/arrow-fix/generated.png');im=Image.open(source).convert('RGBA');assert im.size==(1448,1086)
a=np.array(im);rgb=a[:,:,:3].astype(float);excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
alpha=1-np.clip(excess/255,0,1);alpha[excess<12]=1;alpha[excess>150]=0
for c,key in [(0,255),(1,0),(2,255)]:a[:,:,c]=np.clip((rgb[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255).astype('uint8')
a[:,:,3]=(alpha*255).astype('uint8');a[alpha==0]=0
arrow_box=(1370,925,1435,1065);north=Image.fromarray(a).crop(arrow_box);north=north.crop(north.getbbox());north.save(out/'north.png')
a[925:1065,1370:1435]=0;paper=Image.fromarray(a);bbox=paper.getbbox();paper=paper.crop(bbox);paper.save(out/'route-paper.png')
icon=paper.copy();icon.thumbnail((116,116),Image.Resampling.LANCZOS);cv=Image.new('RGBA',(128,128));cv.alpha_composite(icon,((128-icon.width)//2,(128-icon.height)//2));cv.save(out/'route-icon.png')
prov={'art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','estimateUsd':0,'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'processing':'Soft chroma matte; full paper at native ratio; separate hand-painted compass extracted. All terrain, route and annotations are model-painted, not code-drawn. Local edit corrected arrow directions.','paper_bbox':bbox,'north_source_region':arrow_box,'symbols':['two separate flat rocky areas','outer access path','shoreline','broken columns','circular stone seat','pale open platform','small shell marks'],'annotations':['沿着石地往外走。','看见断柱时，方向就对了。'],'no_entrance':True,'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')}}
(out/'provenance.json').write_text(json.dumps(prov,ensure_ascii=False,indent=2),encoding='utf-8')
Path('art/coastal-route-v6/processing.json').write_text(json.dumps({'paper_size':paper.size,'paper_bbox':bbox,'north_size':north.size,'preserved_original_ratio':True,'source_route_start':[197,855],'source_route_goal':[1095,278]},ensure_ascii=False,indent=2),encoding='utf-8')
p=Path('data/exploration_items.json');rows=json.loads(p.read_text(encoding='utf-8-sig'))
for row in rows:
 if row['item_id']=='ancient_mine_record':row.update(description='旧路线纸上画着两片石地、海岸与断柱记号。可反复查看。',icon='res://assets/exploration/coastal-route-v6/route-icon.png',world_visual='res://assets/exploration/coastal-route-v6/route-icon.png')
p.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
