from pathlib import Path
from PIL import Image, ImageOps
import json, hashlib

base=Path('art/hair-night-local-v1')
out=Path('prototypes/hair-night-local-v1');out.mkdir(exist_ok=True)
source=Image.open(base/'keyed/raw-sheet-clean.png').convert('RGBA')
catalog_path=Path('prototypes/character-creation-v1/catalog.json')
cat=json.loads(catalog_path.read_text(encoding='utf-8'))
records=[]
for row,(identity,name) in enumerate([('unisex_mohawk','莫西干发型'),('unisex_bun','丸子头')]):
    entry={'name':name,'gender':'unisex'}
    for col,view in enumerate(['front','back','side']):
        box=(col*512,row*512,(col+1)*512,(row+1)*512)
        cell=source.crop(box);bbox=cell.getbbox();part=cell.crop(bbox)
        scale=224/part.width
        # Match the existing head cap width and face opening, retaining tall crests.
        part=part.resize((224,round(part.height*scale)),Image.Resampling.LANCZOS)
        bottom=300 if row==1 and view=='front' else 285
        at=(68,bottom-part.height)
        canvas=Image.new('RGBA',(360,440));canvas.alpha_composite(part,at)
        path=out/f'{identity}-{view}.png';canvas.save(path)
        entry[view]={'front':'res://'+path.as_posix(),'rear':''}
        if view=='side':
            ImageOps.mirror(canvas).save(out/f'{identity}-left.png')
            canvas.save(out/f'{identity}-right.png')
        records.append({'id':identity,'view':view,'source_box':box,'bbox':bbox,'scale':scale,'paste':at,'canvas':[360,440]})
    cat['hair'][identity]=entry
catalog_path.write_text(json.dumps(cat,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(base/'registration.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
provenance={'status':'pending_user','art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','source':'generated/job.json','prompt':'prompt.txt','registration':'register.py','four_views':'front/back/right; left is exact right mirror, matching existing rig','sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')}}
(base/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
print('Registered',len(records),'views plus explicit left/right exports')
