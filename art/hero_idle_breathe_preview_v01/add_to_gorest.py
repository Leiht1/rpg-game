"""Add four breathing previews without changing existing assets or scene data."""
from datetime import datetime, timezone
from pathlib import Path
import copy, hashlib, json, shutil

ROOT=Path(__file__).resolve().parent
APP=Path(r'C:\Users\HT\Documents\Codex\2026-10-15\https-github-com-0x0funky-agent-sprite\outputs\gorest-2d-animation-spritesheet-generator-main')
GENERATED=APP/'public/generated'
LIBRARY=GENERATED/'game_asset_library.json'
backup=ROOT/'gorest_library.before.json'
assert not backup.exists(), 'Keep the original library backup; do not duplicate entries.'
before_bytes=LIBRARY.read_bytes(); before=json.loads(before_bytes)
after=copy.deepcopy(before); additions=[]
now=datetime.now(timezone.utc).isoformat()
for direction,label,semantic in [('front','正面','down'),('back','背面','up'),('right','右侧','right'),('left','左侧','left')]:
    stem=f'windrest_hero_{direction}_idle_breathe_v01'
    asset_id=f'asset_{stem}'; clip_id=f'clip_{stem}'
    assert not any(a['id']==asset_id for a in before['assets'])
    source_direction=direction if direction in ['front','back'] else 'side'
    meta=json.loads((ROOT/direction/'normalization.json').read_text(encoding='utf-8'))
    qa=json.loads((ROOT/direction/'qa.json').read_text(encoding='utf-8'))
    assert qa['uniqueFrameCount']==4 and qa['soleBottomRangePx']==0
    assert qa['minimumAlphaMargin']>=16 and not meta['sourceEdgeRisks']
    prompt=(ROOT/f'{source_direction}_prompt.txt').read_text(encoding='utf-8')
    source=GENERATED/'sources'/stem; source.mkdir(parents=True,exist_ok=True)
    for src,name in [(ROOT/source_direction/'take1/generated.png','generated.png'),
                     (ROOT/source_direction/'take1/job.json','job.json'),
                     (ROOT/f'{source_direction}_prompt.txt','prompt.txt'),
                     (ROOT/f'references/{source_direction}_idle_master.png','existing_idle_master.png'),
                     (ROOT/f'references/{source_direction}_four_frame_edit_target.png','edit_target.png'),
                     (ROOT/direction/'normalization.json','normalization.json'),
                     (ROOT/direction/'qa.json','qa.json')]:
        shutil.copy2(src,source/name)
    href=f'/generated/{stem}.png'
    shutil.copy2(ROOT/direction/f'{direction}_idle_breathe_sheet.png',GENERATED/f'{stem}.png')
    sprite={**meta,'id':f'sprite_{stem}','characterName':'风栖原野主角',
        'description':f'现有{label} idle 站姿延展，四帧轻微呼吸、3 秒循环。仅预览，未接入游戏。',
        'style':'warm bright simplified hand-painted cartoon matching existing idle',
        'prompt':prompt,'createdTime':now,'isPreset':False,'spritesheetPng':href,
        'sourceMasterPng':f'/generated/sources/{stem}/existing_idle_master.png',
        'generationMode':'spritesheet','gridColumns':2,'fps':4/3,'loop':True,
        'sourceEdgeRiskCount':0,
        'artSourcePolicy':'Complete-body generated bitmap poses; native alpha, one shared scale per direction, rigid whole-frame registration. Left mirrors whole right frames.',
        'qualityPolicy':'Restrained breathing candidate; minor redraw contour changes remain. Needs user visual review; no runtime acceptance.',
        'provenance':{'route':'host:image_gen + generate2dmedia adopt','underlyingImageModel':'not exposed',
            'rawSheet':f'/generated/sources/{stem}/generated.png','rawSha256':meta['sourceSha256'],
            'sourceDirection':source_direction,'status':'preview_not_game_integrated'}}
    title=f'风栖原野主角 · {label}呼吸待机（4帧预览）'
    binding={'actionName':'idle_breathe','triggerType':'auto','triggerValue':'preview-loop',
        'gameState':f'windrest.preview.{direction}_idle_breathe','notes':'Preview only; no game scene binding.'}
    additions.append({'id':asset_id,'name':title,'role':'player','confirmed':False,
        'savedTime':now,'updatedTime':now,'sprite':sprite,
        'animations':[{'id':clip_id,'name':title,'actionName':'idle_breathe','direction':semantic,
            'sprite':copy.deepcopy(sprite),'binding':binding,'loop':True,'fps':4/3}],
        'defaultAnimationId':clip_id,'binding':binding,
        'tags':['windrest','hero',direction,'idle-breathe','preview','not-game-integrated']})
backup.write_bytes(before_bytes)
after['assets']=additions+before['assets']; after['updatedTime']=now
assert after['assets'][4:]==before['assets']
assert all(before[k]==after[k] for k in before if k not in ['assets','updatedTime'])
LIBRARY.write_text(json.dumps(after,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'addedAssetIds':[a['id'] for a in additions],'beforeAssetCount':len(before['assets']),
    'afterAssetCount':len(after['assets']),'existingAssetsAndOrderUnchanged':True,'otherLibraryDataUnchanged':True,
    'beforeSha256':hashlib.sha256(before_bytes).hexdigest(),'afterSha256':hashlib.sha256(LIBRARY.read_bytes()).hexdigest()}
(ROOT/'gorest_library_change.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
