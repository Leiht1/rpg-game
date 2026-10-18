"""Package generated UI only: measured ownership, alpha, equal scaling and provenance."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
src=ROOT/'art/ui-rework-v1/candidate-01/generated.png'
im=Image.open(src).convert('RGBA')
out=ROOT/'assets/ui/rework_v1';out.mkdir(parents=True,exist_ok=True)
rects={'panel':(16,16,500,490),'slot':(555,50,984,460),'slot_selected':(1065,50,1490,460),'button':(4,615,510,865),'tooltip':(550,495,1000,990),'accent':(1100,600,1460,910)}
limits={'panel':(256,256),'slot':(96,96),'slot_selected':(96,96),'button':(256,88),'tooltip':(256,300),'accent':(96,96)}
records=[]
for name,rect in rects.items():
    a=np.array(im.crop(rect));rgb=a[:,:,:3].astype(float)
    key=(rgb[:,:,0]>150)&(rgb[:,:,2]>120)&(rgb[:,:,0]>rgb[:,:,1]*1.4)&(rgb[:,:,2]>rgb[:,:,1]*1.4)
    a[:,:,3][key]=0
    crop=Image.fromarray(a);bbox=crop.getbbox()
    assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<crop.width and bbox[3]<crop.height,(name,bbox)
    crop=crop.crop(bbox);w,h=limits[name];crop.thumbnail((w-4,h-4),Image.Resampling.LANCZOS)
    size=(w,h) if name.startswith('slot') else (crop.width+4,crop.height+4)
    canvas=Image.new('RGBA',size);canvas.alpha_composite(crop,((size[0]-crop.width)//2,(size[1]-crop.height)//2))
    file=out/(name+'.png');canvas.save(file)
    pixels=np.array(canvas);height,width=pixels.shape[:2]
    center=pixels[int(height*.25):int(height*.75),int(width*.25):int(width*.75)]
    qa={'transparent_outer_edge':bool((pixels[[0,-1],:,3]==0).all() and (pixels[:,[0,-1],3]==0).all()),'center_min_alpha':int(center[:,:,3].min()),'center_luma_min':round(float((center[:,:,:3]@np.array([.2126,.7152,.0722])).min()/255),4)}
    assert qa['transparent_outer_edge']
    if name!='accent':assert qa['center_min_alpha']==255 and qa['center_luma_min']>.65
    records.append({'file':str(file.relative_to(ROOT)),'ownership':rect,'bbox_in_ownership':bbox,'runtime_size':size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'qa':qa})
job=json.loads((src.parent/'job.json').read_text('utf-8'))
record={'version':'core-ui-art-2.0.0','status':'representative-pilot-before-promotion','art_source':'host_image','route':'local:codex-cli','exact_image_model':'not exposed','source':str(src.relative_to(ROOT)),'source_size':im.size,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'prompt':'art/ui-rework-v1/prompt.txt','receipt':'art/ui-rework-v1/candidate-01/job.json','estimate':job['estimate'],'processing':'Chroma key, complete measured ownership crops, equal-scale LANCZOS resize and 2px alpha padding. Slot states share a 96px registration canvas. No repaint, rotation or baked non-uniform scaling.','selection_reason':'Illustrated notebook paper, linen inserts and cloth tabs have distinct material structures; no wood beams, no text in images, corners and body treated separately.','warnings':['Some generated silhouettes do not meet the requested 48px nominal cell padding; complete measured ownership rectangles keep all visible paint with positive clear margins.'],'files':records,'external_assets':[]}
(out/'provenance.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print('Packaged',len(records),'generated UI assets; measured regions and QA saved.')
