from pathlib import Path
from PIL import Image
import hashlib,json
out=Path('prototypes/sleep-occupied-v8/final');out.mkdir(parents=True,exist_ok=True)
transforms=[]
for i,name in enumerate(['wood_bed','straw_mat','straw_mat-vertical'],1):
 original=Image.open(Path('prototypes/sleep-occupied-v5/final')/(name+'.png')).convert('RGBA');target=original.getbbox()
 im=Image.open(f'art/sleep-occupied-v8/processed/sheet-{i}.png').convert('RGBA');box=im.getbbox();im=im.crop(box)
 scale=min((target[2]-target[0])/im.width,(target[3]-target[1])/im.height)
 im=im.convert('RGBa').resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS).convert('RGBA')
 canvas=Image.new('RGBA',original.size);xy=((target[0]+target[2]-im.width)//2,(target[1]+target[3]-im.height)//2);canvas.alpha_composite(im,xy);canvas.save(out/(name+'.png'))
 transforms.append(dict(name=name,bbox=box,scale=scale,xy=xy,canvas=original.size))
(out.parent/'provenance.json').write_text(json.dumps(dict(status='pending_user',approval=None,art_source='host_image',route='local:codex-cli',job='art/sleep-occupied-v8/raw/job.json',transforms=transforms,files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')},notes=['Artist source did not follow equal rows; ownership boundaries 0/480/800/1536 retained all three complete props. Repacked with magenta padding before soft keying.','Three head-end shortened blankets, original orange bed and cream mat palette. Successful vertical wood bed V6 and sleeping bag V5 unchanged.']),ensure_ascii=False,indent=2),encoding='utf8')
