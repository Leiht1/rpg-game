from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'art/ui-hints-v1/candidate-01/generated.png'
image=Image.open(source).convert('RGBA');a=np.array(image);rgb=a[:,:,:3].astype(float)
key=(rgb[:,:,0]>150)&(rgb[:,:,2]>120)&(rgb[:,:,0]>rgb[:,:,1]*1.4)&(rgb[:,:,2]>rgb[:,:,1]*1.4)
a[:,:,3][key]=0
cut=Image.fromarray(a);bbox=cut.getbbox()
assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<cut.width and bbox[3]<cut.height
cut=cut.crop(bbox);cut.thumbnail((252,96),Image.Resampling.LANCZOS)
canvas=Image.new('RGBA',(cut.width+4,cut.height+4));canvas.alpha_composite(cut,(2,2))
dest=ROOT/'assets/ui/hints_v1';dest.mkdir(parents=True,exist_ok=True)
file=dest/'target_hint.png';canvas.save(file)
pixels=np.array(canvas);h,w=pixels.shape[:2];center=pixels[h//4:3*h//4,w//4:3*w//4]
qa={'transparent_outer_edge':bool((pixels[[0,-1],:,3]==0).all() and (pixels[:,[0,-1],3]==0).all()),'content_alpha_min':int(center[:,:,3].min()),'content_luma_min':float((center[:,:,:3]@np.array([.2126,.7152,.0722])).min()/255)}
assert qa['transparent_outer_edge'] and qa['content_alpha_min']==255 and qa['content_luma_min']>.65
record={'version':'ui-target-hint-1.0.0','status':'integrated_per_user_request_visual_review_pending','route':'local:codex-cli','art_source':'host_image','source':str(source.relative_to(ROOT)),'source_size':image.size,'prompt':'art/ui-hints-v1/prompt.txt','receipt':'art/ui-hints-v1/candidate-01/job.json','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'file':'assets/ui/hints_v1/target_hint.png','sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'bbox':bbox,'runtime_size':canvas.size,'processing':'Full silhouette chroma key, tight crop, equal aspect LANCZOS downscale, 2px alpha safety edge. No code painting.','design':'One single continuous light paper sheet, no offset backing or folded lower-right corner.','qa':qa,'warnings':[f'WARN source_size_mismatch: value={image.width}x{image.height}, requested=1024x1024; file=art/ui-hints-v1/candidate-01/generated.png. Full measured silhouette used.']}
(dest/'provenance.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(record,ensure_ascii=False,indent=2))
