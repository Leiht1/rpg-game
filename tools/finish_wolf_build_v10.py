"""Complete generated muscular leg pieces; colour-only registration for fixed paws."""
from pathlib import Path
import sys,json,shutil,hashlib
import numpy as np
from PIL import Image
sys.path.insert(0,str(Path.home()/'.codex/skills/generate2dsprite/scripts'))
from forge_core import connected_components,dilate_square

root=Path(__file__).resolve().parents[1];source=Path(sys.argv[1])
art=root/'art/wolf-build-v10';out=root/'prototypes/boss-beasts-v1/assets/wolf/side-v10'
art.mkdir(parents=True,exist_ok=True);out.mkdir(parents=True,exist_ok=True)
shutil.copy2(source,art/'generated.png')
im=Image.open(source).convert('RGBA');data=np.array(im)
components=connected_components(im,threshold=8,min_area=500,with_masks=True)
assert len(components)==7,[(c['area'],c['bbox'])for c in components]
records=[]
for c in components:
    x0,y0,x1,y1=c['bbox'];cx,cy=(x0+x1)/2,(y0+y1)/2
    if cy<im.height*.35:name='fore_upper' if cx<im.width/2 else 'hip'
    elif cy<im.height*.78:name=['fore_lower','hind_lower','hind_ankle'][min(2,int(cx//(im.width/3)))]
    else:name='fore_paw' if cx<im.width/2 else 'hind_paw'
    assert not c['touches_edge'],name
    if 'paw' in name:
        old_path=root/f'prototypes/boss-beasts-v1/assets/wolf/side-v6/{name}.png'
        old=np.array(Image.open(old_path).convert('RGBA'));pixels=old.copy()
        color=data[y0:y1,x0:x1,:3].copy();mask=c['mask'];rows=np.flatnonzero(mask.any(axis=1))
        for y in rows:
            xs=np.flatnonzero(mask[y]);grid=np.arange(mask.shape[1]);at=np.searchsorted(xs,grid)
            left=xs[np.maximum(at-1,0)];right=xs[np.minimum(at,len(xs)-1)]
            closest=np.where(abs(grid-left)<=abs(grid-right),left,right);color[y]=color[y,closest]
        for y in np.flatnonzero(~mask.any(axis=1)):color[y]=color[rows[np.argmin(abs(rows-y))]]
        ys,xs=np.where(old[:,:,3]>8);ox0,oy0,ox1,oy1=xs.min(),ys.min(),xs.max()+1,ys.max()+1
        rgb=np.array(Image.fromarray(color).resize((ox1-ox0,oy1-oy0),Image.Resampling.LANCZOS))
        yy=np.clip(np.arange(old.shape[0])-oy0,0,rgb.shape[0]-1);xx=np.clip(np.arange(old.shape[1])-ox0,0,rgb.shape[1]-1)
        pixels[:,:,:3]=rgb[yy[:,None],xx[None,:]]
        # Keep the existing accepted light-grey material palette on the paws,
        # while retaining the generated toe/fur shading and charcoal claws.
        coat_path=root/'prototypes/boss-beasts-v1/assets/wolf/side-v9/fore_lower.png'
        coat=np.array(Image.open(coat_path).convert('RGBA'))
        target=coat[(coat[:,:,3]>128)&(coat[:,:,:3].min(axis=2)>140),:3]
        target=target[np.argsort(target.mean(axis=1))]
        fur=(pixels[:,:,3]>8)&(pixels[:,:,:3].min(axis=2)>100)&(np.ptp(pixels[:,:,:3].astype(int),axis=2)<30)
        values=pixels[fur,:3].mean(axis=1);ranking=np.argsort(np.argsort(values))
        pixels[fur,:3]=target[np.minimum(len(target)-1,(ranking/max(1,len(values)-1)*(len(target)-1)).astype(int))]
        saved=Image.fromarray(pixels)
        assert np.array_equal(pixels[:,:,3],old[:,:,3]),name
        record={'part':name,'paw_alpha_and_size_identical_to_v6':True,'source_v6_sha256':hashlib.sha256(old_path.read_bytes()).hexdigest()}
    else:
        mask=np.zeros(data.shape[:2],bool);mask[y0:y1,x0:x1]=c['mask'];mask=dilate_square(mask,3)
        box=(max(0,x0-3),max(0,y0-3),min(im.width,x1+3),min(im.height,y1+3));a,b,d,e=box
        pixels=data[b:e,a:d].copy();pixels[~mask[b:e,a:d]]=0
        saved=Image.new('RGBA',(pixels.shape[1]+4,pixels.shape[0]+4));saved.paste(Image.fromarray(pixels),(2,2))
        if name in ('fore_lower','hind_lower','hind_ankle'):
            # New silhouette, original accepted V9 light-grey RGB material.
            # Do not accept the image model's darker lower-leg colour drift.
            material_path=root/f'prototypes/boss-beasts-v1/assets/wolf/side-v9/{name}.png'
            material=Image.open(material_path).convert('RGB').resize(saved.size,Image.Resampling.LANCZOS)
            rgba=np.array(saved);rgba[:,:,:3]=np.array(material);saved=Image.fromarray(rgba)
        alpha=np.array(saved)[:,:,3]>128;ys=np.flatnonzero(alpha.any(axis=1));lo,hi=ys.min(),ys.max()
        top_q,bottom_q={'fore_upper':(.10,.90),'hip':(.15,.85),'fore_lower':(.08,.93),'hind_lower':(.08,.93),'hind_ankle':(.10,.92)}[name]
        top=int(round(lo+(hi-lo)*top_q));bottom=int(round(lo+(hi-lo)*bottom_q))
        record={'part':name,'joint_a':[float(np.where(alpha[top])[0].mean())/saved.width,top/saved.height],'joint_b':[float(np.where(alpha[bottom])[0].mean())/saved.width,bottom/saved.height]}
        if name in ('fore_lower','hind_lower','hind_ankle'):
            ax,bx=record['joint_a'][0]*saved.width,record['joint_b'][0]*saved.width
            dev=[abs(np.where(alpha[y])[0].mean()-(ax+(bx-ax)*(y-top)/(bottom-top)))for y in range(top,bottom+1)]
            record['axis_deviation_over_width']=float(max(dev)/saved.width)
            assert record['axis_deviation_over_width']<.12, f'{name}: pre-bent shaft rejected'
    dest=out/(name+'.png');saved.save(dest)
    record.update({'size':saved.size,'source_bbox':c['bbox'],'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()});records.append(record)
assert len({p['part']for p in records})==7
manifest={'route':'host_image:imagegen','approval':'pending_user','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'processing':'Five complete generated thicker limb contours; lower three retain registered V9 RGB material; paw recolours use the V9 light-grey coat palette in exact V6 alpha and dimensions; no painted limb clipping.','parts':records}
for dest in [art/'provenance.json',out/'provenance.json']:dest.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(records))
