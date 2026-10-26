"""Finish the V2 cutout atlas; source pixels only, no generated geometry."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image,ImageDraw
from scipy.ndimage import label,find_objects

source=Path('art/boss-posture-v2/parts-source/generated.png')
im=Image.open(source).convert('RGB')
raw=np.array(im).astype(float)
source_labels,component_count=label(np.minimum(raw[:,:,0],raw[:,:,2])-raw[:,:,1]<130)
component_sizes=np.bincount(source_labels.ravel())
components=[(i+1,(b[1].start,b[0].start,b[1].stop,b[0].stop)) for i,b in enumerate(find_objects(source_labels)) if component_sizes[i+1]>300]
assert len(components)==48,len(components)
used=set()
slots=['torso','head','left_upper','left_forearm','left_fist','right_upper','right_forearm','right_fist','left_thigh','left_shin','left_foot','right_thigh','right_shin','right_foot','armor','core']
out=Path('prototypes/boss-posture-v2/parts')
records=[]
for v,view in enumerate(['front','back','side']):
    folder=out/view;folder.mkdir(parents=True,exist_ok=True)
    for i,slot in enumerate(slots):
        col=i%8;row=v*2+i//8
        columns=[0,235,406,596,778,962,1153,1341,1536]
        rows=[0,201,365,544,697,854,1024]
        expected=(columns[col],rows[row],columns[col+1],rows[row+1])
        cx=(expected[0]+expected[2])/2;cy=(expected[1]+expected[3])/2
        component_id,owned=min(components,key=lambda p:((p[1][0]+p[1][2])/2-cx)**2+((p[1][1]+p[1][3])/2-cy)**2)
        assert component_id not in used,(view,slot,component_id)
        used.add(component_id)
        box=(max(0,owned[0]-2),max(0,owned[1]-2),min(im.width,owned[2]+2),min(im.height,owned[3]+2))
        rgb=np.array(im.crop(box)).astype(float)
        excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
        alpha=np.clip(1-excess/200,0,1);alpha[excess<15]=1;alpha[excess>160]=0
        rgba=np.zeros((*alpha.shape,4),dtype='uint8')
        for c,key in enumerate([255,0,255]):rgba[:,:,c]=np.clip((rgb[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255)
        rgba[:,:,3]=(alpha*255).astype('uint8')
        labels,count=label(alpha>.12)
        assert count,(view,slot)
        sizes=np.bincount(labels.ravel());sizes[0]=0
        keep=labels==sizes.argmax();rgba[~keep]=0
        part=Image.fromarray(rgba);bounds=part.getbbox();assert bounds
        part=part.crop(bounds)
        # The source adds a second joint stone below these owned limb blocks.
        # Keep the proximal solid rock; the next real bone owns the joint overlap.
        if slot.endswith('_upper'):part=part.crop((0,0,part.width,round(part.height*.63)))
        if slot.endswith('_thigh'):part=part.crop((0,0,part.width,round(part.height*.79)))
        if slot.endswith('_shin'):part=part.crop((0,0,part.width,round(part.height*.61)))
        if view=='front' and slot=='core':
            gem=np.array(part);colors=gem[:,:,:3].astype(float)
            cyan=(colors[:,:,1]>colors[:,:,0]*1.3)&(colors[:,:,2]>colors[:,:,0]*1.3)&(colors[:,:,1]>80)
            gem[~cyan]=0;part=Image.fromarray(gem);part=part.crop(part.getbbox())
        path=folder/(slot+'.png');part.save(path)
        records.append(dict(view=view,slot=slot,ownership=box,bounds=bounds,size=part.size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
armor_source=Path('art/boss-posture-v2/armor-source/generated.png')
armor_image=Image.open(armor_source).convert('RGB')
for i,view in enumerate(['front','back','side']):
    edges=[0,540,1120,1536]
    box=(edges[i],0,edges[i+1],1024)
    rgb=np.array(armor_image.crop(box)).astype(float)
    excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
    alpha=np.clip(1-excess/200,0,1);alpha[excess<15]=1;alpha[excess>160]=0
    rgba=np.zeros((*alpha.shape,4),dtype='uint8')
    for c,key in enumerate([255,0,255]):rgba[:,:,c]=np.clip((rgb[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255)
    rgba[:,:,3]=(alpha*255).astype('uint8');rgba[alpha==0]=0
    part=Image.fromarray(rgba);bounds=part.getbbox();part=part.crop(bounds)
    path=out/view/'armor.png';part.save(path)
    record=next(r for r in records if r['view']==view and r['slot']=='armor')
    record.update(source=str(armor_source),ownership=box,bounds=bounds,size=part.size,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
correction_source=Path('art/boss-posture-v2/anatomy-corrected/generated.png')
corrected=Image.open(correction_source).convert('RGB')
rgb_all=np.array(corrected).astype(float)
labels,number=label(np.minimum(rgb_all[:,:,0],rgb_all[:,:,2])-rgb_all[:,:,1]<130)
sizes=np.bincount(labels.ravel())
islands=[(i+1,(b[1].start,b[0].start,b[1].stop,b[0].stop)) for i,b in enumerate(find_objects(labels)) if sizes[i+1]>300]
assert len(islands)==18,len(islands)
correction_slots=['torso','head','left_foot','right_foot','left_fist','right_fist']
used=set()
for row,view in enumerate(['front','back','side']):
    for col,slot in enumerate(correction_slots):
        cx=(col+.5)*corrected.width/6;cy=(row+.5)*corrected.height/3
        component_id,box=min(islands,key=lambda p:((p[1][0]+p[1][2])/2-cx)**2+((p[1][1]+p[1][3])/2-cy)**2)
        assert component_id not in used,(view,slot)
        used.add(component_id)
        rgb=rgb_all[box[1]:box[3],box[0]:box[2]]
        excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
        alpha=np.clip(1-excess/200,0,1);alpha[excess<15]=1;alpha[excess>160]=0
        alpha[labels[box[1]:box[3],box[0]:box[2]]!=component_id]=0
        rgba=np.zeros((*alpha.shape,4),dtype='uint8')
        for c,key in enumerate([255,0,255]):rgba[:,:,c]=np.clip((rgb[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255)
        rgba[:,:,3]=(alpha*255).astype('uint8');rgba[alpha==0]=0
        part=Image.fromarray(rgba);path=out/view/(slot+'.png');part.save(path)
        record=next(r for r in records if r['view']==view and r['slot']==slot)
        record.update(source=str(correction_source),ownership=box,bounds=(0,0,part.width,part.height),size=part.size,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
board=Image.new('RGB',(1200,840),'#68716b');draw=ImageDraw.Draw(board)
for n,rec in enumerate(records):
    part=Image.open(out/rec['view']/(rec['slot']+'.png'));part.thumbnail((130,110))
    x=n%8*150;y=n//8*140
    board.paste(part,(x+(150-part.width)//2,y+8),part);draw.text((x+4,y+120),rec['view']+' '+rec['slot'],fill='white')
board.save('reports/boss-posture-v2/parts.png')
provenance=dict(art_source='host_image',route='local:codex-cli',model='codex-image_gen',source=str(source),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),armor_source=str(armor_source),armor_sha256=hashlib.sha256(armor_source.read_bytes()).hexdigest(),master='art/boss-posture-v2/master-corrected/generated.png',prompt='art/boss-posture-v2/parts-prompt.txt',approval='pending_user',parts=records,notes=['whole master is reference only; rig displays independent cutouts','common bone lengths and anchor sizes across all views','owned atlas cells chroma-keyed, largest connected art island retained; source saved unchanged','upperarm 63%, thigh 79%, shin 61% proximal silhouette retained to exclude duplicate distal joint stones; true elbow/knee supplied by hierarchy','generated collar rejected; independent solid shoulder slabs used instead'])
provenance.update(correction_source=str(correction_source),correction_sha256=hashlib.sha256(correction_source.read_bytes()).hexdigest(),correction_prompt='art/boss-posture-v2/anatomy-correction-prompt.txt')
provenance['notes'].append('2026-10-26 user rejected feet, compact torso, back hand layers, armor alignment, side face occlusion and extraction residue; 18 torso/head/foot/fist parts corrected, full connected-source silhouettes extracted instead of fixed grids')
provenance['notes'].append('front cyan core keyed separately from old bezel; installed behind new torso at the actual socket center (source hole 82,57,178,155 on 260x284 torso), avoiding double rim or empty black socket')
(out/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
print('V2: 48 independent parts; pending visual assembly review')
