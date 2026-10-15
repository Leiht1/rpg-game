"""Minimal candidate repair: whole-frame registration, no local pixel edits."""
from pathlib import Path
import importlib.util, json, shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage, optimize

OUT=Path(__file__).resolve().parent
OLD=OUT.parent/'hero_consistency_preview_v04'
spec=importlib.util.spec_from_file_location('previous',OLD/'package_preview.py')
P=importlib.util.module_from_spec(spec);spec.loader.exec_module(P)
FONT=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',17)
def save(name,v):P.save(OUT/name,v)
def frames(direction,action,base=OLD):
    return [Image.open(p).convert('RGBA') for p in sorted((base/f'{direction}_{action}_preview/frames').glob('*.png'))]

def register_idle(direction):
    canonical='side' if direction=='right' else direction
    folder=OLD/f'{canonical}_breathe'
    meta=json.loads((folder/'normalization.json').read_text(encoding='utf-8'))
    raw=P.clean(Image.open(folder/meta['selectedTake']/'generated.png'))
    cells=[raw.crop(tuple(t['sourceCell'])) for t in meta['transforms']]
    scale=meta['globalScale']; old=frames(direction,'idle')
    reference=old[0]; r=P.feat(reference)
    # Shoes only, both boots together. No head/torso weighting.
    mask=np.zeros((128,128),bool);mask[96:115,22:110]=True
    mask &= ndimage.binary_dilation(r[:,:,3]>.02,iterations=2)
    def render(c,offset):
        return P.clean(P.W.render(c,scale,offset,512).convert('RGBa').resize((128,128),Image.Resampling.LANCZOS).convert('RGBA'))
    result=[reference];tr=[meta['transforms'][0]]
    for i in range(1,4):
        t=meta['transforms'][i];offset=np.array(t['offsetPx'])
        def cost(delta):return float(np.mean((P.feat(render(cells[i],offset+delta))-r)[mask]**2))
        fit=optimize.minimize(cost,[0,0],method='Powell',bounds=[(-2,2),(-2,2)],options={'xtol':.002,'maxiter':25})
        result.append(render(cells[i],offset+fit.x))
        tr.append({**t,'offsetPx':(offset+fit.x).tolist(),'v05FeetOnlyDeltaPx':fit.x.tolist(),'feetCost':float(fit.fun)})
    P.sheet(OUT/f'{direction}_idle_preview',f'{direction}_idle',result,2)
    save(f'{direction}_idle_preview/registration.json',{'source':str(folder),'scale':scale,'transforms':tr,
        'policy':'Same v04 complete source frames and one shared scale. Whole-frame rigid translation fitted only to both boots, y=96:115. First frame unchanged. No local patch/warp/scale.'})
    return result

def contact(name,rows,cols=4,size=256):
    im=Image.new('RGB',(cols*size,len(rows)* (size+28)),'#e2eacb');d=ImageDraw.Draw(im)
    for y,(label,fs) in enumerate(rows):
        for x,f in enumerate(fs):
            if x>=cols:continue
            P.panel(im,f,x*size,y*(size+28)+28,size)
            d.text((x*size+8,y*(size+28)+4),f'{label}  {x+1}',font=FONT,fill='#344539')
    im.save(OUT/name)

def idle():
    data={}
    for direction in ['front','right']:data[direction]=register_idle(direction)
    data['left']=[im.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for im in data['right']]
    P.sheet(OUT/'left_idle_preview','left_idle',data['left'],2)
    for direction in ['back']:
        shutil.copytree(OLD/f'{direction}_idle_preview',OUT/f'{direction}_idle_preview',dirs_exist_ok=True)
        data[direction]=frames(direction,'idle')
    contact('idle_feet_before_after.png',[(f'{di} v04',frames(di,'idle')) for di in ['front','right']]+[(f'{di} v05',data[di]) for di in ['front','right']])
    metrics={}
    for di in ['front','right']:
        metrics[di]={}
        for label,fs in [('v04',frames(di,'idle')),('v05',data[di])]:
            metrics[di][label]={
                'bothBoots':[P.residual(fs[0],f,96,115) for f in fs],
                'lowerLegs':[P.residual(fs[0],f,85,115) for f in fs],
                'head':[P.residual(fs[0],f,19,49) for f in fs]}
    save('idle_registration_diagnostic.json',metrics)
    print(json.dumps(metrics))

if __name__=='__main__':idle()
