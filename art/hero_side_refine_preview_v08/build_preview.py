from pathlib import Path
import json, hashlib, importlib.util
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[1]
ART=OUT.parent
OLD=ART/'hero_side_phase_preview_v07'
def save(name,v): (OUT/name).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def clean(im):
    a=np.array(im.convert('RGBA'));a[a[:,:,3]<=8]=0
    return Image.fromarray(a)
def bbox(im): return im.getchannel('A').point(lambda v:255 if v>32 else 0).getbbox()
def render(im,s,dx,dy,size=512):
    return clean(im.convert('RGBa').transform((size,size),Image.Transform.AFFINE,(1/s,0,-dx/s,0,1/s,-dy/s),Image.Resampling.BICUBIC).convert('RGBA'))
def restore(folder,index,metadata='registration.json',raw='generated.png'):
    m=json.loads((folder/metadata).read_text(encoding='utf-8'))
    t=m['transforms'][index] if 'transforms' in m else m
    im=clean(Image.open(folder/raw))
    if 'sourceCell' in t:im=im.crop(t['sourceCell'])
    return render(im,t['scale']*4,t['offsetPx'][0]*4,t['offsetPx'][1]*4)

high=[]
for i in range(8):
    if i in [0,3]: im=restore(ART/'hero_consistency_preview_v04/side_walk',i,'normalization.json','take1/generated.png')
    elif i in [1,2]: im=Image.open(OLD/f'take{i+1}/high_frame_{i:02}.png').convert('RGBA')
    elif i in [4,5]:
        im=Image.open(OUT/f'edit_frame{i+1}/generated.png').convert('RGBA')
        im=im.convert('RGBa').resize((512,512),Image.Resampling.LANCZOS).convert('RGBA')
    elif i==6: im=restore(ART/'hero_sequence_repair_preview_v05/side_walk/take4',0)
    else: im=restore(ART/'hero_sequence_repair_preview_v05/side_walk/take3',3)
    high.append(clean(im))

# Measure a stable anatomical region, not the moving full-body bounding box.
# The user explicitly requests correction of inconsistent source sizes.
# Isotropic whole-frame source calibration only; one final 1/4 display scale.
def head(im):
    a=np.array(im).astype(float);b=bbox(im)
    skin=(a[:,:,0]>210)&(a[:,:,1]>140)&(a[:,:,2]>100)&(a[:,:,0]-a[:,:,1]>20)&(a[:,:,1]-a[:,:,2]>15)&(a[:,:,3]>128)
    skin[:b[1]+75]=False;skin[b[1]+160:]=False
    yy,xx=np.where(skin)
    chin=float(np.percentile(yy,99.5))
    band=a[:,:,3].copy();band[b[1]+140:]=0
    by,bx=np.where(band>32)
    return chin-b[1],float((bx.min()+bx.max())/2)
refheight,refx=head(high[0]); rows=[];frames=[]
for i,im in enumerate(high):
    w,x=head(im);scale=refheight/w
    # Side-view stance feet are grounded in all eight supplied poses.
    # Register their ground line, keeping the swing foot above it.
    ground=bbox(im)[3]
    dx=refx-x*scale;dy=448-ground*scale
    reg=render(im,scale,dx,dy)
    f=clean(reg.convert('RGBa').resize((128,128),Image.Resampling.LANCZOS).convert('RGBA'))
    frames.append(f)
    rows.append({'frame':i+1,'anatomicalHeadHeightSource512':w,'isotropicSourceCalibration':scale,'translation512':[dx,dy],'groundSource512':ground,'finalDisplayScale':.25})
    (OUT/'registered_high').mkdir(exist_ok=True);reg.save(OUT/f'registered_high/frame_{i+1:02}.png')

