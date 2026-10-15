"""New user-authorized full-body redraw; fixed v08 phase references, one sheet scale."""
from pathlib import Path
import json,hashlib,importlib.util
import numpy as np
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1];ART=OUT.parent
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def clean(im):
    a=np.array(im.convert('RGBA'));a[a[:,:,3]<=8]=0
    return Image.fromarray(a)
def bbox(im):return im.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()
def head_anchor(im):
    b=bbox(im);a=np.array(im.getchannel('A'),dtype=float)
    a[b[1]+round((b[3]-b[1])*.34):]=0
    yy,xx=np.indices(a.shape)
    return float((a*xx).sum()/a.sum()),float(b[1])
def sample(im,scale,offset,side=128):
    # Same premultiplied supersampling path for ALL 24 full body poses.
    factor=4
    hi=im.convert('RGBa').transform((side*factor,side*factor),Image.Transform.AFFINE,(1/(scale*factor),0,-offset[0]/scale,0,1/(scale*factor),-offset[1]/scale),Image.Resampling.BICUBIC)
    return clean(hi.resize((side,side),Image.Resampling.LANCZOS).convert('RGBA'))
def diagnostics(path,cols,rows,output,href):
    spec=importlib.util.spec_from_file_location('gorest',ROOT/'.forge/gorest/scripts/normalize_spritesheet.py')
    n=importlib.util.module_from_spec(spec);spec.loader.exec_module(n)
    n.remove_chroma_key=lambda im:clean(im)
    d=n.normalize_sheet(path,output/'gorest_diagnostic.png',cols,rows,128,128,href,safe_padding=12,anchor_mode='feet-baseline')
    save(output/'gorest_diagnostic.json',d);assert not d['sourceEdgeRisks']
    return d
