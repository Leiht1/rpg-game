"""Two complete-pose replacements; preserve all other candidate frames."""
from pathlib import Path
import hashlib, importlib.util, json, shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT=Path(__file__).resolve().parent
OLD=OUT.parent/'hero_sequence_repair_preview_v05'
spec=importlib.util.spec_from_file_location('previous',OLD/'repair_preview.py')
M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M);P=M.P
FONT=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(name,v):P.save(OUT/name,v)
def previous(di):return [Image.open(OLD/f'{di}_walk_preview/frames/{di}_walk_{i:02}.png').convert('RGBA') for i in range(8)]
def animate(name,fs):
    durations=[83,84,83,83,84,83,83,84]
    ticks=[round(sum(durations[:i+1])/10)*10-round(sum(durations[:i])/10)*10 for i in range(8)]
    fs[0].save(OUT/f'{name}.gif',save_all=True,append_images=fs[1:],duration=ticks,loop=0,disposal=2)
    fs[0].save(OUT/f'{name}.webp',save_all=True,append_images=fs[1:],duration=durations,loop=0,lossless=True)

def main():
    take=OUT/'take1';raw=P.clean(Image.open(take/'generated.png'));raw.save(take/'native_alpha_clean.png')
    diag=P.N.normalize_sheet(take/'native_alpha_clean.png',take/'gorest_diagnostic.png',2,1,128,128,
        '/generated/windrest_hero_side_spacing_v06.png',safe_padding=12,anchor_mode='feet-baseline')
    assert not diag['sourceEdgeRisks'],diag['sourceEdgeRisks']
    save('take1/gorest_diagnostic.json',diag)
    cells=[raw.crop(tuple(b)) for b in diag['sourceCells']]
    scale=float(92/np.median([P.bbox(c)[3]-P.bbox(c)[1] for c in cells]))
    transforms=[];changed={}
    for ci,(index,c) in enumerate(zip([2,4],cells)):
        hx,hy=P.W.head_anchor(c);offset=[61-hx*scale,20-hy*scale]
        hi=P.W.render(c,scale,offset,512)
        frame=P.clean(hi.convert('RGBa').resize((128,128),Image.Resampling.LANCZOS).convert('RGBA'))
        changed[index]=frame;c.save(take/f'cell_{ci:02}.png');frame.save(take/f'frame_{index:02}.png')
        transforms.append({'sourceCellIndexZeroBased':ci,'outputIndexZeroBased':index,
            'sourceCell':diag['sourceCells'][ci],'scale':scale,'offsetPx':offset})
    save('take1/registration.json',{'globalScale':scale,'transforms':transforms,'sourceSha256':sha(take/'generated.png'),
        'policy':'One common source-sheet scale; whole-frame head registration only. No per-pose scale, local patch, limb compositing or warp.'})
    old=previous('right');right=[changed.get(i,f) for i,f in enumerate(old)]
    left=[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in right]
    for di,fs in [('right',right),('left',left)]:
        folder=OUT/f'{di}_walk_preview';P.sheet(folder,f'{di}_walk',fs,4)
        for i in [0,1,3,5,6,7]:shutil.copy2(OLD/f'{di}_walk_preview/frames/{di}_walk_{i:02}.png',folder/f'frames/{di}_walk_{i:02}.png')
    contact=Image.new('RGB',(1536,568),'#e2eacb');d=ImageDraw.Draw(contact)
    for row,(label,fs) in enumerate([('v05',old),('v06',right)]):
        for col,index in enumerate([1,2,3,3,4,5]):
            x=col*256;y=row*284;P.panel(contact,fs[index],x,y+28,256)
            d.text((x+8,y+3),f'{label} · 第 {index+1} 帧',font=FONT,fill='#344539')
    contact.save(OUT/'adjacent_before_after.png')
    contact=Image.new('RGB',(1024,568),'#e2eacb');d=ImageDraw.Draw(contact)
    for i,f in enumerate(right):
        x=i%4*256;y=i//4*284;P.panel(contact,f,x,y+28,256)
        d.text((x+8,y+3),f'v06 · 第 {i+1} 帧',font=FONT,fill='#344539')
    contact.save(OUT/'all_frames_contact.png')
    seq=[];compare=[]
    for i in range(8):
        im=Image.new('RGB',(512,468),'#e2eacb');d=ImageDraw.Draw(im)
        for col,(di,fs) in enumerate([('右侧',right),('左侧',left)]):
            P.panel(im,fs[i],col*256,28,256)
            d.rectangle((col*256,284,col*256+256,468),fill='#303b39')
            P.panel(im,fs[i],col*256+64,312,128)
            d.text((col*256+8,3),f'{di} v06 · {i+1}',font=FONT,fill='#344539')
            d.text((col*256+8,286),'游戏原尺寸 1:1',font=FONT,fill='#e2eacb')
        seq.append(im)
        im=Image.new('RGB',(512,284),'#e2eacb');d=ImageDraw.Draw(im)
        for col,(label,f) in enumerate([('v05',old[i]),('v06',right[i])]):
            P.panel(im,f,col*256,28,256);d.text((col*256+8,3),f'{label} · 第 {i+1} 帧',font=FONT,fill='#344539')
        compare.append(im)
    animate('side_walk',seq);animate('side_walk_before_after',compare)
    seq[0].save(OUT/'side_walk_poster.png')
    selection=[]
    for i in range(8):
        selection.append({'frameOneBased':i+1,'outputIndexZeroBased':i,
            'source':f'take1/generated.png cell {0 if i==2 else 1}' if i in changed else f'../hero_sequence_repair_preview_v05/right_walk_preview/frames/right_walk_{i:02}.png'})
    save('selection.json',{'selection':selection,'changedFramesOneBased':[3,5],
        'unchangedFramesOneBased':[1,2,4,6,7,8],'root':[64,112],
        'leftPolicy':'Whole-frame horizontal mirror, same phase order','idlePolicy':'All v05 breathing previews retained without changes.'})
    hashes={};checks=[]
    for di,fs in [('right',right),('left',left)]:
        folder=OUT/f'{di}_walk_preview';sheet=Image.open(folder/f'{di}_walk_sheet.png').convert('RGBA')
        for i,f in enumerate(fs):
            path=folder/f'frames/{di}_walk_{i:02}.png';actual=Image.open(path)
            assert actual.mode=='RGBA' and actual.size==(128,128)
            b=P.bbox(actual);assert b and b[0]>0 and b[1]>0 and b[2]<128 and b[3]<128
            assert actual.getchannel('A').getextrema()[0]==0
            assert np.array_equal(np.array(actual),np.array(sheet.crop((i%4*128,i//4*128,i%4*128+128,i//4*128+128))))
            if i not in changed:assert sha(path)==sha(OLD/f'{di}_walk_preview/frames/{di}_walk_{i:02}.png')
            hashes[str(path.relative_to(OUT))]=sha(path)
        checks.append(di+' 8 RGBA frames, canvas, transparent margins, sheet round-trip, unchanged six PNG byte hashes')
    assert all(np.array_equal(np.array(l),np.array(r.transpose(Image.Transpose.FLIP_LEFT_RIGHT))) for r,l in zip(right,left))
    checks.append('All eight left frames are exact full-frame mirrors of right')
    for name in ['side_walk','side_walk_before_after']:
        for ext in ['gif','webp']:
            im=Image.open(OUT/f'{name}.{ext}');assert im.n_frames==8
            total=0
            for i in range(im.n_frames):
                im.seek(i);im.load();total+=im.info.get('duration',0)
            assert total==(670 if ext=='gif' else 667),(name,ext,total)
    checks.append('Both previews decode to eight frames; WebP 667 ms, GIF 670 ms (10 ms quantization), authored 12 FPS retained')
    save('minimal_verification.json',{'status':'pass','checks':checks,'frameSha256':hashes,
        'changedFramesOneBased':[3,5],'framesChecked':16,'fps':12,'cycleMs':2000/3,
        'visualStatus':'needs-visual-review','sourceEdgeRisks':diag['sourceEdgeRisks'],
        'scope':'Two side walk candidates only. No idle rerun, engine, map, performance, web build or long browser tests.'})
    save('provenance.json',{'route':'host:image_gen + generate2dmedia cli_media.py adopt','imageCalls':1,'videoCalls':0,
        'model':'not exposed','cost':'unknown','license':'Subject to provider and account terms; not asserted public domain or open source.',
        'prompt':'prompt.txt','references':['references/edit_targets_3_5.png','references/context_2_3_4_and_4_5_6.png'],
        'raw':'take1/generated.png','job':'take1/job.json','sourceSha256':sha(take/'generated.png'),
        'registration':'take1/registration.json','selection':'selection.json','status':'needs-visual-review','previewOnly':True,
        'inheritedSources':'../hero_sequence_repair_preview_v05/provenance.json','rejectedTakes':[]})
    print(json.dumps({'status':'pass','frames':16,'changed':[3,5],'scale':scale,'sourceSize':raw.size}))

if __name__=='__main__':main()
