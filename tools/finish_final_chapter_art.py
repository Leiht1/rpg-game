from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
out=Path('assets/exploration/final-v1');out.mkdir(parents=True,exist_ok=True)
sources={};qa=[]
def take(name,path,box):
 im=Image.open(path).convert('RGBA').crop(box);a=np.array(im);rgb=a[:,:,:3].astype(float)
 excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
 alpha=1-np.clip(excess/255,0,1);alpha[excess<12]=1;alpha[excess>130]=0
 for c,key in [(0,255),(1,0),(2,255)]:a[:,:,c]=np.clip((rgb[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255).astype('uint8')
 a[:,:,3]=(alpha*255).astype('uint8');a[alpha==0]=0
 im=Image.fromarray(a);bounds=im.getbbox();assert bounds;im=im.crop(bounds);im.save(out/(name+'.png'))
 sources[name]={'source':str(path),'ownership':box,'bounds':bounds,'size':im.size,'sha256':hashlib.sha256((out/(name+'.png')).read_bytes()).hexdigest()}
 qa.append({'id':name+'_alpha','visible_pixels':int((a[:,:,3]>0).sum()),'magenta_visible':int(((np.minimum(a[:,:,0].astype(int),a[:,:,2].astype(int))-a[:,:,1]>35)&(a[:,:,3]>64)).sum())})
kit=Path('art/final-chapter-v1/kit/generated.png')
for name,box in [('boss',(0,0,550,512)),('chest',(550,0,1024,512)),('ruin',(1024,0,1536,512)),('letter',(0,512,520,1024)),('dock',(1024,512,1536,1024))]:take(name,kit,box)
take('ground',Path('art/final-chapter-v1/ground/generated.png'),(0,0,1536,1024))
items=Path('art/final-chapter-v1/items/generated.png');im=Image.open(items)
take('blueprint',items,(0,0,im.width//2,im.height));take('core',items,(im.width//2,0,im.width,im.height))
(out/'provenance.json').write_text(json.dumps({'art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','estimateUsd':0,'sources':sources,'authorization':'本轮完整开发与正式功能接入；具体审美未获用户确认','warnings':['ground approach touches source lower edge; kept whole, no fabricated extension','no video generation route; guardian uses master pose with state motion, not full directional animation clips'],'qa':qa},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(qa))
