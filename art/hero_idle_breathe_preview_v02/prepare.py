"""Prepare exact repeated complete-body references, never synthesize motion."""
from pathlib import Path
import hashlib, json
import numpy as np
from PIL import Image
OUT=Path(__file__).resolve().parent; ROOT=OUT.parents[1]
OLD=OUT.parent/'hero_idle_breathe_preview_v01'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(OUT/'references').mkdir(exist_ok=True)
for direction in ['front','back','side']:
    (OUT/direction).mkdir(exist_ok=True)
    meta=json.loads((OLD/direction/'normalization.json').read_text(encoding='utf-8'))
    raw=Image.open(OLD/direction/'take1/generated.png').convert('RGBA')
    cell=raw.crop(tuple(meta['sourceCells'][0])); a=np.array(cell); a[a[:,:,3]<=8]=0; cell=Image.fromarray(a)
    box=cell.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()
    # A single whole character source is repeated exactly, to avoid inherited v01 pose drift.
    figure=cell.crop(box)
    reference=Image.open(ROOT/f'assets/hero/final_sprite/{direction}_idle_00.png').convert('RGBA')
    rb=reference.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()
    scale=4*(rb[3]-rb[1])/figure.height
    figure=figure.convert('RGBa').resize((round(figure.width*scale),round(figure.height*scale)),Image.Resampling.LANCZOS).convert('RGBA')
    full=Image.new('RGBA',(512,512)); full.alpha_composite(figure,(256-figure.width//2,448-figure.height))
    full.save(OUT/f'references/{direction}_canonical_complete.png')
    reference.save(OUT/f'references/{direction}_existing_idle.png')
    sheet=Image.new('RGBA',(1024,1024))
    for i in range(4): sheet.alpha_composite(full,((i%2)*512,(i//2)*512))
    sheet.save(OUT/f'references/{direction}_locked_four_frame_target.png')
    facing={'front':'FRONT: both eyes visible, chest and scarf knot face camera.',
            'back':'BACK: only rear hair, jacket back, heels; no face, no front scarf knot.',
            'side':'RIGHT SIDE: face right, one visible eye, same upright nose profile, no head pitch.'}[direction]
    prompt=f'''Use case: identity-preserve, precise-object-edit.
Edit target: the attached transparent 2x2 sheet. The FOUR cells are EXACT copies of ONE complete standing character. It is a production game animation edit, not four different drawings.
Fix the previous idle-breath attempt: its chest motion was too tiny while the whole person drifted. Keep this exact identity, standing pose, face, hair, outfit, proportions, original simple warm hand-painted cartoon brushwork, color and camera. {facing}

ONLY animate visible ribcage breathing in jacket and cream shirt. READABLE but calm normal breathing, no panting. At the provided 512px cell size the upper chest expands by 8 pixels TOTAL WIDTH at peak inhale (4px on each side); shoulder tops rise 6-8px. Exhale relaxes chest by 3-4px total relative to neutral and shoulders lower 3-4px. At final 128px cell size this should be 2-3 pixels shoulder excursion, rather than imperceptible subpixel noise. Change the chest volume and jacket/shirt folds, NOT body scale.

Timeline, row-major order, four unique poses:
00 top-left: exact neutral reference, torso at baseline.
01 top-right: inhale peak, upper chest visibly fuller and shoulder line gently lifted as described. Shoulder-to-neck length changes, not the head location. Arms respond by at most 2-3px at this source size.
02 bottom-left: returning almost to neutral after inhale, with tiny residual chest fullness. This is a descending transition, not a second inhale.
03 bottom-right: relaxed exhale trough, shoulders slightly lower and shirt/chest volume smaller; close enough to neutral for a smooth loop back to 00.

IMMOBILE REGIONS: both boots, socks, shins, knees, shorts/pelvis/waist, face, eyes, nose, ears and entire hair silhouette must stay EXACTLY in the same pixel positions and have identical shape, size, color and texture in every cell. Duplicate them faithfully, do not reinterpret or repaint them. Head stays absolutely still: no lift, bob, nod, rotation or blink. Waist stays still. Only the upper chest, shoulder garment and tiny passive sleeve/scarf-fold changes carry the breathing. Do not translate the whole figure. Do not enlarge or shrink the entire sprite. No forward/back rocking, side sway, stepping, foot movement, arm swing or new stance.

Keep fixed 2x2 equal square cells, identical per-cell coordinates, enough transparent margins, original left-upper soft lighting. True RGBA transparent background, no checkerboard paint, no ground shadow, no text, no panel borders, no added objects. Output one transparent square sprite sheet. Prioritize a locked lower body and head, with clearly visible chest/shoulder breathing between the four complete frames.'''
    (OUT/f'{direction}_prompt.txt').write_text(prompt,encoding='utf-8')
paths=[p for f in ['assets/hero','scripts','scenes'] for p in (ROOT/f).rglob('*') if p.is_file() and p.suffix not in ['.import','.uid']]
baseline={p.relative_to(ROOT).as_posix():sha(p) for p in paths}; baseline['project.godot']=sha(ROOT/'project.godot')
assert not (OUT/'game_files_before.json').exists()
save(OUT/'game_files_before.json',baseline)
save(OUT/'plan.json',{'previewOnly':True,'userFeedback':'v01 too little visible breathing and obvious whole-body displacement',
    'art':'three image-generated full-body edits, left whole-frame mirror','framesPerDirection':4,'cycleMs':3000,
    'goal':'stationary head/pelvis/legs/boots; readable chest and shoulders, not whole-sprite bobbing',
    'packaging':'one common scale per direction, whole-frame subpixel translation fitted to static head and legs; no per-frame scale, no local edits',
    'previousVersion':'../hero_idle_breathe_preview_v01','generationPending':True})
print(json.dumps({'targets':3,'runtimeHashes':len(baseline)}))
