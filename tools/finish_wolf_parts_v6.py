"""Retain complete native-alpha anatomical segments; never cut painted joints."""
from pathlib import Path
import sys,json,shutil,hashlib
import numpy as np
from PIL import Image
sys.path.insert(0,str(Path.home()/'.codex/skills/generate2dsprite/scripts'))
from forge_core import connected_components,dilate_square

root=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1])
art=root/'art/wolf-parts-v6'
out=root/'prototypes/boss-beasts-v1/assets/wolf/side-v6'
art.mkdir(parents=True,exist_ok=True)
out.mkdir(parents=True,exist_ok=True)
shutil.copy2(source,art/'generated.png')
im=Image.open(source).convert('RGBA');data=np.array(im)
components=connected_components(im,threshold=8,min_area=500,with_masks=True)
assert len(components)==5,[(c['bbox'],c['area'])for c in components]
records=[]
for c in components:
    x0,y0,x1,y1=c['bbox'];cx,cy=(x0+x1)/2,(y0+y1)/2
    name=['fore_lower','hind_lower','hind_ankle'][int(cx//512)] if cy<650 else ('fore_paw' if cx<768 else 'hind_paw')
    assert not c['touches_edge'],name
    mask=np.zeros(data.shape[:2],bool);mask[y0:y1,x0:x1]=c['mask'];mask=dilate_square(mask,3)
    box=(max(0,x0-3),max(0,y0-3),min(im.width,x1+3),min(im.height,y1+3))
    x0,y0,x1,y1=box
    pixels=data[y0:y1,x0:x1].copy();pixels[~mask[y0:y1,x0:x1]]=0
    saved=Image.new('RGBA',(pixels.shape[1]+4,pixels.shape[0]+4));saved.paste(Image.fromarray(pixels),(2,2))
    dest=out/(name+'.png');saved.save(dest)
    record={'part':name,'source_bbox':box,'size':saved.size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()}
    if 'paw' not in name:
        alpha=np.array(saved)[:,:,3]>128
        ys=np.where(alpha.any(axis=1))[0];lo,hi=ys.min(),ys.max()
        top=int(round(lo+(hi-lo)*.12));bottom=int(round(lo+(hi-lo)*.88))
        centers=[(y,float(np.where(alpha[y])[0].mean()))for y in range(top,bottom+1)]
        a=np.array([centers[0][1],top]);b=np.array([centers[-1][1],bottom])
        deviations=[abs(x-(a[0]+(b[0]-a[0])*(y-top)/(bottom-top))) for y,x in centers]
        record['joint_a']=(a/[saved.width,saved.height]).tolist()
        record['joint_b']=(b/[saved.width,saved.height]).tolist()
        record['axis_deviation_px']=max(deviations)
        record['axis_deviation_over_width']=max(deviations)/saved.width
        assert record['axis_deviation_over_width']<.10, f"{name}: rejected pre-bent shaft"
    records.append(record)
assert len({r['part']for r in records})==5
assert len({r['sha256']for r in records})==5
manifest={'route':'host_image:imagegen','art_source':'host_image','approval':'pending_user','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'processing':'Native alpha; full component ownership at alpha>8 expanded3px; transparent safety margin2px. No painted-limb cropping. Five separate anatomical shapes, not resized copies.','parts':records}
for path in [art/'provenance.json',out/'provenance.json']:path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(records))
