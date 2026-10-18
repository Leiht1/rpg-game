"""Package approved task-direction redraw: ownership crops, alpha and equal scale only."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'art/ui-v1/candidate-02/generated.png'
image=Image.open(source).convert('RGBA')
out=ROOT/'assets/ui/v2';out.mkdir(parents=True,exist_ok=True)
regions={'panel':(40,90,620,655),'slot':(770,220,1100,545),'button':(35,800,625,1040),'hotbar':(630,800,1220,1040)}
max_sizes={'panel':(256,256),'slot':(96,96),'button':(256,80),'hotbar':(512,128)}
records=[]
for name,rect in regions.items():
    a=np.array(image.crop(rect))
    rgb=a[:,:,:3].astype(float)
    key=(rgb[:,:,0]>150)&(rgb[:,:,2]>120)&(rgb[:,:,0]>rgb[:,:,1]*1.4)&(rgb[:,:,2]>rgb[:,:,1]*1.4)
    a[:,:,3][key]=0
    crop=Image.fromarray(a);bbox=crop.getbbox()
    assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<crop.width and bbox[3]<crop.height,(name,bbox)
    crop=crop.crop(bbox)
    limit=max_sizes[name];crop.thumbnail((limit[0]-4,limit[1]-4),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',(crop.width+4,crop.height+4));canvas.alpha_composite(crop,(2,2))
    dest=out/(name+'.png');canvas.save(dest)
    pixels=np.array(canvas);h,w=pixels.shape[:2]
    center=pixels[int(h*.2):int(h*.8),int(w*.2):int(w*.8)]
    qa={'edge_alpha_zero':bool((pixels[[0,-1],:,3]==0).all() and (pixels[:,[0,-1],3]==0).all()),'text_zone_min_luma':float((center[:,:,:3]@np.array([.2126,.7152,.0722])).min()/255),'text_zone_min_alpha':int(center[:,:,3].min()),'green_dominant_pixels':int(((center[:,:,1]>center[:,:,0]+8)&(center[:,:,1]>center[:,:,2]+8)).sum())}
    # Pale opaque text surface, with no green or magenta ornaments.
    assert qa['edge_alpha_zero'] and qa['text_zone_min_alpha']==255 and qa['text_zone_min_luma']>.80
    records.append({'path':str(dest.relative_to(ROOT)),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'ownership_rect':rect,'source_alpha_bbox':bbox,'runtime_size':canvas.size,'qa':qa})
job=json.loads((source.parent/'job.json').read_text('utf-8'))
record={'version':'core-ui-art-1.1.0','status':'integrated_user_requested_redraw_visual_review_pending','route':'local:codex-cli','art_source':'host_image','exact_image_model':'not exposed','source':str(source.relative_to(ROOT)),'source_size':image.size,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'prompt':'art/ui-v1/prompt-redraw.txt','receipt':'art/ui-v1/candidate-02/job.json','estimate':job['estimate'],'selection_reason':'Redrawn pale text zones, no green/leaf decoration, thin lightweight boundaries. Texture supports content; layout measures actual text separately.','processing':'Magenta key, complete ownership crop, equal aspect LANCZOS resize, 2px transparent safe margin; no repaint, rotation or stretching baked into assets.','warnings':['Returned 1254x1254 rather than requested 1024x1024; measured ownership crops are used.'],'files':records}
(out/'provenance.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(record,ensure_ascii=False,indent=2))
