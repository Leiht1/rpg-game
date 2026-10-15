"""Gorest grid detection + whole-frame fixed-foot registration for preview only."""
from pathlib import Path
import hashlib, importlib.util, json, statistics, zipfile
import numpy as np
from PIL import Image, ImageDraw

OUT=Path(__file__).resolve().parent
PROJECT=OUT.parents[1]
GOREST=Path(r'C:\Users\HT\Documents\Codex\2026-10-15\https-github-com-0x0funky-agent-sprite\outputs\gorest-2d-animation-spritesheet-generator-main')
spec=importlib.util.spec_from_file_location('gorest_normalizer',GOREST/'scripts/normalize_spritesheet.py')
NORMALIZER=importlib.util.module_from_spec(spec); spec.loader.exec_module(NORMALIZER)
# The image editor returned native alpha; do not chroma-key green clothing.
NORMALIZER.remove_chroma_key=lambda im: im.convert('RGBA')
SIZE=128; ANCHOR=(64,112); DURATIONS=[750]*4

def save(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def bbox(im): return im.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()
def clean(im):
    a=np.array(im.convert('RGBA')); a[a[:,:,3]<=8]=0
    return Image.fromarray(a)

def process(direction):
    folder=OUT/direction; raw=folder/'take1/generated.png'
    original=Image.open(raw).convert('RGBA'); im=clean(original)
    im.save(folder/'native_alpha_clean.png')
    # Use the same Gorest grid/feet detector as the accepted walk workflow.
    meta=NORMALIZER.normalize_sheet(folder/'native_alpha_clean.png',folder/'gorest_normalized_diagnostic.png',
        2,2,SIZE,SIZE,f'/generated/windrest_hero_{direction}_idle_breathe_v01.png',
        safe_padding=15,anchor_mode='feet-baseline')
    save(folder/'gorest_normalization_diagnostic.json',meta)
    cells=[im.crop(tuple(c)) for c in meta['sourceCells']]
    bounds=[bbox(c) for c in cells]
    anchors=[NORMALIZER.feet_baseline_anchor(c.getchannel('A'),b) for c,b in zip(cells,bounds)]
    master=Image.open(OUT/f'references/{direction}_idle_master.png').convert('RGBA')
    master_box=bbox(master)
    # One scale from the original standing reference height, shared by all four poses.
    scale=(master_box[3]-master_box[1])/statistics.median(b[3]-b[1] for b in bounds)
    frames=[]; transforms=[]
    for i,(cell,anchor) in enumerate(zip(cells,anchors)):
        resized=cell.convert('RGBa').resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.LANCZOS).convert('RGBA')
        scaled_box=bbox(resized)
        # Register the resampled sole edge, avoiding a one-pixel rounding drift.
        position=(round(ANCHOR[0]-anchor[0]*scale),ANCHOR[1]-scaled_box[3])
        frame=Image.new('RGBA',(SIZE,SIZE)); frame.alpha_composite(resized,position)
        assert np.count_nonzero(np.array(resized)[:,:,3]>16)==np.count_nonzero(np.array(frame)[:,:,3]>16),'Visible clipping'
        frame=clean(frame)
        frames.append(frame)
        transforms.append({'source_frame':i,'source_cell':meta['sourceCells'][i],
            'source_feet_anchor':anchor,'source_to_output_scale':scale,'offset':position,'output_anchor':ANCHOR})
    final_meta={**meta,'globalScale':scale,'rootAnchorPolicy':'fixed_lower_body_centroid_x_and_resampled_visible_sole_baseline_64_112',
        'normalization':'gorest_grid_and_feet_detector_native_alpha_one_scale_from_existing_idle_height',
        'rootAnchors':[list(ANCHOR)]*4,'frameBboxes':[list(bbox(f)) for f in frames],
        'transforms':transforms,'alphaPolicy':'native_alpha; only alpha <= 8 cleared; no chroma key',
        'sourceSha256':sha(raw),'referenceSha256':sha(OUT/f'references/{direction}_idle_master.png'),
        'frameSize':[SIZE,SIZE],'sheetSize':[SIZE*2,SIZE*2],
        'frame00Policy':'model-generated neutral extension from current idle, not byte-identical source copy',
        'previewOnly':True,'status':'needs-visual-review','fps':4/3,'cycleMs':3000}
    return frames,final_meta

