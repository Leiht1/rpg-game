"""Register complete images, preserve native alpha, package review-only clips."""
from pathlib import Path
import hashlib, json, importlib.util
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage, optimize

OUT=Path(__file__).resolve().parent; ROOT=OUT.parents[1]
spec=importlib.util.spec_from_file_location('walks',OUT/'normalize_walks.py')
W=importlib.util.module_from_spec(spec); spec.loader.exec_module(W)
N=W.N; clean=W.clean; bbox=W.bbox; save=W.save
FONT=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
FONT_SM=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',14)
LABELS={'front':'正面','back':'背面','left':'左侧','right':'右侧'}
DIRS=['front','back','left','right']

def feat(im):
    a=np.array(im,dtype=float)/255
    return np.concatenate([a[:,:,:3]*a[:,:,3:4],a[:,:,3:4]],axis=2)

def residual(ref,other,y0,y1):
    r=feat(ref); a=feat(other); mask=np.zeros((128,128),bool)
    mask[y0:y1,20:110]=True; mask&=(r[:,:,3]>.03)|(a[:,:,3]>.03)
    def cost(delta):
        shifted=ndimage.shift(a,(delta[1],delta[0],0),order=1,mode='constant',prefilter=False)
        return float(np.mean((r-shifted)[mask]**2))
    fit=optimize.minimize(cost,[0,0],method='Powell',bounds=[(-3,3),(-3,3)],options={'xtol':.003})
    return {'bestRigidResidualShiftPx':fit.x.round(3).tolist(),'zeroShiftRms':round(cost([0,0])**.5,6)}

def process_breathe(direction):
    folder=OUT/f'{direction}_breathe'; take={'front':'take1','back':'take1','side':'take2'}[direction]
    source=folder/take/'generated.png'
    raw=clean(Image.open(source)); raw.save(folder/'native_alpha_clean.png')
    diag=N.normalize_sheet(folder/'native_alpha_clean.png',folder/'gorest_diagnostic.png',2,2,128,128,
                           f'/generated/v04_{direction}_breathe.png',safe_padding=12,anchor_mode='feet-baseline')
    assert not diag['sourceEdgeRisks']; save(folder/'gorest_diagnostic.json',diag)
    cells=[raw.crop(tuple(b)) for b in diag['sourceCells']]; boxes=[bbox(c) for c in cells]
    scale=float(92/np.median([b[3]-b[1] for b in boxes]))
    offsets=[]
    for c,b in zip(cells,boxes):
        hx,hy=W.head_anchor(c)
        offsets.append(np.array([(61 if direction=='side' else 64)-hx*scale,112-b[3]*scale]))
    def render(c,off):
        return clean(W.render(c,scale,off,512).convert('RGBa').resize((128,128),Image.Resampling.LANCZOS).convert('RGBA'))
    first=render(cells[0],offsets[0]); r=feat(first)
    mask=np.zeros((128,128),bool); mask[19:49,20:110]=True; mask[82:116,20:110]=True
    mask&=ndimage.binary_dilation(r[:,:,3]>.03,iterations=2)
    frames=[first]; transforms=[]
    for i,c in enumerate(cells):
        if i==0: delta=np.array([0.,0.]); objective=0.
        else:
            initial=offsets[i].copy()
            def cost(delta):return float(np.mean((feat(render(c,initial+delta))-r)[mask]**2))
            fit=optimize.minimize(cost,[0,0],method='Powell',bounds=[(-2,2),(-2,2)],options={'xtol':.003,'maxiter':30})
            delta=fit.x; objective=float(fit.fun); offsets[i]=initial+delta
            frames.append(render(c,offsets[i]))
        transforms.append({'sourceCell':diag['sourceCells'][i],'scale':scale,'offsetPx':offsets[i].tolist(),
                           'staticRegionRegistrationDeltaPx':delta.tolist(),'objective':objective})
    meta={**diag,'globalScale':scale,'sourceSha256':W.sha(source),'transforms':transforms,
          'root':[64,112],'selectedTake':take,'sourceOrder':[0,1,2,3],'frameBboxes':[bbox(f) for f in frames],
          'frameCount':4,'cycleMs':1800,'fps':20/9,'status':'needs-visual-review','previewOnly':True,
          'policy':'One common scale per direction from median 92px body height. Whole-frame rigid translation to static head/legs only. No local redraw, warp, cut/paste or per-frame scale.'}
    save(folder/'normalization.json',meta)
    print(direction,'breath scale',round(scale,6),'bboxes',meta['frameBboxes'])
    return frames

