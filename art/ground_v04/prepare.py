from PIL import Image
import numpy as np,json,hashlib
from pathlib import Path
im=Image.open('art/ground_v04/generated/generated.png').convert('RGBA')
out=Path('assets/environment/ground_v04');out.mkdir(exist_ok=True)
qa=[]
for i in range(6):
 a=np.array(im.crop(((i%3)*512,(i//3)*512,(i%3+1)*512,(i//3+1)*512)))
 alpha=a[:,:,3].copy();mask=alpha>=210
 a[:,:,3]=np.where(mask,255,0)
 img=Image.fromarray(a);box=img.getbbox();img=img.crop(box)
 img.save(out/f'{i}.png')
 qa.append({'cell':i,'crop':box,'removed_haze_pixels':int(((alpha>0)&(~mask)).sum()),'original_boundary_alpha_max':int(max(alpha[0].max(),alpha[-1].max(),alpha[:,0].max(),alpha[:,-1].max()))})
Path('art/ground_v04/processing.json').write_text(json.dumps({'native_alpha':True,'alpha_threshold':210,'reason':'generated soft colored halo rejected; keep flat opaque cartoon shapes only','cells':qa,'status':'pending_user'},indent=2),encoding='utf-8')