def metrics(frames):
    arrays=[np.array(f) for f in frames]; bounds=[bbox(f) for f in frames]
    def centroid(a,y0,y1):
        alpha=a[y0:y1,:,3].astype(float); yy,xx=np.indices(alpha.shape)
        return [float((xx*alpha).sum()/alpha.sum()),float((yy*alpha).sum()/alpha.sum()+y0)]
    foot=[centroid(a,94,116) for a in arrays]; heads=[centroid(a,15,52) for a in arrays]
    # Premultiplied pixel differences, all comparison regions remain fixed in canvas space.
    premul=[np.concatenate((a[:,:,:3]*(a[:,:,3:4]/255),a[:,:,3:4]),axis=2) for a in arrays]
    steps=[float(np.abs(premul[i]-premul[(i+1)%4]).mean()) for i in range(4)]
    return {'status':'needs-visual-review','frameCount':4,'uniqueFrameCount':len({a.tobytes() for a in arrays}),
        'canvas':[SIZE,SIZE],'anchor':list(ANCHOR),'cycleMs':3000,'durationsMs':DURATIONS,
        'bounds':bounds,'minimumAlphaMargin':min(min(b[0],b[1],SIZE-b[2],SIZE-b[3]) for b in bounds),
        'bodyHeights':[b[3]-b[1] for b in bounds],
        'soleBottomRangePx':max(b[3] for b in bounds)-min(b[3] for b in bounds),
        'footCentroids':foot,'footCentroidRangePx':np.ptp(np.array(foot),axis=0).tolist(),
        'headCentroids':heads,'headCentroidRangePx':np.ptp(np.array(heads),axis=0).tolist(),
        'adjacentPremultipliedMeanDifferences':steps,
        'wrapOverMedianAdjacent':steps[-1]/max(1e-8,statistics.median(steps)),
        'notProven':['Numerical geometry does not certify breathing, nodding or zero foot sliding.',
            'Generated neutral is based on current idle but has small redraw differences.']}

