"""Prepare review-only timing, actual comparison metrics and preview media."""
from pathlib import Path
import importlib.util, json, shutil
import numpy as np
from scipy import ndimage
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parent
OLD=ROOT.parent/'hero_idle_breathe_preview_v01'
spec=importlib.util.spec_from_file_location('pack',ROOT/'package_preview.py')
P=importlib.util.module_from_spec(spec); spec.loader.exec_module(P)
manifest=json.loads((OLD/'clips-manifest.json').read_text(encoding='utf-8'))
manifest['name']='windrest-idle-breathe-preview-v02'
P.save(ROOT/'clips-manifest.json',manifest)

comparison={}
for d in ['front','back','left','right']:
    comparison[d]={}
    for label,folder in [('v01',OLD),('v02',ROOT)]:
        frames=[Image.open(folder/d/'frames'/f'{d}_idle_breathe_{i:02}.png').convert('RGBA') for i in range(4)]
        head=[P.region_residual(frames[0],f,15,51) for f in frames]
        legs=[P.region_residual(frames[0],f,81,116) for f in frames]
        width=[float(np.array(f)[54:64,:,3].sum()/255/10) for f in frames]
        ref=P.features(frames[0]); registered=[]
        for i,f in enumerate(frames):
            shift=np.mean([head[i]['bestRigidResidualShiftPx'],legs[i]['bestRigidResidualShiftPx']],axis=0)
            a=ndimage.shift(P.features(f),(shift[1],shift[0],0),order=1,mode='constant',prefilter=False)
            registered.append(float(np.sqrt(np.mean((a[52:77]-ref[52:77])**2))))
        comparison[d][label]={'headRegionResidual':head,'legsRegionResidual':legs,
            'maxStaticRegionResidualShiftPx':max(float(np.linalg.norm(a['bestRigidResidualShiftPx'])) for a in head+legs),
            'shoulderBandAlphaWidthPx':width,'shoulderBandWidthRangePx':max(width)-min(width),
            'chestRmsAfterEstimatedStaticRegionTranslation':registered}
    frames=[Image.open(ROOT/d/'frames'/f'{d}_idle_breathe_{i:02}.png').convert('RGBA') for i in range(4)]
    single=[]; pair=[]
    for i,f in enumerate(frames):
        canvas=Image.new('RGB',(256,288),'#dce6c8'); draw=ImageDraw.Draw(canvas)
        ff=f.resize((256,256),Image.Resampling.LANCZOS); canvas.paste(ff,(0,24),ff)
        draw.text((8,7),f'{d} v02 | {i:02}',fill='#45543c'); single.append(canvas)
        both=Image.new('RGB',(512,288),'#dce6c8'); bd=ImageDraw.Draw(both)
        old=Image.open(OLD/d/'frames'/f'{d}_idle_breathe_{i:02}.png').convert('RGBA').resize((256,256),Image.Resampling.LANCZOS)
        both.paste(old,(0,24),old); both.paste(ff,(256,24),ff)
        bd.text((8,7),f'{d} v01 | {i:02}',fill='#45543c'); bd.text((264,7),f'{d} v02 | {i:02}',fill='#45543c'); pair.append(both)
    P.animated(ROOT/d/f'{d}_preview',single); P.animated(ROOT/f'{d}_before_after',pair)
P.save(ROOT/'comparison_metrics.json',{'measurementScope':'Image matching and alpha-band width are diagnostics, not anatomical proof. Old frames are only translated in this measurement, never changed in the comparison preview.',
    'regions':{'head':[15,51],'legs':[81,116],'chest':[52,77],'shoulderBand':[54,64]},'directions':comparison})
game=[]
for i in range(4):
    im=Image.new('RGB',(512,152),'#dce6c8'); draw=ImageDraw.Draw(im)
    for col,d in enumerate(['front','back','left','right']):
        f=Image.open(ROOT/d/'frames'/f'{d}_idle_breathe_{i:02}.png').convert('RGBA'); im.paste(f,(col*128,24),f)
        draw.text((col*128+4,7),d,fill='#45543c')
    game.append(im)
P.animated(ROOT/'game_size_preview',game)
plan=json.loads((ROOT/'plan.json').read_text(encoding='utf-8')); plan['generationPending']=False
plan['status']='needs-visual-review'; P.save(ROOT/'plan.json',plan)
print(json.dumps({d:{v:round(q['maxStaticRegionResidualShiftPx'],4) for v,q in versions.items()} for d,versions in comparison.items()}))
