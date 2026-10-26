from pathlib import Path
from PIL import Image
import numpy as np, json, hashlib

source=Path('art/boss-rig-v1/atlas/generated.png')
im=Image.open(source).convert('RGBA')
slots=['torso','head','left_upper','left_forearm','left_fist','right_upper','right_forearm','right_fist','left_thigh','left_shin','left_foot','right_thigh','right_shin','right_foot','armor','core']
out=Path('assets/exploration/boss-rig-v1'); records=[]
for row,view in enumerate(['front','back','side']):
    folder=out/view;folder.mkdir(parents=True,exist_ok=True)
    for i,slot in enumerate(slots):
        columns=[0,236,400,588,777,958,1148,1335,1536]
        rows=[0,190,347,531,698,861,1024]
        col=i%8;r=row*2+i//8
        box=(columns[col],rows[r],columns[col+1],rows[r+1])
        a=np.array(im.crop(box));rgb=a[:,:,:3].astype(float)
        excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
        alpha=np.clip(1-excess/200,0,1);alpha[excess<15]=1;alpha[excess>160]=0
        for c,key in enumerate([255,0,255]):a[:,:,c]=np.clip((rgb[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255)
        a[:,:,3]=(alpha*255).astype('uint8');a[alpha==0]=0
        from scipy.ndimage import label
        labels,count=label(a[:,:,3]>32)
        if count:
            sizes=np.bincount(labels.ravel());sizes[0]=0
            keep=labels==sizes.argmax();a[~keep]=0
        part=Image.fromarray(a);bounds=part.getbbox();assert bounds
        part=part.crop(bounds)
        # The generator included ankle/boot contours in shin cells. Keep only the
        # complete upper stone section; the independently drawn foot owns the boot.
        if slot.endswith('_shin'):part=part.crop((0,round(part.height*.16),part.width,round(part.height*.66)))
        if slot.endswith('_upper') or slot.endswith('_thigh'):part=part.crop((0,round(part.height*.15),part.width,round(part.height*.84)))
        if slot.endswith('_forearm'):part=part.crop((0,round(part.height*.12),part.width,part.height))
        path=folder/(slot+'.png');part.save(path)
        records.append(dict(view=view,slot=slot,ownership=box,bounds=bounds,size=part.size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
provenance={'art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'prompt':'art/boss-rig-v1/prompt.txt','authorization':'2026-10-26 用户要求直接制作、接入、运行与验证；审美仍由用户查看','parts':records,'notes':['one unified three-view part atlas, no per-action regenerated body','shin boot contour excluded by ownership crop; independent foot supplies ankle overlap','all views share the same runtime joint lengths; sprite registration documented in ancient_lord_rig.gd']}
(out/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
print('48 parts finished')
