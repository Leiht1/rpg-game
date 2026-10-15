"""Scope-limited asset checks; no Godot import or game asset mutations."""
from pathlib import Path
import hashlib, json
import numpy as np
from PIL import Image, ImageSequence
OUT=Path(__file__).resolve().parent; ROOT=OUT.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

manifest=json.loads((OUT/'clips_input.json').read_text()); clips=json.loads((OUT/'clips_final/animation-clips.json').read_text())
assert len(manifest['frames'])==48 and len(manifest['clips'])==8
frames=[]
for i,rel in enumerate(manifest['frames']):
    p=OUT/rel; im=Image.open(p); assert im.size==(128,128) and im.mode=='RGBA'; a=np.array(im)[:,:,3]
    assert a.min()==0 and a.max()>0 and not np.any(a[[0,-1],:]) and not np.any(a[:,[0,-1]])
    assert p.read_bytes()==(OUT/'clips_final'/clips['frames'][i]['file']).read_bytes()
    frames.append({'file':rel,'sha256':sha(p)})
for d in ['front','back','right','left']:
    for action in ['idle','walk']:
        name=f'{d}_{action}'; c=clips['clips'][name]
        assert len(c['frames'])==(4 if action=='idle' else 8)
        assert c['total_duration_ms']==(1800 if action=='idle' else 667)
        assert c['preview']['timeline_verified'] and c['preview']['alpha_and_visible_rgb_exact']
        folder=OUT/f'{name}_preview'; sheet=Image.open(folder/f'{name}_sheet.png').convert('RGBA'); cols=2 if action=='idle' else 4
        for i in range(len(c['frames'])):
            im=Image.open(folder/'frames'/f'{name}_{i:02}.png').convert('RGBA')
            assert im.tobytes()==sheet.crop((i%cols*128,i//cols*128,(i%cols+1)*128,(i//cols+1)*128)).tobytes()
            if d=='left':
                right=Image.open(OUT/f'right_{action}_preview/frames/right_{action}_{i:02}.png').convert('RGBA')
                assert im.tobytes()==right.transpose(Image.Transpose.FLIP_LEFT_RIGHT).tobytes()

preview_files={}
for name in ['four_directions_idle','four_directions_walk','side_walk_before_after','idle_walk_switch']:
    for ext in ['gif','webp']:
        p=OUT/f'{name}.{ext}'; im=Image.open(p); durations=[]
        for f in ImageSequence.Iterator(im):
            f.load(); durations.append(f.info.get('duration',im.info.get('duration',0)))
        preview_files[p.name]={'frames':im.n_frames,'durationMs':sum(durations),'sha256':sha(p)}
assert preview_files['four_directions_idle.gif']['durationMs']==1800
assert preview_files['four_directions_idle.webp']['durationMs']==1800
before=json.loads((OUT/'game_files_before.json').read_text(encoding='utf-8-sig'))
after={p:sha(ROOT/p) for p in before}; changed=[p for p in before if before[p]!=after[p]]; assert not changed
save(OUT/'game_files_after.json',after)
qa=json.loads((OUT/'qa_summary.json').read_text()); spans=qa['right_walk']
static={d:max(abs(v) for k in ['headResidual','legsResidual'] for a in qa[f'{d}_idle'][k] for v in a['bestRigidResidualShiftPx']) for d in ['front','back','right','left']}
provenance={'art_source':'host_image','route':'host:image_gen + generate2dmedia cli_media.py adopt',
 'completedImageCalls':8,'interruptedImageCalls':1,'videoCalls':0,'model':'not exposed','cost':'unknown; adoption estimate is not generation billing',
 'licenseBoundary':'Generated original character edits under provider and account applicable terms; no external downloads or protected commercial game assets; not asserted public domain or open-source.',
 'rawTakes':[{'file':str(p.relative_to(OUT)).replace('\\','/'),'sha256':sha(p)} for p in sorted(OUT.glob('*/*/generated.png'))],
 'prompts':[{'file':p.name,'sha256':sha(p)} for p in sorted(OUT.glob('*prompt.txt'))],
 'references':[{'file':str(p.relative_to(OUT)).replace('\\','/'),'sha256':sha(p)} for p in sorted((OUT/'references').glob('*.png'))],
 'selection':{'walk':{'front':'take1','back':'take1','side':'take1'},'breathe':{'front':'take1','back':'take1','side':'take2'}},
 'rejectedRefinement':'front_breathe/take2: static-region estimated max residual .852px vs take1 .766px, not a stability improvement.',
 'processing':'Native alpha <=8 cleanup; Gorest actual source cell detection; one common scale per action/direction; whole-frame rigid registration. No local art patches/warps or per-frame scale.',
 'finalFrames':frames}
save(OUT/'provenance.json',provenance)
report={'status':'technical_checks_pass_visual_review_pending','frames':48,'clips':8,'canvas':[128,128],'root':[64,112],
 'gameFilesChecked':len(before),'gameFilesChanged':changed,'pngByteCopies':True,'sheetReadbackExact':True,'mirrorExact':True,
 'previewFiles':preview_files,'skillQaStatus':clips['qa']['status'],'skillChecks':clips['qa']['checks'],
 'staticRegionMaxEstimatedShiftPx':static,'sideBootBandMaxSpanBeforePx':max(spans['oldBootBandSpanPx']),
 'sideBootBandMaxSpanAfterPx':max(spans['bootBand99to114SpanPx']),
 'sideBootBandMaxSpanReduction':1-max(spans['bootBand99to114SpanPx'])/max(spans['oldBootBandSpanPx']),
 'notProven':['anatomical ankle travel or head angle from alpha regions','exact same drawn palette/proportions across generated sheets','zero foot drift or perfect natural motion','Godot idle/walk switching with this candidate; game not changed']}
save(OUT/'verification.json',report)
checks=[{'file':'clips_final/animation-clips.json',**c} for c in clips['qa']['checks'] if c['status'] not in ['pass','skipped']]
save(OUT/'qc_nonpass.json',checks)
print(json.dumps({k:v for k,v in report.items() if k not in ['previewFiles','skillChecks']},ensure_ascii=True))
