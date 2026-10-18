"""Register generated contact structures, preserving chosen upper art and source anchors."""
from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,os
from collections import deque
root=Path(__file__).resolve().parent
selected=json.loads((root.parent/'environment-adapt-v01/selection.json').read_text(encoding='utf8'))['selected']
master_folder=root.parent/'environment-variety-v01/runtime'
records=[]
def anchor(im,y):
    a=np.asarray(im.convert('RGBA')).astype(float);row=a[max(0,min(im.height-1,y))]
    mask=(row[:,3]>128)&~((row[:,1]>row[:,0]*1.12)&(row[:,1]>row[:,2]*1.1))
    xs=np.where(mask)[0];return float(np.median(xs)) if len(xs) else im.width/2
for surface in ['grass','forest','dirt']:
    dirt_take=os.environ.get('CONTACT_DIRT_TAKE','02')
    processed=f'{surface}-processed-{dirt_take}' if surface=='dirt' else f'{surface}-processed'
    plate=Image.open(root/'art'/processed/'raw-sheet-clean.png').convert('RGBA')
    cw=plate.width/3;ch=plate.height/3
    for i,e in enumerate(selected):
        original=Image.open(master_folder/e['file']).convert('RGBA')
        cut=original.height-(40 if e['kind']=='tree' else 24)
        row,col=i//3,i%3
        cell=plate.crop((round(col*cw),round(row*ch),round((col+1)*cw),round((row+1)*ch)))
        pixels=np.asarray(cell);ys,xs=np.where(pixels[...,3]>32)
        bbox=(int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1)
        ob=original.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
        scale=(ob[3]-ob[1])/(bbox[3]-bbox[1])
        cut_src=round(bbox[3]-(original.height-cut)/scale)
        dx=anchor(original,cut+1)-anchor(cell,cut_src+1)*scale
        dy=original.height-1-bbox[3]*scale
        mapped=cell.convert('RGBa').transform(original.size,Image.Transform.AFFINE,(1/scale,0,-dx/scale,0,1/scale,-dy/scale),Image.Resampling.BICUBIC).convert('RGBA')
        old=np.asarray(original).astype(float);new=np.asarray(mapped).astype(float)
        weight=np.clip((np.arange(original.height)-cut+1)/(6 if e['kind']=='tree' else 4),0,1)[:,None,None]
        oa=old[...,3:4]/255;na=new[...,3:4]/255
        a=oa*(1-weight)+na*weight
        rgb=(old[...,:3]*oa*(1-weight)+new[...,:3]*na*weight)/np.maximum(a,1e-8)
        final=np.concatenate([rgb,a*255],axis=2).clip(0,255).astype('uint8');final[:cut]=np.asarray(original)[:cut]
        body_preserved=True
        # Rear contact blades may appear above the fixed bottom strip. Keep them
        # behind the unchanged chosen stone, instead of cropping them at a flat seam.
        if e['kind']=='rock' and surface!='dirt':
            x=np.asarray(mapped).astype(float);o=np.asarray(original)
            semantic=(x[...,1]-x[...,0]>9)&(x[...,1]-x[...,2]>24)
            if surface=='forest':semantic|=(x[...,0]-x[...,1]>13)&(x[...,0]-x[...,2]>25)
            near=semantic.copy()
            for oy,ox in [(1,0),(-1,0),(0,1),(0,-1)]:near|=np.roll(semantic,(oy,ox),(0,1))
            rows_mask=(np.arange(original.height)>=original.height-45)&(np.arange(original.height)<cut)
            use=near&(o[...,3]<16)&(x[...,3]>0)&rows_mask[:,None]
            final[use]=np.asarray(mapped)[use]
            body_preserved=bool(np.array_equal(final[:cut][o[:cut, :,3]>128],o[:cut][o[:cut, :,3]>128]))
        detached_removed=0
        if surface=='dirt' and dirt_take!='02':
            # The user requires attached soil on one plane. Remove only unattached
            # generated contact specks; never move pieces or invent connecting art.
            visible=final[...,3]>16;seen=np.zeros(visible.shape,bool);queue=deque()
            for y,x in zip(*np.where(visible[:cut])):seen[y,x]=True;queue.append((int(y),int(x)))
            while queue:
                y,x=queue.popleft()
                for oy in [-1,0,1]:
                    for ox in [-1,0,1]:
                        ny=y+oy;nx=x+ox
                        if 0<=ny<visible.shape[0] and 0<=nx<visible.shape[1] and visible[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;queue.append((ny,nx))
            detached=(visible&~seen);detached[:cut]=False
            detached_removed=int(detached.sum());final[detached]=0
        name=f'{e["id"]}_{surface}.png';p=root/'runtime'/name;Image.fromarray(final).save(p)
        records.append({'id':e['id'],'name':e['name'],'surface':surface,'file':name,'canvas':original.size,'cut_y':cut,'upper_original_equal':bool(np.array_equal(final[:cut],np.asarray(original)[:cut])),'opaque_upper_body_preserved':body_preserved,'source':f'art/{processed}/raw-sheet-clean.png','cell':[row,col],'scale':scale,'offset':[dx,dy],'source_bbox':bbox,'detached_soil_pixels_removed':detached_removed,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'status':'layout_pending_user_color_previously_accepted'})
(root/'runtime/manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'assets':len(records),'upper_preserved':all(x['upper_original_equal'] for x in records)},ensure_ascii=False))
