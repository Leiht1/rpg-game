"""Package generated cutouts only; never paint or replace approved formal assets."""
from PIL import Image
from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[2]
src=root/'art/animals-style-v2'
out=root/'prototypes/animals-style-v2/parts';out.mkdir(parents=True,exist_ok=True)
names=['chicken_body','chicken_head','chicken_wing','chicken_leg','sheep_wool','sheep_bare','sheep_head','sheep_leg','chicken_head_closed']
images={}
for i,name in enumerate(names,1):
 im=Image.open(src/f'processed/sheet-{i}.png').convert('RGBA')
 if name=='sheep_head' and (root/'art/animals-head-v3/generated/generated.png').exists():
  im=Image.open(root/'art/animals-head-v3/generated/generated.png').convert('RGBA')
 im=im.crop(im.getbbox());images[name]=im
 # Retain complete generated art, including disconnected intentional features.
 if name not in ['chicken_body','sheep_wool','sheep_bare']:im.save(out/f'{name}.png')
# Runtime body canvases retain one registered footprint and uniform source scaling.
body_specs={'chicken_body':(420,310),'sheep_wool':(690,430),'sheep_bare':(690,430)}
transforms={}
for name,(cw,ch) in body_specs.items():
 im=images[name];limit=(cw,ch) if name!='sheep_bare' else (490,310)
 scale=min(limit[0]/im.width,limit[1]/im.height)
 final=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',(cw,ch));offset=((cw-final.width)//2,(ch-final.height)//2)
 canvas.alpha_composite(final,offset);canvas.save(out/f'{name}.png')
 transforms[name]={'source_size':im.size,'uniform_scale':scale,'registered_canvas':[cw,ch],'offset':offset,'size':final.size}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
refs=['art/animals-style-v2/hero-reference.png','art/animals-style-v2/scene-reference.png']
meta={'status':'pending_user_visual_review','art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','precise_model_revision':'not disclosed','estimateUsd':0.0,'actual_cash_receipt':'none; local subscription quota','raw':str((src/'generated/generated.png').relative_to(root)).replace('\\','/'),'raw_sha256':sha(src/'generated/generated.png'),'prompt':'art/animals-style-v2/prompt.txt','job':'art/animals-style-v2/generated/job.json','references':{p:sha(root/p) for p in refs},'reference_roles':['current formal hero rendered from character.tscn','actual scene context only; old animals explicitly excluded as style references'],'ownership':'equal 3x3 cells, source 1254x1254; no crossing components','processing':'soft magenta key, despill 1; full alpha bbox; no largest-component filtering; body uniform resize into registered transparent canvases','transforms':transforms,'qa':['art/animals-style-v2/raw-qc/sheet-qc.json','art/animals-style-v2/processed/pipeline-meta.json'],'formal_assets_replaced':False,'animation':'current Skeleton2D/Bone2D actor inherited; candidate-only pivots/textures/contact shadow','files':{p.name:sha(p) for p in out.glob('*.png')}}
if (root/'art/animals-head-v3/provenance.json').exists():meta['head_revision']='art/animals-head-v3/provenance.json'
(src/'provenance.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
(out.parent/'provenance.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'parts':len(names),'transforms':transforms}))
