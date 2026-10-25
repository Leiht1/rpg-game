"""Reference lamp: immutable stone + edited chamber. Eight whole generated rocks."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
import numpy as np,json,hashlib
OUT=Path('assets/exploration/mine-lamps-rocks-v3');OUT.mkdir(parents=True,exist_ok=True)
ref=Image.open('art/mine-lamps-rocks-v3/lamp-user-reference.png').convert('RGBA')
reference_rgba=np.array(ref)
# The supplied transparent reference still contains its old magenta key fringe.
# Remove only contaminated pixels, before deriving every on/off lamp variant.
clean_rgba=reference_rgba.copy();colour=clean_rgba[:,:,:3].astype(int)
purple=(np.minimum(colour[:,:,0],colour[:,:,2])-colour[:,:,1]>8)&(clean_rgba[:,:,3]>0)
clean_rgba[purple]=0
clean_rgba[clean_rgba[:,:,3]==0]=0
ref=Image.fromarray(clean_rgba)
edit=Image.open('art/mine-lamps-rocks-v3/lamp-unlit/generated.png').convert('RGBA')
off=ref.copy()
# Only the chamber openings are edited. The stone colour stays the user image.
chamber_mask=Image.new('L',ref.size)
for box,region in [((140,66,180,94),(699,347,900,457)),((104,72,114,93),(703,350,739,425))]:
 crop=edit.crop(region).resize((box[2]-box[0],box[3]-box[1]),Image.Resampling.LANCZOS)
 off.alpha_composite(crop,(box[0],box[1]));ImageDraw.Draw(chamber_mask).rectangle((box[0],box[1],box[2]-1,box[3]-1),fill=255)
qa=[{'id':'lamp_magenta_fringe_cleanup','visible_purple_pixels_before':int(purple.sum()),'visible_purple_pixels_after':0,'unchanged_non_fringe_pixels':bool(np.array_equal(reference_rgba[~purple],np.array(ref)[~purple]))}]
for i in range(4):
 glyph=Image.open(f'assets/exploration/mine-scene-v2/glyph-{i}.png').convert('RGBA');glyph.thumbnail((51,51),Image.Resampling.LANCZOS)
 # Engraved bevel is the same actual generated glyph as the investigation view.
 g=np.array(glyph);g[:,:,:3]=(g[:,:,:3].astype(float)*.73).astype('uint8');glyph=Image.fromarray(g)
 where=(161-glyph.width//2,151-glyph.height//2)
 states=[]
 for name,base in [('off',off),('on',ref)]:
  lamp=base.copy();lamp.alpha_composite(glyph,where);lamp.save(OUT/f'lamp-{i}-{name}.png');states.append(np.array(lamp))
  pixels=np.array(lamp);col=pixels[:,:,:3].astype(int);remaining=int(((np.minimum(col[:,:,0],col[:,:,2])-col[:,:,1]>8)&(pixels[:,:,3]>0)).sum());assert remaining==0,(i,name,remaining)
  qa.append({'id':f'lamp_{i}_{name}_purple_pixels','visible_purple_pixels':remaining})
 diff=np.any(states[0]!=states[1],axis=2)
 unchanged=int((diff&(np.array(chamber_mask)==0)).sum());assert unchanged==0
 qa.append({'id':'lamp_body_unchanged_'+str(i),'changed_pixels_outside_light_chambers':unchanged,'state_difference_pixels':int(diff.sum()),'glyph_center':[161,151],'glyph_bounds':[where[0],where[1],glyph.width,glyph.height]})
sheet=Image.open('art/mine-lamps-rocks-v3/rocks/generated.png').convert('RGBA');a=np.array(sheet);rgb=a[:,:,:3].astype(float)
excess=np.minimum(rgb[:,:,0],rgb[:,:,2])-rgb[:,:,1];alpha=1-np.clip(excess/255,0,1);alpha[excess<12]=1;alpha[excess>150]=0
for c,key in [(0,255),(1,0),(2,255)]:a[:,:,c]=np.clip((rgb[:,:,c]-key*(1-alpha))/np.maximum(alpha,.001),0,255).astype('uint8')
a[:,:,3]=(alpha*255).astype('uint8');a[alpha==0]=0;sheet=Image.fromarray(a)
# Actual source gutters, not a forced equal grid that would crop rock 0.
xs=[0,490,900,1300,1774];ys=[0,450,887]
for i in range(8):
 region=(xs[i%4],ys[i//4],xs[i%4+1],ys[i//4+1]);cell=sheet.crop(region);bbox=cell.getbbox();assert bbox
 edge=bbox[0]==0 or bbox[1]==0 or bbox[2]==cell.width or bbox[3]==cell.height
 qa.append({'id':'whole_rock_'+str(i),'source_region':region,'source_bounds':bbox,'source_edge_touch':edge});assert not edge
 cell=cell.crop((max(0,bbox[0]-4),max(0,bbox[1]-4),min(cell.width,bbox[2]+4),min(cell.height,bbox[3]+4)))
 cell.save(OUT/f'rock-{i}.png')
# Back-to-front rest anchors. Every entry is one complete independent rock.
entries=[(1,5,-42,140),(2,-105,-10,125),(4,105,-10,128),(0,0,32,236),(4,-110,40,139),(0,103,38,145),(2,-165,42,93),(5,-125,80,108),(0,-32,86,136),(3,75,84,150),(7,156,66,78),(6,-181,68,65),(6,15,103,63),(7,120,96,68)]
stones=[]
for i,(kind,x,y,width) in enumerate(entries):
 stones.append({'texture':f'rock-{kind}.png','at':[x,y],'width':width,'start':round(.18+i*.092,4),'duration':.78,'slide':[round((x/190)*64,3),80+(i%4)*12],'rotation':round((x/190)*.25,4)})
manifest={'lamp':{'width':132,'anchor':[146,208],'chamber_center':[156,80]},'stones':stones,'source':'eight complete separately drawn rocks; no heap slicing; per-stone fixed scale'}
(OUT/'visuals.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
qa.append({'id':'fixed_scale_animation','scale_keyframes':0,'instances':len(stones),'last_stone_end':max(s['start']+s['duration'] for s in stones),'event_seconds':2.4})
Path('art/mine-lamps-rocks-v3/qa.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2),encoding='utf-8')
prov={'route':'local:codex-cli','model':'codex-image_gen','estimateUsd':0,'art_source':'existing','generated_parts':['unlit chamber','eight whole rocks'],'lamp_reference':'art/mine-lamps-rocks-v3/lamp-user-reference.png','lamp_edit':'art/mine-lamps-rocks-v3/lamp-unlit/generated.png','rocks_source':'art/mine-lamps-rocks-v3/rocks/generated.png','lamp_processing':'Remove old magenta key fringe before deriving every state. Only edited unlit chamber crops replace the original reference openings; grey stone and roof are byte-identical between states; generated abstract glyphs composited inside the round recess','rocks_processing':'Eight whole original silhouettes from real source gutters, alpha key, fixed source scale per instance; no cutting a rock heap','files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.iterdir() if p.is_file() and p.name!='provenance.json'},'approval':'User requested these corrections; no claim of subsequent visual approval'}
(OUT/'provenance.json').write_text(json.dumps(prov,ensure_ascii=False,indent=2),encoding='utf-8')
