from PIL import Image
from pathlib import Path
import numpy as np,json
base=Path('art/hair-night-local-v1');sheet=Image.new('RGBA',(1536,1024),'#ff00ff')
paths=['prototypes/character-creation-v1/heads/front.png','prototypes/character-creation-v1/heads/back.png','prototypes/character-hair-v2/heads/side.png']
for col,view in enumerate(['front','back','side']):
    h=Image.open(paths[col]).convert('RGBA');a=np.array(h);r=np.zeros_like(a);r[:,:,:3]=[0,255,255];r[:,:,3]=a[:,:,3]
    if view=='side':
        m=(a[96:153,47:105,:3].max(2)<120)&(a[96:153,47:105,3]>100);p=r[96:153,47:105];p[m,:3]=[0,255,0]
    tile=Image.new('RGBA',(360,440));tile.alpha_composite(Image.fromarray(r,'RGBA'),(68,130));tile.alpha_composite(Image.open(f'prototypes/bun-exact-fit-v3/{view}.png').convert('RGBA'))
    # Fixed known transform: native canvas centre (180,220) -> (256,580), scale 1.5.
    resized=tile.resize((540,660),Image.Resampling.LANCZOS)
    sheet.alpha_composite(resized,(col*512-14,250))
sheet.save(base/'current-native-fit-with-gap.png')
