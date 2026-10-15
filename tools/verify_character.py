"""Verify the published complete-frame actor and its authored pose contract."""
from pathlib import Path
import hashlib, json, statistics
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
HERO=ROOT/'assets/hero'
WORK=ROOT/'art/hero_v11_runtime_v05'

def read(path): return json.loads(path.read_text(encoding='utf-8'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

runtime=read(HERO/'animation/runtime.json')
template=read(HERO/'modular_plan/template.json')
manifest=read(HERO/'animation/clips.json')
registration=read(HERO/'animation/registration.json')
failures=[]; rows={}

def check(condition,message):
    if not condition: failures.append(message)

check(runtime['canvas']==[128,128] and runtime['anchor']==[64,112],'Runtime canvas/root mismatch')
check(template['version']==runtime['template_version']==registration['template_version']=='windrest-character-template-5','Template version mismatch')
check(runtime['movement_speed']==template['timing']['movement_speed']==115,'Movement speed metadata mismatch')
check(len(manifest['clips'])==6 and len(manifest['frames'])==36,'Expected six clips / 36 frames')
check(abs(runtime['stride_world_units']-200/3)<1e-8,'Wrong distance per walk cycle')
walk_records=[f for d in registration['directions'].values() for f in d['frames'] if '_walk_' in f['name']]
check(len(walk_records)==24,'Missing walk registration')
check({f['source_to_output_scale'] for f in walk_records}=={1.0},'Approved walk scale changed')
check({tuple(f['offset']) for f in walk_records}=={(0,0)},'Approved walk registration changed')
for direction in ['front','back','side']:
    records=registration['directions'][direction]['frames']
    for record in records:
        check(sha(ROOT/record['source'])==record['source_sha256'],record['name']+': changed approved source')
    for action,count in [('idle',4),('walk',8)]:
        name=f'{direction}_{action}'; clip=manifest['clips'][name]
        check(len(clip['frames'])==count,name+': wrong frame count')
        check(clip['loop_policy']=='cycle',name+': not looping')
        check(clip['ticks']==(5 if action=='walk' else 27),name+': wrong timing')
        if action=='walk':
            check(clip['speed_ref']==100 and abs(clip['stride_world_units']-200/3)<1e-8,name+': speed/stride mismatch')
        frames=[]; hashes=[]; bounds=[]
        for i in range(count):
            key=f'{name}_{i:02}'; p=HERO/f'final_sprite/{key}.png'; im=Image.open(p)
            check(im.mode=='RGBA' and im.size==(128,128),p.name+': wrong mode/canvas')
            pixels=np.asarray(im)
            bbox=Image.fromarray(np.where(pixels[:,:,3]>16,255,0).astype('uint8')).getbbox()
            check(bbox is not None and min(bbox[0],bbox[1],128-bbox[2],128-bbox[3])>=3,p.name+': clipped/empty')
            frames.append(pixels.astype(float)); hashes.append(sha(p)); bounds.append(bbox)
            rec=[f for f in template['directions'][direction]['frames'] if f['key']==key]
            check(len(rec)==1 and rec[0]['sha256']==hashes[-1] and rec[0]['anchor']==[64,112],p.name+': template mismatch')
            source_record=next(r for r in records if r['name']==key)
            check(hashes[-1]==source_record['output_sha256']==sha(ROOT/source_record['source']),p.name+': approved complete frame changed')
        check(len(set(hashes))==count,name+': duplicate authored poses')
        heights=[b[3]-b[1] for b in bounds]
        steps=[float(np.abs(frames[i]-frames[(i+1)%count]).mean()) for i in range(count)]
        rows[name]={'frame_count':count,'unique_files':len(set(hashes)),'bounds':bounds,
            'anchor':[64,112],'canvas':[128,128],
            'loop_seam_over_median_step':steps[-1]/max(.00001,statistics.median(steps)),
            'body_height_cv':statistics.pstdev(heights)/statistics.mean(heights)}
for name in ['hero-atlas-00.png','hero.tres','hero.tscn']:
    check(sha(HERO/'animation'/name)==sha(WORK/'engine/godot'/name),name+': differs from skill export')
qa_status={}
for folder,name in [('clips','animation-clips.json'),('engine','engine-export.json')]:
    payload=read(WORK/folder/name); qa=payload['qa']; qa_status[folder]=qa['status']
    for c in qa.get('checks',[]):
        check(str(c['status']).lower() not in ['warn','fail'],folder+': '+json.dumps(c,ensure_ascii=False))
baseline=read(WORK/'unchanged_game_baseline.json')
for path,digest in baseline.items(): check(sha(ROOT/path)==digest,path+': unrelated game file changed')
preserved=read(WORK/'unchanged_frames.json')
check(len(preserved)==28,'Expected 28 preserved non-side-walk frames')
for name,digest in preserved.items(): check(sha(HERO/'final_sprite'/name)==digest,name+': previous accepted frame changed')
for i in range(8):
    approved=ROOT/f'art/hero_v08_pose_redraw_preview_v11/right_walk_preview/frames/right_walk_{i:02}.png'
    check(sha(HERO/f'final_sprite/side_walk_{i:02}.png')==sha(approved),f'side_walk_{i:02}: differs from approved v11')
check(sha(HERO/'modular_plan/CHARACTER_MODULAR_RULES.md')==sha(ROOT/'CHARACTER_MODULAR_RULES.md'),'Character rules copy out of sync')
report={'status':'pass' if not failures else 'fail','failures':failures,'rows':rows,
    'runtime_layers':1,'template_version':template['version'],'whole_frames':36,
    'common_walk_scale':1.0,'common_walk_offset':[0,0],'movement_speed':115,'idle_cycle_ms':1800,'skill_qa':qa_status,
    'approved_v11_frames':8,'preserved_previous_frames':len(preserved),
    'not_proven':['Numeric geometry does not certify anatomy, facing, identity or perfectly planted feet.',
        'The v11 side walk is user accepted; v04 front/back walk and v05 idle remain unchanged. Small redraw contour/projection differences remain.',
        'Left mirrors the complete side frame including its soft lighting.']}
(ROOT/'reports/character-art-tests.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':report['status'],'failures':failures,'clips':len(rows),'whole_frames':36,'skill_qa':qa_status}))
raise SystemExit(0 if not failures else 1)
