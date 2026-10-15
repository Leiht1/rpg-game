"""Append two independent unconfirmed previews, preserving all accepted entries."""
from pathlib import Path
import copy,hashlib,json,shutil
from datetime import datetime,timezone
from PIL import Image
OUT=Path(__file__).resolve().parent
APP=Path(r'C:/Users/HT/Documents/Codex/2026-10-15/https-github-com-0x0funky-agent-sprite/outputs/gorest-2d-animation-spritesheet-generator-main')
GEN=APP/'public/generated';LIB=GEN/'game_asset_library.json'
raw=LIB.read_bytes();before=json.loads(raw);after=copy.deepcopy(before)
backup=OUT/'gorest_library.before.json'
refresh=backup.exists()
if refresh:backup=OUT/'gorest_library.before_hand_fix.json'
assert not backup.exists()
now=datetime.now(timezone.utc).isoformat();added=[]
source=GEN/'sources/windrest_hero_side_phase_v07'
source.mkdir(parents=True,exist_ok=refresh)
for take in range(1,7):
    dest=source/f'take{take}';dest.mkdir(exist_ok=refresh)
    for name in ['generated.png','job.json','registration.json','gorest_diagnostic.json']:
        shutil.copy2(OUT/f'take{take}'/name,dest/name)
for name in ['prompt.txt','prompt_frame2.txt','prompt_frame3.txt','prompt_frame5.txt','prompt_frame6.txt','prompt_frame6_hand.txt',
        'plan.json','selection.json','provenance.json','minimal_verification.json']:
    shutil.copy2(OUT/name,source/name)
for di,label in [('right','右侧'),('left','左侧')]:
    asset=copy.deepcopy(next(a for a in before['assets'] if a['id']==f'asset_windrest_hero_{di}_walk_v04'))
    aid=f'asset_windrest_hero_{di}_walk_v07'
    if refresh:assert next(a for a in before['assets'] if a['id']==aid)['confirmed'] is False
    else:assert not any(a['id']==aid for a in before['assets'])
    stem=f'windrest_hero_{di}_walk_v07';href=f'/generated/{stem}.png'
    folder=OUT/f'{di}_walk_preview';destination=GEN/f'{stem}.png'
    if not refresh:assert not destination.exists()
    shutil.copy2(folder/f'{di}_walk_sheet.png',destination)
    title=f'风栖原野主角 · {label}行走 v07（2/3/5 相位、6 腿部修订）'
    sprite=asset['sprite'];inherited=copy.deepcopy(sprite.get('provenance',{}))
    frames=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{i%4*128} {i//4*128} 128 128" width="128" height="128"><image href="{href}" x="0" y="0" width="512" height="256"/></svg>' for i in range(8)]
    bboxes=[Image.open(p).getchannel('A').point(lambda a:255 if a>16 else 0).getbbox() for p in sorted((folder/'frames').glob('*.png'))]
    sprite.update({'id':f'sprite_windrest_hero_{di}_walk_v07',
        'description':'完整重绘第 2、3、5、6 帧，重新分配收腿/前伸/回收，修正第 6 帧前景腿及反向摆臂。13.8 FPS 对应游戏 115 速度，未接入游戏。',
        'prompt':'\n\n'.join((OUT/p).read_text(encoding='utf-8') for p in ['prompt.txt','prompt_frame2.txt','prompt_frame3.txt','prompt_frame5.txt','prompt_frame6.txt','prompt_frame6_hand.txt']),
        'createdTime':now,'updatedTime':now,'spritesheetPng':href,'sourceMasterPng':href,
        'frameCount':8,'frameSize':[128,128],'cellSize':[128,128],'sheetSize':[512,256],
        'gridColumns':4,'fps':13.8,'cycleMs':8000/13.8,'loop':True,'frames':frames,'rootAnchors':[[64,112]]*8,
        'frameBboxes':bboxes,'sourceEdgeRisks':[],'globalScale':None,
        'normalization':'Four selected singleton sources share the same 512/1254/4 scale; whole-frame registration. Four v06 PNGs unchanged. No per-pose body-height fitting, local patch, warp or limb compositing.',
        'sourceSha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'previewOnly':True,'status':'needs-visual-review',
        'derivation':'Frames 2/3/5/6 from v07 take2/3/4/6, frames 1/4/7/8 from v06 unchanged'+('; whole-frame mirror' if di=='left' else ''),
        'provenance':{'route':'host:image_gen + generate2dmedia adopt','model':'not exposed','cost':'unknown',
            'revision':'v07','record':'/generated/sources/windrest_hero_side_phase_v07/','inherited':inherited}})
    clip_id=f'clip_windrest_hero_{di}_walk_v07'
    asset.update({'id':aid,'name':title,'savedTime':now,'updatedTime':now,'confirmed':False,'defaultAnimationId':clip_id})
    asset['tags']=[x for x in asset.get('tags',[]) if x not in ['v04','v05','v06','v07']]+['v07']
    asset['binding']['gameState']=f'windrest.preview.v07.{di}_walk'
    asset['binding']['notes']='Independent unconfirmed v07 preview; current game v06/template 4 preserved.'
    assert len(asset['animations'])==1
    asset['animations'][0].update({'id':clip_id,'name':title,'fps':13.8,'sprite':copy.deepcopy(sprite),'binding':copy.deepcopy(asset['binding'])})
    if refresh:
        index=next(i for i,a in enumerate(after['assets']) if a['id']==aid);after['assets'][index]=asset
    else:after['assets'].append(asset)
    added.append(aid)
after['updatedTime']=now
assert all(next(a for a in after['assets'] if a['id']==old['id'])==old for old in before['assets'] if old['id'] not in added)
if refresh:assert [a['id'] for a in after['assets']]==[a['id'] for a in before['assets']]
else:assert after['assets'][:len(before['assets'])]==before['assets']
assert all(before[k]==after[k] for k in before if k not in ['assets','updatedTime'])
backup.write_bytes(raw)
assert LIB.read_bytes()==raw,'Library changed concurrently; use a fresh snapshot.'
LIB.write_text(json.dumps(after,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
actual=json.loads(LIB.read_bytes());assert actual==json.loads(json.dumps(after))
for di in ['right','left']:
    assert (GEN/f'windrest_hero_{di}_walk_v07.png').read_bytes()==(OUT/f'{di}_walk_preview/{di}_walk_sheet.png').read_bytes()
(OUT/'gorest_library_change.json').write_text(json.dumps({'status':'pass','addedIds':added,
    'beforeCount':len(before['assets']),'afterCount':len(after['assets']),
    'allOtherEntriesAndOrderPreserved':True,'otherDataUnchanged':True,'sheetCopiesMatch':True,
    'confirmed':False,'fps':13.8,'browserPlayback':'Not rerun, user requested minimal checks/manual verification.'},indent=2)+'\n',encoding='utf-8')
print(f'Published 2 independent v07 previews; all other entries and scene data preserved. Total {len(after["assets"])}.')