for direction,fs in [('right',frames),('left',[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in frames])]:
    folder=OUT/f'{direction}_walk_preview';(folder/'frames').mkdir(parents=True,exist_ok=True)
    sheet=Image.new('RGBA',(512,256))
    for i,f in enumerate(fs):
        f.save(folder/f'frames/{direction}_walk_{i:02}.png');sheet.alpha_composite(f,(i%4*128,i//4*128))
    sheet.save(folder/f'{direction}_walk_sheet.png')

font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
contact=Image.new('RGB',(1024,576),'#e2eacb');d=ImageDraw.Draw(contact)
for i,f in enumerate(frames):
    x=i%4*256;y=i//4*288
    contact.paste(f.resize((256,256)),(x,y+24),f.resize((256,256)))
    d.text((x+8,y+2),f'v08 · 第 {i+1} 帧',font=font,fill='#344539')
    d.line((x,y+248,x+256,y+248),fill='#a2b495')
contact.save(OUT/'all_frames_contact.png')
old=[Image.open(OLD/f'right_walk_preview/frames/right_walk_{i:02}.png').convert('RGBA') for i in range(8)]
previews=[]
for i,(a,b) in enumerate(zip(old,frames)):
    page=Image.new('RGB',(512,442),'#e2eacb');draw=ImageDraw.Draw(page)
    for col,(label,f) in enumerate([('v07 原版',a),('v08 修订',b)]):
        draw.text((col*256+10,3),f'{label} · 第 {i+1} 帧',font=font,fill='#344539')
        big=f.resize((256,256));page.paste(big,(col*256,26),big)
        page.paste(f,(col*256+64,310),f)
    previews.append(page)
for name,ms in [('side_walk_compare', [70,70,80,70,70,70,80,70]),('side_walk_slow',[140,150,140,150,140,150,140,150])]:
    previews[0].save(OUT/f'{name}.gif',save_all=True,append_images=previews[1:],duration=ms,loop=0,disposal=2)
    previews[0].save(OUT/f'{name}.webp',save_all=True,append_images=previews[1:],duration=ms,loop=0,lossless=True)
display=[]
for i,f in enumerate(frames):
    page=Image.new('RGB',(512,442),'#e2eacb');draw=ImageDraw.Draw(page)
    draw.rectangle((0,302,512,442),fill='#2c3837')
    for col,p in enumerate([f,f.transpose(Image.Transpose.FLIP_LEFT_RIGHT)]):
        draw.text((col*256+8,3),f'v08 · {"右侧" if col==0 else "左侧"} · 第{i+1}帧',font=font,fill='#344539')
        big=p.resize((256,256));page.paste(big,(col*256,28),big)
        page.paste(p,(col*256+64,310),p)
    display.append(page)
for name,ms in [('side_walk_game_speed',[72,73,72,73,72,73,72,73]),('side_walk_game_speed_slow',[145]*8)]:
    display[0].save(OUT/f'{name}.webp',save_all=True,append_images=display[1:],duration=ms,loop=0,lossless=True)
    gifms=[70,70,80,70,70,70,80,70] if 'slow' not in name else [140,150]*4
    display[0].save(OUT/f'{name}.gif',save_all=True,append_images=display[1:],duration=gifms,loop=0,disposal=2)
save('registration.json',{'canvas':[128,128],'root':[64,112],'policy':'User-requested source scale correction from stable head region, full-frame isotropic calibration and ground registration. No limb edits by code, no full-body bounding-box height fitting. All calibrated sources share final display scale 1/4. Original v07 preserved.','transforms':rows})
checks=[]
for direction in ['right','left']:
    folder=OUT/f'{direction}_walk_preview';sheet=Image.open(folder/f'{direction}_walk_sheet.png')
    for i in range(8):
        f=Image.open(folder/f'frames/{direction}_walk_{i:02}.png');b=bbox(f)
        assert f.size==(128,128) and f.mode=='RGBA' and min(b[:2])>0 and max(b[2:])<128
        assert np.array_equal(f,sheet.crop((i%4*128,i//4*128,i%4*128+128,i//4*128+128)))
        if direction=='left': assert np.array_equal(f,frames[i].transpose(Image.Transpose.FLIP_LEFT_RIGHT))
        checks.append({'file':str(folder.relative_to(OUT)/f'frames/{direction}_walk_{i:02}.png'),'sha256':sha(folder/f'frames/{direction}_walk_{i:02}.png'),'bbox':b})
decoded=[]
for p in sorted(OUT.glob('*.webp'))+sorted(OUT.glob('*.gif')):
    anim=Image.open(p);assert anim.n_frames==8
    total=0
    for i in range(8):anim.seek(i);anim.load();total+=anim.info.get('duration',0)
    decoded.append({'file':p.name,'frameCount':8,'cycleMs':total})
# Use Gorest's real grid/alpha diagnostic; its automatic re-layout is saved
# separately because its generic foot centroid would cancel stance changes.
spec=importlib.util.spec_from_file_location('gorest',ROOT/'.forge/gorest/scripts/normalize_spritesheet.py')
gorest=importlib.util.module_from_spec(spec);spec.loader.exec_module(gorest)
gorest.remove_chroma_key=lambda im:im.convert('RGBA')
diag=gorest.normalize_sheet(OUT/'right_walk_preview/right_walk_sheet.png',OUT/'gorest_diagnostic.png',4,2,128,128,'/generated/windrest_hero_right_walk_v08.png',force_proportional=True,safe_padding=12,anchor_mode='feet-baseline')
assert not diag['sourceEdgeRisks'];save('gorest_diagnostic.json',diag)
metric=[]
for i in range(8):
    actual=Image.open(OUT/f'registered_high/frame_{i+1:02}.png')
    hh,hx=head(actual);b=bbox(frames[i])
    metric.append({'frame':i+1,'registeredHeadHeightPx':round(hh/4,3),'headCenterXPx':round(hx/4,3),'visibleHeightPx':b[3]-b[1],'stanceBaselinePx':b[3]})
save('verification.json',{'packaging':'pass','visualStatus':'needs-visual-review','frames':checks,'measuredRegistration':metric,'animationDecodes':decoded,'gorestSourceEdgeRisks':diag['sourceEdgeRisks'],'limits':['Anatomical redraw differences remain possible; head calibration is not a zero-drift guarantee.','No game integration or performance test.']})
print(json.dumps(rows))
