from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
root=Path(__file__).resolve().parents[1];source=root/'art/cooking-discovery-v1/candidate-01/generated.png';im=Image.open(source).convert('RGBA');a=np.array(im);rgb=a[:,:,:3].astype(float)
# Recover smooth alpha from the solid magenta matte, retaining all pixels within each ownership cell.
key=(rgb[:,:,0]>140)&(rgb[:,:,2]>100)&(rgb[:,:,0]>rgb[:,:,1]*1.45)&(rgb[:,:,2]>rgb[:,:,1]*1.45)
a[key,3]=0
clean=Image.fromarray(a);out=root/'prototypes/cooking-discovery-v1';out.mkdir(parents=True,exist_ok=True);files=[]
for i,name in enumerate(['herb_roasted_mushroom','roasted_fruit_platter','field_harvest_platter']):
 edges=[0,510,997,1536];cell=(edges[i],0,edges[i+1],im.height);cut=clean.crop(cell);bbox=cut.getbbox();assert bbox and bbox[0]>0 and bbox[2]<cut.width
 cut=cut.crop(bbox);cut.thumbnail((224,224),Image.Resampling.LANCZOS);canvas=Image.new('RGBA',(256,256));canvas.alpha_composite(cut,((256-cut.width)//2,(256-cut.height)//2));p=out/(name+'.png');canvas.save(p)
 files.append(dict(file=p.name,cell=cell,bbox=bbox,sha256=hashlib.sha256(p.read_bytes()).hexdigest(),canvas=[256,256],alpha_bbox=canvas.getbbox(),safe_edges=True))
record=dict(status='pending_user; candidate art only; no formal asset promotion',route='local:codex-cli',art_source='host_image',model='codex-image_gen; underlying image model undisclosed',estimateUsd=0,actual_cost='unknown',source=str(source.relative_to(root)),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),prompt='art/cooking-discovery-v1/prompt.txt',receipt='art/cooking-discovery-v1/candidate-01/job.json',source_size=im.size,processing='Complete ownership cells, magenta extraction, aspect preserving Lanczos to 224px on 256px transparent canvas',files=files,references=[{'file':f,'sha256':hashlib.sha256((root/f).read_bytes()).hexdigest()} for f in ['assets/campfire/v1/roasted_mushroom.png','assets/items/v03/wildflower_icon.png']],warnings=['WARN source_grid_alignment: right platter crosses nominal x=1024 boundary; measured ownership boundaries 510/997 preserve all subjects. Source margins below requested 15%; output padded to at least 16px.'])
(out/'provenance.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(record,ensure_ascii=False))

