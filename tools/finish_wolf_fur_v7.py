"""Register generated fur RGB into the user-approved, pixel-identical V6 alpha."""
from pathlib import Path
import sys,json,shutil,hashlib
import numpy as np
from PIL import Image
sys.path.insert(0,str(Path.home()/'.codex/skills/generate2dsprite/scripts'))
from forge_core import connected_components

root=Path(__file__).resolve().parents[1]
version=sys.argv[2] if len(sys.argv)>2 else 'v7'
assert version in ('v7','v8','v9')
base='v7' if version=='v8' else 'v6'
source=Path(sys.argv[1]);art=root/f'art/wolf-fur-{version}';out=root/f'prototypes/boss-beasts-v1/assets/wolf/side-{version}'
art.mkdir(parents=True,exist_ok=True);out.mkdir(parents=True,exist_ok=True)
shutil.copy2(source,art/'generated.png')
generated=np.array(Image.open(source).convert('RGBA'))
components=connected_components(generated,threshold=8,min_area=500,with_masks=True)
assert len(components)==3,[(c['area'],c['bbox'])for c in components]
parts=[]
for c in components:
    x0,y0,x1,y1=c['bbox'];cx=(x0+x1)/2
    name=['fore_lower','hind_lower','hind_ankle'][int(cx//(generated.shape[1]/3))]
    color=generated[y0:y1,x0:x1,:3].copy();mask=c['mask']
    # Extend generated edge colours into transparent margins only, so registration
    # never samples the arbitrary black RGB stored under generated transparency.
    rows=np.flatnonzero(mask.any(axis=1))
    for y in rows:
        xs=np.flatnonzero(mask[y]);grid=np.arange(mask.shape[1]);insert=np.searchsorted(xs,grid)
        left=xs[np.maximum(insert-1,0)];right=xs[np.minimum(insert,len(xs)-1)]
        closest=np.where(abs(grid-left)<=abs(grid-right),left,right)
        color[y]=color[y,closest]
    for y in np.flatnonzero(~mask.any(axis=1)):
        color[y]=color[rows[np.argmin(abs(rows-y))]]
    old_path=root/f'prototypes/boss-beasts-v1/assets/wolf/side-{base}/{name}.png'
    old=np.array(Image.open(old_path).convert('RGBA'));result=old.copy()
    ys,xs=np.where(old[:,:,3]>8);ox0,oy0,ox1,oy1=xs.min(),ys.min(),xs.max()+1,ys.max()+1
    sampled=np.array(Image.fromarray(color).resize((ox1-ox0,oy1-oy0),Image.Resampling.LANCZOS))
    original=result[oy0:oy1,ox0:ox1,:3]
    # Keep the accepted source's existing dark outline; all new fur paint is
    # provided by imagegen, never synthesized or palette-painted by this script.
    if version in ('v8','v9'):
        # The user also rejected blue outlines: use the model's neutral fur RGB
        # for every original contour pixel, retaining the exact original alpha.
        yy=np.clip(np.arange(old.shape[0])-oy0,0,sampled.shape[0]-1)
        xx=np.clip(np.arange(old.shape[1])-ox0,0,sampled.shape[1]-1)
        result[:,:,:3]=sampled[yy[:,None],xx[None,:]]
    else:
        keep_outline=(original.mean(axis=2)<70)
        original[~keep_outline]=sampled[~keep_outline]
    dest=out/(name+'.png');Image.fromarray(result).save(dest)
    assert np.array_equal(old[:,:,3],result[:,:,3]),name
    assert old.shape==result.shape,name
    parts.append({'part':name,'size':[old.shape[1],old.shape[0]],'source_bbox':c['bbox'],'source_version':base,'source_sha256':hashlib.sha256(old_path.read_bytes()).hexdigest(),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'alpha_identical_to_source':True,'median_visible_rgb_before':np.median(old[old[:,:,3]>128,:3],axis=0).tolist(),'median_visible_rgb_after':np.median(result[result[:,:,3]>128,:3],axis=0).tolist()})
assert len({p['part']for p in parts})==3
record={'route':'host_image:imagegen','approval':'pending_user','scope':f'Generated fur RGB only; original {base} dimensions and alpha preserved bit-for-bit; source joint anchors and transforms unchanged. '+('Generated grey RGB includes outlines.' if version in ('v8','v9') else 'Existing dark outlines retained.'),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'parts':parts}
for path in [art/'provenance.json',out/'provenance.json']:path.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(parts))
