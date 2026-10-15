"""Prepare generated cutouts, then bake synchronized interchangeable rig layers.

Source pixels come from host image generation via generate2dsprite. Motion is a
deterministic cutout/IK fallback because route_media reports no video route.
No new illustrated shapes are drawn by this script.
"""
from pathlib import Path
import json, math, hashlib
import numpy as np
from PIL import Image, ImageOps, ImageEnhance
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'art/candidates'
OUT = ROOT / 'assets'
S = 4  # render transforms at 4x, premultiplied final reduction
CELL = 128
ANCHOR = (64, 112)
N = 12
SLOTS = ['far_leg', 'far_pants', 'far_shoe', 'far_arm', 'far_sleeve',
         'torso', 'near_leg', 'near_pants', 'near_shoe', 'head',
         'near_arm', 'jacket', 'near_sleeve', 'hair']
NAMES = ['head', 'hair', 'torso', 'jacket', 'arm', 'sleeve', 'pants', 'leg', 'shoe']
# Ownership crops use the actual returned composition, not nominal cell bounds.
BOXES = [(55,135,370,439),(420,40,835,409),(919,140,1206,440),
         (70,465,414,807),(560,455,730,817),(940,480,1150,792),
         (60,848,432,1133),(575,815,738,1211),(940,871,1215,1211)]

def save_json(p, obj):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding='utf-8')

def alpha_clean(im):
    a = np.array(im.convert('RGBA'))
    # Generated haze is below 128. Keep actual solid paint and reconstruct AA.
    a[:,:,3] = np.clip((a[:,:,3].astype(float)-128)*255/125,0,255).astype('uint8')
    a[a[:,:,3] == 0,:3] = 0
    return Image.fromarray(a)

def hygiene(im, min_area=0):
    a=np.array(im)
    a[a[:,:,3]<=4]=0
    if min_area:
        labels, count=ndimage.label(a[:,:,3]>0,np.ones((3,3)))
        sizes=np.bincount(labels.ravel())
        remove=sizes<min_area; remove[0]=False
        a[remove[labels]]=0
    return Image.fromarray(a)

def crop_subject(im):
    bb = im.getchannel('A').getbbox()
    if not bb: raise ValueError('empty cutout')
    return im.crop(bb)

def resize(im, size):
    return im.convert('RGBa').resize(tuple(max(1,round(x)) for x in size),Image.Resampling.LANCZOS).convert('RGBA')

def export_props():
    dest=OUT/'environment'; dest.mkdir(parents=True,exist_ok=True)
    source_specs = [('trees',2,[220,252],'tree'),('rocks',2,[60,108],'rock'),('tufts',3,[32,36,40],'tuft')]
    review=Image.new('RGBA',(1000,370),(156,191,121,255))
    x=10
    for source, cols, heights, prefix in source_specs:
        sheet=alpha_clean(Image.open(SRC/f'{source}.png'))
        w,h=sheet.size
        for i,target_h in enumerate(heights):
            part=crop_subject(sheet.crop((round(w*i/cols),0,round(w*(i+1)/cols),h)))
            part=resize(part,(part.width*target_h/part.height,target_h))
            canvas=Image.new('RGBA',(part.width+12,part.height+12))
            canvas.alpha_composite(part,(6,6))
            canvas=hygiene(canvas,64)
            canvas.save(dest/f'{prefix}_{i}.png')
            review.alpha_composite(canvas,(x,320-canvas.height)); x+=canvas.width+12
    ground=Image.open(SRC/'meadow.png').convert('RGB').resize((512,512),Image.Resampling.LANCZOS)
    # Periodic-plus-smooth decomposition removes model edge discontinuity without
    # drawing another texture. Global shader coordinates keep chunk edges aligned.
    a=np.array(ground,dtype=float)
    b=np.zeros_like(a)
    b[0,:,:]=a[-1,:,:]-a[0,:,:]; b[-1,:,:]=-b[0,:,:]
    b[:,0,:]+=a[:,-1,:]-a[:,0,:]; b[:,-1,:]-=a[:,-1,:]-a[:,0,:]
    yy,xx=np.meshgrid(np.arange(512),np.arange(512),indexing='ij')
    den=2*np.cos(2*np.pi*xx/512)+2*np.cos(2*np.pi*yy/512)-4
    den[0,0]=1
    bf=np.fft.fft2(b,axes=(0,1))/den[:,:,None]; bf[0,0,:]=0
    smooth=np.fft.ifft2(bf,axes=(0,1)).real
    tile=np.clip(a-smooth,0,255).astype('uint8')
    Image.fromarray(tile).save(dest/'meadow.png')
    review.save(ROOT/'art/reference/environment-lineup.png')

