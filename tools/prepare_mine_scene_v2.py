"""Finish generated sprites; wall closeups sample the unchanged real cave backdrop."""
from pathlib import Path
from PIL import Image,ImageFilter,ImageDraw
import numpy as np,json,hashlib
src=Path('art/mine-scene-v2/generated/generated.png');im=Image.open(src).convert('RGBA')
out=Path('assets/exploration/mine-scene-v2');out.mkdir(parents=True,exist_ok=True)
a=np.array(im);rgb=a[:,:,:3].astype(float)
excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
alpha=1-np.clip(excess/255,0,1)
alpha[excess<12]=1;alpha[excess>150]=0
for c,key in [(0,255),(1,0),(2,255)]:a[:,:,c]=np.clip((rgb[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255).astype('uint8')
a[:,:,3]=(alpha*255).astype('uint8');a[alpha==0]=0
sheet=Image.fromarray(a)
files=['glyph-0','glyph-1','glyph-2','glyph-3','etch-0','etch-1','etch-2','etch-3','lamp','chest-closed','chest-open','rubble']
qa=[]
for i,name in enumerate(files):
 x=i%4*im.width//4;y=i//4*im.height//3;w=im.width//4;h=im.height//3
 cell=sheet.crop((x,y,x+w,y+h));bbox=cell.getbbox()
 assert bbox,(name,'empty')
 qa.append({'file':name,'alpha_bbox':bbox,'cell':[w,h],'edge_touch':bbox[0]==0 or bbox[1]==0 or bbox[2]==w or bbox[3]==h})
 # Chest pair shares its original fixed cell, source scale and base anchor.
 if not name.startswith('chest-'):cell=cell.crop((max(0,bbox[0]-4),max(0,bbox[1]-4),min(w,bbox[2]+4),min(h,bbox[3]+4)))
 cell.save(out/(name+'.png'))
# Separate along the painted rock seams, preserving one common source canvas.
heap=Image.open(out/'rubble.png').convert('RGBA');hw,hh=heap.size
assert (hw,hh)==(338,179)
polygons=[[(81,75),(104,31),(146,5),(174,17),(193,61),(168,76),(149,105),(139,99),(115,92),(103,95)],[(145,108),(163,76),(194,59),(241,69),(272,93),(281,119),(269,135),(244,141),(233,154),(189,160),(150,146),(145,127)],[(16,121),(35,103),(43,82),(68,62),(96,76),(105,92),(87,108),(72,135),(62,143),(44,136),(32,144)],[(65,145),(78,115),(93,102),(115,92),(139,99),(146,123),(125,140),(115,159),(93,153)],[(176,27),(203,27),(221,48),(237,50),(251,73),(240,73),(195,63)],[(268,95),(291,94),(309,119),(334,138),(316,151),(299,143),(288,154),(251,157),(245,140),(269,131),(281,120)],[(112,156),(119,143),(135,135),(153,149),(161,165),(145,174),(124,172)],[(162,148),(190,162),(228,156),(242,146),(259,154),(249,172),(216,177),(197,166),(171,172)]]
owner=np.full((hh,hw),-1,dtype=int);centers=[]
for i,poly in enumerate(polygons):
 mask=Image.new('L',(hw,hh));ImageDraw.Draw(mask).polygon(poly,fill=255);m=np.array(mask)>0;owner[m&(owner<0)]=i;centers.append(np.mean(poly,axis=0))
yy,xx=np.mgrid[0:hh,0:hw];distance=np.stack([(xx-cx)**2+(yy-cy)**2 for cx,cy in centers]);nearest=distance.argmin(axis=0);owner[owner<0]=nearest[owner<0]
ha=np.array(heap);reconstructed=np.zeros_like(ha)
for i in range(8):
 part=ha.copy();part[owner!=i]=0;Image.fromarray(part).save(out/f'heap-part-{i}.png');reconstructed=np.maximum(reconstructed,part)
qa.append({'file':'heap-parts','partition':'painted rock seam polygons; source canvas retained','recomposition_difference_pixels':int(np.any(ha!=reconstructed,axis=2).sum())})
assert np.array_equal(ha,reconstructed)
# Retain the already generated blue ore identity; only redo its faulty old matte.
old=Image.open('art/mine-puzzle-v1/generated/generated.png').convert('RGBA');oa=np.array(old);rgb=oa[:,:,:3].astype(float)
excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
alpha=1-np.clip(excess/255,0,1);alpha[excess<12]=1;alpha[excess>150]=0
for c,key in [(0,255),(1,0),(2,255)]:oa[:,:,c]=np.clip((rgb[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255).astype('uint8')
oa[:,:,3]=(alpha*255).astype('uint8');oa[alpha==0]=0;old=Image.fromarray(oa)
for name,row in [('ore',0),('crystal',3)]:
 part=old.crop((old.width//2,row*old.height//4,old.width,(row+1)*old.height//4));part=part.crop(part.getbbox())
 if name=='ore':
  part.thumbnail((232,224),Image.Resampling.LANCZOS);cv=Image.new('RGBA',(256,256));cv.alpha_composite(part,((256-part.width)//2,248-part.height));part=cv
 part.save(out/(name+'.png'))
bg=Image.open('assets/exploration/mine-v1/interior.png').convert('RGBA')
walls=[(-440,-417),(-40,-417),(440,-417),(-850,-70),(850,10)]
for i,(wx,wy) in enumerate(walls):
 cx=round(bg.width/2+wx*bg.width/2000);cy=round(bg.height/2+wy*bg.width/2000)
 region=(max(0,cx-87),max(0,cy-65),min(bg.width,cx+87),min(bg.height,cy+65))
 near=bg.crop(region).resize((1120,832),Image.Resampling.LANCZOS)
 if i<4:
  etch=Image.open(out/f'etch-{i}.png');etch.thumbnail((630,430),Image.Resampling.LANCZOS)
  # Carved lines remain a transparent overlay on the actual sampled wall.
  near.alpha_composite(etch,(110+(630-etch.width)//2,105+(430-etch.height)//2))
  glyph=Image.open(out/f'glyph-{i}.png');glyph.thumbnail((162,162),Image.Resampling.LANCZOS)
  near.alpha_composite(glyph,(830+(162-glyph.width)//2,230+(162-glyph.height)//2))
 yy,xx=np.mgrid[0:832,0:1120]
 distance=np.minimum(np.minimum(xx,1119-xx),np.minimum(yy,831-yy))
 mask=np.clip(distance/72,0,1);data=np.array(near);data[:,:,3]=(mask*255).astype('uint8')
 Image.fromarray(data).save(out/('closeup-'+(str(i) if i<4 else 'main')+'.png'))
 qa.append({'file':'closeup-'+str(i),'source_region':region,'source':'assets/exploration/mine-v1/interior.png'})
prov={'art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','estimateUsd':0,'source':str(src),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'plan':{'camera':'same existing cave slight overhead','lamp_width':76,'chest_width':94,'heap_width':410,'wall_hotspot_width':48,'closeup':'actual original backdrop crop + same incisions and glyph; soft edges; no separate wall slab'},'processing':'4x3 ownership; soft magenta key and unmix; shared chest cells; immutable backdrop sampling','files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.png')},'approval':'Requested scene rework; no claim of user approval of these exact PNGs'}
(out/'provenance.json').write_text(json.dumps(prov,ensure_ascii=False,indent=2),encoding='utf-8')
Path('art/mine-scene-v2/qa.json').write_text(json.dumps(qa,indent=2),encoding='utf-8')
assert not any(q.get('edge_touch') for q in qa),'source cell spill'
