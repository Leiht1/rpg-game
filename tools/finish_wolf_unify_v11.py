"""Register generated fur and ink along each accepted contour, not a loose bbox."""
from pathlib import Path
import sys,json,shutil,hashlib
import numpy as np
from PIL import Image
sys.path.insert(0,str(Path.home()/'.codex/skills/generate2dsprite/scripts'))
from forge_core import connected_components

root=Path(__file__).resolve().parents[1];source=Path(sys.argv[1])
art=root/'art/wolf-unify-v11';out=root/'prototypes/boss-beasts-v1/assets/wolf/side-v11'
art.mkdir(parents=True,exist_ok=True);out.mkdir(parents=True,exist_ok=True)
shutil.copy2(source,art/'generated.png')
im=Image.open(source).convert('RGBA');data=np.array(im)
components=connected_components(im,threshold=8,min_area=500,with_masks=True)
assert len(components)==5,[(c['area'],c['bbox'])for c in components]
thigh_path=root/'prototypes/boss-beasts-v1/assets/wolf/side-v10/hip.png'
thigh=np.array(Image.open(thigh_path).convert('RGBA'));t=thigh[:,:,:3].astype(float)
coat=t[(thigh[:,:,3]>128)&(t.min(axis=2)>140)&(np.ptp(t,axis=2)<20)]
coat=coat[np.argsort(coat.mean(axis=1))]
ink=t[(thigh[:,:,3]>128)&(t.max(axis=2)<65)]
ink=ink[np.argsort(ink.mean(axis=1))]
assert len(coat)>1000 and len(ink)>50
records=[]
for c in components:
    x0,y0,x1,y1=c['bbox'];cx,cy=(x0+x1)/2,(y0+y1)/2
    name=['fore_lower','hind_lower','hind_ankle'][min(2,int(cx//(im.width/3)))] if cy<im.height*.66 else ('fore_paw' if cx<im.width/2 else 'hind_paw')
    rgb=data[y0:y1,x0:x1,:3].astype(float);src_mask=c['mask']&(data[y0:y1,x0:x1,3]>32)
    lum=rgb.mean(axis=2);fur=src_mask&(lum>=110)&(np.ptp(rgb,axis=2)<40)
    levels=np.sort(lum[fur]);assert len(levels)>100
    rank=np.clip(np.searchsorted(levels,lum[fur],side='right')/len(levels),0,1)
    rgb[fur]=coat[np.minimum(len(coat)-1,(rank*(len(coat)-1)).astype(int))]
    dark=src_mask&(lum<90);dark_levels=np.sort(lum[dark]);assert len(dark_levels)>30
    rank=np.clip(np.searchsorted(dark_levels,lum[dark],side='right')/len(dark_levels),0,1)
    rgb[dark]=ink[np.minimum(len(ink)-1,(rank*(len(ink)-1)).astype(int))]
    rows=np.flatnonzero(src_mask.any(axis=1));left={};right={}
    for y in rows:
        xs=np.flatnonzero(src_mask[y]);grid=np.arange(src_mask.shape[1]);at=np.searchsorted(xs,grid)
        lo=xs[np.maximum(at-1,0)];hi=xs[np.minimum(at,len(xs)-1)]
        rgb[y]=rgb[y,np.where(abs(grid-lo)<=abs(grid-hi),lo,hi)]
        left[y],right[y]=xs[0],xs[-1]
    def sample(y,u):
        y=int(rows[np.argmin(abs(rows-y))]);xx=left[y]+u*(right[y]-left[y])
        lo=np.floor(xx).astype(int);hi=np.minimum(lo+1,rgb.shape[1]-1);fraction=xx-lo
        return rgb[y,lo]*(1-fraction[:,None])+rgb[y,hi]*fraction[:,None]
    old_path=root/f'prototypes/boss-beasts-v1/assets/wolf/side-v10/{name}.png'
    old=np.array(Image.open(old_path).convert('RGBA'));result=np.zeros_like(old);result[:,:,3]=old[:,:,3]
    solid=old[:,:,3]>32;valid=np.flatnonzero(solid.any(axis=1));top,bottom=valid[0],valid[-1]
    for y in np.flatnonzero((old[:,:,3]>0).any(axis=1)):
        anchor_y=int(valid[np.argmin(abs(valid-y))]);xs=np.flatnonzero(solid[anchor_y]);target=np.flatnonzero(old[y,:,3]>0)
        u=np.clip((target-xs[0])/max(1,xs[-1]-xs[0]),0,1)
        sy=rows[0]+np.clip((y-top)/max(1,bottom-top),0,1)*(rows[-1]-rows[0]);lo=int(np.floor(sy));hi=int(np.ceil(sy));f=sy-lo
        result[y,target,:3]=np.clip(sample(lo,u)*(1-f)+sample(hi,u)*f,0,255).astype(np.uint8)
    if 'paw' in name:
        # Toe gaps are non-convex: keep their original correctly placed ink and
        # fur strokes instead of dragging an outer outline through a solid toe.
        # Transfer the actual thigh coat palette onto the original paw paint.
        original_rgb=old[:,:,:3].astype(float);original_lum=original_rgb.mean(axis=2)
        painted=old[:,:,3]>0
        fur=painted&(original_lum>=110)&(np.ptp(original_rgb,axis=2)<40)
        levels=np.sort(original_lum[fur]);rank=np.clip(np.searchsorted(levels,original_lum[fur],side='right')/len(levels),0,1)
        result[:,:,:3]=old[:,:,:3]
        result[fur,:3]=coat[np.minimum(len(coat)-1,(rank*(len(coat)-1)).astype(int))]
        result[~painted,:3]=0
    assert np.array_equal(old[:,:,3],result[:,:,3]),name
    dest=out/(name+'.png');Image.fromarray(result).save(dest)
    records.append({'part':name,'source_bbox':c['bbox'],'size':[result.shape[1],result.shape[0]],'alpha_identical_to_v10':True,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'source_v10_sha256':hashlib.sha256(old_path.read_bytes()).hexdigest(),'median_visible_rgb':np.median(result[result[:,:,3]>128,:3],axis=0).tolist()})
assert len({p['part']for p in records})==5
record={'route':'host_image:imagegen','approval':'pending_user','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'processing':'Three generated lower-leg fur/ink materials registered between real contours; paws retain original correctly placed ink and fur strokes with the current thigh coat palette. Five original V10 alpha/dimensions retained; no painted shape cutting or code-drawn outline.','thigh_coat_median_rgb':np.median(coat,axis=0).tolist(),'thigh_ink_median_rgb':np.median(ink,axis=0).tolist(),'parts':records}
for path in [art/'provenance.json',out/'provenance.json']:path.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(record))
