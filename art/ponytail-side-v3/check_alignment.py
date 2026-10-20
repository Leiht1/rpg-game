from pathlib import Path
from PIL import Image
import numpy as np,json
base=Path('art/ponytail-side-v3');old=Image.open('prototypes/character-hair-v2/hair/female_ponytail-side.png').convert('RGBA');generated=Image.open(base/'processed/clean.png').convert('RGBA')
a=np.array(old);ys,xs=np.where(a[:,:,3]>16);oldbox=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1))
b=np.array(generated);ys,xs=np.where(b[:,:,3]>16);box=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1));part=generated.crop(box);scale=(oldbox[2]-oldbox[0])/part.width;part=part.resize((round(part.width*scale),round(part.height*scale)),Image.Resampling.LANCZOS)
aligned=Image.new('RGBA',old.size);aligned.alpha_composite(part,(oldbox[0],oldbox[1]));aligned.save(base/'aligned-edit.png')
head=Image.new('RGBA',old.size);head.alpha_composite(Image.open('prototypes/character-hair-v2/heads/side.png'),(68,130));h=np.array(head).astype(int);roi=np.zeros(h.shape[:2],bool);roi[220:286,78:120]=True;skin=(h[:,:,3]>200)&(h[:,:,0]>160)&(h[:,:,0]-h[:,:,1]>25)&(h[:,:,1]-h[:,:,2]>25)
print('oldbox',oldbox,'sourcebox',box,'scale',scale)
for dx in [0,-1,-2,-3,-4]:
 shifted=Image.new('RGBA',old.size);shifted.alpha_composite(aligned,(dx,0));s=np.array(shifted);mask=roi&skin&(s[:,:,3]<240);print('dx',dx,'leak',int(mask.sum()))
