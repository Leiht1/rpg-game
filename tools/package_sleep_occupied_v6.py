from pathlib import Path
from PIL import Image
import hashlib,json
source=Path('art/sleep-occupied-v6/vertical-bed-refined-processed/clean.png')
out=Path('prototypes/sleep-occupied-v6/final');out.mkdir(parents=True,exist_ok=True)
old=Image.open('prototypes/sleep-occupied-v5/final/wood_bed-vertical.png').convert('RGBA')
target=old.getbbox();im=Image.open(source).convert('RGBA');box=im.getbbox();im=im.crop(box)
scale=min((target[2]-target[0])/im.width,(target[3]-target[1])/im.height)
im=im.convert('RGBa').resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS).convert('RGBA')
canvas=Image.new('RGBA',old.size);xy=((target[0]+target[2]-im.width)//2,(target[1]+target[3]-im.height)//2)
canvas.alpha_composite(im,xy);path=out/'wood_bed-vertical.png';canvas.save(path)
(out.parent/'provenance.json').write_text(json.dumps(dict(status='pending_user',approval=None,art_source='host_image',route='local:codex-cli',job='art/sleep-occupied-v6/vertical-bed-refined-raw/job.json',source=str(source),bbox=box,scale=scale,xy=xy,canvas=old.size,files={path.name:hashlib.sha256(path.read_bytes()).hexdigest()},notes=['Vertical bed upper quilt shortened by image edit; cream mattress exposed below pillow.','Horizontal heads final net upward shift five world units from V5; two down from initial V6. Other four V5 occupied assets unchanged.']),ensure_ascii=False,indent=2),encoding='utf8')
print('Registered revised vertical bed; pending_user.')

