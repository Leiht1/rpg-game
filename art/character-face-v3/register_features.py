from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import numpy as np, json, hashlib
from scipy.ndimage import distance_transform_edt
base=Path(__file__).resolve().parent;root=base.parents[1];out=root/'prototypes/character-face-v3';out.mkdir(exist_ok=True)
records=[]
for view,source,regions in [
 ('front','prototypes/character-creation-v1/heads/front.png',[(49,82,83,130),(137,81,172,130),(89,129,134,146)]),
 ('side','prototypes/character-hair-v2/heads/side.png',[(143,68,183,128),(167,128,194,145)])]:
 original=Image.open(root/source).convert('RGBA');generated=Image.open(base/(view+'-generated/generated.png')).convert('RGBA')
 raw=np.array(generated);ys,xs=np.where(raw[:,:,3]>128);gb=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1))
 bbox=original.getbbox();aligned=Image.new('RGBA',original.size);aligned.alpha_composite(generated.crop(gb).resize((bbox[2]-bbox[0],bbox[3]-bbox[1]),Image.Resampling.LANCZOS),(bbox[0],bbox[1]))
 mask=Image.new('L',original.size);draw=ImageDraw.Draw(mask)
 for region in regions:draw.rectangle(region,fill=255)
 mask=np.array(mask.filter(ImageFilter.GaussianBlur(1.5)))
 old=np.array(original);mask[distance_transform_edt(old[:,:,3]>250)<9]=0
 edited=np.array(Image.composite(aligned,original,Image.fromarray(mask)));edited[:,:,3]=old[:,:,3]
 result=Image.fromarray(edited);result.save(out/(view+'.png'))
 changed=np.any(edited!=old,axis=2);protected=(distance_transform_edt(old[:,:,3]>250)<9)
 assert np.array_equal(edited[:,:,3],old[:,:,3]);assert not changed[protected].any();assert not changed[:65].any()
 records.append({'view':view,'source':source,'source_size':original.size,'generated_bbox':gb,'destination_bbox':bbox,'feature_regions':regions,'alpha_identical':True,'outline_9px_identical':True,'upper_65px_identical':True,'changed_pixels':int(changed.sum()),'runtime_sha256':hashlib.sha256((out/(view+'.png')).read_bytes()).hexdigest()})
(base/'registration-qa.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
print(json.dumps(records))
