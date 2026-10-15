"""User-locked v08 poses. Deterministic full-frame registration and RGB finish only."""
from pathlib import Path
import json,hashlib,importlib.util,copy
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageFilter
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1];ART=OUT.parent
V8=ART/'hero_side_refine_preview_v08';V4=ART/'hero_consistency_preview_v04'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(name,v):(OUT/name).write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def clean(im):
    a=np.array(im.convert('RGBA'));a[a[:,:,3]<=8]=0
    return Image.fromarray(a)
def bbox(im,cutoff=32):return im.getchannel('A').point(lambda a:255 if a>cutoff else 0).getbbox()
def affine(im,s,offset,size=512):
    return clean(im.convert('RGBa').transform((size,size),Image.Transform.AFFINE,(1/s,0,-offset[0]/s,0,1/s,-offset[1]/s),Image.Resampling.BICUBIC).convert('RGBA'))
def finish(hi):
    im=hi.convert('RGBa').resize((128,128),Image.Resampling.LANCZOS).convert('RGBA')
    a=np.array(im);blur=np.array(im.convert('RGB').filter(ImageFilter.GaussianBlur(.5))).astype(float)
    # Same bounded RGB-only finish in ALL directions; alpha/geometry untouched.
    detail=np.clip((a[:,:,:3].astype(float)-blur)*.45,-8,8)
    detail*=np.clip((a[:,:,3:4].astype(float)-192)/63,0,1)
    rgb=np.clip(a[:,:,:3].astype(float)+detail,0,255).round().astype(np.uint8)
    b=a.copy();b[:,:,:3]=rgb
    assert np.array_equal(a[:,:,3],b[:,:,3])
    b[b[:,:,3]<=8]=0
    return Image.fromarray(b),clean(im)

(OUT/'locked_v08').mkdir(parents=True,exist_ok=True)
lock={};native={};old={};records={};frames={};unsharpened={}
for di in ['front','back']:
    folder=V4/f'{di}_walk';rawpath=folder/'take1/generated.png';raw=clean(Image.open(rawpath))
    meta=json.loads((folder/'normalization.json').read_text(encoding='utf-8'))
    native[di]=[];records[di]=[]
    for i,t in enumerate(meta['transforms']):
        c=raw.crop(t['sourceCell']);hi=affine(c,t['scale']*4,[v*4 for v in t['offsetPx']])
        native[di].append(hi)
        records[di].append({'frame':i+1,'source':rawpath.relative_to(ROOT).as_posix(),'sourceSha256':sha(rawpath),'sourceCellIndexZeroBased':i,'sourceCell':t['sourceCell'],'sourceRegistration':t,'sizeCalibration':1.0,'additionalTranslation512':[0,0]})
    old[di]=[Image.open(ROOT/f'assets/hero/final_sprite/{di}_walk_{i:02}.png').convert('RGBA') for i in range(8)]
native['right']=[];old['right']=[];records['right']=[]
for i in range(8):
    src=V8/f'registered_high/frame_{i+1:02}.png';base=V8/f'right_walk_preview/frames/right_walk_{i:02}.png'
    native['right'].append(Image.open(src).convert('RGBA'));old['right'].append(Image.open(base).convert('RGBA'))
    lock[str(src.relative_to(ROOT))]=sha(src);lock[str(base.relative_to(ROOT))]=sha(base)
    (OUT/f'locked_v08/frame_{i+1:02}.png').write_bytes(base.read_bytes())
    records['right'].append({'frame':i+1,'source':src.relative_to(ROOT).as_posix(),'sourceSha256':sha(src),'poseBaseline':base.relative_to(ROOT).as_posix(),'poseBaselineSha256':sha(base),'sourceCellIndexZeroBased':i,'operation':'Only full-frame uniform scale/translation; no rotation, shear, warp, part processing or generated pixels.'})

