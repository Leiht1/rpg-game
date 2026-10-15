"""Update only the two existing unconfirmed side previews; preserve the library."""
from pathlib import Path
import copy,json,hashlib,shutil
from datetime import datetime,timezone
from PIL import Image
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1]
GEN=ROOT/'.forge/gorest/public/generated';LIB=GEN/'game_asset_library.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
raw=LIB.read_bytes();before=json.loads(raw);after=copy.deepcopy(before)
assert not (OUT/'gorest_library.before.json').exists()
dest=GEN/'sources/windrest_hero_pose_locked_v10';dest.mkdir(parents=True,exist_ok=False)
for name in ['preview.html','pose_lock.json','registration.json','verification.json','provenance.json','RESULT.md','QC_FINDINGS.md','gorest_diagnostic.json','side_v08_sheet.png','side_contact.png','crossview_contact.png','crossview_walk.webp','crossview_walk.gif','crossview_walk_slow.webp','side_before_after.webp','side_before_after_slow.webp']:
    shutil.copy2(OUT/name,dest/name)
for di in ['front','back','right','left']:
    folder=dest/f'{di}_walk_preview';folder.mkdir()
    shutil.copy2(OUT/f'{di}_walk_preview/{di}_walk_sheet.png',folder/f'{di}_walk_sheet.png')
changed=[];now=datetime.now(timezone.utc).isoformat()
for di,label in [('right','右侧'),('left','左侧')]:
    aid=f'asset_windrest_hero_{di}_walk_v07';a=next(a for a in after['assets'] if a['id']==aid)
    assert a['confirmed'] is False
    name=f'风栖原野主角 · {label}行走 v10（v08原姿势，仅尺寸/清晰度）'
    png=GEN/f'windrest_hero_{di}_walk_v10.png';assert not png.exists()
    shutil.copy2(OUT/f'{di}_walk_preview/{di}_walk_sheet.png',png)
    url=f'/generated/{png.name}';s=a['sprite'];inherited=copy.deepcopy(s.get('provenance',{}))
    svg=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{i%4*128} {i//4*128} 128 128" width="128" height="128"><image href="{url}" x="0" y="0" width="512" height="256"/></svg>' for i in range(8)]
    boxes=[Image.open(OUT/f'{di}_walk_preview/frames/{di}_walk_{i:02}.png').getchannel('A').point(lambda a:255 if a>32 else 0).getbbox() for i in range(8)]
    s.update({'description':'严格沿用v08八个完整姿势，保留第5帧右腿和第6帧左手；只作整帧等比尺寸/定位、统一采样和轻度RGB锐化，与正背视对照。无重绘或新动作，生成0次。',
        'prompt':'Existing v08 pose-locked source processing only. No image-generation prompt or new image call. See pose_lock.json and registration.json.',
        'updatedTime':now,'spritesheetPng':url,'sourceMasterPng':url,'frames':svg,'frameCount':8,'frameSize':[128,128],'cellSize':[128,128],'sheetSize':[512,256],'gridColumns':4,
        'fps':13.8,'cycleMs':8000/13.8,'loop':True,'rootAnchors':[[64,112]]*8,'frameBboxes':boxes,'sourceEdgeRisks':[],'sourceSha256':sha(png),'previewOnly':True,'status':'needs-visual-review','globalScale':None,
        'normalization':'V08 pose-locked complete-frame isotropic source-size/position calibration; common 512->128 premultiplied LANCZOS and bounded RGB-only sharpening across front/back/side. No rotation, shear, part edits or new pose pixels.',
        'derivation':'All eight complete right-facing poses from v08, in original order. No v09 art. Left is the complete-frame mirror.',
        'provenance':{'art_source':'existing','route':'v08 source registration and shared deterministic finish','revision':'v10','model':None,'imageCalls':0,'videoCalls':0,'estimateUsd':0,'record':'/generated/sources/windrest_hero_pose_locked_v10/','inherited':inherited}})
    a.update({'name':name,'updatedTime':now,'confirmed':False})
    a['tags']=[t for t in a.get('tags',[]) if t!='v10']+['v10','pose-locked-v08']
    a['binding']['notes']='Only v08 full-frame size/position/clarity treatment. No new poses or v09 art; game unchanged.'
    assert len(a['animations'])==1
    a['animations'][0].update({'name':name,'fps':13.8,'sprite':copy.deepcopy(s),'binding':copy.deepcopy(a['binding'])});changed.append(aid)
after['updatedTime']=now
assert [a['id'] for a in before['assets']]==[a['id'] for a in after['assets']]
assert all(a==next(b for b in after['assets'] if b['id']==a['id']) for a in before['assets'] if a['id'] not in changed)
assert all(before[k]==after[k] for k in before if k not in ['assets','updatedTime'])
assert LIB.read_bytes()==raw
(OUT/'gorest_library.before.json').write_bytes(raw);write(LIB,after)
assert json.loads(LIB.read_bytes())==json.loads(json.dumps(after))
write(OUT/'gorest_library_change.json',{'status':'pass','changedIds':changed,'beforeCount':len(before['assets']),'afterCount':len(after['assets']),'idsAndOrderPreserved':True,'otherAssetsAndSceneDataUnchanged':True,'confirmed':False,'previewVersion':'v10','poseVersion':'v08','imageCalls':0,'comparisonUrl':'http://localhost:3000/generated/sources/windrest_hero_pose_locked_v10/preview.html','sheetSha256':{d:sha(GEN/f'windrest_hero_{d}_walk_v10.png') for d in ['right','left']}})
print('Published v08-pose-locked v10 and synchronized crossview review. Two entries updated; all other data preserved.')
