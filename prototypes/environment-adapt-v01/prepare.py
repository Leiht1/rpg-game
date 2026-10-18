"""Keep selected upper art byte-for-byte; register generated contact drawings only."""
from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
root=Path(__file__).resolve().parent
selected=json.loads((root/'selection.json').read_text(encoding='utf8'))['selected']
original=root.parent/'environment-variety-v01/runtime'
records=[]
def anchor(im,y):
    a=np.asarray(im.convert('RGBA'));y=max(0,min(a.shape[0]-1,y))
    row=a[y];mask=(row[:,3]>128)&~((row[:,1]>row[:,0]*1.12)&(row[:,1]>row[:,2]*1.1))
    xs=np.where(mask)[0]
    return float(np.median(xs)) if len(xs) else im.width/2
for index,entry in enumerate(selected):
    master=Image.open(original/entry['file']).convert('RGBA')
    is_tree=entry['kind']=='tree';kind='trees' if is_tree else 'rocks'
    i=index if is_tree else index-3
    plate=Image.open(root/'art'/f'{kind}-processed/raw-sheet-clean.png').convert('RGBA')
    rows=2 if is_tree else 4;cw=plate.width/3;ch=plate.height/rows
    for surface in ['grass','forest','dirt']:
        out=master.copy();cut=master.height-(40 if is_tree else 24)
        note={'source':'selected original','body_unchanged':True}
        if surface!='grass':
            row=(0 if surface=='forest' else 1) if is_tree else (i//3+(0 if surface=='forest' else 2))
            col=i if is_tree else i%3
            cell=plate.crop((round(col*cw),round(row*ch),round((col+1)*cw),round((row+1)*ch)))
            a=np.asarray(cell)[...,3];ys,xs=np.where(a>32)
            bbox=(int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1)
            oldbox=master.getchannel('A').point(lambda v:255 if v>32 else 0).getbbox()
            factor=(oldbox[3]-oldbox[1])/(bbox[3]-bbox[1])
            source_y=round(bbox[3]-(master.height-cut)/factor)
            original_anchor=anchor(master,cut+1);source_anchor=anchor(cell,source_y+1)
            dx=original_anchor-source_anchor*factor
            dy=master.height-1-bbox[3]*factor
            # Inverse affine resampling is only isotropic registration, never a warp.
            mapped=cell.convert('RGBa').transform(master.size,Image.Transform.AFFINE,(1/factor,0,-dx/factor,0,1/factor,-dy/factor),Image.Resampling.BICUBIC).convert('RGBA')
            m=np.asarray(master).astype(float);n=np.asarray(mapped).astype(float)
            # Join two genuinely painted structures in premultiplied alpha.
            weight=np.clip((np.arange(master.height)-cut+1)/(6 if is_tree else 4),0,1)[:,None,None]
            olda=m[...,3:4]/255;newa=n[...,3:4]/255
            alpha=olda*(1-weight)+newa*weight
            rgb=(m[...,:3]*olda*(1-weight)+n[...,:3]*newa*weight)/np.maximum(alpha,1e-8)
            result=np.concatenate([rgb,alpha*255],axis=2).clip(0,255).astype('uint8')
            result[:cut]=np.asarray(master)[:cut]
            out=Image.fromarray(result)
            note={'source':f'art/{kind}-processed/raw-sheet-clean.png','cell':[row,col],'isotropic_scale':factor,'offset':[dx,dy],'join_row':cut,'blend_rows':6 if is_tree else 4,'body_unchanged':bool(np.array_equal(np.asarray(out)[:cut],np.asarray(master)[:cut]))}
        path=root/'runtime'/f'{entry["id"]}_{surface}.png';out.save(path)
        pixels=np.asarray(out);lower=pixels[cut:];green=(lower[...,3]>64)&(lower[...,1]>lower[...,0]*1.2)&(lower[...,1]>lower[...,2]*1.12)
        records.append({'id':entry['id'],'name':entry['name'],'kind':entry['kind'],'surface':surface,'file':path.name,'canvas':master.size,'contact_height':master.height-cut,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'green_contact_px':int(green.sum()),'status':'shape_selected_adapter_pending' if surface!='grass' else 'selected','registration':note})
(root/'runtime/manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'assets':len(records),'upper_preserved':all(x['registration']['body_unchanged'] for x in records),'dirt_green_px':{x['id']:x['green_contact_px'] for x in records if x['surface']=='dirt'}},ensure_ascii=False))
