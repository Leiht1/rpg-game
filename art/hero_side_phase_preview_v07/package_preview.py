"""Four complete-pose replacements and small preview-only verification."""
from pathlib import Path
import hashlib,importlib.util,json,shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFont
OUT=Path(__file__).resolve().parent;OLD=OUT.parent/'hero_side_spacing_preview_v06'
spec=importlib.util.spec_from_file_location('norm',OUT/'normalize_takes.py')
M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M);P=M.P
FONT=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
CHANGED={1:'take2',2:'take3',4:'take4',5:'take6'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(name,v):P.save(OUT/name,v)
def animate(name,fs,fps):
    ms=[round((i+1)*1000/fps)-round(i*1000/fps) for i in range(8)]
    ticks=[round((i+1)*100/fps)*10-round(i*100/fps)*10 for i in range(8)]
    fs[0].save(OUT/f'{name}.gif',save_all=True,append_images=fs[1:],duration=ticks,loop=0,disposal=2)
    fs[0].save(OUT/f'{name}.webp',save_all=True,append_images=fs[1:],duration=ms,loop=0,lossless=True)
    return sum(ms),sum(ticks)

def main():
    old=[Image.open(OLD/f'right_walk_preview/frames/right_walk_{i:02}.png').convert('RGBA') for i in range(8)]
    right=[Image.open(OUT/CHANGED[i]/f'frame_{i:02}.png').convert('RGBA') if i in CHANGED else old[i] for i in range(8)]
    left=[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in right]
    for di,fs in [('right',right),('left',left)]:
        folder=OUT/f'{di}_walk_preview';P.sheet(folder,f'{di}_walk',fs,4)
        for i in [0,3,6,7]:
            shutil.copy2(OLD/f'{di}_walk_preview/frames/{di}_walk_{i:02}.png',folder/f'frames/{di}_walk_{i:02}.png')
    contact=Image.new('RGB',(1024,568),'#e2eacb');d=ImageDraw.Draw(contact)
    for i,f in enumerate(right):
        x=i%4*256;y=i//4*284;P.panel(contact,f,x,y+28,256)
        d.text((x+8,y+3),f'v07 · 第 {i+1} 帧',font=FONT,fill='#344539')
    contact.save(OUT/'all_frames_contact.png')
    compare=Image.new('RGB',(1536,568),'#e2eacb');d=ImageDraw.Draw(compare)
    for row,(label,fs) in enumerate([('v06',old),('v07',right)]):
        for i in range(6):
            x=i*256;y=row*284;P.panel(compare,fs[i],x,y+28,256)
            d.text((x+8,y+3),f'{label} · 第 {i+1} 帧',font=FONT,fill='#344539')
    compare.save(OUT/'adjacent_before_after.png')
    seq=[];before_after=[]
    for i in range(8):
        im=Image.new('RGB',(512,468),'#e2eacb');d=ImageDraw.Draw(im)
        for col,(di,fs) in enumerate([('右侧',right),('左侧',left)]):
            P.panel(im,fs[i],col*256,28,256)
            d.rectangle((col*256,284,col*256+256,468),fill='#303b39')
            P.panel(im,fs[i],col*256+64,312,128)
            d.text((col*256+8,3),f'{di} v07 · 第 {i+1} 帧',font=FONT,fill='#344539')
            d.text((col*256+8,286),'游戏原尺寸 1:1',font=FONT,fill='#e2eacb')
        seq.append(im)
        im=Image.new('RGB',(512,284),'#e2eacb');d=ImageDraw.Draw(im)
        for col,(label,f) in enumerate([('v06',old[i]),('v07',right[i])]):
            P.panel(im,f,col*256,28,256);d.text((col*256+8,3),f'{label} · 第 {i+1} 帧',font=FONT,fill='#344539')
        before_after.append(im)
    timings={}
    timings['side_walk_game_speed']=animate('side_walk_game_speed',seq,13.8)
    timings['side_walk_slow']=animate('side_walk_slow',seq,6.9)
    timings['side_walk_reference_12fps']=animate('side_walk_reference_12fps',seq,12)
    timings['side_walk_before_after']=animate('side_walk_before_after',before_after,13.8)
    seq[0].save(OUT/'side_walk_poster.png')
    selection=[]
    for i in range(8):
        selection.append({'frameOneBased':i+1,'outputIndexZeroBased':i,
            'source':f'{CHANGED[i]}/generated.png' if i in CHANGED else f'../hero_side_spacing_preview_v06/right_walk_preview/frames/right_walk_{i:02}.png',
            'registration':f'{CHANGED[i]}/registration.json' if i in CHANGED else 'inherited without resampling'})
    save('selection.json',{'selection':selection,'changedFramesOneBased':[2,3,5,6],
        'unchangedFramesOneBased':[1,4,7,8],'root':[64,112],
        'leftPolicy':'Whole-frame horizontal mirror, identical phase order',
        'runtimePolicy':'Preview only; current game template 4, speed 115 and all idle frames unchanged.'})
    hashes={};checks=[]
    for di,fs in [('right',right),('left',left)]:
        folder=OUT/f'{di}_walk_preview';sheet=Image.open(folder/f'{di}_walk_sheet.png').convert('RGBA')
        for i,f in enumerate(fs):
            path=folder/f'frames/{di}_walk_{i:02}.png';actual=Image.open(path)
            assert actual.mode=='RGBA' and actual.size==(128,128)
            b=P.bbox(actual);assert b and b[0]>0 and b[1]>0 and b[2]<128 and b[3]<128
            assert actual.getchannel('A').getextrema()[0]==0
            assert np.array_equal(np.array(actual),np.array(sheet.crop((i%4*128,i//4*128,i%4*128+128,i//4*128+128))))
            if i not in CHANGED:assert sha(path)==sha(OLD/f'{di}_walk_preview/frames/{di}_walk_{i:02}.png')
            hashes[str(path.relative_to(OUT))]=sha(path)
        checks.append(di+' eight RGBA frames; 128 canvas; transparent safe margins; packed sheet readback; four preserved PNG byte hashes')
    assert all(np.array_equal(np.array(l),np.array(r.transpose(Image.Transpose.FLIP_LEFT_RIGHT))) for r,l in zip(right,left))
    checks.append('All eight left frames are exact full-frame mirrors; no order reversal')
    regs=[json.loads((OUT/t/'registration.json').read_text(encoding='utf-8')) for t in CHANGED.values()]
    assert len({r['globalScale'] for r in regs})==1
    for name,(webp_ms,gif_ms) in timings.items():
        for ext,total_expected in [('gif',gif_ms),('webp',webp_ms)]:
            im=Image.open(OUT/f'{name}.{ext}');assert im.n_frames==8
            total=0
            for i in range(im.n_frames):im.seek(i);im.load();total+=im.info.get('duration',0)
            assert total==total_expected,(name,ext,total,total_expected)
    checks.append('Four paired GIF/WebP previews decode to eight numbered frames at their recorded timing')
    save('minimal_verification.json',{'status':'pass','checks':checks,'frameSha256':hashes,
        'changedFramesOneBased':[2,3,5,6],'framesChecked':16,'fpsGameSpeed115':13.8,
        'authoredReferenceFps':12,'previewTimesWebpGifMs':timings,
        'commonNewSourceScale':regs[0]['globalScale'],
        'visualStatus':'needs-visual-review','sourceEdgeRisks':[],
        'scope':'Side walk preview only. No engine, idle, map, performance, build or long browser test.'})
    save('provenance.json',{'art_source':'host_image','route':'host:image_gen + generate2dmedia cli_media.py adopt',
        'imageCalls':6,'videoCalls':0,'model':'not exposed','cost':'unknown',
        'license':'Subject to provider/account terms; not asserted public domain or open source.',
        'prompts':['prompt.txt','prompt_frame2.txt','prompt_frame3.txt','prompt_frame5.txt','prompt_frame6.txt','prompt_frame6_hand.txt'],
        'references':['references/edit_targets_2_3_5_6.png','references/current_8_frames.png',
            'take1/high_frame_01.png','take1/high_frame_02.png','take1/high_frame_04.png','take1/high_frame_05.png','take5/high_frame_05.png'],
        'sources':[{'raw':f'take{t}/generated.png','job':f'take{t}/job.json','registration':f'take{t}/registration.json',
            'sourceSha256':sha(OUT/f'take{t}/generated.png')} for t in range(1,7)],
        'selection':'selection.json','status':'needs-visual-review','previewOnly':True,
        'inheritedSources':'../hero_side_spacing_preview_v06/provenance.json',
        'rejectedTakes':[{'source':'take1','reason':'Four-pose candidate retained only as editing reference: frame 2 still rear-folded, frame 3 too extended, frame 5 insufficient recovery, frame 6 arm too forward.'},
            {'source':'take5','reason':'Corrected legs retained as reference; near hand too far behind frame 7. take6 corrects complete pose to interpolate hand between frames 5 and 7.'}],
        'normalization':'The four selected 1254px single-pose sources share scale 512/1254/4. Complete-frame rigid registration, no individual body-bbox fitting, limb patch, warp or compositing.'})
    print(json.dumps({'status':'pass','frames':16,'changed':[2,3,5,6],'gamePreviewMs':timings['side_walk_game_speed']}))

if __name__=='__main__':main()
