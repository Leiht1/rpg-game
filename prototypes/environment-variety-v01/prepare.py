from pathlib import Path
from PIL import Image
import json,hashlib
root=Path(__file__).resolve().parent
entries=[]
names={'tree':['高瘦幼树','矮胖阔冠树','高大开展树','疏冠分叉树'],'rock':['低矮扁石','敦实孤石','楔形石','双肩连体石','窄高石','缺角碎石']}
for kind,count,scale,canvas in [('tree',4,.72,(256,256)),('rock',6,.24,(128,100))]:
    for i in range(count):
        src=root/'art'/f'{kind}s-processed-02'/f'sheet-{i+1}.png'
        im=Image.open(src).convert('RGBA');box=im.getchannel('A').point(lambda v:255 if v>16 else 0).getbbox()
        crop=im.crop(box)
        dims=(round(crop.width*scale),round(crop.height*scale))
        fit=crop.convert('RGBa').resize(dims,Image.Resampling.LANCZOS).convert('RGBA')
        # The processor registered roots at cell center, never center each silhouette.
        pos=(round(canvas[0]/2-(256-box[0])*scale),canvas[1]-1-dims[1])
        if pos[0]<0 or pos[0]+fit.width>canvas[0] or pos[1]<0:raise ValueError('Art would clip')
        result=Image.new('RGBA',canvas);result.alpha_composite(fit,pos)
        name=f'{kind}_{i+1:02d}.png';p=root/'runtime'/name;result.save(p)
        entries.append({'id':f'{kind}_{i+1:02d}','name':names[kind][i],'kind':kind,'file':name,'canvas':canvas,'source_bbox':box,'display_bbox':result.getchannel('A').getbbox(),'scale':scale,'offset':pos,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'surface':'grass','status':'pending_user'})
(root/'runtime/manifest.json').write_text(json.dumps(entries,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(entries,ensure_ascii=False))
