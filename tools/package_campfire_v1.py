from pathlib import Path
from PIL import Image
import numpy as np, json, hashlib
R=Path(__file__).resolve().parents[1]
src=R/'art/campfire-v1/candidate-01/generated.png'
im=Image.open(src).convert('RGBA'); a=np.array(im); rgb=a[:,:,:3].astype(float)
key=(rgb[:,:,0]>140)&(rgb[:,:,2]>100)&(rgb[:,:,0]>rgb[:,:,1]*1.4)&(rgb[:,:,2]>rgb[:,:,1]*1.4)
a[key,3]=0;clean=Image.fromarray(a)
out=R/'assets/campfire/v1';out.mkdir(parents=True,exist_ok=True)
records=[]
for i,name in enumerate(['base','lit_reference','flame','roasted_carrot','roasted_mushroom','icon']):
    x=i%3;y=i//3
    cell=(round(x*im.width/3),round(y*im.height/2),round((x+1)*im.width/3),round((y+1)*im.height/2))
    cut=clean.crop(cell);box=cut.getbbox();assert box and box[0]>0 and box[1]>0 and box[2]<cut.width and box[3]<cut.height
    cut=cut.crop(box);cut.thumbnail((240,240),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(256,256));canvas.alpha_composite(cut,((256-cut.width)//2,(256-cut.height)//2))
    p=out/(name+'.png');canvas.save(p)
    records.append(dict(name=name,cell=cell,bbox=box,size=cut.size,sha256=hashlib.sha256(p.read_bytes()).hexdigest(),safe_edges=True))
receipt=json.loads((src.parent/'job.json').read_text(encoding='utf-8'))
record=dict(version='campfire-art-1.0.0',status='integrated_per_explicit_task_visual_review_pending',route='local:codex-cli',art_source='host_image',model='codex-image_gen; underlying image model undisclosed',estimateUsd=0,actual_cost='unknown',source=str(src.relative_to(R)),source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),source_size=im.size,prompt='art/campfire-v1/prompt.txt',receipt='art/campfire-v1/candidate-01/job.json',processing='Complete cell ownership crop, magenta key, aspect-preserving Lanczos to 256 canvas. No code-painted artwork. Lit reference retained; game uses unlit base plus generated flame.',files=records,warnings=[] if im.size==(1536,1024) else [f'WARN source_size_mismatch value={im.width}x{im.height} requested=1536x1024'])
record['references']=[dict(file=f,sha256=hashlib.sha256((R/f).read_bytes()).hexdigest()) for f in ['reports/broadleaf-v1/grass-contact.png','assets/environment/view_v01/tree_0.png','assets/environment/view_v01/tree_1.png','assets/environment/view_v01/rock_0.png','assets/environment/view_v01/rock_1.png']]
(out/'provenance.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(record,ensure_ascii=False))
