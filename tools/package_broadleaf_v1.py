from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
R=Path(__file__).resolve().parents[1];source=R/'art/broadleaf-v1/candidate-02/generated.png'
image=Image.open(source).convert('RGBA');pixels=np.array(image);rgb=pixels[:,:,:3].astype(float)
key=(rgb[:,:,0]>150)&(rgb[:,:,2]>100)&(rgb[:,:,0]>rgb[:,:,1]*1.4)&(rgb[:,:,2]>rgb[:,:,1]*1.4)
pixels[key,3]=0;subject=Image.fromarray(pixels);bbox=subject.getbbox()
assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<image.width and bbox[3]<image.height
cut=subject.crop(bbox);cut.thumbnail((216,192),Image.Resampling.LANCZOS)
canvas=Image.new('RGBA',(256,256));canvas.alpha_composite(cut,((256-cut.width)//2,248-cut.height))
dest=R/'assets/harvest/broadleaf_v1';dest.mkdir(parents=True,exist_ok=True);file=dest/'plant.png';canvas.save(file)
alpha=np.array(canvas)[:,:,3]
record={'version':'broadleaf-art-1.0.0','status':'integrated_per_user_request_visual_review_pending','art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen; underlying model undisclosed','source':str(source.relative_to(R)),'prompt':'art/broadleaf-v1/prompt.txt','receipt':'art/broadleaf-v1/candidate-02/job.json','source_size':image.size,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'file':str(file.relative_to(R)),'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'bbox':bbox,'canvas':[256,256],'visible_size':cut.size,'registration':'visible bottom y=248; existing 64px canvas renderer gives foot+6px; no rotation or nonuniform scaling','processing':'Complete silhouette chroma key; aspect-preserving LANCZOS downscale; source-painted basal grass retained, no code-painted blades or ground patch','qa':{'transparent_outer_edges':bool((alpha[0]==0).all() and (alpha[-1]==0).all() and (alpha[:,0]==0).all() and (alpha[:,-1]==0).all()),'full_source_silhouette_inside':True},'warnings':[f'WARN source_size_mismatch: value={image.width}x{image.height}, requested=1024x1024; file=art/broadleaf-v1/candidate-02/generated.png'],'failed_attempt':'candidate-01: ARTIFACT_MISSING because six references exceeded tool limit five; no image returned. Approved two-tree/two-rock reference montage used for candidate-02.'}
assert record['qa']['transparent_outer_edges']
(dest/'provenance.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(record,ensure_ascii=False))
