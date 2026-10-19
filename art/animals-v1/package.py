from PIL import Image
from pathlib import Path
import hashlib,json
out=Path('assets/animals/v1');out.mkdir(parents=True,exist_ok=True)
names=['chicken_body','chicken_head','chicken_wing','chicken_leg','sheep_wool','sheep_bare','sheep_head','sheep_leg','chicken_egg','wool','shears','chicken_head_closed']
for n,name in enumerate(names,1):
 im=Image.open(f'art/animals-v1/processed/sheet-{n}.png').convert('RGBA');im=im.crop(im.getbbox())
 if name in ['shears','wool','chicken_egg']:
  im.thumbnail((224,224),Image.Resampling.LANCZOS);canvas=Image.new('RGBA',(256,256));canvas.alpha_composite(im,((256-im.width)//2,(256-im.height)//2));im=canvas
 im.save(out/(name+'.png'))
meta={'art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','estimateUsd':0,'status':'pending_user_visual_review','authorization':'本轮实现动物生态与养殖系统 V1；正式工程功能接入授权，非具体画稿视觉批准','camera':'side only facing right; runtime mirror for left','motion':'Skeleton2D/Bone2D procedural joint animation as explicitly requested; no video frames','source':'art/animals-v1/generated/generated.png','prompt':'art/animals-v1/prompt.txt','ownership':{'x':[0,410,790,1135,1448],'y':[0,350,695,1086]},'qa':'art/animals-v1/processed/pipeline-meta.json','warnings':['ownership-qc safe_frame value=1 threshold=0 cell=[0,0]; raw atlas cross_cell_components/cross_cell_visible failures corrected by ownership reframe'],'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')}}
(out/'provenance.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8');Path('art/animals-v1/provenance.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf-8')
