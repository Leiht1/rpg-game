"""Update only the five unconfirmed revision entries; preserve live user edits."""
from pathlib import Path
import copy,json,hashlib,shutil
from datetime import datetime,timezone
OUT=Path(__file__).resolve().parent;OLD=OUT.parent/'hero_consistency_preview_v04'
APP=Path(r'C:/Users/HT/Documents/Codex/2026-10-15/https-github-com-0x0funky-agent-sprite/outputs/gorest-2d-animation-spritesheet-generator-main')
GEN=APP/'public/generated';LIB=GEN/'game_asset_library.json'
raw=LIB.read_bytes();before=json.loads(raw);after=copy.deepcopy(before)
backup=OUT/'gorest_library.before.json';assert not backup.exists()
now=datetime.now(timezone.utc).isoformat();changed=[]
for di,action,label in [('front','idle','正面'),('right','idle','右侧'),('left','idle','左侧'),('right','walk','右侧'),('left','walk','左侧')]:
    suffix='idle_breathe' if action=='idle' else 'walk'
    aid=f'asset_windrest_hero_{di}_{suffix}_v04'
    asset=next(a for a in after['assets'] if a['id']==aid);assert asset['confirmed'] is False
    sprite=asset['sprite'];stem=f'windrest_hero_{di}_{suffix}_v05';href=f'/generated/{stem}.png'
    folder=OUT/f'{di}_{action}_preview';shutil.copy2(folder/f'{di}_{action}_sheet.png',GEN/f'{stem}.png')
    source=GEN/'sources'/stem;source.mkdir(parents=True,exist_ok=True)
    title=f'风栖原野主角 · {label}{"呼吸脚底对齐" if action=="idle" else "行走手脚衔接"} v05（修订预览）'
    count=4 if action=='idle' else 8;cols=2 if action=='idle' else 4;w=128*cols;h=256
    frames=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{i%cols*128} {i//cols*128} 128 128" width="128" height="128"><image href="{href}" x="0" y="0" width="{w}" height="{h}"/></svg>' for i in range(count)]
    if action=='idle':
        canonical='front' if di=='front' else 'right'
        registration=json.loads((OUT/f'{canonical}_idle_preview/registration.json').read_text(encoding='utf-8'))
        raw_sprite=OLD/('front_breathe/take1' if di=='front' else 'side_breathe/take2')
        for name in ['generated.png','job.json']:shutil.copy2(raw_sprite/name,source/name)
        (source/'registration.json').write_text(json.dumps(registration,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        desc='以双脚重新刚性对齐完整原帧；胸肩呼吸保留，背面未修改。1.8 秒循环，仅预览。'
        prompt='Existing v04 full-frame breathing art; feet-only rigid registration, same scale, no new drawing or frozen local patches.'
        norm=registration['policy'];scale=registration['scale'];source_master=f'/generated/sources/{stem}/generated.png'
        derivation='existing full frames; feet-only registration'
    else:
        for take in ['take1','take2','take3','take4']:
            sub=source/take;sub.mkdir(exist_ok=True)
            for name in ['generated.png','job.json','registration.json']:
                if (OUT/'side_walk'/take/name).exists():shutil.copy2(OUT/'side_walk'/take/name,sub/name)
        shutil.copy2(OUT/'side_walk/selection.json',source/'selection.json')
        for p in OUT.glob('*prompt.txt'):shutil.copy2(p,source/p.name)
        desc='逐帧核对近远手脚与反向摆臂，修正第 3、5、6、7 帧及第 8 帧回环；第 1、2、4 帧保留。12 FPS，仅预览。'
        prompt=(OUT/'side_second_half_prompt.txt').read_text(encoding='utf-8')
        norm='Selected complete v04/take1/take3/take4 figures; one scale per source canvas, shared head registration. No limb patches or warps.'
        scale=None;source_master=href;derivation='selected complete generated poses; selection.json records every frame'
    files=sorted((folder/'frames').glob('*.png'))
    from PIL import Image
    bboxes=[Image.open(p).getchannel('A').point(lambda a:255 if a>16 else 0).getbbox() for p in files]
    sprite.update({'description':desc,'prompt':prompt,'updatedTime':now,'spritesheetPng':href,'sourceMasterPng':source_master,
        'frameCount':count,'frameSize':[128,128],'cellSize':[128,128],'sheetSize':[w,h],'gridColumns':cols,
        'fps':20/9 if action=='idle' else 12,'cycleMs':1800 if action=='idle' else 2000/3,'loop':True,
        'frames':frames,'rootAnchors':[[64,112]]*count,'frameBboxes':bboxes,'sourceEdgeRisks':[],
        'normalization':norm,'globalScale':scale,'proportionPolicy':'Shared scale per source sheet/canvas; no per-pose body-bbox scale',
        'sourceSha256':hashlib.sha256((GEN/f'{stem}.png').read_bytes()).hexdigest(),
        'previewOnly':True,'status':'needs-visual-review','derivation':derivation+('; whole-frame horizontal mirror' if di=='left' else ''),
        'provenance':{'route':'host:image_gen + generate2dmedia adopt' if action=='walk' else 'existing host:image_gen art + whole-frame registration',
            'model':'not exposed','cost':'unknown','revision':'v05','record':f'/generated/sources/{stem}/'}})
    asset.update({'name':title,'updatedTime':now,'confirmed':False})
    asset['tags']=[x for x in asset.get('tags',[]) if x!='v04']+['v05']
    asset['binding']['gameState']=f'windrest.preview.v05.{di}_{action}'
    for clip in asset['animations']:
        clip.update({'name':title,'fps':sprite['fps'],'sprite':copy.deepcopy(sprite)})
        clip['binding']=copy.deepcopy(asset['binding'])
    changed.append(aid)
after['updatedTime']=now
assert [a['id'] for a in before['assets']]==[a['id'] for a in after['assets']]
assert all(a==b for a,b in zip(before['assets'],after['assets']) if a['id'] not in changed)
assert all(before[k]==after[k] for k in before if k not in ['assets','updatedTime'])
backup.write_bytes(raw)
# Recheck the file immediately before publishing, preserving concurrent edits.
assert LIB.read_bytes()==raw,'Library changed during preparation; retry from fresh snapshot.'
LIB.write_text(json.dumps(after,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(OUT/'gorest_library_change.json').write_text(json.dumps({'changedIds':changed,'assetCount':len(after['assets']),
    'idAndOrderPreserved':True,'otherAssetsUnchanged':True,'otherDataUnchanged':True,'confirmed':False},indent=2)+'\n',encoding='utf-8')
print('Updated 5 preview entries; 57 entries/order and unrelated content preserved.')
