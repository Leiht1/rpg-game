from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1];ART=OUT.parent
(OUT/'references').mkdir(parents=True,exist_ok=True)
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def render(im,scale,offset,size=512):
    return im.convert('RGBa').transform((size,size),Image.Transform.AFFINE,(1/(scale*size/128),0,-offset[0]/scale,0,1/(scale*size/128),-offset[1]/scale),Image.Resampling.BICUBIC).convert('RGBA')
for di in ['front','back']:
    folder=ART/f'hero_consistency_preview_v04/{di}_walk'
    raw=Image.open(folder/'take1/generated.png').convert('RGBA');meta=json.loads((folder/'normalization.json').read_text(encoding='utf-8'))
    sheet=Image.new('RGBA',(2048,1024));hs=[]
    for i,t in enumerate(meta['transforms']):
        hi=render(raw.crop(t['sourceCell']),t['scale'],t['offsetPx']);hs.append(hi)
        sheet.alpha_composite(hi,(i%4*512,i//4*512))
        hi.save(OUT/f'references/{di}_{i+1:02}.png')
    sheet.save(OUT/f'references/{di}_walk.png')
side=Image.new('RGBA',(2048,1024))
for i in range(8):
    im=Image.open(ART/f'hero_side_refine_preview_v08/registered_high/frame_{i+1:02}.png').convert('RGBA')
    side.alpha_composite(im,(i%4*512,i//4*512))
side.save(OUT/'references/side_pose_targets.png')
master=Image.open(ART/'hero_side_refine_preview_v08/registered_high/frame_01.png').convert('RGBA')
master.save(OUT/'references/side_body_master.png')
turn=Image.new('RGBA',(1536,512))
for i,p in enumerate([OUT/'references/front_01.png',OUT/'references/back_01.png',OUT/'references/side_body_master.png']):turn.alpha_composite(Image.open(p),(i*512,0))
turn.save(OUT/'references/crossview_body_reference.png')
baseline={p.relative_to(ROOT).as_posix():sha(p) for folder in ['assets/hero','scripts','scenes'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix not in ['.import','.uid']}
baseline['project.godot']=sha(ROOT/'project.godot')
if not (OUT/'game_files_before.json').exists():save(OUT/'game_files_before.json',baseline)
save(OUT/'plan.json',{'previewOnly':True,'request':'Repair whole side sequence anatomy and clarity, align with approved front/back','canvas':[128,128],'root':[64,112],'directionFrames':8,'fps':13.8,'sourcePolicy':'Side eight poses in one whole-sheet edit. Front/back from original high-resolution source. Same sampling method and density; one common scale per source sheet. No per-frame size fitting.','bodyMaster':'references/side_body_master.png','crossviewReference':'references/crossview_body_reference.png','referenceDirections':['front','back'],'repairedDirection':'right','left':'whole-frame mirror','preservePoseChanges':['Frame5 modest near/right knee bend','Frame6 far/left hand behind body, only small portion visible'],'runtime':'No game assets, scripts, template or map changes before user confirmation'})
print('Prepared native-source front/back references, complete side pose targets and common-body reference.')