def prepare_parts():
    parts={}
    base_sheet=alpha_clean(Image.open(SRC/'base-pelvis.png'))
    for direction in ['front','back','right']:
        source=alpha_clean(Image.open(SRC/f'parts-{direction}.png'))
        cuts={}
        packed=Image.new('RGBA',(1200,1200))
        for i,(name,box) in enumerate(zip(NAMES,BOXES)):
            cut=crop_subject(hygiene(source.crop(box),24))
            path=ROOT/'art/parts'/direction/f'{name}.png'
            path.parent.mkdir(parents=True,exist_ok=True); cut.save(path)
            cuts[name]=cut
            scale=min(300/cut.width,300/cut.height)
            thumb=resize(cut,(cut.width*scale,cut.height*scale))
            packed.alpha_composite(hygiene(thumb),(i%3*400+(400-thumb.width)//2,i//3*400+(400-thumb.height)//2))
        packed.save(ROOT/f'art/reference/parts-{direction}-clean.png')
        i=['front','back','right'].index(direction)
        # Actual ownership bounds: front shorts overhang the nominal third.
        base_boxes=[(35,310,547,710),(565,310,1080,710),(1130,310,1480,710)]
        cuts['pelvis']=crop_subject(hygiene(base_sheet.crop(base_boxes[i]),24))
        cuts['pelvis'].save(ROOT/f'art/parts/{direction}/pelvis.png')
        parts[direction]=cuts
    return parts

def place(canvas, im, xy, size=None, pivot=(.5,0), angle=0, shade=1):
    if size is not None: im=resize(im,(size[0]*S,size[1]*S))
    if shade!=1: im=ImageEnhance.Brightness(im).enhance(shade)
    px,py=pivot[0]*im.width,pivot[1]*im.height
    pad=max(im.width,im.height)*3
    work=Image.new('RGBA',(pad,pad))
    center=(pad//2,pad//2)
    work.alpha_composite(im,(round(center[0]-px),round(center[1]-py)))
    work=work.rotate(angle,Image.Resampling.BICUBIC,center=center)
    canvas.alpha_composite(work,(round(xy[0]*S-center[0]),round(xy[1]*S-center[1])))

def limb(canvas, image, root, end, width, length1, length2, bend=1, shade=1, projected=False):
    """Two bone IK; split one generated limb with an overlap at the joint."""
    dx,dy=end[0]-root[0],end[1]-root[1]
    dist=max(.01,min(math.hypot(dx,dy),length1+length2-.01))
    direction=math.atan2(dx,dy)
    c=(length1**2+dist**2-length2**2)/(2*length1*dist)
    a=direction+bend*math.acos(max(-1,min(1,c)))
    knee=(root[0]+math.sin(a)*length1,root[1]+math.cos(a)*length1)
    if projected:
        # Front/back knees bend in camera depth: projected segment length changes,
        # not an exaggerated sideways knee. Source pixels remain separate bones.
        knee=((root[0]+end[0])*.5,(root[1]+end[1])*.5)
        length1=math.dist(root,knee); length2=math.dist(knee,end)
        a=math.atan2(knee[0]-root[0],knee[1]-root[1])
    b=math.atan2(end[0]-knee[0],end[1]-knee[1])
    split=round(image.height*length1/(length1+length2))
    overlap=max(4,round(image.height*.06))
    upper=image.crop((0,0,image.width,split+overlap))
    lower=image.crop((0,max(0,split-overlap),image.width,image.height))
    place(canvas,lower,knee,(width,length2+2),(.5,.12),math.degrees(b),shade)
    place(canvas,upper,root,(width,length1+2),(.5,.06),math.degrees(a),shade)
    return math.degrees(a)

def bake(parts):
    atlases={slot:Image.new('RGBA',(CELL*N,CELL*8)) for slot in SLOTS}
    review=Image.new('RGBA',(CELL*N,CELL*8),(156,191,121,255))
    contacts=[]
    for row,(direction,action) in enumerate((d,a) for d in ['front','back','right','left'] for a in ['idle','walk']):
        p=parts['right' if direction=='left' else direction]
        side=direction in ('right','left')
        count=6 if action=='idle' else N
        for frame in range(count):
            t=frame/count
            walking=action=='walk'
            bob= -.65*(1-math.cos(t*math.tau*2)) if walking else -.35*math.sin(t*math.tau)
            layers={slot:Image.new('RGBA',(CELL*S,CELL*S)) for slot in SLOTS}
            hip=(64,83+bob)
            for near in [False,True]:
                prefix='near' if near else 'far'
                phase=(t+(.5 if near else 0))%1
                # Planted foot travels backward at constant speed; swing returns
                # forward with a lifted knee. 40 world units per 0.50s cycle.
                stance=.6
                if walking and phase<stance:
                    travel=12-40*phase; lift=0
                    planted=True
                elif walking:
                    u=(phase-stance)/(1-stance)
                    travel=-12+24*(u*u*(3-2*u)); lift=5*math.sin(math.pi*u)
                    planted=False
                else: travel=0; lift=0; planted=True
                shade=.85 if side and not near else 1
                leg_x=64+((1 if near else -1)*7 if not side else (2 if near else -2))
                if side:
                    ankle=(leg_x+travel,105-lift)
                    legroot=(leg_x,82+bob)
                else:
                    ankle=(leg_x,101+travel*(1 if direction=='front' else -1)-lift)
                    legroot=(leg_x,83+bob)
                angle=limb(layers[f'{prefix}_leg'],p['leg'],legroot,ankle,8 if side else 9,16,16,1 if side else (-1 if near else 1),shade,not side)
                pants=p['pants']
                if not side:
                    middle=round(pants.width*.5)
                    pants=pants.crop((middle if near else 0,0,pants.width if near else middle,pants.height))
                place(layers[f'{prefix}_pants'],pants,(leg_x,79+bob),(13 if not side else 17,15),(.5,.05),angle*.3,shade)
                place(layers[f'{prefix}_shoe'],p['shoe'],(ankle[0]+(2 if side else 0),ankle[1]+5),(17 if side else 13,15),(.5,1),0,shade)
                shoulder=(64+(3 if near else -3) if side else 64+(16 if near else -16),57+bob)
                swing=-travel*.75 if walking else 0
                hand=(shoulder[0]+(swing if side else (2 if near else -2)),83+bob+(-abs(travel)*.12 if walking else 0))
                arm_angle=limb(layers[f'{prefix}_arm'],p['arm'],shoulder,hand,8,14,14, -1 if side else (1 if near else -1),shade)
                place(layers[f'{prefix}_sleeve'],p['sleeve'],shoulder,(12 if side else 13,17),(.5,.06),arm_angle,shade)
                contacts.append({'direction':direction,'action':action,'frame':frame,'leg':prefix,'planted':planted,'travel':travel,'lift':lift})
            place(layers['torso'],p['torso'],(64,56+bob),(23 if side else 30,29),(.5,0))
            place(layers['torso'],p['pelvis'],(64,79+bob),(17 if side else 26,13),(.5,0))
            place(layers['jacket'],p['jacket'],(64,55+bob),(28 if side else 35,31),(.5,0))
            place(layers['head'],p['head'],(64,29+bob),(27 if side else 30,31),(.5,0))
            # Hair opening matches the separate bald head; no painted-in face.
            place(layers['hair'],p['hair'],(64,22+bob),(38 if side else 40,35),(.5,0))
            for slot,high in layers.items():
                low=hygiene(high.convert('RGBa').resize((CELL,CELL),Image.Resampling.BOX).convert('RGBA'))
                if direction=='left': low=ImageOps.mirror(low)
                atlases[slot].alpha_composite(low,(CELL*frame,CELL*row))
                review.alpha_composite(low,(CELL*frame,CELL*row))
    for slot,atlas in atlases.items(): atlas.save(OUT/f'hero/{slot}.png')
    review.save(ROOT/'art/reference/animation-review.png')
    previews=[]
    for k in range(N):
        grid=Image.new('RGBA',(CELL*4,CELL*2),(156,191,121,255))
        for d in range(4):
            for action in range(2):
                f=k% (6 if action==0 else N)
                cell=review.crop((f*CELL,(d*2+action)*CELL,(f+1)*CELL,(d*2+action+1)*CELL))
                grid.alpha_composite(cell,(d*CELL,action*CELL))
        previews.append(grid.convert('RGB'))
    previews[0].save(ROOT/'art/reference/animation-preview.gif',save_all=True,append_images=previews[1:],duration=48,loop=0)
    contract={'schema':'windrest.layered_actor.v1','art_source':'host_image','route':'host:image_gen via generate2dsprite',
        'motion_source':'procedural_two_bone_cutout_rig; no image-to-video route',
        'canvas':[CELL,CELL],'anchor':list(ANCHOR),'body_height':88,'columns':N,'slots':SLOTS,
        'rows':{f'{a}_{d}':i*2+j for i,d in enumerate(['front','back','right','left']) for j,a in enumerate(['idle','walk'])},
        'animations':{'idle':{'frames':6,'fps':6},'walk':{'frames':N,'stride_world_units':40,'distance_driven':True}},
        'rig_rest':{'head_anchor':[64,29],'hair_anchor':[64,22],'torso_anchor':[64,56],
        'jacket_anchor':[64,55],'pelvis_anchor':[64,79],
        'front_back_leg_hips':[[57,83],[71,83]],'side_leg_hips':[[62,82],[66,82]],
        'front_back_shoulders':[[48,57],[80,57]],'side_shoulders':[[61,57],[67,57]],
        'base_ankle_y_front_back':101,'base_ankle_y_side':105,'stance_fraction':.6,'swing_lift_px':5},
        'layer_groups':{'body':['far_leg','far_arm','torso','near_leg','head','near_arm'],'hair':['hair'],
        'top':['far_sleeve','jacket','near_sleeve'],'pants':['far_pants','near_pants'],'shoes':['far_shoe','near_shoe']},
        'limits':['Cutout rig, not hand-drawn frame-by-frame or generated video.','Left view is mirrored right view.',
        'Future clothes must match these joints, canvas, layer order and timebase; base torso is an undershirt.']}
    save_json(OUT/'hero/actor.json',contract)
    save_json(ROOT/'art/rig/contact-data.json',contacts)

if __name__=='__main__':
    raise SystemExit('Retired: the cutout/rig character pipeline was rejected. Use tools/prepare_character.py for complete frames; see CHARACTER_MODULAR_RULES.md. Historical functions are retained for provenance only.')
