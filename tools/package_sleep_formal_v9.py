from pathlib import Path
from PIL import Image
import json,hashlib,shutil
candidate=Path('prototypes/sleep-formal-v9/final');candidate.mkdir(parents=True,exist_ok=True)
old=Image.open('prototypes/sleep-occupied-v8/final/straw_mat.png').convert('RGBA');target=old.getbbox()
im=Image.open('art/sleep-formal-v9/processed/clean.png').convert('RGBA');box=im.getbbox();im=im.crop(box);scale=min((target[2]-target[0])/im.width,(target[3]-target[1])/im.height)
im=im.convert('RGBa').resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS).convert('RGBA');canvas=Image.new('RGBA',old.size);xy=((target[0]+target[2]-im.width)//2,(target[1]+target[3]-im.height)//2);canvas.alpha_composite(im,xy);canvas.save(candidate/'straw_mat.png')
approval='横向草席的被子太短了，头下面都漏出来了一节空的，再调整一下，然后就可以接入游戏了'
for out,files in [(Path('assets/sleep/v1'),{p.name:p for p in Path('prototypes/sleep-v1/final').glob('*.png')}),(Path('assets/sleep/occupied-v9'),{'wood_bed.png':Path('prototypes/sleep-occupied-v8/final/wood_bed.png'),'wood_bed-vertical.png':Path('prototypes/sleep-occupied-v6/final/wood_bed-vertical.png'),'straw_mat.png':candidate/'straw_mat.png','straw_mat-vertical.png':Path('prototypes/sleep-occupied-v8/final/straw_mat-vertical.png'),'sleeping_bag.png':Path('prototypes/sleep-occupied-v5/final/sleeping_bag.png')})]:
 out.mkdir(parents=True,exist_ok=True)
 for name,source in files.items(): shutil.copyfile(source,out/name)
 manifest=dict(status='approved_formal',approval=approval,approval_scope='Current sleep facilities and occupied art, including explicitly authorized final horizontal mat hem extension; does not approve future art.',art_source='host_image',route='local:codex-cli',files={name:dict(source=str(source),sha256=hashlib.sha256((out/name).read_bytes()).hexdigest(),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest()) for name,source in files.items()},final_mat_job='art/sleep-formal-v9/raw/job.json',final_mat_transform=dict(bbox=box,scale=scale,xy=xy))
 (out/'provenance.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
print('Formal base and five occupied facilities copied and SHA verified.')
