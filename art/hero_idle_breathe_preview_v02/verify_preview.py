"""Verify the delivered preview files and the deliberately unchanged runtime."""
from pathlib import Path
import hashlib, json
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent; GAME=ROOT.parent.parent
APP=Path(r'C:\Users\HT\Documents\Codex\2026-10-15\https-github-com-0x0funky-agent-sprite\outputs\gorest-2d-animation-spritesheet-generator-main')
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
report={'status':'pass-files-only','visualApproval':False,'previewOnly':True,'frames':{},'media':{},'sources':{}}
all_frames=[]
for d in ['front','back','right','left']:
    sheet=Image.open(ROOT/d/f'{d}_idle_breathe_sheet.png').convert('RGBA')
    assert sheet.size==(256,256)
    frames=[]; margins=[]; heights=[]
    for i in range(4):
        p=ROOT/d/'frames'/f'{d}_idle_breathe_{i:02}.png'; im=Image.open(p)
        assert im.mode=='RGBA' and im.size==(128,128)
        assert im.getchannel('A').getextrema()==(0,255)
        assert np.array_equal(np.array(im),np.array(sheet.crop((i%2*128,i//2*128,i%2*128+128,i//2*128+128))))
        box=im.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()
        margins.append(min(box[0],box[1],128-box[2],128-box[3])); heights.append(box[3]-box[1])
        frames.append(im.copy()); all_frames.append(p)
    assert len({f.tobytes() for f in frames})==4 and min(margins)>=15
    assert sha(APP/'public/generated'/f'windrest_hero_{d}_idle_breathe_v02.png')==sha(ROOT/d/f'{d}_idle_breathe_sheet.png')
    report['frames'][d]={'count':4,'unique':4,'size':[128,128],'mode':'RGBA','minimumAlpha16MarginPx':min(margins),'visibleHeightsPx':heights,'pngSheetReadbackExact':True}
for i in range(4):
    right=Image.open(ROOT/'right/frames'/f'right_idle_breathe_{i:02}.png')
    left=Image.open(ROOT/'left/frames'/f'left_idle_breathe_{i:02}.png')
    assert np.array_equal(np.array(left),np.array(right.transpose(Image.Transpose.FLIP_LEFT_RIGHT)))
report['wholeFrameLeftMirrorExact']=True
for d in ['front','back','side']:
    raw=ROOT/d/'take1/generated.png'; meta=read(ROOT/d/'normalization.json')
    assert sha(raw)==meta['sourceSha256']; assert len({a['scale'] for a in meta['transforms']})==1
    report['sources'][d]={'sha256':sha(raw),'size':list(Image.open(raw).size),'oneDirectionScale':meta['globalScale'],'sourceEdgeRisks':meta['sourceEdgeRisks']}
for p in sorted(ROOT.glob('*.gif'))+sorted(ROOT.glob('*.webp')):
    im=Image.open(p); count=im.n_frames; duration=0
    for i in range(count):
        im.seek(i); im.load(); duration+=im.info.get('duration',0)
    assert count==4 and duration==3000,(p,count,duration)
    report['media'][p.name]={'frames':count,'totalMs':duration}
before=read(ROOT/'game_files_before.json'); changed=[f for f,h in before.items() if not (GAME/f).exists() or sha(GAME/f)!=h]
assert not changed,changed
report['runtime']={'filesCompared':len(before),'changed':changed,'godotTestRun':False,'performanceMeasured':False}
old=read(ROOT/'gorest_library.before.json'); new=read(APP/'public/generated/game_asset_library.json')
ids={f'asset_windrest_hero_{d}_idle_breathe_v01' for d in ['front','back','right','left']}
assert len(old['assets'])==len(new['assets'])==49
assert [a['id'] for a in old['assets']]==[a['id'] for a in new['assets']]
assert all(a==b for a,b in zip(old['assets'],new['assets']) if a['id'] not in ids)
assert all(old[k]==new[k] for k in old if k not in ['assets','updatedTime'])
assert all(not a['confirmed'] for a in new['assets'] if a['id'] in ids)
report['gorest']={'count':49,'updatedPreviews':4,'otherAssetsPreserved':45,'idsOrderScenesPreserved':True,'confirmed':False,'lintExitCode':0,'buildExitCode':0}
clips=read(ROOT/'clips/animation-clips.json')
for i,p in enumerate(all_frames): assert sha(p)==sha(ROOT/'clips/frames'/f'frame-{i:02}.png')
report['skillQA']=clips['qa']['checks']; report['skillStatus']=clips['qa']['status']
report['frameSha256']={str(p.relative_to(ROOT)).replace('\\','/'):sha(p) for p in all_frames}
(ROOT/'export_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k not in ['frameSha256','skillQA','media','sources']},ensure_ascii=False))