# Use the approved front/back as the physical display-height reference.
# In this explicitly requested size-only repair, side source registration uses
# two full-figure reference points (crown and stance ground), never limb edits.
# These are OFFLINE constant transforms, not a runtime bbox-normalization rule.
refheights=[bbox(f)[3]-bbox(f)[1] for di in ['front','back'] for f in old[di]]
targetheight=float(np.median(refheights));targetground=112.;targettop=targetground-targetheight
refcenter=61.125
for di in ['front','back','right']:
    frames[di]=[];unsharpened[di]=[]
    folder=OUT/f'{di}_walk_preview';(folder/'frames').mkdir(parents=True,exist_ok=True);(folder/'registered_high').mkdir(exist_ok=True)
    for i,hi in enumerate(native[di]):
        if di=='right':
            x0,y0,x1,y1=bbox(hi);s=targetheight*4/(y1-y0)
            # All previous v08 heads already share their horizontal reference.
            dx=refcenter*4*(1-s);dy=targetground*4-y1*s
            reg=affine(hi,s,[dx,dy]);records[di][i].update({'sizeCalibration':s,'additionalTranslation512':[dx,dy],'registeredCrown512':targettop*4,'registeredGround512':targetground*4,'sourceRegistrationPoints512':{'crownY':y0,'stanceGroundY':y1}})
        else:reg=hi
        reg.save(folder/f'registered_high/frame_{i+1:02}.png')
        f,plain=finish(reg);frames[di].append(f);unsharpened[di].append(plain)
        f.save(folder/f'frames/{di}_walk_{i:02}.png')
        records[di][i].update({'outputSha256':sha(folder/f'frames/{di}_walk_{i:02}.png'),'finalScale':.25,'visibleBounds':bbox(f)})
    sheet=Image.new('RGBA',(512,256))
    for i,f in enumerate(frames[di]):sheet.alpha_composite(f,(i%4*128,i//4*128))
    sheet.save(folder/f'{di}_walk_sheet.png')
frames['left']=[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in frames['right']]
folder=OUT/'left_walk_preview';(folder/'frames').mkdir(parents=True,exist_ok=True);sheet=Image.new('RGBA',(512,256))
for i,f in enumerate(frames['left']):f.save(folder/f'frames/left_walk_{i:02}.png');sheet.alpha_composite(f,(i%4*128,i//4*128))
sheet.save(folder/'left_walk_sheet.png')
Image.open(V8/'right_walk_preview/right_walk_sheet.png').save(OUT/'side_v08_sheet.png')
save('pose_lock.json',{'authoritativeVersion':'v08','sourceHashes':lock,'frameIndicesZeroBased':list(range(8)),'frameOrderChanged':False,'imageCalls':0,'videoCalls':0,'rejectedSource':'v09; no v09 generated pixels used','allowedOperations':['Whole-frame uniform scale','Whole-frame translation','Same premultiplied LANCZOS downsample for all views','Bounded RGB-only sharpening, alpha unchanged'],'prohibitedOperations':['Redraw or generate','Rotate/shear/warp','Limb or part edits','Change hand/foot angles, relative positions, occlusion or phase']})
save('registration.json',{'canvas':[128,128],'root':[64,112],'targetDisplayHeight':targetheight,'targetCrownY':targettop,'targetGroundY':targetground,'directions':records,'finish':{'sampler':'Premultiplied RGBA LANCZOS, common 512 to 128 final grid','rgbSharpness':{'gaussianRadius':.5,'amount':.45,'maximumChannelDelta':8,'alphaChanged':False}},'policy':'All source poses are fixed. Side uses small constant whole-frame isotropic source-size repairs to the front/back display stature. No nonuniform shape edits. Do not convert these into runtime per-frame dynamic normalization.','limitations':'Native drawn texture and nonuniform body proportions cannot be fully equalized by full-frame transforms. No claim of synthesized detail or exact anatomical consistency.'})

font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18);labels={'front':'正视参考','back':'背视参考','right':'侧视 v08 姿势锁定'}
contact=Image.new('RGB',(2048,864),'#e5ebd6');d=ImageDraw.Draw(contact)
for row,di in enumerate(['front','back','right']):
    for i,f in enumerate(frames[di]):
        x=i*256;y=row*288;d.text((x+5,y+3),f'{labels[di]} · {i+1}',font=font,fill='#344539')
        big=f.resize((256,256));contact.paste(big,(x,y+28),big);d.line((x,y+252,x+256,y+252),fill='#a6b69c')
contact.save(OUT/'crossview_contact.png')
sidecontact=Image.new('RGB',(1024,576),'#e5ebd6');d=ImageDraw.Draw(sidecontact)
for i,f in enumerate(frames['right']):
    x=i%4*256;y=i//4*288;d.text((x+6,y+3),f'v08 姿势 · 第{i+1}帧',font=font,fill='#344539')
    big=f.resize((256,256));sidecontact.paste(big,(x,y+28),big)
sidecontact.save(OUT/'side_contact.png')
cross=[];compare=[]
for i in range(8):
    p=Image.new('RGB',(768,442),'#e5ebd6');d=ImageDraw.Draw(p);d.rectangle((0,302,768,442),fill='#2c3837')
    for col,di in enumerate(['front','back','right']):
        f=frames[di][i];d.text((col*256+8,3),f'{labels[di]} · {i+1}',font=font,fill='#344539')
        big=f.resize((256,256));p.paste(big,(col*256,28),big);p.paste(f,(col*256+64,310),f)
    cross.append(p)
    p=Image.new('RGB',(512,442),'#e5ebd6');d=ImageDraw.Draw(p)
    for col,(name,f) in enumerate([('v08 原帧',old['right'][i]),('v10 仅尺寸/清晰度',frames['right'][i])]):
        d.text((col*256+6,3),f'{name} · {i+1}',font=font,fill='#344539')
        big=f.resize((256,256));p.paste(big,(col*256,28),big);p.paste(f,(col*256+64,310),f)
    compare.append(p)
for name,ps in [('crossview_walk',cross),('side_before_after',compare)]:
    for suffix,webpms,gifms in [('',[72,73]*4,[70,70,80,70,70,70,80,70]),('_slow',[145]*8,[140,150]*4)]:
        ps[0].save(OUT/f'{name}{suffix}.webp',save_all=True,append_images=ps[1:],duration=webpms,loop=0,lossless=True)
        ps[0].save(OUT/f'{name}{suffix}.gif',save_all=True,append_images=ps[1:],duration=gifms,loop=0,disposal=2)

checks=[]
for di,fs in frames.items():
    assert len({hashlib.sha256(f.tobytes()).hexdigest() for f in fs})==8
    sheet=Image.open(OUT/f'{di}_walk_preview/{di}_walk_sheet.png')
    for i,f in enumerate(fs):
        b=bbox(f);assert f.mode=='RGBA' and f.size==(128,128) and b[0]>0 and b[1]>0 and b[2]<128 and b[3]<128
        assert np.array_equal(f,sheet.crop((i%4*128,i//4*128,i%4*128+128,i//4*128+128)))
        if di=='left':assert np.array_equal(f,frames['right'][i].transpose(Image.Transpose.FLIP_LEFT_RIGHT))
        else:assert np.array_equal(f.getchannel('A'),unsharpened[di][i].getchannel('A'))
    checks.append({'direction':di,'frames':8,'visibleHeights':[bbox(f)[3]-bbox(f)[1] for f in fs],'topY':[bbox(f)[1] for f in fs],'groundY':[bbox(f)[3] for f in fs]})
for p,h in lock.items():assert sha(ROOT/p)==h
decodes=[]
for p in sorted(OUT.glob('*.webp'))+sorted(OUT.glob('*.gif')):
    a=Image.open(p);assert a.n_frames==8;total=0
    for i in range(8):a.seek(i);a.load();total+=a.info.get('duration',0)
    assert total==(1160 if '_slow' in p.stem else 580)
    decodes.append({'file':p.name,'frames':8,'cycleMs':total})
# Reuse Gorest grid and alpha diagnostics, without using its optional auto-layout.
spec=importlib.util.spec_from_file_location('gorest',ROOT/'.forge/gorest/scripts/normalize_spritesheet.py')
n=importlib.util.module_from_spec(spec);spec.loader.exec_module(n);n.remove_chroma_key=lambda im:im.convert('RGBA')
g=n.normalize_sheet(OUT/'right_walk_preview/right_walk_sheet.png',OUT/'gorest_diagnostic.png',4,2,128,128,'/generated/windrest_hero_right_walk_v10.png',force_proportional=True,safe_padding=12,anchor_mode='feet-baseline')
assert not g['sourceEdgeRisks'];save('gorest_diagnostic.json',g)
runtime={p.relative_to(ROOT).as_posix():sha(p) for folder in ['assets/hero','scripts','scenes'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix not in ['.import','.uid']}
if not (OUT/'game_files_before.json').exists():save('game_files_before.json',runtime)
assert json.loads((OUT/'game_files_before.json').read_text(encoding='utf-8'))==runtime
save('verification.json',{'packaging':'pass','visualStatus':'needs-visual-review','poseSourceHashesUnchanged':True,'sourceContainsV09':False,'imageCalls':0,'videoCalls':0,'directionChecks':checks,'decodes':decodes,'sourceEdgeRisks':g['sourceEdgeRisks'],'runtimeHashCheck':{'files':len(runtime),'unchanged':True},'limits':['Nonuniform source body proportions and differing painted textures remain; geometry is deliberately preserved.','Clarity is deterministic resampling/sharpening, not generated detail restoration.']})
save('provenance.json',{'art_source':'existing','route':'existing v08 high-resolution frames + approved v04 front/back original sheets; deterministic Gorest/Pillow registration','imageCalls':0,'videoCalls':0,'model':None,'estimateUsd':0,'sourcePoseVersion':'v08','inherit':'../hero_side_refine_preview_v08/provenance.json','lock':'pose_lock.json','license':'Inherited original generated art provider/account terms. No external game assets. Gorest and Forge tooling retain their respective MIT licenses.','status':'needs-visual-review','previewOnly':True})
print(json.dumps({'targetHeight':targetheight,'sideScales':[r['sizeCalibration'] for r in records['right']],'checks':checks,'poseSources':'v08 only, unchanged'}))
