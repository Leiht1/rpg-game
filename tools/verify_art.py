"""Historical layered checks; current whole-frame validation is verify_character.py."""
raise SystemExit('Retired layered validation. Run tools/verify_character.py for current complete character frames.')
from pathlib import Path
from PIL import Image
import json, hashlib, statistics
import numpy as np

root=Path(__file__).resolve().parents[1]
contract=json.loads((root/'assets/hero/actor.json').read_text(encoding='utf-8'))
atlases={s:Image.open(root/f'assets/hero/{s}.png').convert('RGBA') for s in contract['slots']}
failures=[]
rows={}
for slot,im in atlases.items():
    if im.size!=(1536,1024): failures.append(f'{slot}: wrong atlas size {im.size}')
    if im.getpixel((0,0))[3]!=0: failures.append(f'{slot}: nontransparent margin')
for name,row in contract['rows'].items():
    count=6 if name.startswith('idle') else 12
    hashes=[]; frames=[]; bounds=[]
    for i in range(count):
        frame=Image.new('RGBA',(128,128))
        for atlas in atlases.values(): frame.alpha_composite(atlas.crop((i*128,row*128,(i+1)*128,(row+1)*128)))
        hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
        bbox=frame.getchannel('A').getbbox()
        if not bbox: failures.append(f'{name} frame {i}: empty')
        elif min(bbox[0],bbox[1],128-bbox[2],128-bbox[3])<3: failures.append(f'{name} frame {i}: clipped envelope {bbox}')
        bounds.append(bbox)
        frames.append(np.array(frame,dtype=float))
    if name.startswith('walk') and len(set(hashes))!=12: failures.append(f'{name}: repeated walking pose')
    steps=[float(np.abs(frames[i]-frames[(i+1)%count]).mean()) for i in range(count)]
    rows[name]={'frame_count':count,'unique_images':len(set(hashes)),'bounds':bounds,
                'loop_seam_over_median_step':steps[-1]/max(.0001,statistics.median(steps)),
                'shared_anchor':contract['anchor'],'shared_canvas':contract['canvas']}
contact=json.loads((root/'art/rig/contact-data.json').read_text())
max_drift=0
for direction in ['front','back','right','left']:
    for leg in ['near','far']:
        phase_offset=.5 if leg=='near' else 0
        planted=[c for c in contact if c['direction']==direction and c['action']=='walk' and c['leg']==leg and c['planted']]
        # Unwrap support intervals; foot travel + forward body travel is constant.
        for run in [[c for c in planted if c['frame']/12+phase_offset<1],
                    [c for c in planted if c['frame']/12+phase_offset>=1]]:
            points=[c['travel']+40*c['frame']/12 for c in run]
            if points: max_drift=max(max_drift,max(points)-min(points))
if max_drift>1e-6: failures.append(f'geometric support-foot drift: {max_drift}')
report={'status':'pass' if not failures else 'fail','failures':failures,'rows':rows,
        'slots':len(atlases),'geometric_support_foot_drift_px':max_drift,
        'not_proven':['Visual appeal, anatomy and freedom from visible sliding are not established by numeric geometry.',
                      'Discrete 12-frame sampling has positional quantization; motion is cutout rigging, not hand-drawn frames.',
                      'Direction switches replace reference views; left lighting is mirrored. Final production quality is not claimed.']}
(root/'reports/art-tests.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
# Preserve every warning/failure from every published skill QC report verbatim.
findings=['# 素材 QC 记录','', '原始候选的失败保留以便追溯；整理后是否通过必须查看对应 final 报告。','']
for path in sorted((root/'art/qc').glob('*/sheet-qc.json')):
    r=json.loads(path.read_text())
    findings += [f'## {path.parent.name} · {r["status"]}', '']
    flagged=[c for c in r['checks'] if c['status'] in ('warn','fail')]
    if not flagged: findings+=['无 FAIL / WARN。','']
    for check in flagged:
        findings+=['```json',json.dumps({'id':check['id'],'status':check['status'],'value':check.get('value'),
                                       'threshold':check.get('threshold'),'files':[str(path.relative_to(root))]},ensure_ascii=False), '```','']
(root/'art/QC_FINDINGS.md').write_text('\n'.join(findings),encoding='utf-8')
print(json.dumps({'status':report['status'],'failures':failures,'rows':len(rows),'layers':len(atlases),'foot_drift':max_drift}))
raise SystemExit(0 if not failures else 1)
