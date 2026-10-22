from pathlib import Path
from PIL import Image,ImageOps,ImageEnhance
import numpy as np,json,hashlib
root=Path(__file__).resolve().parents[1]
source=root/'art/combat-v1/generated/generated.png'
out=root/'assets/combat/v1';out.mkdir(parents=True,exist_ok=True)
names=['wood_club','tusk_club','boar_tusk','boar_meat','cured_pork','meatballs','smoked_meatballs','carrot_pork','plaster','medical_kit','relic','portal','boar_torso','boar_head','boar_leg','boar_tail']
im=Image.open(source).convert('RGBA');report=[];derived=[]
for n,name in enumerate(names):
 cell_source=Image.open(root/'art/combat-v1/repair/generated.png').convert('RGBA') if name=='boar_torso' else im
 x=n%4;y=n//4;box=tuple(round(v) for v in (x*cell_source.width/4,y*cell_source.height/4,(x+1)*cell_source.width/4,(y+1)*cell_source.height/4))
 if y==3:
  # Generated boar pieces overhang the nominal quarter lines. These ownership
  # boundaries lie in empty magenta gaps and preserve the complete drawings.
  boundaries=[0,350,700,940,1254]
  box=(round(boundaries[x]*cell_source.width/1254),round(cell_source.height*3/4),round(boundaries[x+1]*cell_source.width/1254),cell_source.height)
 tile=cell_source.crop(box);a=np.array(tile).astype(float);mag=np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1]
 alpha=np.clip(1-(mag-60)/110,0,1);a[:,:,3]=alpha*255
 # Remove magenta fringe while retaining the painted contour.
 edge=(alpha>0)&(alpha<1);a[:,:,0][edge]=np.minimum(a[:,:,0][edge],a[:,:,1][edge]+40);a[:,:,2][edge]=np.minimum(a[:,:,2][edge],a[:,:,1][edge]+40)
 tile=Image.fromarray(a.astype('uint8'));bounds=tile.getbbox();tile=tile.crop(bounds);tile.thumbnail((218,218),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',(256,256));canvas.alpha_composite(tile,((256-tile.width)//2,(256-tile.height)//2));canvas.save(out/(name+'.png'))
 if name in ('boar_meat','cured_pork','meatballs','smoked_meatballs','carrot_pork'):
  gray=ImageOps.grayscale(canvas);rotten=ImageOps.colorize(gray,'#343a2c','#939765').convert('RGBA');rotten.putalpha(canvas.getchannel('A'));rotten.save(out/(name+'_rotten.png'))
  derived.append({'id':name+'_rotten','source_id':name,'processing':'Grayscale colorized #343a2c to #939765; original alpha retained.','sha256':hashlib.sha256((out/(name+'_rotten.png')).read_bytes()).hexdigest()})
 report.append({'id':name,'source_box':box,'source_alpha_bbox':bounds,'runtime_size':[256,256],'sha256':hashlib.sha256((out/(name+'.png')).read_bytes()).hexdigest()})
provenance={'route':'local:codex-cli','model':'codex-image_gen','source':str(source.relative_to(root)),'prompt':'art/combat-v1/prompt.txt','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'reference':'art/animals-style-v2/scene-reference.png','reference_sha256':hashlib.sha256((root/'art/animals-style-v2/scene-reference.png').read_bytes()).hexdigest(),'repair':{'source':'art/combat-v1/repair/generated.png','prompt':'art/combat-v1/repair-prompt.txt','sha256':hashlib.sha256((root/'art/combat-v1/repair/generated.png').read_bytes()).hexdigest(),'adopted_only':'boar_torso'},'authorization':'User requested production integration of all assets for combat V1; visual feedback pending, not a claim of user aesthetic approval.','processing':'4x4 ownership crop from actual canvas; magenta soft alpha and edge despill; proportional LANCZOS to fixed 256 cells. Rotten versions color treatment of their own source.','assets':report,'qa_limits':['Original generated torso had cut-like end faces; only torso replaced from repair generation.','Rig joint and gameplay-size visual review pending.']}
provenance['derived_assets']=derived
provenance['runtime_review']='art/combat-v1/runtime-review.png'
previous=out/'provenance.json'
if previous.exists():
 old=json.loads(previous.read_text(encoding='utf-8'))
 for field in ['runtime_revision','qa_files','qa_limits','processing','hero_animation','effects']:
  if field in old:provenance[field]=old[field]
previous.write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
review=Image.new('RGBA',(1024,1024))
for n,name in enumerate(names):review.alpha_composite(Image.open(out/(name+'.png')),(n%4*256,n//4*256))
review.save(root/'art/combat-v1/runtime-review.png')
print('Packaged',len(report),'source cells and',len(derived),'derived rotten assets')
