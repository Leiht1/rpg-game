from pathlib import Path
from PIL import Image,ImageOps
import json,hashlib
import numpy as np
from scipy.ndimage import label,find_objects,binary_opening,binary_dilation
root=Path('prototypes/boss-beasts-v1'); (root/'assets').mkdir(exist_ok=True)
# Compose original character at the actual tscn rest transforms (4x density).
hero=Image.new('RGBA',(512,512))
def paste(name,x,y):
 p=Image.open('assets/hero/cartoon/art/'+name+'.png').convert('RGBA'); hero.alpha_composite(p,(round(x*4-p.width/2),round(y*4-p.height/2)))
paste('front_arm',53,84.5)
for x in [59,69]:paste('front_leg',x,102)
paste('front_torso',64,83);paste('front_head',64,51.5);paste('front_arm',75,84.5)
box=hero.getbbox();hero.crop(box).save(root/'assets/player.png');print('Hero logical visible height',(box[3]-box[1])/4)
records=[]
for kind,cols in [('bear',10),('wolf',11)]:
 src=Path('art/boss-beasts-v1')/(kind+'-source-retry/generated.png')
 if not src.exists():continue
 im=Image.open(src).convert('RGB');rgb=np.asarray(im).astype(float);ex=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
 mask=binary_opening(ex<100,structure=np.ones((4,4)));labs,n=label(mask);counts=np.bincount(labs.ravel()); islands=[(i+1,(s[1].start,s[0].start,s[1].stop,s[0].stop)) for i,s in enumerate(find_objects(labs)) if counts[i+1]>400]
 print(kind,im.size,'islands',len(islands));used=set()
 names=['torso','head','neck','shoulder','fore_upper','fore_lower','fore_paw','hip','hind_lower','hind_paw','tail'][:cols]
 for row,view in enumerate(['front','back','side']):
  folder=root/'assets'/kind/view;folder.mkdir(parents=True,exist_ok=True)
  owned=sorted([z for z in islands if row*im.height/3 < (z[1][1]+z[1][3])/2 < (row+1)*im.height/3],key=lambda z:z[1][0])
  if kind=='bear' and view=='front':owned.pop(7) # model added a redundant forepaw; kept in raw source.
  assert len(owned)==cols,(kind,view,len(owned))
  for col,name in enumerate(names):
   idx,b=owned[col]
   if kind=='wolf' and name in ['fore_upper','hip','fore_lower','hind_lower']:
    # Model supplied distal extensions; preserve the complete proximal muscle as the owned upper bone.
    b=(b[0],b[1],b[2],round(b[1]+(b[3]-b[1])*({'fore_upper':.63,'hip':.77,'fore_lower':.80,'hind_lower':.80}[name])))
   x0,y0,x1,y1=b; a=rgb[y0:y1,x0:x1];e=ex[y0:y1,x0:x1];alpha=np.clip(1-e/180,0,1);alpha[e<20]=1;alpha[e>145]=0
   owned_mask=binary_dilation(labs[y0:y1,x0:x1]==idx,iterations=3);alpha[~owned_mask]=0
   out=np.zeros((*alpha.shape,4),dtype=np.uint8)
   for c,key in enumerate([255,0,255]):out[:,:,c]=np.clip((a[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255)
   out[:,:,3]=(alpha*255).astype('uint8');out[alpha==0]=0
   path=folder/(name+'.png');part=Image.fromarray(out)
   if kind=='wolf' and view=='side' and name=='tail':part=ImageOps.mirror(part)
   part.save(path)
   records.append(dict(kind=kind,view=view,part=name,ownership=b,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
(root/'assets/provenance.json').write_text(json.dumps(dict(approval='pending_user',route='local:codex-cli',parts=records,hero=dict(source='assets/hero/cartoon/character.tscn',visible_height=(box[3]-box[1])/4),animation='hierarchical cutout rig with two bone IK, user requested; no generated motion frames'),indent=2),encoding='utf8')



# Targeted head revision from built-in imagegen, preserving all source/body PNGs.
head_source=Path('art/boss-beasts-v1/bear-head-host/generated.png')
if head_source.exists():
 im=Image.open(head_source).convert('RGB');rgb=np.asarray(im).astype(float);ex=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1]
 ls,n=label(binary_opening(ex<100,structure=np.ones((4,4))));ct=np.bincount(ls.ravel());boxes=sorted([s for i,s in enumerate(find_objects(ls)) if ct[i+1]>1000],key=lambda s:s[1].start)
 assert len(boxes)==3
 for view,sl in zip(['front','back','side'],boxes):
  a=rgb[sl];e=ex[sl];alpha=np.clip(1-e/180,0,1);alpha[e<20]=1;alpha[e>145]=0;out=np.zeros((*alpha.shape,4),dtype=np.uint8)
  for c,key in enumerate([255,0,255]):out[:,:,c]=np.clip((a[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255)
  out[:,:,3]=(alpha*255).astype('uint8');out[alpha==0]=0;path=root/'assets/bear'/view/'head.png';Image.fromarray(out).save(path)
  for rec in records:
   if rec['kind']=='bear' and rec['view']==view and rec['part']=='head':rec.update(source=str(head_source),route='host_image:imagegen',ownership=[sl[1].start,sl[0].start,sl[1].stop,sl[0].stop],sha256=hashlib.sha256(path.read_bytes()).hexdigest())
 data=json.loads((root/'assets/provenance.json').read_text(encoding='utf8'));data['parts']=records;data['source_notes']=['Source atlas is 1774x887, not requested 3072x1536; ownership follows actual parts, not equal cells.','Bear front atlas contains an unused extra forepaw. Thin grid lines removed by component ownership.','Wolf upper thigh and foreleg sources include distal extensions; proximal ownership is recorded per part.','Bear head-only revision uses built-in imagegen after local CLI returned TOOL_UNAVAILABLE; model exact revision unknown.'];(root/'assets/provenance.json').write_text(json.dumps(data,indent=2),encoding='utf8')