def sheet(folder,name,frames,cols):
    folder.mkdir(exist_ok=True); (folder/'frames').mkdir(exist_ok=True)
    out=Image.new('RGBA',(128*cols,128*((len(frames)+cols-1)//cols)))
    for i,f in enumerate(frames):
        f.save(folder/'frames'/f'{name}_{i:02}.png'); out.alpha_composite(f,(i%cols*128,i//cols*128))
    out.save(folder/f'{name}_sheet.png')

def old_frames(direction,action):
    sd=direction if direction in ['front','back'] else 'side'
    frames=[Image.open(p).convert('RGBA') for p in sorted((ROOT/'assets/hero/animation'/f'{sd}_{action}').glob('*.png'))]
    if not frames:
        # Runtime stores all canonical frame files together on current template.
        frames=[Image.open(p).convert('RGBA') for p in sorted((ROOT/'assets/hero/animation').rglob(f'{sd}_{action}_*.png'))]
    if not frames:
        frames=[Image.open(p).convert('RGBA') for p in sorted((ROOT/'assets/hero').rglob(f'{sd}_{action}_*.png'))]
    assert len(frames)==(4 if action=='idle' else 8),(direction,action,len(frames))
    if direction=='left':frames=[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in frames]
    return frames

def panel(im,frame,x,y,size=256):
    f=frame.resize((size,size),Image.Resampling.LANCZOS); im.paste(f,(x,y),f)

def animate(name,frames,durations):
    boundaries=[0]+np.cumsum(durations).tolist()
    gif_durations=[round(boundaries[i+1]/10)*10-round(boundaries[i]/10)*10 for i in range(len(durations))]
    frames[0].save(OUT/f'{name}.gif',save_all=True,append_images=frames[1:],duration=gif_durations,loop=0,disposal=2)
    frames[0].save(OUT/f'{name}.webp',save_all=True,append_images=frames[1:],duration=durations,loop=0,lossless=True)

def previews(all_frames):
    for action,count in [('idle',4),('walk',8)]:
        seq=[]
        for i in range(count):
            im=Image.new('RGB',(1024,584),'#e2eacb'); d=ImageDraw.Draw(im)
            for col,direction in enumerate(DIRS):
                for row,color in enumerate(['#e2eacb','#303b39']):
                    x=col*256; y=row*292; d.rectangle((x,y,x+256,y+292),fill=color)
                    panel(im,all_frames[direction,action][i],x,y+28)
                    d.text((x+10,y+5),f'{LABELS[direction]} {"呼吸" if action=="idle" else "行走"} · {i+1:02}',font=FONT,fill='#344539' if row==0 else '#e4edcc')
            seq.append(im)
        animate(f'four_directions_{action}',seq,[450]*4 if action=='idle' else [83,84,83,83,84,83,83,84])
        seq[0].save(OUT/f'four_directions_{action}_poster.png')
    # Every neutral breath pose beside all eight walk poses, without recentering or resizing individual frames.
    contact=Image.new('RGB',(12*192,4*222),'#e2eacb'); d=ImageDraw.Draw(contact)
    for row,direction in enumerate(DIRS):
        for col,f in enumerate(all_frames[direction,'idle']+all_frames[direction,'walk']):
            x=col*192; y=row*222; panel(contact,f,x,y+27,192)
            d.text((x+6,y+4),f'{LABELS[direction]} {"呼吸" if col<4 else "行走"}{col if col<4 else col-4:02}',font=FONT_SM,fill='#344539')
    contact.save(OUT/'all_frames_contact.png')
    # 1800ms idle then 1333ms walk, 60Hz timeline; no crossfade hiding a scale difference.
    seq=[]
    for tick in range(188):
        action='idle' if tick<108 else 'walk'; index=(tick//27)%4 if action=='idle' else ((tick-108)//5)%8
        im=Image.new('RGB',(1024,302),'#e2eacb'); d=ImageDraw.Draw(im)
        for col,direction in enumerate(DIRS):
            x=col*256; panel(im,all_frames[direction,action][index],x,35)
            d.text((x+9,7),f'{LABELS[direction]} · {"呼吸" if action=="idle" else "行走"}',font=FONT,fill='#344539')
        seq.append(im)
    durations=[round((i+1)*1000/60)-round(i*1000/60) for i in range(188)]
    # WebP keeps the 60Hz timing; GIF below uses authored holds to avoid GIF 10ms quantization drift.
    seq[0].save(OUT/'idle_walk_switch.webp',save_all=True,append_images=seq[1:],duration=durations,loop=0,lossless=True)
    held=[seq[i] for i in [0,27,54,81]+list(range(108,188,5))]
    animate('idle_walk_switch',held,[450]*4+[round((i+1)*1000/12)-round(i*1000/12) for i in range(16)])
    # Matched-clock old/new side stride comparison.
    old=old_frames('right','walk'); side=[]
    for i in range(8):
        im=Image.new('RGB',(768,408),'#e2eacb'); d=ImageDraw.Draw(im)
        for col,(title,f) in enumerate([('调整前：原步幅',old[i]),('调整后：收小步幅',all_frames['right','walk'][i])]):
            panel(im,f,col*384,25,384); d.text((col*384+18,4),f'{title} · {i+1:02}',font=FONT,fill='#344539')
        side.append(im)
    animate('side_walk_before_after',side,[83,84,83,83,84,83,83,84]); side[0].save(OUT/'side_walk_before_after_poster.png')
    # Full-body before/after master comparison, plus true 1x canvas previews.
    im=Image.new('RGB',(4*384,488),'#e2eacb'); d=ImageDraw.Draw(im)
    for col,direction in enumerate(DIRS):
        for half,(title,f) in enumerate([('原呼吸',old_frames(direction,'idle')[0]),('新呼吸',all_frames[direction,'idle'][0])]):
            panel(im,f,col*384+half*192,30,192)
            d.text((col*384+half*192+5,5),f'{LABELS[direction]} {title}',font=FONT_SM,fill='#344539')
        panel(im,all_frames[direction,'idle'][0],col*384+32,239,128)
        panel(im,all_frames[direction,'walk'][0],col*384+208,239,128)
        d.text((col*384+16,384),'下排：新呼吸 / 新行走 · 游戏原尺寸',font=FONT_SM,fill='#344539')
    im.save(OUT/'scale_eyes_head_comparison.png')

def main():
    all_frames={}; qa={}; manifest={'schema':'generate2dsprite.animation_clips.v2','frames':[],
        'anchor_px':[64,112],'clips':{},'sampling':'linear','pixel_art':False,'art_source':'host_image','body_height_px':92}
    canonical={}
    for direction in ['front','back','side']:
        canonical[direction,'idle']=process_breathe(direction)
        canonical[direction,'walk']=[Image.open(p).convert('RGBA') for p in sorted((OUT/f'{direction}_walk/frames').glob('*.png'))]
    for direction in DIRS:
        sd=direction if direction in ['front','back'] else 'side'
        for action in ['idle','walk']:
            frames=canonical[sd,action]
            if direction=='left':frames=[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in frames]
            all_frames[direction,action]=frames; folder=OUT/f'{direction}_{action}_preview'; name=f'{direction}_{action}'
            sheet(folder,name,frames,2 if action=='idle' else 4)
            ids=[]
            for i,f in enumerate(frames):
                assert f.mode=='RGBA' and f.size==(128,128)
                alpha=np.array(f)[:,:,3]; assert alpha.min()==0 and alpha.max()>0
                assert not np.any(alpha[[0,-1],:]) and not np.any(alpha[:,[0,-1]])
                ids.append(len(manifest['frames'])); manifest['frames'].append(f'{folder.name}/frames/{name}_{i:02}.png')
            manifest['clips'][name]={'frames':ids,'ticks':27 if action=='idle' else 5,'tick_hz':60,
                'loop_policy':'cycle','entry_frame':0,'role':'player'}
            if action=='walk':manifest['clips'][name].update({'stride_world_units':200/3,'speed_ref':100})
            q={'status':'needs-visual-review','frameBboxes':[bbox(f) for f in frames],
               'uniqueFrames':len({f.tobytes() for f in frames}),'root':[64,112],'frameHashes':[hashlib.sha256(f.tobytes()).hexdigest() for f in frames]}
            if action=='idle':
                q.update({'headResidual':[residual(frames[0],f,19,49) for f in frames],
                    'legsResidual':[residual(frames[0],f,82,116) for f in frames],
                    'chestRms':[float(np.sqrt(np.mean((feat(f)[52:77]-feat(frames[0])[52:77])**2))) for f in frames],
                    'notProven':'Static-region fits do not establish zero drift, unchanged anatomy, natural motion or exact palette identity.'})
            if action=='walk' and direction=='right':
                def span(f):
                    a=np.array(f.getchannel('A')); y,x=np.where(a[99:114]>16); return int(x.max()-x.min()+1)
                q['bootBand99to114SpanPx']=[span(f) for f in frames]
                q['oldBootBandSpanPx']=[span(f) for f in old_frames('right','walk')]
                q['measurementLimit']='Whole lower-boot alpha envelope, includes overlap and contour; not anatomical ankle travel.'
            qa[name]=q; save(folder/'qa.json',q)
    save(OUT/'clips_input.json',manifest); save(OUT/'qa_summary.json',qa); previews(all_frames)
    for name,q in qa.items():
        print(name,'unique',q['uniqueFrames'],'head', [a['bestRigidResidualShiftPx'] for a in q.get('headResidual',[])],
              'legs',[a['bestRigidResidualShiftPx'] for a in q.get('legsResidual',[])])
    plan=json.loads((OUT/'plan.json').read_text(encoding='utf-8-sig')); plan['status']='packaged_needs_visual_review'
    plan['completedImageGenerations']=8; plan['generationModel']='not exposed by host'; plan['generationCost']='unknown; adoption receipt is not generation billing'
    plan['selectedBreathTakes']={'front':'take1','back':'take1','side':'take2'}
    plan['rejectedRefinement']='front take2 did not improve static-region residual (0.852px vs 0.766px), so take1 retained; not claimed as a stability improvement'
    save(OUT/'plan.json',plan)

if __name__=='__main__':main()
