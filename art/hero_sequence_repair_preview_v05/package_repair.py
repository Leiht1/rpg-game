from pathlib import Path
import importlib.util,json,hashlib,shutil
import numpy as np
from PIL import Image,ImageDraw
OUT=Path(__file__).resolve().parent;OLD=OUT.parent/'hero_consistency_preview_v04'
spec=importlib.util.spec_from_file_location('normal',OUT/'normalize_side.py')
N=importlib.util.module_from_spec(spec);spec.loader.exec_module(N)
R=N.R;P=R.P
def cached(take,index):return Image.open(OUT/'side_walk'/take/f'frame_{index:02}.png').convert('RGBA')

def final_side():
    half,cells,ts=N.source('take3',2,2)
    folder=OUT/'side_walk/take4';raw=P.clean(Image.open(folder/'generated.png'))
    # The singleton is an edit of a full cell of take2. Transfer that cell's
    # canvas scale, never fit the new pose to its alpha body bounding box.
    parent=Image.open(OUT/'side_walk/take2/cell_02.png')
    parent_meta=json.loads((OUT/'side_walk/take2/registration.json').read_text())
    canvas_ratio=(parent.width/raw.width*parent.height/raw.height)**.5
    scale=parent_meta['scale']*canvas_ratio
    ax,ay=P.W.head_anchor(raw);offset=[61-ax*scale,20-ay*scale]
    single=P.clean(P.W.render(raw,scale,offset,512).convert('RGBa').resize((128,128),Image.Resampling.LANCZOS).convert('RGBA'))
    P.save(folder/'registration.json',{'reference':'../take2/cell_02.png','canvasRatio':canvas_ratio,
        'parentGlobalScale':parent_meta['scale'],'scale':scale,'offsetPx':offset,
        'policy':'Whole reference-cell canvas mapping, then parent common scale; no per-pose alpha-bbox scale.'})
    old=R.frames('right','walk')
    fs=[old[0],old[1],cached('take1',2),old[3],half[0],half[1],single,half[3]]
    P.sheet(OUT/'right_walk_preview','right_walk',fs,4)
    P.sheet(OUT/'left_walk_preview','left_walk',[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in fs],4)
    selection=[{'frame':i+1,'source':s} for i,s in enumerate([
        'v04/right_walk_00.png','v04/right_walk_01.png','take1 cell 2','v04/right_walk_03.png',
        'take3 cell 0','take3 cell 1','take4 cell 0','take3 cell 3'])]
    P.save(OUT/'side_walk/selection.json',{'selection':selection,'unchangedV04Frames':[1,2,4],
        'repairedFrames':[3,5,6,7,8],'root':[64,112],
        'policy':'Complete frames only; original unchanged frames retained byte-for-byte; one common scale per source sheet; singleton inherits reference-cell canvas scale.'})
    return fs

def animate(name,fs,durations):
    boundaries=[0]+np.cumsum(durations).tolist()
    gif=[round(boundaries[i+1]/10)*10-round(boundaries[i]/10)*10 for i in range(len(durations))]
    fs[0].save(OUT/f'{name}.gif',save_all=True,append_images=fs[1:],duration=gif,loop=0,disposal=2)
    fs[0].save(OUT/f'{name}.webp',save_all=True,append_images=fs[1:],duration=durations,loop=0,lossless=True)

