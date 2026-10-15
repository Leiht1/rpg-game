"""Add eight independent review candidates, preserving all prior library content."""
from pathlib import Path
from datetime import datetime, timezone
import copy, hashlib, json, shutil
ROOT=Path(__file__).resolve().parent
APP=Path(r'C:/Users/HT/Documents/Codex/2026-10-15/https-github-com-0x0funky-agent-sprite/outputs/gorest-2d-animation-spritesheet-generator-main')
GEN=APP/'public/generated'; LIB=GEN/'game_asset_library.json'
backup=ROOT/'gorest_library.before.json'; assert not backup.exists(),'Do not overwrite the first library backup.'
raw=LIB.read_bytes(); before=json.loads(raw); after=copy.deepcopy(before)
now=datetime.now(timezone.utc).isoformat(); added=[]; assets=[]
for direction,label,engine_dir in [('front','正面','down'),('back','背面','up'),('right','右侧','right'),('left','左侧','left')]:
    sd=direction if direction in ['front','back'] else 'side'
    for action in ['idle','walk']:
        idle=action=='idle'; source_action='breathe' if idle else 'walk'
        folder=ROOT/f'{direction}_{action}_preview'; canonical=ROOT/f'{sd}_{source_action}'
        meta=json.loads((canonical/'normalization.json').read_text(encoding='utf-8'))
        qa=json.loads((folder/'qa.json').read_text(encoding='utf-8'))
        stem=f'windrest_hero_{direction}_{"idle_breathe" if idle else "walk"}_v04'
        take=meta.get('selectedTake','take1'); source=GEN/'sources'/stem; source.mkdir(parents=True,exist_ok=True)
        prompt_name=f'{sd}_breathe_refine_prompt.txt' if idle and take=='take2' else f'{sd}_{source_action}_prompt.txt'
        prompt=(ROOT/prompt_name).read_text(encoding='utf-8')
        for src,name in [(canonical/take/'generated.png','generated.png'),(canonical/take/'job.json','job.json'),
                         (canonical/'normalization.json','normalization.json'),(folder/'qa.json','qa.json'),
                         (ROOT/prompt_name,'prompt.txt'),(ROOT/'plan.json','plan.json')]:shutil.copy2(src,source/name)
        shutil.copy2(folder/f'{direction}_{action}_sheet.png',GEN/f'{stem}.png')
        count=4 if idle else 8; cols=2 if idle else 4; sw=cols*128; sh=256
        href=f'/generated/{stem}.png'; title=f'风栖原野主角 · {label}{"呼吸" if idle else "行走"} v04（{count}帧修订预览）'
        binding={'actionName':'idle_breathe' if idle else 'walk','triggerType':'auto','triggerValue':'preview-loop',
                 'gameState':f'windrest.preview.v04.{direction}_{action}','notes':'Review candidate only; not game integrated.'}
        sprite={'id':f'sprite_{stem}','characterName':'风栖原野主角','description':f'{label} {"1.8秒呼吸" if idle else "小步幅行走"}；完整眼型、头部摆正、统一比例和配色。仅预览。',
            'style':'warm bright simplified hand-painted cartoon','prompt':prompt,'createdTime':now,'updatedTime':now,'isPreset':False,
            'frameCount':count,'frameSize':[128,128],'cellSize':[128,128],'sheetSize':[sw,sh],
            'spritesheetPng':href,'sourceMasterPng':f'/generated/sources/{stem}/generated.png','generationMode':'spritesheet',
            'gridColumns':cols,'fps':20/9 if idle else 12,'cycleMs':1800 if idle else 2000/3,'loop':True,
            'frames':[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{i%cols*128} {i//cols*128} 128 128" width="128" height="128"><image href="{href}" x="0" y="0" width="{sw}" height="{sh}"/></svg>' for i in range(count)],
            'rootAnchors':[[64,112]]*count,'frameBboxes':qa['frameBboxes'],'sourceEdgeRisks':[],
            'normalization':meta['policy'],'sourceSha256':meta['sourceSha256'],'globalScale':meta['globalScale'],
            'proportionPolicy':'One common scale per action/direction; no local edits or per-frame scale',
            'previewOnly':True,'status':'needs-visual-review','derivation':'whole-frame horizontal mirror' if direction=='left' else 'complete generated frames',
            'provenance':{'route':'host:image_gen + generate2dmedia adopt','model':'not exposed','cost':'unknown',
                'sourceDirection':sd,'selectedTake':take,'rawSheet':f'/generated/sources/{stem}/generated.png','revision':'v04'}}
        aid=f'asset_{stem}'; cid=f'clip_{stem}'; assert all(a['id']!=aid for a in before['assets'])
        asset={'id':aid,'name':title,'role':'player','confirmed':False,'savedTime':now,'updatedTime':now,
               'defaultAnimationId':cid,'binding':binding,'tags':['windrest','v04','preview','not-game-integrated'],
               'sprite':sprite,'animations':[{'id':cid,'name':title,'actionName':binding['actionName'],'direction':engine_dir,
                   'binding':copy.deepcopy(binding),'loop':True,'fps':sprite['fps'],'sprite':copy.deepcopy(sprite)}]}
        assets.append(asset); added.append(aid)
after['assets']=assets+after['assets']; after['updatedTime']=now
assert after['assets'][len(assets):]==before['assets']
assert all(before[k]==after[k] for k in before if k not in ['assets','updatedTime'])
backup.write_bytes(raw); LIB.write_text(json.dumps(after,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'addedAssetIds':added,'beforeCount':len(before['assets']),'afterCount':len(after['assets']),
        'allPriorAssetsAndOrderUnchanged':True,'otherLibraryDataUnchanged':True,'allNewAssetsConfirmed':False,
        'beforeSha256':hashlib.sha256(raw).hexdigest(),'afterSha256':hashlib.sha256(LIB.read_bytes()).hexdigest()}
(ROOT/'gorest_library_change.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,ensure_ascii=True))
