from pathlib import Path
import json,hashlib
from PIL import Image
import numpy as np
out=Path('assets/exploration/final-v2');out.mkdir(parents=True,exist_ok=True)
source=Path('art/final-chapter-v2/props/generated.png');im=Image.open(source).convert('RGBA');files={}
for i,name in enumerate(['pillar','stump','seat']):
 box=[(0,0,512,im.height),(512,0,980,im.height),(980,0,im.width,im.height)][i];pic=im.crop(box);a=np.array(pic);rgb=a[:,:,:3].astype(float)
 excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1];alpha=1-np.clip(excess/255,0,1);alpha[excess<12]=1;alpha[excess>130]=0
 for c,key in [(0,255),(1,0),(2,255)]:a[:,:,c]=np.clip((rgb[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255).astype('uint8')
 a[:,:,3]=(alpha*255).astype('uint8');a[alpha==0]=0;pic=Image.fromarray(a);bounds=pic.getbbox();pic=pic.crop(bounds);pic.save(out/(name+'.png'))
 width={'pillar':78,'stump':76,'seat':103}[name]
 files[name]={'source':str(source),'ownership':box,'bounds':bounds,'source_size':pic.size,'world_width':width,'world_height':round(width*pic.height/pic.width,2),'anchor':'bottom center +6 world units','visible_magenta_pixels':int(((np.minimum(a[:,:,0].astype(int),a[:,:,2].astype(int))-a[:,:,1]>35)&(a[:,:,3]>64)).sum())}
source=Path('art/final-chapter-v2/ground-retry/generated.png');im=Image.open(source).convert('RGB');im.save(out/'ground.png');files['ground']={'source':str(source),'size':im.size,'processing':'Whole continuous texture. Runtime irregular world-space gradual opacity mask, no source cropping or painted silhouette.'}
for name,row in files.items():row['sha256']=hashlib.sha256((out/(name+'.png')).read_bytes()).hexdigest()
(out/'provenance.json').write_text(json.dumps({'route':'local:codex-cli','art_source':'host_image','model':'codex-image_gen','estimateUsd':0,'files':files,'visual_approval':'pending user review','failure':'first ground generation capacity error; retried without changing model'},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(files,ensure_ascii=False))