def previews(side):
    old=R.frames('right','walk');rows=[]
    for title,fs in [('v04',old),('v05',side)]:
        rows += [(f'{title} 1-4',fs[:4]),(f'{title} 5-8',fs[4:])]
    R.contact('side_frame_review.png',rows,size=320)
    fs=[]
    for i in range(8):
        im=Image.new('RGB',(768,406),'#e2eacb');d=ImageDraw.Draw(im)
        for col,(title,f) in enumerate([('v04 修改前',old[i]),('v05 手脚修正',side[i])]):
            P.panel(im,f,col*384,22,384);d.text((col*384+12,3),f'{title} · 第 {i+1} 帧',font=R.FONT,fill='#344539')
        fs.append(im)
    animate('side_walk_before_after',fs,[83,84,83,83,84,83,83,84])
    # True-size and enlarged walk together, with visible frame number.
    fs=[]
    for i,f in enumerate(side):
        im=Image.new('RGB',(512,412),'#e2eacb');d=ImageDraw.Draw(im)
        P.panel(im,f,0,28,384);P.panel(im,f,384,120,128)
        d.text((12,3),f'侧视 v05 · 第 {i+1} 帧 / 8 · 12 FPS',font=R.FONT,fill='#344539')
        fs.append(im)
    animate('side_walk',fs,[83,84,83,83,84,83,83,84])
    dirs=['front','back','left','right'];seq=[]
    for i in range(4):
        im=Image.new('RGB',(1024,584),'#e2eacb');d=ImageDraw.Draw(im)
        for x,di in enumerate(dirs):
            f=R.frames(di,'idle',OUT)[i]
            for row,color in enumerate(['#e2eacb','#303b39']):
                y=row*292;d.rectangle((x*256,y,(x+1)*256,y+292),fill=color)
                P.panel(im,f,x*256,y+28,256)
                d.text((x*256+8,y+4),f'{P.LABELS[di]}呼吸 · 第 {i+1} 帧',font=R.FONT,fill='#344539' if row==0 else '#e4edcc')
                # Ground marker is preview only, never added to sprite alpha.
                d.line((x*256+90,y+252,x*256+170,y+252),fill='#ae7851' if row==0 else '#e1b880',width=1)
        seq.append(im)
    animate('four_directions_idle',seq,[450]*4)

def minimal_check():
    checks={};all_frames={}
    for di,action,count in [('right','walk',8),('left','walk',8)]+[(di,'idle',4) for di in ['front','back','left','right']]:
        fs=R.frames(di,action,OUT);assert len(fs)==count
        sheet=Image.open(OUT/f'{di}_{action}_preview/{di}_{action}_sheet.png').convert('RGBA');cols=4 if action=='walk' else 2
        for i,f in enumerate(fs):
            assert f.mode=='RGBA' and f.size==(128,128)
            a=np.array(f)[:,:,3];assert not np.any(a[[0,-1],:]) and not np.any(a[:,[0,-1]])
            assert sheet.crop((i%cols*128,i//cols*128,i%cols*128+128,i//cols*128+128)).tobytes()==f.tobytes()
        checks[f'{di}_{action}']={'frames':count,'bboxes':[P.bbox(f) for f in fs],'pngSheetRoundtrip':True}
        all_frames[di,action]=fs
    for action,count in [('walk',8),('idle',4)]:
        assert all(l.tobytes()==r.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes() for l,r in zip(all_frames['left',action],all_frames['right',action]))
    old=R.frames('right','walk');assert all(old[i].tobytes()==all_frames['right','walk'][i].tobytes() for i in [0,1,3])
    assert all(a.tobytes()==b.tobytes() for a,b in zip(R.frames('back','idle'),all_frames['back','idle']))
    P.save(OUT/'minimal_verification.json',{'checks':checks,'leftRightMirror':True,'unchangedWalkFrames':[1,2,4],
        'backIdleUnchanged':True,'noGodotOrMapTests':True,'status':'technical_checks_pass_needs_user_visual_review'})
    manifest={'schema':'generate2dsprite.animation_clips.v2','frames':[],'anchor_px':[64,112],
        'clips':{},'sampling':'linear','pixel_art':False,'art_source':'host_image','body_height_px':92}
    for di,action in all_frames:
        ids=[]
        for p in sorted((OUT/f'{di}_{action}_preview/frames').glob('*.png')):
            ids.append(len(manifest['frames']));manifest['frames'].append(str(p.relative_to(OUT)).replace('\\','/'))
        manifest['clips'][f'{di}_{action}']={'frames':ids,'ticks':27 if action=='idle' else 5,
            'tick_hz':60,'loop_policy':'cycle','entry_frame':0,'role':'player'}
    P.save(OUT/'clips_input.json',manifest)
    print('Minimal image checks pass; 32 frames / 6 previews. No game test.')

if __name__=='__main__':
    side=final_side();previews(side);minimal_check()
