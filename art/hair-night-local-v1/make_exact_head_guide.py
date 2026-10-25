from PIL import Image
from pathlib import Path
import numpy as np,json
base=Path('art/hair-night-local-v1')
sheet=Image.new('RGBA',(1536,1024),'#ff00ff')
paths=['prototypes/character-creation-v1/heads/front.png','prototypes/character-creation-v1/heads/back.png','prototypes/character-hair-v2/heads/side.png']
records=[]
for col,p in enumerate(paths):
    im=Image.open(p).convert('RGBA');a=np.array(im);rgb=a[:,:,:3].astype(float)
    mannequin=np.zeros_like(a);mannequin[:,:,:3]=[0,255,255];mannequin[:,:,3]=a[:,:,3]
    # Mark the original ear's actual ink pixels, not an inferred mannequin ear.
    boxes=[[(0,115,38,160),(186,115,224,160)],[(0,114,38,160),(186,114,224,160)],[(47,96,105,153)]][col]
    for x0,y0,x1,y1 in boxes:
        region=(rgb[y0:y1,x0:x1].max(2)<120)&(a[y0:y1,x0:x1,3]>100)
        patch=mannequin[y0:y1,x0:x1];patch[region,:3]=[0,255,0]
    guide=Image.fromarray(mannequin,'RGBA').resize((448,360),Image.Resampling.NEAREST)
    sheet.alpha_composite(guide,(512*col+32,400))
    records.append({'view':['front','back','side'][col],'head_texture':p,'head_origin':[512*col+32,400],'scale':2,'original_ear_boxes':boxes,'target_canvas_origin':[68,130]})
sheet.save(base/'exact-native-head-guide.png')
(base/'exact-native-head-guide.json').write_text(json.dumps(records,indent=2),encoding='utf-8',newline='\n')
