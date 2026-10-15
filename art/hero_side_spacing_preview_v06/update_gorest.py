"""Publish only the two unconfirmed side walk previews, preserving live edits."""
from pathlib import Path
import copy,hashlib,json,shutil
from datetime import datetime,timezone
from PIL import Image

OUT=Path(__file__).resolve().parent
APP=Path(r'C:/Users/HT/Documents/Codex/2026-10-15/https-github-com-0x0funky-agent-sprite/outputs/gorest-2d-animation-spritesheet-generator-main')
GEN=APP/'public/generated';LIB=GEN/'game_asset_library.json'
raw=LIB.read_bytes();before=json.loads(raw);after=copy.deepcopy(before)
backup=OUT/'gorest_library.before.json';assert not backup.exists()
now=datetime.now(timezone.utc).isoformat();changed=[]
for di,label in [('right','右侧'),('left','左侧')]:
    aid=f'asset_windrest_hero_{di}_walk_v04'
    asset=next(a for a in after['assets'] if a['id']==aid);assert asset['confirmed'] is False
    sprite=asset['sprite'];stem=f'windrest_hero_{di}_walk_v06';href=f'/generated/{stem}.png'
    previous_record=copy.deepcopy(sprite.get('provenance',{}))
    folder=OUT/f'{di}_walk_preview';destination=GEN/f'{stem}.png'
    shutil.copy2(folder/f'{di}_walk_sheet.png',destination)
    source=GEN/'sources'/stem;source.mkdir(parents=True,exist_ok=True)
    for name in ['generated.png','job.json','registration.json','gorest_diagnostic.json']:
        shutil.copy2(OUT/'take1'/name,source/name)
    for name in ['prompt.txt','selection.json','provenance.json']:
        shutil.copy2(OUT/name,source/name)
    title=f'风栖原野主角 · {label}行走相位微调 v06（修订预览）'
    frames=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{i%4*128} {i//4*128} 128 128" width="128" height="128"><image href="{href}" x="0" y="0" width="512" height="256"/></svg>' for i in range(8)]
    files=sorted((folder/'frames').glob('*.png'))
    bboxes=[Image.open(p).getchannel('A').point(lambda a:255 if a>16 else 0).getbbox() for p in files]
    sprite.update({'description':'只微调第 3、5 帧：收小 2→3 的手脚跨度，增加 4→5 的收步与承重变化；其余六帧和呼吸候选保留。12 FPS，仅预览。',
        'prompt':(OUT/'prompt.txt').read_text(encoding='utf-8'),'updatedTime':now,'spritesheetPng':href,'sourceMasterPng':href,
        'frameCount':8,'frameSize':[128,128],'cellSize':[128,128],'sheetSize':[512,256],'gridColumns':4,
        'fps':12,'cycleMs':2000/3,'loop':True,'frames':frames,'rootAnchors':[[64,112]]*8,
        'frameBboxes':bboxes,'sourceEdgeRisks':[],'globalScale':None,
        'normalization':'Six v05 whole PNG frames unchanged; two new complete figures share one source scale and head registration. No local patches or warps.',
        'sourceSha256':hashlib.sha256(destination.read_bytes()).hexdigest(),'previewOnly':True,'status':'needs-visual-review',
        'derivation':'v05 complete frames except frame 3 = take1 cell 0, frame 5 = take1 cell 1'+('; full-frame horizontal mirror' if di=='left' else ''),
        'provenance':{'route':'host:image_gen + generate2dmedia adopt','model':'not exposed','cost':'unknown',
            'revision':'v06','record':f'/generated/sources/{stem}/','inherited':previous_record}})
    asset.update({'name':title,'updatedTime':now,'confirmed':False})
    asset['tags']=[x for x in asset.get('tags',[]) if x not in ['v04','v05','v06']]+['v06']
    asset['binding']['gameState']=f'windrest.preview.v06.{di}_walk'
    for clip in asset['animations']:
        clip.update({'name':title,'fps':12,'sprite':copy.deepcopy(sprite),'binding':copy.deepcopy(asset['binding'])})
    changed.append(aid)
after['updatedTime']=now
assert [a['id'] for a in before['assets']]==[a['id'] for a in after['assets']]
assert all(a==b for a,b in zip(before['assets'],after['assets']) if a['id'] not in changed)
assert all(before[k]==after[k] for k in before if k not in ['assets','updatedTime'])
backup.write_bytes(raw)
assert LIB.read_bytes()==raw,'Library changed during preparation; retry using fresh snapshot.'
LIB.write_text(json.dumps(after,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
actual=json.loads(LIB.read_bytes());assert actual==json.loads(json.dumps(after))
for di in ['right','left']:
    assert (GEN/f'windrest_hero_{di}_walk_v06.png').read_bytes()==(OUT/f'{di}_walk_preview/{di}_walk_sheet.png').read_bytes()
(OUT/'gorest_library_change.json').write_text(json.dumps({'status':'pass','changedIds':changed,
    'assetCount':len(after['assets']),'idAndOrderPreserved':True,'otherAssetsUnchanged':True,
    'otherDataUnchanged':True,'sheetCopiesMatch':True,'confirmed':False},indent=2)+'\n',encoding='utf-8')
print(f'Updated 2 walk previews; {len(after["assets"])-2} other assets and all IDs/order preserved.')