def process(take='take1'):
    selected=OUT/take;images={};records={}
    for direction in ['front','back','right']:
        folder=OUT/f'{direction}_walk_preview';(folder/'frames').mkdir(parents=True,exist_ok=True)
        if direction in ['front','back']:
            src=ART/f'hero_consistency_preview_v04/{direction}_walk/take1/generated.png'
            meta=json.loads((src.parent.parent/'normalization.json').read_text(encoding='utf-8'))
            raw=clean(Image.open(src));transforms=meta['transforms']
            scale=meta['globalScale']
            assert len({t['scale'] for t in transforms})==1
        else:
            src=selected/'generated.png';raw=clean(Image.open(src));raw.save(selected/'native_alpha_clean.png')
            diag=diagnostics(selected/'native_alpha_clean.png',4,2,selected,'/generated/windrest_hero_right_walk_v11.png')
            cells=[raw.crop(c) for c in diag['sourceCells']]
            heights=[bbox(c)[3]-bbox(c)[1] for c in cells]
            scale=92/float(np.median(heights))
            transforms=[]
            for box,c in zip(diag['sourceCells'],cells):
                hx,top=head_anchor(c)
                transforms.append({'sourceCell':box,'scale':scale,'offsetPx':[61-hx*scale,20-top*scale]})
        fs=[];hi=[];entries=[]
        for i,t in enumerate(transforms):
            c=raw.crop(t['sourceCell']);f=sample(c,scale,t['offsetPx']);fs.append(f)
            f.save(folder/f'frames/{direction}_walk_{i:02}.png')
            native=c.convert('RGBa').transform((512,512),Image.Transform.AFFINE,(1/(scale*4),0,-t['offsetPx'][0]/scale,0,1/(scale*4),-t['offsetPx'][1]/scale),Image.Resampling.BICUBIC).convert('RGBA')
            (folder/'registered_high').mkdir(exist_ok=True);native.save(folder/f'registered_high/frame_{i+1:02}.png')
            entries.append({'frameOneBased':i+1,'sourceCellIndexZeroBased':i,**t,'outputSha256':sha(folder/f'frames/{direction}_walk_{i:02}.png'),'bbox':bbox(f)})
        sheet=Image.new('RGBA',(512,256))
        for i,f in enumerate(fs):sheet.alpha_composite(f,(i%4*128,i//4*128))
        sheet.save(folder/f'{direction}_walk_sheet.png');images[direction]=fs
        records[direction]={'source':src.relative_to(ROOT).as_posix(),'sourceSha256':sha(src),'sourceSize':list(raw.size),'globalScale':scale,'transforms':entries,'canvas':[128,128],'root':[64,112],'sampling':'RGBA premultiplied, 4x affine BICUBIC, common LANCZOS area downsample, one source-to-final pass; no sharpening'}
    left=[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in images['right']];images['left']=left
    folder=OUT/'left_walk_preview';(folder/'frames').mkdir(parents=True,exist_ok=True)
    sheet=Image.new('RGBA',(512,256))
    for i,f in enumerate(left):f.save(folder/f'frames/left_walk_{i:02}.png');sheet.alpha_composite(f,(i%4*128,i//4*128))
    sheet.save(folder/'left_walk_sheet.png')
    save(OUT/'registration.json',{'directions':records,'policy':'One scale per full-sheet source, no per-frame source calibration or bbox height fitting. Side whole-sheet generation; approved front/back native source reconstructions. Identical final sampling for all directions. Head-band/top full-frame rigid translation only, common root; stance pixels may move with pose.','selectedTake':take,'left':'whole-frame mirror around pixel-grid center 64'})
    font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
    labels={'front':'正视','back':'背视','right':'侧视'}
    contact=Image.new('RGB',(2048,864),'#e5ebd6');draw=ImageDraw.Draw(contact)
    for row,di in enumerate(['front','back','right']):
        for i,f in enumerate(images[di]):
            x=i*256;y=row*288
            draw.text((x+6,y+3),f'{labels[di]} v11 · 第{i+1}帧',font=font,fill='#344539')
            big=f.resize((256,256));contact.paste(big,(x,y+28),big)
            draw.line((x,y+252,x+256,y+252),fill='#b1bda5')
    contact.save(OUT/'crossview_contact.png')
    sidecontact=contact.crop((0,576,2048,864));sidecontact.save(OUT/'side_contact_strip.png')
    old=[Image.open(ART/f'hero_side_refine_preview_v08/right_walk_preview/frames/right_walk_{i:02}.png').convert('RGBA') for i in range(8)]
    oldsheet=Image.open(ART/'hero_side_refine_preview_v08/right_walk_preview/right_walk_sheet.png');oldsheet.save(OUT/'side_v08_sheet.png')
    pages=[];compare=[]
    for i in range(8):
        p=Image.new('RGB',(768,442),'#e5ebd6');d=ImageDraw.Draw(p);d.rectangle((0,302,768,442),fill='#2c3837')
        for col,di in enumerate(['front','back','right']):
            f=images[di][i];d.text((col*256+8,3),f'{labels[di]} · 第{i+1}帧',font=font,fill='#344539')
            big=f.resize((256,256));p.paste(big,(col*256,28),big);p.paste(f,(col*256+64,310),f)
        pages.append(p)
        c=Image.new('RGB',(512,442),'#e5ebd6');d=ImageDraw.Draw(c)
        for col,(name,f) in enumerate([('v08 原姿势',old[i]),('v11 同姿势重绘',images['right'][i])]):
            d.text((col*256+8,3),f'{name} · 第{i+1}帧',font=font,fill='#344539')
            big=f.resize((256,256));c.paste(big,(col*256,28),big);c.paste(f,(col*256+64,310),f)
        compare.append(c)
    for name,ps in [('crossview_walk',pages),('side_before_after',compare)]:
        for speed,times in [('',[72,73]*4),('_slow',[145]*8)]:
            ps[0].save(OUT/f'{name}{speed}.webp',save_all=True,append_images=ps[1:],duration=times,loop=0,lossless=True)
            gt=[70,70,80,70,70,70,80,70] if not speed else [140,150]*4
            ps[0].save(OUT/f'{name}{speed}.gif',save_all=True,append_images=ps[1:],duration=gt,loop=0,disposal=2)
    verification=[]
    for di,fs in images.items():
        sheet=Image.open(OUT/f'{di}_walk_preview/{di}_walk_sheet.png')
        assert len({hashlib.sha256(f.tobytes()).hexdigest() for f in fs})==8
        for i,f in enumerate(fs):
            assert f.mode=='RGBA' and f.size==(128,128)
            b=bbox(f);assert b[0]>0 and b[1]>0 and b[2]<128 and b[3]<128
            assert np.array_equal(f,sheet.crop((i%4*128,i//4*128,i%4*128+128,i//4*128+128)))
        if di=='left':assert all(np.array_equal(a,b.transpose(Image.Transpose.FLIP_LEFT_RIGHT)) for a,b in zip(fs,images['right']))
        verification.append({'direction':di,'canvas':[128,128],'count':8,'bboxes':[bbox(f) for f in fs]})
    decode=[]
    for p in sorted(OUT.glob('*.webp'))+sorted(OUT.glob('*.gif')):
        a=Image.open(p);assert a.n_frames==8;total=0
        for i in range(8):a.seek(i);a.load();total+=a.info.get('duration',0)
        assert total==(1160 if '_slow' in p.stem else 580)
        decode.append({'file':p.name,'frames':8,'cycleMs':total})
    baseline=json.loads((OUT/'game_files_before.json').read_text(encoding='utf-8'))
    assert all(sha(ROOT/p)==h for p,h in baseline.items())
    save(OUT/'verification.json',{'packaging':'pass','visualStatus':'needs-visual-review','directionChecks':verification,'animationChecks':decode,'runtimeHashCheck':{'files':len(baseline),'unchanged':True},'sameSamplingAllDirections':True,'noPerFrameScale':True})
    print(json.dumps({'take':take,'scales':{di:r['globalScale'] for di,r in records.items()},'sideBboxes':[bbox(f) for f in images['right']],'status':'packaging pass; visual review required'}))
if __name__=='__main__':
    import sys
    process(sys.argv[1] if len(sys.argv)>1 else 'take1')
