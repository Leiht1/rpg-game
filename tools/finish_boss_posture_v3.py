"""Extract complete owned cutouts; keep source and previous candidate unchanged."""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageOps
from scipy.ndimage import label, find_objects

source=Path('art/boss-posture-v3/parts-source/generated.png')
im=Image.open(source).convert('RGB'); a=np.asarray(im).astype(float)
mask=np.minimum(a[:,:,0],a[:,:,2])-a[:,:,1]<125
labs,n=label(mask); counts=np.bincount(labs.ravel())
islands=[(i+1,(s[1].start,s[0].start,s[1].stop,s[0].stop)) for i,s in enumerate(find_objects(labs)) if counts[i+1]>300]
assert len(islands)==24,[(i,b,counts[i]) for i,b in islands]
out=Path('prototypes/boss-posture-v3/parts'); records=[]; used=set()
slots=['torso','armor','upper','forearm','fist','thigh','shin','foot']
for row,view in enumerate(['front','back','side']):
    folder=out/view; folder.mkdir(parents=True,exist_ok=True)
    for col,slot in enumerate(slots):
        cx=(col+.5)*im.width/8;cy=(row+.5)*im.height/3
        index,box=min(islands,key=lambda p:((p[1][0]+p[1][2])/2-cx)**2+((p[1][1]+p[1][3])/2-cy)**2)
        assert index not in used,(view,slot);used.add(index)
        rgb=a[box[1]:box[3],box[0]:box[2]]
        excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
        alpha=np.clip(1-excess/200,0,1);alpha[excess<15]=1;alpha[excess>160]=0
        # Ownership contains the complete part, never a proximal fraction.
        rgba=np.zeros((*alpha.shape,4),dtype=np.uint8)
        for c,key in enumerate([255,0,255]):rgba[:,:,c]=np.clip((rgb[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255)
        rgba[:,:,3]=(alpha*255).astype(np.uint8);rgba[alpha==0]=0
        part=Image.fromarray(rgba)
        names=[slot] if slot in ['torso','armor'] else ['left_'+slot,'right_'+slot]
        for name in names:
            # Frontal paired thumb/toe direction; profiles remain pointed right.
            paired=ImageOps.mirror(part) if name.startswith('right_') and view!='side' else part
            path=folder/(name+'.png');paired.save(path)
            records.append(dict(view=view,slot=name,source=str(source),ownership=box,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    for slot in ['head','core']:
        old=Path('prototypes/boss-posture-v2/parts')/view/(slot+'.png');dest=folder/old.name;dest.write_bytes(old.read_bytes())
        records.append(dict(view=view,slot=slot,source=str(old),sha256=hashlib.sha256(dest.read_bytes()).hexdigest()))
(out/'provenance.json').write_text(json.dumps(dict(approval='pending_user',route='local:codex-cli',source=str(source),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),reference='art/boss-posture-v2/master-corrected/generated.png',prompt='art/boss-posture-v3/parts-prompt.txt',notes=['Controlled necessary-part silhouette revision, same identity and joint lengths','Full owned source silhouettes, uniform sprite scaling only','Head and unused core retained byte-for-byte; embedded chest crystal belongs to torso'],parts=records),ensure_ascii=False,indent=2),encoding='utf8')
board=Image.new('RGB',(1280,900),'#69756e');d=ImageDraw.Draw(board)
for i,r in enumerate(records):
    p=Image.open(out/r['view']/(r['slot']+'.png'));p.thumbnail((145,110));x=i%8*160;y=i//8*150
    board.paste(p,(x+(160-p.width)//2,y),p);d.text((x+3,y+118),r['view']+' '+r['slot'],fill='white')
board.save('reports/boss-posture-v3/parts.png')
print('Extracted',len(records),'complete cutouts')
