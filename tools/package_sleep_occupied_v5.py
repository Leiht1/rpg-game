from pathlib import Path
from PIL import Image
import hashlib, json
source=Path('art/sleep-occupied-v5')
out=Path('prototypes/sleep-occupied-v5/final');out.mkdir(parents=True,exist_ok=True)
transforms=[]
for name,frame in [('wood_bed','horizontal-processed/sheet-1.png'),('straw_mat','horizontal-processed/sheet-2.png'),('sleeping_bag','horizontal-processed/sheet-3.png'),('wood_bed-vertical','vertical-processed/sheet-1.png'),('straw_mat-vertical','vertical-processed/sheet-2.png')]:
    original=Image.open(Path('prototypes/sleep-v1/final')/(name+'.png')).convert('RGBA')
    target=original.getbbox()
    im=Image.open(source/frame).convert('RGBA');box=im.getbbox();im=im.crop(box)
    scale=min((target[2]-target[0])/im.width,(target[3]-target[1])/im.height)
    im=im.convert('RGBa').resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS).convert('RGBA')
    canvas=Image.new('RGBA',original.size)
    xy=((target[0]+target[2]-im.width)//2,(target[1]+target[3]-im.height)//2)
    canvas.alpha_composite(im,xy);canvas.save(out/(name+'.png'))
    transforms.append(dict(name=name,source=frame,bbox=box,scale=scale,xy=xy,canvas=original.size,target_bbox=target))
manifest=dict(status='pending_user',approval=None,art_source='host_image',route='local:codex-cli',jobs=[str(source/'horizontal-raw/job.json'),str(source/'vertical-raw/job.json')],transforms=transforms,files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')},notes=['Five separately painted occupied props: same orange bed quilt, cream mat blanket matching pillow, sage occupied sleeping bag.','No baked character, skin, hair or clothing; current head is resolved at runtime.','Complete curved silhouettes retained with uniform scaling; no rectangular blanket crops, no recolored bed quilt for mat.'])
(out.parent/'provenance.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
print('Packaged five occupied facilities, pending_user.')
