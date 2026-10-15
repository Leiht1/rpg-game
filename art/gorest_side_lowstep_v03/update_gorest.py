"""Revise only the two existing side previews; preserve every other library asset."""
from pathlib import Path
from datetime import datetime, timezone
import copy
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parent
APP = Path(r'C:\Users\HT\Documents\Codex\2026-10-15\https-github-com-0x0funky-agent-sprite\outputs\gorest-2d-animation-spritesheet-generator-main')
GENERATED = APP/'public/generated'
LIBRARY = GENERATED/'game_asset_library.json'
backup = ROOT/'gorest_library.before.json'
assert not backup.exists(), 'Do not replace the revision backup.'
before_bytes = LIBRARY.read_bytes()
before = json.loads(before_bytes)
after = copy.deepcopy(before)
now = datetime.now(timezone.utc).isoformat()
changed = []
for direction in ['right','left']:
    asset_id = f'asset_windrest_hero_{direction}_walk_v02'
    asset = next(a for a in after['assets'] if a['id']==asset_id)
    meta = json.loads((ROOT/direction/'normalization.json').read_text(encoding='utf-8'))
    qa = json.loads((ROOT/direction/'qa.json').read_text(encoding='utf-8'))
    assert qa['uniqueFrameCount']==8 and qa['minimumAlphaMargin']>=24
    stem = f'windrest_hero_{direction}_walk_lowstep_v03'
    href = f'/generated/{stem}.png'
    sprite = copy.deepcopy(asset['sprite'])
    for key in ['frames','frameBboxes','sourceFrameRefs','sourceFrameOrder','phaseOrderPolicy',
                'normalization','rootAnchorPolicy','targetedEdit','previousVersion']:
        sprite[key] = meta[key]
    sprite['spritesheetPng'] = href
    sprite['description'] = '侧面第3、7帧降低抬腿高度，其余帧不变；预览未接入游戏。'
    sprite['prompt'] = (ROOT/'edit_prompt.txt').read_text(encoding='utf-8')
    sprite['createdTime'] = now
    sprite['sourceMasterPng'] = f'/generated/sources/{stem}/edit_target.png'
    sprite['provenance']['targetedEdit'] = {
        'route':'host:image_gen, generate2dmedia adoption',
        'model':'not exposed', 'changedFramesOneBased':[3,7],
        'sourceSheet':f'/generated/sources/{stem}/generated.png',
        'rawSha256':hashlib.sha256((ROOT/'take1/generated.png').read_bytes()).hexdigest(),
        'previousSheet':f'/generated/windrest_hero_{direction}_walk_v02.png',
        'status':'preview_not_game_integrated'}
    sprite['qualityPolicy'] = 'Targeted low-step preview; preserve six original frames. Small redraw contour differences remain; not final game acceptance.'
    if direction=='left':
        sprite['derivation'] = meta['derivation']
    asset['sprite'] = sprite
    for clip in asset['animations']:
        clip['sprite'] = copy.deepcopy(sprite)
    asset['updatedTime'] = now
    changed.append(asset_id)
    shutil.copy2(ROOT/direction/f'{direction}_walk_sheet.png',GENERATED/f'{stem}.png')
    source = GENERATED/'sources'/stem
    source.mkdir(parents=True,exist_ok=True)
    for src,dest in [(ROOT/'take1/generated.png','generated.png'),(ROOT/'take1/job.json','job.json'),
                     (ROOT/'edit_prompt.txt','prompt.txt'),(ROOT/'edit_provenance.json','edit_provenance.json'),
                     (ROOT/'references/side_frames_03_07_edit_target.png','edit_target.png'),
                     (ROOT/direction/'normalization.json','normalization.json'),(ROOT/direction/'qa.json','qa.json')]:
        shutil.copy2(src,source/dest)
before_other = [a for a in before['assets'] if a['id'] not in changed]
after_other = [a for a in after['assets'] if a['id'] not in changed]
assert before_other==after_other
assert all(before[k]==after[k] for k in before if k not in ['assets','updatedTime'])
backup.write_bytes(before_bytes)
after['updatedTime']=now
LIBRARY.write_text(json.dumps(after,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'changedAssetIds':changed,'otherAssetsUnchanged':before_other==after_other,
        'existingAssetIdsAndOrderUnchanged':[a['id'] for a in before['assets']]==[a['id'] for a in after['assets']],
        'assetCount':len(after['assets']), 'beforeSha256':hashlib.sha256(before_bytes).hexdigest(),
        'afterSha256':hashlib.sha256(LIBRARY.read_bytes()).hexdigest()}
(ROOT/'gorest_library_change.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
