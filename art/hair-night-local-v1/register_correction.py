from pathlib import Path
from PIL import Image, ImageOps, ImageDraw
import json,hashlib,runpy
base=Path('art/hair-night-local-v1');out=Path('prototypes/hair-night-local-v1')
torch_out=Path('prototypes/torch-separated-v1');torch_out.mkdir(exist_ok=True)
im=Image.open(base/'torch-separated-keyed/raw-sheet-clean.png').convert('RGBA')
torch_records=[]
for col,name in enumerate(['body','flame']):
    cell=im.crop((round(im.width*col/2),0,round(im.width*(col+1)/2),im.height))
    box=cell.getbbox();part=cell.crop(box);part.save(torch_out/f'{name}.png')
    torch_records.append({'part':name,'source_cell':col,'alpha_bbox':box,'size':part.size})
(torch_out/'registration.json').write_text(json.dumps({'body_height':64.0,'flame_height':28.0,'flame_anchor_y':-53.0,'parts':torch_records},indent=2),encoding='utf-8',newline='\n')
source=Image.open(base/'mohawk-corrected-keyed/raw-sheet-clean.png').convert('RGBA')
records=[]
# Ownership boundaries sit in real blank gutters; the right crest crosses the nominal 1024 boundary.
boundaries=[0,500,980,source.width]
settings={'front':{'width':96,'bottom':190,'center':180},'back':{'width':118,'bottom':298,'center':180},'side':{'width':208,'bottom':293,'center':171}}
for col,view in enumerate(['front','back','side']):
    cell=source.crop((boundaries[col],0,boundaries[col+1],source.height));box=cell.getbbox();part=cell.crop(box)
    spec=settings[view];scale=spec['width']/part.width
    part=part.resize((spec['width'],round(part.height*scale)),Image.Resampling.LANCZOS)
    at=(spec['center']-part.width//2,spec['bottom']-part.height)
    canvas=Image.new('RGBA',(360,440));canvas.alpha_composite(part,at)
    canvas.save(out/f'unisex_mohawk-{view}.png')
    if view=='side':
        ImageOps.mirror(canvas).save(out/'unisex_mohawk-left.png');canvas.save(out/'unisex_mohawk-right.png')
    records.append({'view':view,'ownership':[boundaries[col],boundaries[col+1]],'source_bbox':box,'scale':scale,'paste':at,'scalp_anchor':spec})
# Align the bun back cap with the nape rather than floating above it.
bun_sheet=Image.open(base/'keyed/raw-sheet-clean.png').convert('RGBA')
bun=bun_sheet.crop((512,512,1024,1024));bun=bun.crop(bun.getbbox())
bun=bun.resize((224,round(bun.height*224/bun.width)),Image.Resampling.LANCZOS)
shifted=Image.new('RGBA',(360,440));shifted.alpha_composite(bun,(68,301-bun.height));shifted.save(out/'unisex_bun-back.png')
(base/'correction-registration.json').write_text(json.dumps(records,indent=2),encoding='utf-8',newline='\n')
catalog=json.loads(Path('prototypes/character-creation-v1/catalog.json').read_text(encoding='utf-8'))
# Exact head-centred overlays, enlarged for visual review before native rig checks.
sheet=Image.new('RGBA',(3*480,4*560),'#d6dbc4')
for row,(identity,gender) in enumerate([('unisex_mohawk','male'),('unisex_mohawk','female'),('unisex_bun','male'),('unisex_bun','female')]):
    for col,view in enumerate(['front','back','side']):
        head_path=catalog.get('gender_heads',{}).get(gender,{}).get(view,catalog['heads'][view])
        hp=Path(head_path.replace('res://','')) if head_path.startswith('res://') else Path('prototypes/character-creation-v1')/head_path
        head=Image.open(hp).convert('RGBA');tile=Image.new('RGBA',(360,440))
        tile.alpha_composite(head,((360-head.width)//2,(440-head.height)//2))
        tile.alpha_composite(Image.open(out/f'{identity}-{view}.png').convert('RGBA'))
        sheet.alpha_composite(tile.resize((450,550),Image.Resampling.LANCZOS),(col*480,row*560))
sheet.save(base/'scalp-registration-review.png')
provenance={'status':'pending_user','art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','correction':'complete newly painted unlit torch and separate flame; mohawk central crest only, exposed shaved sides; head-centred registration','jobs':['torch-separated-generated/job.json','mohawk-corrected-generated/job.json'],'ownership':'correction-registration.json','sha256':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for folder in [out,torch_out] for p in folder.glob('*.png')}}
(base/'correction-provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8',newline='\n')
print(torch_records,records)
if (base/'bun-exact-keyed/raw-sheet-clean.png').exists():runpy.run_path(str(base/'register_bun_exact.py'))
elif (base/'bun-fitted-keyed/raw-sheet-clean.png').exists():runpy.run_path(str(base/'register_bun_fit.py'))
