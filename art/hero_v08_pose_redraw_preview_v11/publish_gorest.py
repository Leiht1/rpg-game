"""Publish the new authorized redraw as an unconfirmed candidate, preserving the library."""
from pathlib import Path
import copy,json,hashlib,shutil
from datetime import datetime,timezone
from PIL import Image
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1];GEN=ROOT/'.forge/gorest/public/generated';LIB=GEN/'game_asset_library.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
raw=LIB.read_bytes();before=json.loads(raw);after=copy.deepcopy(before)
backup=OUT/'gorest_library.before.json';assert not backup.exists()
dest=GEN/'sources/windrest_hero_pose_redraw_v11';dest.mkdir(parents=True,exist_ok=False)
for name in ['preview.html','pose_reference.json','pose_and_scale_diagnostics.json','review_metrics.json','registration.json','verification.json','provenance.json','selection.json','RESULT.md','QC_FINDINGS.md','side_v08_sheet.png','side_contact.png','crossview_contact.png','pose_comparison_contact.png','crossview_walk.webp','crossview_walk.gif','crossview_walk_slow.webp','side_before_after.webp','side_before_after_slow.webp','prompt_take1.txt','prompt_take2.txt','frames_and_records.zip']:
    shutil.copy2(OUT/name,dest/name)
for name in ['take1','take2','references']:shutil.copytree(OUT/name,dest/name)
for di in ['front','back','right','left']:
    p=dest/f'{di}_walk_preview';p.mkdir();shutil.copy2(OUT/f'{di}_walk_preview/{di}_walk_sheet.png',p/f'{di}_walk_sheet.png')
changed=[];now=datetime.now(timezone.utc).isoformat()
for di,label in [('right','右侧'),('left','左侧')]:
    aid=f'asset_windrest_hero_{di}_walk_v07';a=next(a for a in after['assets'] if a['id']==aid);assert a['confirmed'] is False
    title=f'风栖原野主角 · {label}行走 v11（按v08逐帧姿势统一重绘）'
    png=GEN/f'windrest_hero_{di}_walk_v11.png';assert not png.exists();shutil.copy2(OUT/f'{di}_walk_preview/{di}_walk_sheet.png',png)
    url=f'/generated/{png.name}';s=a['sprite'];inherited=copy.deepcopy(s.get('provenance',{}))
    svg=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{i%4*128} {i//4*128} 128 128" width="128" height="128"><image href="{url}" x="0" y="0" width="512" height="256"/></svg>' for i in range(8)]
    boxes=[Image.open(OUT/f'{di}_walk_preview/frames/{di}_walk_{i:02}.png').getchannel('A').point(lambda a:255 if a>16 else 0).getbbox() for i in range(8)]
    s.update({'description':'按用户新授权重绘完整侧视8帧，逐帧参考v08的原姿势、顺序和遮挡，统一头、躯干、手脚及清晰度。最终全套取take2，单一源尺度，左向整帧镜像；正背视参考同步对照。未接入游戏，待确认。',
        'prompt':'\n\n'.join((OUT/f'prompt_take{i}.txt').read_text(encoding='utf-8') for i in [1,2]),
        'updatedTime':now,'spritesheetPng':url,'sourceMasterPng':url,'frames':svg,'frameCount':8,'frameSize':[128,128],'cellSize':[128,128],'sheetSize':[512,256],'gridColumns':4,'fps':13.8,'cycleMs':8000/13.8,'loop':True,'rootAnchors':[[64,112]]*8,'frameBboxes':boxes,'sourceEdgeRisks':[],
        'sourceSha256':sha(png),'previewOnly':True,'status':'needs-visual-review','globalScale':0.2746268656716418,
        'normalization':'All eight poses from one selected complete-sheet redraw, one shared source scale, complete-frame rigid registration only; common premultiplied sampling with approved front/back references. No per-frame fitting, part patch or nonuniform deformation.',
        'derivation':'User-authorized complete redraw using v08 exact-pose references; take2 indices0..7; no mixed takes or v09 art. Left is the full-frame mirror.',
        'provenance':{'art_source':'host_image','route':'host:image_gen + generate2dmedia cli_media.py adopt','revision':'v11','sourcePoseVersion':'v08','selectedTake':'take2','model':'not exposed','imageCalls':2,'videoCalls':0,'estimateUsd':None,'record':'/generated/sources/windrest_hero_pose_redraw_v11/','inherited':inherited}})
    a.update({'name':title,'updatedTime':now,'confirmed':False});a['tags']=[t for t in a.get('tags',[]) if t!='v11']+['v11','v08-pose-redraw']
    a['binding']['notes']='Authorized v11 full-character redraw based on all v08 poses. Candidate only; current game and original v08 preserved.'
    assert len(a['animations'])==1;a['animations'][0].update({'name':title,'fps':13.8,'sprite':copy.deepcopy(s),'binding':copy.deepcopy(a['binding'])});changed.append(aid)
after['updatedTime']=now
assert [a['id'] for a in before['assets']]==[a['id'] for a in after['assets']]
assert all(a==next(b for b in after['assets'] if b['id']==a['id']) for a in before['assets'] if a['id'] not in changed)
assert all(before[k]==after[k] for k in before if k not in ['assets','updatedTime']);assert LIB.read_bytes()==raw
backup.write_bytes(raw);write(LIB,after);assert json.loads(LIB.read_bytes())==json.loads(json.dumps(after))
write(OUT/'gorest_library_change.json',{'status':'pass','changedIds':changed,'beforeCount':len(before['assets']),'afterCount':len(after['assets']),'idsAndOrderPreserved':True,'otherAssetsAndSceneDataUnchanged':True,'confirmed':False,'version':'v11','poseReference':'v08','selectedTake':'take2','imageCalls':2,'comparisonUrl':'http://localhost:3000/generated/sources/windrest_hero_pose_redraw_v11/preview.html','sheetSha256':{d:sha(GEN/f'windrest_hero_{d}_walk_v11.png') for d in ['right','left']}})
print('Published the unconfirmed v11 redraw, preserving all library IDs/order and other data.')