def output_direction(direction,frames,meta):
    folder=OUT/direction; (folder/'frames').mkdir(exist_ok=True)
    sheet=Image.new('RGBA',(256,256))
    for i,frame in enumerate(frames):
        frame.save(folder/'frames'/f'{direction}_idle_breathe_{i:02}.png')
        sheet.alpha_composite(frame,((i%2)*128,(i//2)*128))
    sheet.save(folder/f'{direction}_idle_breathe_sheet.png')
    href=f'/generated/windrest_hero_{direction}_idle_breathe_v01.png'
    meta['frames']=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{(i%2)*128} {(i//2)*128} 128 128" width="128" height="128"><image href="{href}" x="0" y="0" width="256" height="256" preserveAspectRatio="none"/></svg>' for i in range(4)]
    save(folder/'normalization.json',meta)
    qa=metrics(frames); save(folder/'qa.json',qa)
    previews=[]
    for i,frame in enumerate(frames):
        p=Image.new('RGB',(512,282),'#dce6c8'); d=ImageDraw.Draw(p)
        d.rectangle((256,0,512,282),fill='#303a3c')
        for x in [0,256]:
            d.text((x+10,8),f'{direction} idle breathe {i:02} | 3s cycle',fill='#647156' if x==0 else '#e5eaca')
            large=frame.resize((256,256),Image.Resampling.LANCZOS); p.paste(large,(x,24),large)
        previews.append(p)
    previews[0].save(folder/f'{direction}_idle_breathe_preview.gif',save_all=True,append_images=previews[1:],duration=DURATIONS,loop=0,disposal=2)
    previews[0].save(folder/f'{direction}_idle_breathe_preview.webp',save_all=True,append_images=previews[1:],duration=DURATIONS,loop=0,lossless=True)
    return qa

def main():
    clips={}; frames_by={}; summary={}
    for direction in ['front','back','side']:
        frames,meta=process(direction); frames_by[direction]=frames
        summary[direction]=output_direction(direction,frames,meta)
    frames_by['right']=frames_by['side']
    right_meta=json.loads((OUT/'side/normalization.json').read_text(encoding='utf-8'))
    (OUT/'right').mkdir(exist_ok=True); summary['right']=output_direction('right',frames_by['right'],{**right_meta,'derivation':'same as side'})
    frames_by['left']=[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in frames_by['side']]
    (OUT/'left').mkdir(exist_ok=True); summary['left']=output_direction('left',frames_by['left'],{**right_meta,'derivation':'complete-frame horizontal mirror of side; source order unchanged'})
    combined=[]; real_size=[]; contact=Image.new('RGB',(5*256,4*282),'#dce6c8')
    labels=ImageDraw.Draw(contact)
    for row,direction in enumerate(['front','back','left','right']):
        reference=Image.open(OUT/f'references/{"side" if direction in ["left","right"] else direction}_idle_master.png').convert('RGBA')
        if direction=='left': reference=reference.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        for col,f in enumerate([reference]+frames_by[direction]):
            large=f.resize((256,256),Image.Resampling.LANCZOS)
            contact.paste(large,(col*256,row*282+24),large)
            labels.text((col*256+8,row*282+5),f'{direction} '+('existing idle' if col==0 else f'breathe {col-1:02}'),fill='#45543c')
    contact.save(OUT/'reference_and_breathe_contact.png')
    for i in range(4):
        p=Image.new('RGB',(768,440),'#dce6c8'); d=ImageDraw.Draw(p)
        small=Image.new('RGB',(512,154),'#dce6c8'); sd=ImageDraw.Draw(small)
        for row,color in enumerate(['#dce6c8','#303a3c']):
            d.rectangle((0,row*220,768,(row+1)*220),fill=color)
            for col,direction in enumerate(['front','back','left','right']):
                f=frames_by[direction][i]; large=f.resize((192,192),Image.Resampling.LANCZOS)
                p.paste(large,(col*192,row*220+24),large)
                d.text((col*192+10,row*220+8),f'{direction} | {i:02}',fill='#647156' if row==0 else '#e5eaca')
        for col,direction in enumerate(['front','back','left','right']):
            f=frames_by[direction][i]; small.paste(f,(col*128,22),f); sd.text((col*128+5,5),direction,fill='#45543c')
        combined.append(p); real_size.append(small)
    for name,images in [('four_directions_preview',combined),('game_size_preview',real_size)]:
        images[0].save(OUT/f'{name}.gif',save_all=True,append_images=images[1:],duration=DURATIONS,loop=0,disposal=2)
        images[0].save(OUT/f'{name}.webp',save_all=True,append_images=images[1:],duration=DURATIONS,loop=0,lossless=True)
    (OUT/'four_directions_still.png').write_bytes((OUT/'reference_and_breathe_contact.png').read_bytes())
    for direction in ['front','back','right','left']:
        name=f'{direction}_idle_breathe'
        clips[name]={'frames':[f'{direction}_{i:02}' for i in range(4)],'ticks':45,'loop_policy':'cycle','role':'player','entry_frame':0}
    manifest={'schema':'generate2dsprite.animation_clips.v2','name':'windrest-idle-breathe-preview',
        'frames':[{'name':f'{d}_{i:02}','file':f'{d}/frames/{d}_idle_breathe_{i:02}.png'} for d in ['front','back','right','left'] for i in range(4)],
        'anchor_px':list(ANCHOR),'sampling':'linear','pixel_art':False,'art_source':'host_image',
        'body_height_px':89,'placeholder':False,'clips':clips}
    save(OUT/'clips-manifest.json',manifest); save(OUT/'qa_summary.json',summary)
    save(OUT/'provenance.json',{'route':'host:image_gen transparent identity-preserving edit + generate2dmedia cli_media.py adopt',
        'underlyingModel':'not exposed','estimateUsd':None,'generationCalls':3,'videoGenerated':False,
        'generatedArt':'three independently edited 2x2 complete-body breathing sequences; left whole-frame mirror',
        'gorestUsed':'normalize_spritesheet.py grid detection and feet-baseline anchor; native alpha preserved',
        'source_refs':{d:sha(OUT/f'references/{d}_idle_master.png') for d in ['front','back','side']},
        'noCreativeLocalPixelEdits':True,'noPerFrameScaling':True,'runtimeIntegrated':False})
    print(json.dumps({d:{k:v[k] for k in ['uniqueFrameCount','bodyHeights','soleBottomRangePx','footCentroidRangePx','headCentroidRangePx']} for d,v in summary.items()}))

if __name__=='__main__': main()
