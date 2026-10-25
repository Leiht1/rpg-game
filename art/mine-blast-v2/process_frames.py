"""Register preserved ownership-sliced FX on one ground root and remove key tint."""
from pathlib import Path
import json, numpy as np, hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
base=ROOT/'art/mine-blast-v2';out=base/'registered-frames-v3';out.mkdir(exist_ok=True)
# Authored ground-contact samples in the central ignition/debris bed, not full-frame alpha bounds.
roots_y=[362,364,371,378,386,385,385,380,361,364,365,367,317,313,314,312]
timing=[35,40,50,60,70,80,90,100,110,120,130,140,150,160,170,190]
records=[]
for i,src in enumerate(sorted((base/'assembled/frames').glob('*.png'))):
 a=np.array(Image.open(src).convert('RGBA'));rgb=a[:,:,:3].astype(float)
 excess=np.maximum(0,np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]-3)
 stained=(rgb[:,:,0]>rgb[:,:,1]+10)&(rgb[:,:,2]>rgb[:,:,1]+10)&(a[:,:,3]>0)
 for channel in [0,2]:rgb[:,:,channel]=np.where(stained,rgb[:,:,channel]-excess,rgb[:,:,channel])
 a[:,:,:3]=np.clip(rgb,0,255).astype('uint8');a[a[:,:,3]==0,:3]=0
 canvas=Image.new('RGBA',(640,640));offset=(320-209,484-roots_y[i]);canvas.paste(Image.fromarray(a),offset)
 dest=out/f'frame-{i:02d}.png';canvas.save(dest)
 records.append({'frame':i,'ground_root_in_ownership_canvas':[209,roots_y[i]],'translation':list(offset),'despilled_pixels':int(stained.sum()),'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
manifest={'schema':'generate2dsprite.animation_clips.v1','frames':[f'registered-frames-v3/frame-{i:02d}.png' for i in range(16)],'anchor_px':[320,484],'clips':{'blast':{'frames':list(range(16)),'duration_ms':timing,'loop':False}},'art_source':'host_image','placeholder':False,'pixel_art':False,'sampling':'linear'}
(base/'clips-input-v3.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(base/'registration-v3.json').write_text(json.dumps({'canvas':[640,640],'shared_anchor':[320,484],'method':'fixed ownership scale; translate only from measured central ground-contact registration; preserve every detached component and all original frame area','frames':records},indent=2),encoding='utf-8')
print('16 fixed-canvas frames; contact root registered; no per-frame scaling or clipping')
