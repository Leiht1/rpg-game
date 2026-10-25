from pathlib import Path
import numpy as np,json,hashlib
from PIL import Image
src=Path('art/weather-v1/generated/generated.png');im=Image.open(src).convert('RGB');a=np.array(im.crop((780,0,im.width,im.height))).astype(float)
d=np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1];alpha=np.clip((110-d)/60,0,1);rgb=np.clip((a-(1-alpha[:,:,None])*[255,0,255])/np.maximum(alpha[:,:,None],.001),0,255)
im=Image.fromarray(np.dstack([rgb,alpha*255]).astype('uint8'));im=im.crop(im.getbbox());im=im.resize((640,round(im.height*640/im.width)),Image.Resampling.LANCZOS);im.save('prototypes/weather-v1/shelter.png')
p=Path('prototypes/weather-v1/provenance.json');j=json.loads(p.read_text(encoding='utf-8'));j['qa']['shelter'].update(size=list(im.size),sha256=hashlib.sha256(Path('prototypes/weather-v1/shelter.png').read_bytes()).hexdigest());p.write_text(json.dumps(j,ensure_ascii=False,indent=2),encoding='utf-8')
p=Path('data/items.json');j=json.loads(p.read_text(encoding='utf-8'));next(x for x in j if x['item_id']=='rain_shelter')['description']='木杆支撑防雨布，覆盖3×3建造格，不提供热量。';p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('clean shelter',im.size)
