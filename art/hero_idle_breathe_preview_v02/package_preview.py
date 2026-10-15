"""Complete-frame rigid registration to static head/legs; generated chest art only."""
from pathlib import Path
import hashlib, importlib.util, json, statistics
import numpy as np
from scipy import ndimage, optimize
from PIL import Image, ImageDraw
OUT=Path(__file__).resolve().parent; OLD=OUT.parent/'hero_idle_breathe_preview_v01'
APP=Path(r'C:\Users\HT\Documents\Codex\2026-10-15\https-github-com-0x0funky-agent-sprite\outputs\gorest-2d-animation-spritesheet-generator-main')
spec=importlib.util.spec_from_file_location('gorest',APP/'scripts/normalize_spritesheet.py')
N=importlib.util.module_from_spec(spec); spec.loader.exec_module(N)
N.remove_chroma_key=lambda im: im.convert('RGBA')
def save(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def bbox(im): return im.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()
def clean(im):
    a=np.array(im.convert('RGBA')); a[a[:,:,3]<=8]=0
    return Image.fromarray(a)
def render(cell,scale,offset):
    # Whole-frame scale+translation in one high-resolution premultiplied sample.
    hi=cell.convert('RGBa').transform((512,512),Image.Transform.AFFINE,
        (1/(scale*4),0,-offset[0]/scale,0,1/(scale*4),-offset[1]/scale),Image.Resampling.BICUBIC)
    return clean(hi.resize((128,128),Image.Resampling.LANCZOS).convert('RGBA'))
def features(im):
    a=np.array(im).astype(np.float32)/255; rgb=a[:,:,:3]*a[:,:,3:4]
    return np.concatenate([rgb,a[:,:,3:4]],axis=2)
def region_residual(reference,other,y0,y1):
    r=features(reference); a=features(other)
    mask=np.zeros((128,128),bool); mask[y0:y1,24:105]=True
    mask&=(r[:,:,3]>0.03)|(a[:,:,3]>0.03)
    def cost(shift):
        moved=ndimage.shift(a,(shift[1],shift[0],0),order=1,mode='constant',prefilter=False)
        return float(np.mean((r-moved)[mask]**2))
    fit=optimize.minimize(cost,[0,0],method='Powell',bounds=[(-2,2),(-2,2)],options={'xtol':0.001})
    return {'bestRigidResidualShiftPx':[round(float(v),4) for v in fit.x],
            'zeroShiftRms':round(float(np.sqrt(cost([0,0]))),6)}
def process(direction):
    folder=OUT/direction; source=folder/'take1/generated.png'; raw=clean(Image.open(source))
    raw.save(folder/'native_alpha_clean.png')
    diag=N.normalize_sheet(folder/'native_alpha_clean.png',folder/'gorest_diagnostic.png',2,2,128,128,
        f'/generated/windrest_hero_{direction}_idle_breathe_v02.png',safe_padding=16,anchor_mode='feet-baseline')
    assert not diag['sourceEdgeRisks']
    save(folder/'gorest_diagnostic.json',diag)
    cells=[raw.crop(tuple(b)) for b in diag['sourceCells']]
    boxes=[bbox(c) for c in cells]
    reference=Image.open(OUT/f'references/{direction}_existing_idle.png').convert('RGBA')
    rb=bbox(reference); scale=(rb[3]-rb[1])/(boxes[0][3]-boxes[0][1])
    anchors=[N.feet_baseline_anchor(c.getchannel('A'),b) for c,b in zip(cells,boxes)]
    offsets=[np.array([64-an[0]*scale,112-b[3]*scale]) for an,b in zip(anchors,boxes)]
    first=render(cells[0],scale,offsets[0]); r=features(first)
    mask=np.zeros((128,128),bool); mask[15:51,24:105]=True; mask[81:116,24:105]=True
    mask&=ndimage.binary_dilation(r[:,:,3]>0.03,iterations=2)
    frames=[first]; fits=[{'rigidOffsetPx':[0,0],'objective':0}]
    for i in range(1,4):
        # Use a subpixel translation of the ENTIRE generated frame; no local cut/paste/warp.
        initial=offsets[i].copy()
        def objective(delta):
            candidate=features(render(cells[i],scale,initial+delta))
            return float(np.mean((candidate-r)[mask]**2))
        fit=optimize.minimize(objective,[0,0],method='Powell',bounds=[(-2,2),(-2,2)],options={'xtol':0.003,'maxiter':35})
        offsets[i]=initial+fit.x; frames.append(render(cells[i],scale,offsets[i]))
        fits.append({'rigidOffsetPx':fit.x.tolist(),'objective':float(fit.fun)})
    meta={**diag,'frameSize':[128,128],'sheetSize':[256,256],'globalScale':scale,
        'rootAnchorPolicy':'static head and pelvis/legs whole-frame subpixel registration against frame00; not per-frame silhouette centroid',
        'normalization':'native alpha; one shared direction scale from neutral; rigid translation only',
        'rootAnchors':[[64,112]]*4,'transforms':[{'sourceCell':b,'scale':scale,'offsetPx':o.tolist(),'registration':f} for b,o,f in zip(diag['sourceCells'],offsets,fits)],
        'sourceSha256':sha(source),'referenceSha256':sha(OUT/f'references/{direction}_existing_idle.png'),
        'frameCount':4,'fps':4/3,'cycleMs':3000,'previewOnly':True,'status':'needs-visual-review',
        'artSource':'host:image_gen','noLocalCreativePixelEdits':True,'noPerFrameScale':True,
        'frame00Policy':'generated neutral based on existing idle posture, not byte-identical copy'}
    return frames,meta
def output(direction,frames,meta):
    folder=OUT/direction; folder.mkdir(exist_ok=True); (folder/'frames').mkdir(exist_ok=True)
    sheet=Image.new('RGBA',(256,256))
    for i,f in enumerate(frames):
        f.save(folder/'frames'/f'{direction}_idle_breathe_{i:02}.png'); sheet.alpha_composite(f,((i%2)*128,(i//2)*128))
    sheet.save(folder/f'{direction}_idle_breathe_sheet.png')
    href=f'/generated/windrest_hero_{direction}_idle_breathe_v02.png'
    meta['frames']=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{i%2*128} {i//2*128} 128 128" width="128" height="128"><image href="{href}" x="0" y="0" width="256" height="256"/></svg>' for i in range(4)]
    meta['frameBboxes']=[bbox(f) for f in frames]; save(folder/'normalization.json',meta)
    qa={'status':'needs-visual-review','uniqueFrames':len({f.tobytes() for f in frames}),
        'canvas':[128,128],'anchor':[64,112],'bodyBounds':[bbox(f) for f in frames],
        'headRegionResidual':[region_residual(frames[0],f,15,51) for f in frames],
        'legsRegionResidual':[region_residual(frames[0],f,81,116) for f in frames],
        'chestRegionFrame00Rms':[float(np.sqrt(np.mean((features(f)[52:77]-features(frames[0])[52:77])**2))) for f in frames],
        'notProven':'Numerical image registration does not certify natural breath, zero drift, or pixel-identical locked regions.'}
    save(folder/'qa.json',qa)
    return qa
def animated(path,frames):
    frames[0].save(path.with_suffix('.gif'),save_all=True,append_images=frames[1:],duration=[750]*4,loop=0,disposal=2)
    frames[0].save(path.with_suffix('.webp'),save_all=True,append_images=frames[1:],duration=[750]*4,loop=0,lossless=True)
def previews(frames_by):
    directions=[d for d in ['front','back','left','right'] if d in frames_by]
    sequence=[]; compare=[]
    for i in range(4):
        overview=Image.new('RGB',(len(directions)*256,568),'#dce6c8'); draw=ImageDraw.Draw(overview)
        comparison=Image.new('RGB',(len(directions)*512,288),'#dce6c8'); cd=ImageDraw.Draw(comparison)
        for col,d in enumerate(directions):
            for row,color in enumerate(['#dce6c8','#303a3c']):
                draw.rectangle((col*256,row*284,(col+1)*256,(row+1)*284),fill=color)
                f=frames_by[d][i].resize((256,256),Image.Resampling.LANCZOS)
                overview.paste(f,(col*256,row*284+24),f)
                draw.text((col*256+8,row*284+7),f'{d} v02 | {i:02}',fill='#45543c' if row==0 else '#dce6c8')
            old=Image.open(OLD/d/'frames'/f'{d}_idle_breathe_{i:02}.png').convert('RGBA').resize((256,256),Image.Resampling.LANCZOS)
            new=frames_by[d][i].resize((256,256),Image.Resampling.LANCZOS)
            comparison.paste(old,(col*512,24),old); comparison.paste(new,(col*512+256,24),new)
            cd.text((col*512+8,7),f'{d} v01 | {i:02}',fill='#45543c'); cd.text((col*512+264,7),f'{d} v02 | {i:02}',fill='#45543c')
        sequence.append(overview); compare.append(comparison)
    animated(OUT/'four_directions_preview',sequence); animated(OUT/'before_after_preview',compare)
    contact=Image.new('RGB',(1024,len(directions)*284),'#dce6c8'); dc=ImageDraw.Draw(contact)
    for row,d in enumerate(directions):
        for i,f in enumerate(frames_by[d]):
            large=f.resize((256,256),Image.Resampling.LANCZOS); contact.paste(large,(i*256,row*284+24),large)
            dc.text((i*256+8,row*284+7),f'{d} | {i:02}',fill='#45543c')
    contact.save(OUT/'four_directions_contact.png')
def main():
    frames_by={}; qa={}
    for d in ['front','back','side']:
        if not (OUT/d/'take1/generated.png').exists(): continue
        frames,meta=process(d); frames_by[d]=frames; qa[d]=output(d,frames,meta)
    if 'side' in frames_by:
        frames_by['right']=frames_by['side']; meta=json.loads((OUT/'side/normalization.json').read_text(encoding='utf-8'))
        qa['right']=output('right',frames_by['right'],{**meta,'derivation':'same complete frames as side'})
        frames_by['left']=[f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in frames_by['side']]
        qa['left']=output('left',frames_by['left'],{**meta,'derivation':'whole-frame horizontal mirror of side, same time order'})
    save(OUT/'qa_summary.json',qa); previews(frames_by)
    print(json.dumps({d:{'headShift':[v['bestRigidResidualShiftPx'] for v in q['headRegionResidual']],
        'legShift':[v['bestRigidResidualShiftPx'] for v in q['legsRegionResidual']],
        'chestRms':q['chestRegionFrame00Rms']} for d,q in qa.items()}))
if __name__=='__main__': main()
