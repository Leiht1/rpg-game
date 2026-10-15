from pathlib import Path
import json,hashlib,urllib.request,zipfile
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
base='http://localhost:3000'
library=json.loads(urllib.request.urlopen(base+'/api/game-library').read())
change=json.loads((OUT/'gorest_library_change.json').read_text(encoding='utf-8'))
results={}
for di in ['right','left']:
    p=OUT/f'{di}_walk_preview/{di}_walk_sheet.png'
    data=urllib.request.urlopen(base+f'/generated/windrest_hero_{di}_walk_v11.png').read()
    assert hashlib.sha256(data).hexdigest()==sha(p)
    a=next(a for a in library['assets'] if a['id']==f'asset_windrest_hero_{di}_walk_v07')
    assert 'v11' in a['name'] and a['confirmed'] is False and a['sprite']['frameCount']==8
    results[di]={'name':a['name'],'servedSha256':sha(p),'confirmed':False,'frames':8}
assert len(library['assets'])==change['afterCount']
runtime=json.loads((OUT/'game_files_before.json').read_text(encoding='utf-8'))
assert all(sha(ROOT/p)==h for p,h in runtime.items())
source=json.loads((OUT/'pose_reference.json').read_text(encoding='utf-8'))
assert all(sha(ROOT/p)==h for p,h in source['sourceHashes'].items())
with zipfile.ZipFile(OUT/'frames_and_records.zip') as z:assert z.testzip() is None
report={'status':'pass','libraryAssets':len(library['assets']),'servedPreviews':results,'runtimeFilesUnchanged':len(runtime),'poseReferenceSourcesUnchanged':True,'zipCRC':'pass','browser':{'url':base+'/generated/sources/windrest_hero_pose_redraw_v11/preview.html','visibleViews':['v08 original','v11 redraw','approved front','approved back'],'pauseAndSelectFrames':[5,6],'halfSpeed':6.9,'originalSpeed':13.8,'oneToOneAndDoubleScale':'checked','lightAndDark':'checked','finalPlayback':'playing at original speed','screenshots':['browser_frame5.jpg','browser_frame6.jpg','browser_crossview.jpg']},'visualStatus':'needs-visual-review','gameChanged':False}
(OUT/'delivery_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'servedPreviews':2,'libraryAssets':len(library['assets']),'unchangedRuntimeFiles':len(runtime),'status':'pass','visualStatus':'needs-visual-review'}))
