"""Revise only the two unconfirmed local v07 preview entries; retain IDs/order."""
from pathlib import Path
import copy,json,hashlib,shutil
from datetime import datetime,timezone
from PIL import Image

OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1]
GEN=ROOT/'.forge/gorest/public/generated';LIB=GEN/'game_asset_library.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
raw=LIB.read_bytes();before=json.loads(raw);after=copy.deepcopy(before)
backup=OUT/'gorest_library.before.json';assert not backup.exists(),'Do not overwrite the initial backup'
source=GEN/'sources/windrest_hero_side_refine_v08';source.mkdir(parents=True,exist_ok=True)
for name in ['prompt_frame5.txt','prompt_frame6.txt','registration.json','verification.json','provenance.json','selection.json','gorest_diagnostic.json','RESULT.md','QC_FINDINGS.md']:
    shutil.copy2(OUT/name,source/name)
for name in ['edit_frame5','edit_frame6']:
    shutil.copytree(OUT/name,source/name)
for name in ['all_frames_contact.png','side_walk_game_speed.webp','side_walk_game_speed.gif','side_walk_game_speed_slow.webp','side_walk_compare.webp']:
    shutil.copy2(OUT/name,source/name)
changed=[];now=datetime.now(timezone.utc).isoformat()
for direction,label in [('right','右侧'),('left','左侧')]:
    aid=f'asset_windrest_hero_{direction}_walk_v07'
    asset=next(a for a in after['assets'] if a['id']==aid)
    assert asset['confirmed'] is False
    title=f'风栖原野主角 · {label}行走 v08（v07 修订：5/6 帧、全帧尺寸定位）'
    folder=OUT/f'{direction}_walk_preview'
    dest=GEN/f'windrest_hero_{direction}_walk_v08.png'
    assert not dest.exists();shutil.copy2(folder/f'{direction}_walk_sheet.png',dest)
    href=f'/generated/{dest.name}';sprite=asset['sprite'];inherited=copy.deepcopy(sprite.get('provenance',{}))
    svg=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{i%4*128} {i//4*128} 128 128" width="128" height="128"><image href="{href}" x="0" y="0" width="512" height="256"/></svg>' for i in range(8)]
    bboxes=[Image.open(folder/f'frames/{direction}_walk_{i:02}.png').getchannel('A').point(lambda a:255 if a>32 else 0).getbbox() for i in range(8)]
    sprite.update({'description':'v07 本轮修订 v08：第5帧减小右腿弯曲，第6帧远侧左手移至身后少量露出；全部8帧按固定头部尺寸校准整身等比尺度及地面定位。128×128、脚底原点(64,112)，13.8 FPS。候选待确认。',
        'prompt':'\n\n'.join((OUT/p).read_text(encoding='utf-8') for p in ['prompt_frame5.txt','prompt_frame6.txt']),
        'updatedTime':now,'spritesheetPng':href,'sourceMasterPng':href,'frames':svg,
        'frameCount':8,'frameSize':[128,128],'cellSize':[128,128],'sheetSize':[512,256],'gridColumns':4,
        'fps':13.8,'cycleMs':8000/13.8,'loop':True,'rootAnchors':[[64,112]]*8,'frameBboxes':bboxes,
        'sourceEdgeRisks':[],'sourceSha256':sha(dest),'previewOnly':True,'status':'needs-visual-review',
        'globalScale':None,'normalization':'Per-source complete-frame isotropic size calibration from stable head-height landmark, rigid registration to shared ground and head center, then common final 1/4 display scale. No body-bbox height fitting or limb compositing. See registration.json.',
        'derivation':'v07 frame5/6 whole-frame image edits; six other original poses restored from high-resolution sources. All eight registered. Left is complete-frame mirror.',
        'provenance':{'route':'host:image_gen + generate2dmedia cli_media.py adopt','revision':'v08','model':'not exposed','estimateUsd':None,'record':'/generated/sources/windrest_hero_side_refine_v08/','inherited':inherited}})
    asset.update({'name':title,'updatedTime':now,'confirmed':False})
    asset['tags']=[t for t in asset.get('tags',[]) if t!='v08']+['v08']
    asset['binding']['notes']='v07 candidate revised as v08: two pose edits plus eight-frame size/root calibration; current game unchanged.'
    assert len(asset['animations'])==1
    asset['animations'][0].update({'name':title,'fps':13.8,'sprite':copy.deepcopy(sprite),'binding':copy.deepcopy(asset['binding'])})
    changed.append(aid)
after['updatedTime']=now
assert [a['id'] for a in before['assets']]==[a['id'] for a in after['assets']]
assert all(a==next(b for b in after['assets'] if b['id']==a['id']) for a in before['assets'] if a['id'] not in changed)
assert all(before[k]==after[k] for k in before if k not in ['assets','updatedTime'])
assert LIB.read_bytes()==raw,'Concurrent library modification'
backup.write_bytes(raw);save(LIB,after)
assert json.loads(LIB.read_bytes())==json.loads(json.dumps(after))
save(OUT/'gorest_library_change.json',{'status':'pass','changedIds':changed,'beforeCount':len(before['assets']),'afterCount':len(after['assets']),'idsAndOrderPreserved':True,'otherAssetsAndSceneDataUnchanged':True,'confirmed':False,'previewVersion':'v08','sheetSha256':{d:sha(GEN/f'windrest_hero_{d}_walk_v08.png') for d in ['right','left']}})
print('Updated two unconfirmed previews, preserved all IDs, order and other data.')
