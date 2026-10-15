"""Revise only the four unconfirmed breathing previews, retaining their IDs/order."""
from datetime import datetime, timezone
from pathlib import Path
import copy, hashlib, json, shutil

ROOT=Path(__file__).resolve().parent
APP=Path(r'C:\Users\HT\Documents\Codex\2026-10-15\https-github-com-0x0funky-agent-sprite\outputs\gorest-2d-animation-spritesheet-generator-main')
GENERATED=APP/'public/generated'; LIBRARY=GENERATED/'game_asset_library.json'
backup=ROOT/'gorest_library.before.json'
assert not backup.exists(), 'Keep the first backup. Do not rerun this mutation.'
before_bytes=LIBRARY.read_bytes(); before=json.loads(before_bytes); after=copy.deepcopy(before)
now=datetime.now(timezone.utc).isoformat(); revised=[]
for direction,label in [('front','正面'),('back','背面'),('right','右侧'),('left','左侧')]:
    existing_id=f'asset_windrest_hero_{direction}_idle_breathe_v01'
    a=next(a for a in after['assets'] if a['id']==existing_id)
    assert a['confirmed'] is False
    stem=f'windrest_hero_{direction}_idle_breathe_v02'
    sd=direction if direction in ['front','back'] else 'side'
    meta=json.loads((ROOT/direction/'normalization.json').read_text(encoding='utf-8'))
    qa=json.loads((ROOT/direction/'qa.json').read_text(encoding='utf-8'))
    assert qa['uniqueFrames']==4 and not meta['sourceEdgeRisks']
    prompt=(ROOT/f'{sd}_prompt.txt').read_text(encoding='utf-8')
    source=GENERATED/'sources'/stem; source.mkdir(parents=True,exist_ok=True)
    for src,name in [(ROOT/sd/'take1/generated.png','generated.png'),(ROOT/sd/'take1/job.json','job.json'),
                     (ROOT/f'{sd}_prompt.txt','prompt.txt'),
                     (ROOT/f'references/{sd}_existing_idle.png','existing_idle_master.png'),
                     (ROOT/f'references/{sd}_locked_four_frame_target.png','edit_target.png'),
                     (ROOT/direction/'normalization.json','normalization.json'),(ROOT/direction/'qa.json','qa.json')]:
        shutil.copy2(src,source/name)
    href=f'/generated/{stem}.png'
    shutil.copy2(ROOT/direction/f'{direction}_idle_breathe_sheet.png',GENERATED/f'{stem}.png')
    sprite={**meta,'id':a['sprite']['id'],'characterName':'风栖原野主角',
        'description':f'{label}呼吸 v02：增强胸肩变化，以头部与下肢共同注册抑制整身位移。四帧、3秒循环，仅预览。',
        'style':'warm bright simplified hand-painted cartoon matching existing idle',
        'prompt':prompt,'createdTime':a['sprite'].get('createdTime',now),'updatedTime':now,'isPreset':False,
        'spritesheetPng':href,'sourceMasterPng':f'/generated/sources/{stem}/existing_idle_master.png',
        'generationMode':'spritesheet','gridColumns':2,'fps':4/3,'loop':True,'sourceEdgeRiskCount':0,
        'artSourcePolicy':'Full-body generated artwork; native alpha; one direction scale; whole-frame subpixel rigid registration to head and legs. No local patches or per-frame scale.',
        'qualityPolicy':'v01 rejected for too little motion and drift. v02 needs user visual review; no runtime acceptance or zero-drift certification.',
        'provenance':{'route':'host:image_gen + generate2dmedia adopt','underlyingImageModel':'not exposed',
            'rawSheet':f'/generated/sources/{stem}/generated.png','rawSha256':meta['sourceSha256'],
            'sourceDirection':sd,'revision':'v02','status':'preview_not_game_integrated'}}
    title=f'风栖原野主角 · {label}呼吸待机 v02（4帧预览）'
    a['name']=title; a['sprite']=sprite; a['updatedTime']=now
    for clip in a['animations']:
        clip['name']=title; clip['sprite']=copy.deepcopy(sprite); clip['fps']=4/3; clip['loop']=True
    revised.append(existing_id)
assert [a['id'] for a in before['assets']]==[a['id'] for a in after['assets']]
assert all(a==b for a,b in zip(before['assets'],after['assets']) if a['id'] not in revised)
assert all(before[k]==after[k] for k in before if k not in ['assets','updatedTime'])
backup.write_bytes(before_bytes); after['updatedTime']=now
LIBRARY.write_text(json.dumps(after,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'revisedAssetIds':revised,'beforeAssetCount':len(before['assets']),'afterAssetCount':len(after['assets']),
    'other45AssetsUnchanged':True,'assetIdsAndOrderUnchanged':True,'otherLibraryDataUnchanged':True,
    'beforeSha256':hashlib.sha256(before_bytes).hexdigest(),'afterSha256':hashlib.sha256(LIBRARY.read_bytes()).hexdigest()}
(ROOT/'gorest_library_change.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
