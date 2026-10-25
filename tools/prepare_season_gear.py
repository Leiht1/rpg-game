from PIL import Image
import numpy as np,json,hashlib
from pathlib import Path
out=Path('assets/season_gear/v1');out.mkdir(parents=True,exist_ok=True)
src=Image.open('art/season-gear-v1/equipment-source.png').convert('RGBA')
def clean(im):
 a=np.array(im);a[a[:,:,3]<24]=0;im=Image.fromarray(a);return im.crop(im.getbbox())
parts={}
for r,(id,y0,y1) in enumerate([('wool_hat',0,300),('straw_hat',300,540),('wool_sweater',540,805),('straw_raincoat',805,1086)]):
 for c,view in enumerate(['front','back','side']):
  im=clean(src.crop(([0,483,966][c],y0,[483,966,1448][c],y1)));parts[id,view]=im
  canvas=Image.new('RGBA',(im.width+16,im.height+16));canvas.alpha_composite(im,(8,8));canvas.save(out/f'{id}-{view}.png')
  if c==0:
   icon=im.copy();icon.thumbnail((112,112));cv=Image.new('RGBA',(128,128));cv.alpha_composite(icon,((128-icon.width)//2,(128-icon.height)//2));cv.save(out/f'{id}-icon.png')
# Torso replacements preserve source rig canvas, hand/leg geometry is untouched.
for view in ['front','back','side']:
 native='side' if view=='side' else 'front';size=Image.open(f'assets/hero/cartoon/art/{native}_torso.png').size
 im=parts['wool_sweater','back' if view=='side' else view].resize(size,Image.Resampling.LANCZOS);im.save(out/f'wool_sweater-{view}-torso.png')
 cape=parts['straw_raincoat',view];cape=cape.resize((int(size[0]*1.38),int(size[1]*1.06)),Image.Resampling.LANCZOS);cape.save(out/f'straw_raincoat-{view}-torso.png')
 sleeve=clean(Image.open('art/season-gear-v1/sleeve-source.png').convert('RGBA')).resize((30,86),Image.Resampling.LANCZOS)
 arm=Image.open(f'assets/hero/cartoon/art/{native}_arm.png').convert('RGBA');cv=Image.new('RGBA',arm.size);cv.alpha_composite(arm.crop((0,82,32,100)),(0,82));cv.alpha_composite(sleeve,(1,0));cv.save(out/f'wool_sweater-{view}-arm.png')
# Side revisions are registered to the upright scalp, not to a tilted hat bounding box.
side=Image.open('art/season-gear-v1/side-hats-source-v2.png').convert('RGBA')
for id,y0,y1 in [('wool_hat',0,800),('straw_hat',800,1536)]:
 im=clean(side.crop((0,y0,side.width,y1)))
 if id=='wool_hat':im=clean(im.rotate(-7,resample=Image.Resampling.BICUBIC,expand=True))
 cv=Image.new('RGBA',(im.width+16,im.height+16));cv.alpha_composite(im,(8,8));cv.save(out/f'{id}-side.png')
# Low, broad beanie revision: crop by actual ownership gaps rather than equal thirds.
wool=Image.open('art/season-gear-v1/wool-hats-source-v4.png').convert('RGBA')
for i,view in enumerate(['front','back','side']):
 edges=[0,725,1430,2091];im=clean(wool.crop((edges[i],0,edges[i+1],wool.height)));cv=Image.new('RGBA',(im.width+16,im.height+16));cv.alpha_composite(im,(8,8));cv.save(out/f'wool_hat-{view}.png')
im=Image.open(out/'wool_hat-front.png').convert('RGBA');im=im.crop(im.getbbox());im.thumbnail((112,112));cv=Image.new('RGBA',(128,128));cv.alpha_composite(im,((128-im.width)//2,(128-im.height)//2));cv.save(out/'wool_hat-icon.png')
# Fixed eye-level straw art: preserve source aspect ratio and split the far rim.
new_straw=Image.open('art/season-gear-v1/straw-hats-source-v3.png').convert('RGBA')
for i,view in enumerate(['front','back','side']):
 im=clean(new_straw.crop((i*724,0,(i+1)*724,new_straw.height)));cv=Image.new('RGBA',(im.width+16,im.height+16));cv.alpha_composite(im,(8,8));cv.save(out/f'straw_hat-{view}.png')
for view in ['front','back','side']:
 im=Image.open(out/f'straw_hat-{view}.png').convert('RGBA');a=np.array(im);h,w=a.shape[:2];yy,xx=np.indices((h,w))
 foreground=((xx>w*.18)&(xx<w*.82))|(yy>=h*.90)
 fore=a.copy();rear=a.copy();fore[~foreground]=0;rear[foreground]=0
 Image.fromarray(fore).save(out/f'straw_hat-{view}-foreground.png');Image.fromarray(rear).save(out/f'straw_hat-{view}-rear.png')
front=Image.open(out/'straw_hat-front.png').convert('RGBA');icon=front.crop(front.getbbox());icon.thumbnail((112,112));cv=Image.new('RGBA',(128,128));cv.alpha_composite(icon,((128-icon.width)//2,(128-icon.height)//2));cv.save(out/'straw_hat-icon.png')
# Per-column lower contour is geometry data for reversible hair clipping.
for id in ['wool_hat','straw_hat']:
 for view in ['front','back','side']:
  a=np.array(Image.open(out/f'{id}-{view}.png'));h,w=a.shape[:2];profile=np.full((1,w,4),255,dtype=np.uint8)
  for x in range(w):
   ys=np.where(a[:,x,3]>12)[0];value=min(255,int(np.ceil((int(ys[-1])+1)/h*255))) if len(ys) else 255
   profile[0,x,:3]=value
  Image.fromarray(profile).save(out/f'{id}-{view}-join.png')
registry={}
for id in ['wool_hat','straw_hat','wool_sweater','straw_raincoat']:
 registry['clothing:'+id]={'foreground_arms':True} if id in ['wool_sweater','straw_raincoat'] else {}
 for view in ['front','back','side']:
  path=f'res://assets/season_gear/v1/{id}-{view}'
  if id.endswith('hat'):
   width=236 if id=='wool_hat' else 300
   pos=[-10,0] if view=='side' else [0,8 if view=='back' else 3 if id=='straw_hat' else 0]
   if id=='wool_hat':
    rows=[dict(parent='Visual/Pelvis/Head/Sprite',texture=path+'.png',display_width=width,position=pos,band_y=pos[1],mask_texture=path+'.png',join_texture=path+'-join.png',clip_below=pos[1]-6)]
   else:
    rows=[dict(parent='Visual/Pelvis/Head/Sprite',texture=path+'-rear.png',display_width=width,position=pos,band_y=pos[1],behind=True),dict(parent='Visual/Pelvis/Head/Sprite',texture=path+'-foreground.png',display_width=width,position=pos,band_y=pos[1],mask_texture=path+'.png',join_texture=path+'-join.png',clip_below=pos[1]-6)]
  elif id=='wool_sweater':
   rows=[dict(parent='Visual/Pelvis/Torso',texture=path+'-torso.png',replace=True)]+[dict(parent=p,texture=path+'-arm.png',replace=True,skin_region=[.86,1.0]) for p in ['Visual/ArmLBehind','Visual/Pelvis/ArmR/Sprite']]
  else:rows=[dict(parent='Visual/Pelvis/Torso',texture=path+'-torso.png',scale=1.0,position=[0,0])]
  registry['clothing:'+id][view]=rows
Path('data/equipment_visuals.json').write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
files=[dict(path=str(p).replace('\\','/'),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in out.glob('*.png')]
(out/'provenance.json').write_text(json.dumps(dict(art_source='host_image',route='image_gen',model='Built-in image_gen; exact image model revision and subscription cost unavailable',estimateUsd=None,prompts=['art/season-gear-v1/'+n for n in ['equipment-prompt.txt','sleeve-prompt.txt','side-hats-v2-prompt.txt','straw-hats-v3-prompt.txt','wool-hats-v4-prompt.txt']],status='integrated per explicit user task; aesthetic confirmation pending',reference='art/season-gear-v1/reference.png',sources=['art/season-gear-v1/equipment-source.png','art/season-gear-v1/sleeve-source.png','art/season-gear-v1/side-hats-source-v2.png','art/season-gear-v1/straw-hats-source-v3.png','art/season-gear-v1/wool-hats-source-v4.png'],processing='Native alpha trim below24; initial sheet ownership columns0/483/966/1448 rows0/300/540/805/1086; woolV4 ownership0/725/1430/2091; strawV3 thirds724. Final hats use fixed per-view uniform display scale independent of hair, separate far/near rim, per-column lower contour masks; original hair pixels never rewritten. Torso and sleeve LANCZOS registration; original hand pixels retained; side sweater torso uses back sweater material.',files=files),ensure_ascii=False,indent=2),encoding='utf-8')
