"""Refined slot/button art; keep approved-direction main/tooltip/accent resources intact."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
src=ROOT/'art/ui-rework-v1/refine-01/generated.png'
im=Image.open(src).convert('RGBA')
out=ROOT/'assets/ui/refine_v1';out.mkdir(parents=True,exist_ok=True)
regions={'slot':(50,50,600,620),'slot_selected':(660,50,1220,620),'button':(20,760,700,1080),'nav_button':(720,680,1180,1160)}
limits={'slot':(64,64),'slot_selected':(64,64),'button':(256,80),'nav_button':(80,80)}
records=[]
for name,rect in regions.items():
    a=np.array(im.crop(rect));rgb=a[:,:,:3].astype(float)
    key=(rgb[:,:,0]>150)&(rgb[:,:,2]>120)&(rgb[:,:,0]>rgb[:,:,1]*1.4)&(rgb[:,:,2]>rgb[:,:,1]*1.4)
    a[:,:,3][key]=0
    crop=Image.fromarray(a);bbox=crop.getbbox()
    assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<crop.width and bbox[3]<crop.height,(name,bbox)
    crop=crop.crop(bbox);w,h=limits[name];crop.thumbnail((w-4,h-4),Image.Resampling.LANCZOS)
    # A wide source can have a different aspect ratio: do not export extra transparent
    # side gutters, which would eat visible text padding on compact close buttons.
    if name=='button':w,h=crop.width+4,crop.height+4
    canvas=Image.new('RGBA',(w,h));canvas.alpha_composite(crop,((w-crop.width)//2,(h-crop.height)//2))
    file=out/(name+'.png');canvas.save(file)
    data=np.array(canvas);center=data[h//4:3*h//4,w//4:3*w//4]
    qa={'transparent_outer_edge':bool((data[[0,-1],:,3]==0).all() and (data[:,[0,-1],3]==0).all()),'content_alpha_min':int(center[:,:,3].min()),'content_luma_min':round(float((center[:,:,:3]@np.array([.2126,.7152,.0722])).min()/255),4)}
    assert qa['transparent_outer_edge'] and qa['content_alpha_min']==255 and qa['content_luma_min']>.65
    records.append({'file':str(file.relative_to(ROOT)),'ownership':rect,'source_bbox':bbox,'runtime_size':[w,h],'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'qa':qa})
job=json.loads((src.parent/'job.json').read_text('utf-8'))
record={'version':'core-ui-art-2.1.0','status':'integrated_per_user_refinement_visual_review_pending','route':'local:codex-cli','art_source':'host_image','exact_image_model':'not exposed','source':str(src.relative_to(ROOT)),'source_size':im.size,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'prompt':'art/ui-rework-v1/prompt-refine.txt','receipt':'art/ui-rework-v1/refine-01/job.json','estimate':job['estimate'],'selection_reason':'Corner caps/stitches removed from item slots, thin continuous linen rim, straight soft-clipped paper-slip buttons and separate light navigation pads. Main paper/note/edge sprig preserved.','processing':'Measured complete ownership crops, chroma alpha, equal scale LANCZOS; slot states share 64x64 canvas to keep fine rim at display size. No repaint or nonuniform baked scale.','warnings':['Generator returned 1254x1254 instead of requested 1024x1024, and wide button exceeds nominal quadrant. Complete measured ownership crops used, no visible paint cut.'],'files':records}
(out/'provenance.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print('Packaged four refined UI assets with alpha/content QA.')
