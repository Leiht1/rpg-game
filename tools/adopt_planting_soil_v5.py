from pathlib import Path
import json,hashlib,shutil
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parents[1]
out=r/'assets/planting/v2';out.mkdir(parents=True,exist_ok=True)
source=r/'art/planting-soil-v5/processed/clean.png';target=out/'soil.png'
shutil.copyfile(source,target)
def brightness(path):
 a=np.asarray(Image.open(path).convert('RGBA'),dtype=float)
 return float((a[:,:,:3]@[.2126,.7152,.0722])[a[:,:,3]>220].mean())
old=brightness(r/'assets/planting/v1/soil.png');new=brightness(target)
(out/'provenance.json').write_text(json.dumps({'date':'2026-10-18','status':'requested_revision',
 'user_quote':'尺寸改为地板的尺寸，上下左右各减少2个单位吧；然后整体看起来现在的土还是太亮了，要再暗一点，然后继续吧',
 'scope':'仅获准soil-v4的本次指定尺寸/压暗修订；残根仍用v1独立叠层，底层共享此PNG；不批准尚未确认的作物候选',
 'route':'generate2dsprite -> route_media -> local:codex-cli','source':str(source.relative_to(r)),
 'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
 'measurement':{'method':'alpha > 220, mean sRGB weighted luma 0.2126/0.7152/0.0722; not perceptual linear luminance','v4':old,'v5':new,'relative_change':new/old-1}},ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'previous_luma':round(old,2),'current_luma':round(new,2),'change_percent':round((new/old-1)*100,1)}))
