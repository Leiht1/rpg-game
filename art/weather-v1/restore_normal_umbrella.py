from pathlib import Path
import numpy as np,json,hashlib
from PIL import Image
src=Path('art/weather-v1/generated/generated.png');im=Image.open(src).convert('RGB');a=np.array(im.crop((0,0,780,im.height))).astype(float)
d=np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1];alpha=np.clip((110-d)/60,0,1);rgb=np.clip((a-(1-alpha[:,:,None])*[255,0,255])/np.maximum(alpha[:,:,None],.001),0,255)
im=Image.fromarray(np.dstack([rgb,alpha*255]).astype('uint8'));im=im.crop(im.getbbox());im=im.resize((256,round(im.height*256/im.width)),Image.Resampling.LANCZOS);im.save('prototypes/weather-v1/umbrella.png')
p=Path('data/held_tools.json');j=json.loads(p.read_text(encoding='utf-8'));j['tool:rain_umbrella']['grip_px']=[128,im.height-32];j['tool:rain_umbrella']['hold_arm_degrees']={'front':-150,'back':-150,'side':-145};p.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=Path('prototypes/weather-v1/provenance.json');j=json.loads(p.read_text(encoding='utf-8'));j['qa']['umbrella']={'size':list(im.size),'sha256':hashlib.sha256(Path('prototypes/weather-v1/umbrella.png').read_bytes()).hexdigest(),'source':str(src),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'route':'local:codex-cli','prompt':'art/weather-v1/prompt.txt','status':'pending_user','note':'original normal proportions restored; long shaft rejected; only native arm rotation raises grip'};p.write_text(json.dumps(j,ensure_ascii=False,indent=2),encoding='utf-8')
print('original umbrella restored',im.size)
