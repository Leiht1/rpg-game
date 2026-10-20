from pathlib import Path
from PIL import Image
import json
base=Path('art/character-creation-v1')
layouts={'male':([0,351,669,1024],[0,386,748,1095,1536]),'female':([0,358,685,1024],[0,351,749,1102,1536]),'outfit':([0,433,873,1254],[0,426,823,1254])}
records=[]
for name,(xs,ys) in layouts.items():
 source=Image.open(base/('outfit-retry' if name=='outfit' else name+'-generated')/'generated.png').convert('RGBA');rows=len(ys)-1;dest=Image.new('RGBA',(1536,rows*512),(255,0,255,255))
 for r in range(rows):
  for c in range(3):
   original_box=(xs[c],ys[r],xs[c+1],ys[r+1]);cell=source.crop(original_box)
   source_name=('outfit-retry' if name=='outfit' else name+'-generated')+'/generated.png'
   if name=='male' and r==2:
    other=Image.open(base/'parted-generated/generated.png').convert('RGBA');w,h=other.size;original_box=(round(c*w/3),0,round((c+1)*w/3),h);cell=other.crop(original_box);source_name='parted-generated/generated.png'
   scale=min(1,448/cell.width,448/cell.height);cell=cell.resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.LANCZOS)
   at=(c*512+(512-cell.width)//2,r*512+(512-cell.height)//2);dest.alpha_composite(cell,at)
   records.append({'source':source_name,'box':original_box,'scale':scale,'dest':at,'sheet':name+'-packed.png'})
 dest.save(base/(name+'-packed.png'))
(base/'ownership.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
