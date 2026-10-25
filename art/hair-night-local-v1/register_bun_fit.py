from pathlib import Path
from PIL import Image, ImageOps
import numpy as np,json,hashlib
base=Path('art/hair-night-local-v1');out=Path('prototypes/hair-night-local-v1')
im=Image.open(base/'bun-fitted-keyed/raw-sheet-clean.png').convert('RGBA')
records=[]
for col,view in enumerate(['front','back','side']):
    cell=im.crop((512*col,0,512*(col+1),1024));a=np.array(cell).astype(float)
    cyan=(np.minimum(a[:,:,1],a[:,:,2])-a[:,:,0]>60)&(a[:,:,3]>16)
    yy,xx=np.where(cyan)
    # Use the fitting mannequin's ears/chin, never the hair or bun outer box.
    cyan_box=(int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1))
    scale=.445
    if view!='side':
        scale=196/(cyan_box[2]-cyan_box[0]);target_x=180;source_x=(cyan_box[0]+cyan_box[2])/2
    else:
        target_x=273;source_x=cyan_box[2]
    source_y=cyan_box[3];target_y=310
    # Remove the cyan fitting mannequin and its antialias; retain only generated dark hair.
    dominance=np.maximum(0,np.minimum(a[:,:,1],a[:,:,2])-a[:,:,0])
    key_alpha=np.clip((45-dominance)/30,0,1)
    a[:,:,3]*=key_alpha
    fringe=dominance>3
    a[:,:,1][fringe]=np.minimum(a[:,:,1][fringe],a[:,:,0][fringe]+2)
    a[:,:,2][fringe]=np.minimum(a[:,:,2][fringe],a[:,:,0][fringe]+2)
    a[a[:,:,3]<4]=0
    clean=Image.fromarray(a.astype('uint8'),'RGBA')
    clean.save(base/f'bun-{view}-hair-only-source.png')
    # One affine fit per complete view, anchored to the original head's chin.
    tx=target_x-source_x*scale;ty=target_y-source_y*scale
    canvas=clean.transform((360,440),Image.Transform.AFFINE,(1/scale,0,-tx/scale,0,1/scale,-ty/scale),Image.Resampling.BICUBIC)
    canvas.save(out/f'unisex_bun-{view}.png')
    if view=='side':
        ImageOps.mirror(canvas).save(out/'unisex_bun-left.png');canvas.save(out/'unisex_bun-right.png')
    records.append({'view':view,'cyan_head_bbox':cyan_box,'scale_from_head':scale,'source_anchor':[source_x,source_y],'target_anchor':[target_x,target_y],'transform':[tx,ty],'hair_alpha_bbox':canvas.getbbox()})
(base/'bun-head-registration.json').write_text(json.dumps(records,indent=2),encoding='utf-8',newline='\n')
p=base/'correction-provenance.json';d=json.loads(p.read_text(encoding='utf-8'));d['jobs'].append('bun-fitted-generated/job.json');d['bun_registration']='bun-head-registration.json';d['sha256'].update({str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('unisex_bun*.png')});p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8',newline='\n')
print(records)
