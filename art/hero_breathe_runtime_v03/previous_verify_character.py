"""Verify the published complete-frame actor and its authored pose contract."""
from pathlib import Path
import hashlib, json, statistics
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
HERO=ROOT/'assets/hero'
WORK=ROOT/'art/hero_gorest_runtime_v02'

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
check(template['version']==runtime['template_version']==registration['template_version']=='windrest-character-template-2','Template version mismatch')
check(len(manifest['clips'])==6 and len(manifest['frames'])==27,'Expected six clips / 27 frames')
check(abs(runtime['stride_world_units']-200/3)<1e-8,'Wrong distance per walk cycle')
walk_records=[f for d in registration['directions'].values() for f in d['frames'] if '_walk_' in f['name']]
check(len(walk_records)==24,'Missing walk registration')
check({f['source_to_output_scale'] for f in walk_records}=={140/256},'Variable walk scale')
check({tuple(f['offset']) for f in walk_records}=={(-6,7)},'Variable walk registration')
for direction in ['front','back','side']:
    records=registration['directions'][direction]['frames']
    for record in records:
        check(sha(ROOT/record['source'])==record['source_sha256'],record['name']+': changed approved source')
    for action,count in [('idle',1),('walk',8)]:
        name=f'{direction}_{action}'; clip=manifest['clips'][name]
        check(len(clip['frames'])==count,name+': wrong frame count')
        check(clip['loop_policy']=='cycle',name+': not looping')
        check(clip['ticks']==(5 if action=='walk' else 60),name+': wrong timing')
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
            if action=='idle':
                check(hashes[-1]==sha(WORK/f'previous_runtime/final_sprite/{key}.png'),p.name+': neutral idle changed')
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
report={'status':'pass' if not failures else 'fail','failures':failures,'rows':rows,
    'runtime_layers':1,'template_version':template['version'],'whole_frames':27,
    'common_walk_scale':140/256,'common_walk_offset':[-6,7],'skill_qa':qa_status,
    'not_proven':['Numeric geometry does not certify anatomy, facing, identity or perfectly planted feet.',
        'Single-frame idle is a neutral hold; its drawing proportions differ slightly from the new walk.',
        'Left mirrors the complete side frame including its soft lighting.']}
(ROOT/'reports/character-art-tests.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'status':report['status'],'failures':failures,'clips':len(rows),'whole_frames':27,'skill_qa':qa_status}))
raise SystemExit(0 if not failures else 1)
