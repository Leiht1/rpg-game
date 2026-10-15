"""Verify preview artifacts and runtime invariants; no engine integration."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, zipfile
import numpy as np
from PIL import Image

OUT=Path(__file__).resolve().parent; PROJECT=OUT.parents[1]
APP=Path(r'C:\Users\HT\Documents\Codex\2026-10-15\https-github-com-0x0funky-agent-sprite\outputs\gorest-2d-animation-spritesheet-generator-main')
def read(path): return json.loads(path.read_text(encoding='utf-8'))
def save(path,value): path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

now=datetime.now(timezone.utc).isoformat()
before=read(OUT/'game_files_before.json')
current_paths=[p for folder in ['assets/hero','scripts','scenes'] for p in (PROJECT/folder).rglob('*') if p.is_file() and p.suffix not in ['.import','.uid']]
current={p.relative_to(PROJECT).as_posix():sha(p) for p in current_paths}
current['project.godot']=sha(PROJECT/'project.godot')
assert current==before, 'Runtime assets, code or scene files changed.'
pngs=[]; frames={}; alpha_bounds={}
for d in ['front','back','right','left']:
    frames[d]=[]; sheet=Image.open(OUT/d/f'{d}_idle_breathe_sheet.png').convert('RGBA')
    meta=read(OUT/d/'normalization.json'); assert meta['rootAnchors']==[[64,112]]*4
    assert meta['frameSize']==[128,128] and sheet.size==(256,256)
    assert len({t['source_to_output_scale'] for t in meta['transforms']})==1
    alpha_bounds[d]=[]
    for i in range(4):
        p=OUT/d/'frames'/f'{d}_idle_breathe_{i:02}.png'; im=Image.open(p)
        assert im.mode=='RGBA' and im.size==(128,128)
        a=np.array(im); assert a[:,:,3].min()==0 and a[:,:,3].max()>16
        b=im.getchannel('A').point(lambda v:255 if v>16 else 0).getbbox()
        assert b[3]==112 and min(b[0],b[1],128-b[2],128-b[3])>=16
        crop=sheet.crop(((i%2)*128,(i//2)*128,(i%2+1)*128,(i//2+1)*128))
        assert np.array_equal(a,np.array(crop)), 'Sheet differs from standalone PNG'
        frames[d].append(a); alpha_bounds[d].append(b)
        pngs.append({'path':p.relative_to(OUT).as_posix(),'sha256':sha(p)})
    assert len({a.tobytes() for a in frames[d]})==4
for i in range(4): assert np.array_equal(frames['left'][i],frames['right'][i][:,::-1,:])
animations=[]
for stem in [*(OUT/d/f'{d}_idle_breathe_preview' for d in ['front','back','side','right','left']), OUT/'four_directions_preview',OUT/'game_size_preview']:
    for ext in ['gif','webp']:
        p=stem.with_suffix('.'+ext); im=Image.open(p); durations=[]
        assert im.n_frames==4
        for i in range(im.n_frames):
            im.seek(i); im.load(); durations.append(im.info['duration'])
        assert durations==[750]*4 and im.info.get('loop')==0
        animations.append({'file':p.relative_to(OUT).as_posix(),'frameCount':4,'durationMs':sum(durations),'sha256':sha(p)})
before_library=read(OUT/'gorest_library.before.json')
after_library=read(APP/'public/generated/game_asset_library.json')
assert after_library['assets'][4:]==before_library['assets']
assert all(before_library[k]==after_library[k] for k in before_library if k not in ['assets','updatedTime'])
for d,asset in zip(['front','back','right','left'],after_library['assets'][:4]):
    assert asset['id']==f'asset_windrest_hero_{d}_idle_breathe_v01'
    assert not asset['confirmed'] and asset['sprite']['fps']==4/3
    assert asset['sprite']['frameCount']==4 and asset['sprite']['gridColumns']==2
    assert (APP/'public'/asset['sprite']['spritesheetPng'].lstrip('/')).read_bytes()==(OUT/d/f'{d}_idle_breathe_sheet.png').read_bytes()
skill=read(OUT/'clips_fixed_feet/animation-clips.json')
assert skill['qa']['status']=='needs-visual-review' and not skill['diagnostics']['lint']
assert all(c['status'] not in ['warn','fail'] for c in skill['qa']['checks'])
for d in ['front','back','side']:
    job=read(OUT/d/'take1/job.json'); assert job['artifact']['sha256']==sha(OUT/d/'take1/generated.png')
    reference=Image.open(OUT/f'references/{d}_idle_master.png').convert('RGBA')
    runtime=Image.open(PROJECT/f'assets/hero/final_sprite/{d}_idle_00.png').convert('RGBA')
    assert np.array_equal(np.array(reference),np.array(runtime))
screens=['gorest_four_direction_gallery.png','gorest_front_frame02.png','gorest_back_preview.png','gorest_right_preview.png','gorest_left_preview.png']
for s in screens: Image.open(OUT/s).verify()
save(OUT/'browser_verification.json',{'checkedAt':now,'url':'http://localhost:3000/',
    'surface':'Spritesheet Only','directionsOpened':['front','back','right','left'],
    'observedFrameCount':4,'observedGrid':[2,2],'observedFrameSize':[128,128],
    'observedPlayback':True,'pauseResumeChecked':['front','right'],
    'manualFramesChecked':{'front':[2,4],'right':[2]},'frameOrder':'one-based UI indices',
    'leftMirrorFacingVerified':True,'finalSurface':'gallery, first four breathing preview cards',
    'timingEvidence':'GIF/WebP file verification + Gorest playback interval uses sprite.fps=4/3 => 750ms; no wall-clock browser benchmark',
    'screenshots':[{'file':s,'sha256':sha(OUT/s)} for s in screens]})
save(OUT/'gorest_build_verification.json',{'lint':{'command':'npm.cmd run lint','exitCode':0},
    'build':{'command':'npm.cmd run build','exitCode':0,'jsKB':599.71,'jsGzipKB':170.16,
        'warning':'(!) Some chunks are larger than 500 kB after minification. Consider:',
        'warningDetails':['Using dynamic import() to code-split the application',
            'Use build.rolldownOptions.output.codeSplitting to improve chunking: https://rolldown.rs/reference/OutputOptions.codeSplitting',
            'Adjust chunk size limit for this warning via build.chunkSizeWarningLimit.']}})
report={'status':'preview_files_verified_user_visual_review_pending','runtimeIntegrated':False,
    'runtimeFilesUnchanged':len(before),'pngFrameCount':16,'framesPerDirection':4,
    'canvas':[128,128],'anchor':[64,112],'visibleSoleBaseline':112,'alphaBounds':alpha_bounds,
    'sheetRoundTrip':'pass','leftRightWholeFrameMirror':'pass','nativeAlpha':'pass',
    'sourceReferencesPixelIdenticalToExistingIdle':True,'oldGorestAssetsPreserved':len(before_library['assets']),
    'otherLibraryDataUnchanged':True,'newGorestAssetsConfirmed':False,
    'skillStatus':skill['qa']['status'],'skillChecks':skill['qa']['checks'],
    'animations':animations,'pngs':pngs,'generatedAt':now}
save(OUT/'export_verification.json',report)
plan=read(OUT/'plan.json'); plan['generation_pending']=False
plan['status']='preview_ready_user_visual_review_pending'; plan['effective_skill_output']='clips_fixed_feet/animation-clips.json'
save(OUT/'plan.json',plan)
archive=OUT/'hero_idle_breathe_preview_v01.zip'
skip_names={'gorest_library.before.json','game_files_before.json'}
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(OUT.rglob('*')):
        if not p.is_file() or p==archive or p.name in skip_names: continue
        rel=p.relative_to(OUT)
        if rel.parts[0] in ['clips','__pycache__'] or '__pycache__' in rel.parts or p.suffix=='.zip': continue
        z.write(p,rel.as_posix())
    z.write(PROJECT/'CHARACTER_SEQUENCE_WORKFLOW.md','CHARACTER_SEQUENCE_WORKFLOW.md')
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    count=len(z.namelist())
save(OUT/'archive_verification.json',{'status':'pass','file':archive.name,'crc':'pass','entries':count,'bytes':archive.stat().st_size,'sha256':sha(archive)})
print(json.dumps({'status':report['status'],'runtimeFilesUnchanged':len(before),'pngFrames':16,'animatedPreviewsChecked':len(animations),'oldGorestAssetsPreserved':len(before_library['assets']),'archiveEntries':count,'archiveBytes':archive.stat().st_size,'skillStatus':skill['qa']['status']}))
