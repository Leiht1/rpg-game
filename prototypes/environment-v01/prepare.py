"""Package model art only: keying is performed by generate2dsprite beforehand."""
from pathlib import Path
from PIL import Image
import json, hashlib, sys
root=Path(__file__).resolve().parent
processed=root/'art'/sys.argv[1]
out=root/'runtime';out.mkdir(exist_ok=True)
records=[]
for row,kind,size in [(0,'tree',(177,190)),(1,'rock',(77,65))]:
    group=[]
    for c in range(3):
        img=Image.open(processed/f'sheet-{row*3+c+1}.png').convert('RGBA')
        b=img.getchannel('A').point(lambda v:255 if v>16 else 0).getbbox()
        group.append(min((size[0]-4)/(b[2]-b[0]),(size[1]-4)/(b[3]-b[1])))
    for col,surface in enumerate(['grass','forest','dirt']):
        src=processed/f'sheet-{row*3+col+1}.png'
        im=Image.open(src).convert('RGBA')
        a=im.getchannel('A');box=a.point(lambda v:255 if v>16 else 0).getbbox()
        crop=im.crop(box)
        # One isotropic fit; bottom center is always original canvas bottom.
        scale=min(group)
        dims=(round(crop.width*scale),round(crop.height*scale))
        fit=crop.convert('RGBa').resize(dims,Image.Resampling.LANCZOS).convert('RGBA')
        canvas=Image.new('RGBA',size);xy=((size[0]-dims[0])//2,size[1]-dims[1]-1)
        canvas.alpha_composite(fit,xy);p=out/f'{kind}_{surface}.png';canvas.save(p)
        records.append(dict(file=p.name,source=str(src.relative_to(root)),source_bbox=box,scale=scale,offset=xy,size=size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
(out/'registration.json').write_text(json.dumps(records,indent=2),encoding='utf8')
print(json.dumps(records))
