"""Prepare exact current-idle edit targets; no new character pixels are drawn."""
from pathlib import Path
import hashlib, json
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

references=OUT/'references'; references.mkdir(exist_ok=True)
identity=('The same approved warm bright simplified hand-painted cartoon boy adventurer: '
    'chestnut short tousled hair, small round face and small brown eyes, sage-green short jacket, '
    'cream shirt and rolled cuffs, ochre-yellow scarf, brown shorts, cream socks, brown short boots. '
    'Preserve the attached exact existing idle drawing, head/body proportion, silhouette, colors, '
    'soft brown outline and viewing direction. No realism, 3D, PBR, anime or pixel-art redesign.')
for direction in ['front','back','side']:
    source=ROOT/'assets/hero/final_sprite'/f'{direction}_idle_00.png'
    im=Image.open(source).convert('RGBA')
    im.save(references/f'{direction}_idle_master.png')
    large=im.resize((512,512),Image.Resampling.LANCZOS)
    large.save(references/f'{direction}_idle_master_4x.png')
    target=Image.new('RGBA',(1024,1024))
    for i in range(4): target.alpha_composite(large,((i%2)*512,(i//2)*512))
    target.save(references/f'{direction}_four_frame_edit_target.png')
    detail={'front':'Face straight toward camera, exactly the reference face and eyes, both arms hanging neutrally.',
        'back':'True back view: preserve back hair, jacket back and both heels; absolutely no face, eyes or front scarf knot.',
        'side':'True right-facing side view: preserve the exact nose profile, single visible eye and upright head orientation; no head pitch or torso rocking.'}[direction]
    prompt=f'''Edit the attached transparent four-panel sprite sheet. This is one {direction} idle breathing animation asset, not four different illustrations. {identity}

KEEP the exact square 2x2 layout, four equally sized square cells, read left-to-right then top-to-bottom. Each cell is an identical copy of the approved idle in the edit target. Retain the same complete character position and scale. Both boot soles stay EXACTLY at the same coordinates in ALL FOUR panels. Do not change hips, knees, shins, boot silhouette, stance, head size, hair mass, facial features, costume, light direction or camera. Leave generous transparent padding. No captions, panel borders, ground, cast shadow, checkerboard or text; real transparent background.

ONLY introduce a tiny calm breathing cycle in the upper chest and shoulder line. Four unique complete-body poses:
00 top-left: EXACT original neutral standing reference, unchanged.
01 top-right: barely perceptible inhale: chest subtly fuller, shoulder line about 2 pixels higher relative to a 512px cell; head follows at most 1 pixel, gaze and angle fixed. Arms hang down and follow minimally.
02 bottom-left: chest returns very close to neutral while exhaling; approximately halfway from 01 toward 03, without changing feet.
03 bottom-right: subtle relaxed exhale: chest and shoulders about 1 pixel lower than 00 relative to a 512px cell. This returns gently into 00.

The entire cycle is a restrained three-second idle breath, not panting. Movement must be smaller than normal line thickness at game size. Only tiny jacket/scarf folds respond. {detail}

No nodding, no blinking, no stepping, no weight shifting, no sideways drift, no arm swing, no swaying, no stretching the whole person, no noticeable height/width change. Preserve all original low-detail character drawing choices; do not repaint as a new polished character. This is a high-fidelity micro-edit of the existing standing frame. Output one transparent square RGBA sheet.'''
    (OUT/f'{direction}_prompt.txt').write_text(prompt,encoding='utf-8')
paths=[p for folder in ['assets/hero','scripts','scenes'] for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix not in ['.import','.uid']]
baseline={p.relative_to(ROOT).as_posix():sha(p) for p in paths}
baseline['project.godot']=sha(ROOT/'project.godot')
(OUT/'game_files_before.json').write_text(json.dumps(baseline,indent=2),encoding='utf-8')
(OUT/'plan.json').write_text(json.dumps({'status':'preview_only_not_game_integrated',
    'directions':['front','back','right','left'],'independent_art':['front','back','side'],
    'left_derivation':'whole-frame horizontal mirror of side; time order unchanged',
    'frames_per_direction':4,'cycle_ms':3000,'frame_durations_ms':[750,750,750,750],
    'canvas':[128,128],'anchor':[64,112],'base':'existing idle frame, not walk proportion correction',
    'phase_order':['neutral','subtle_inhale','near_neutral','subtle_exhale'],
    'art_source':'host_image','route':'host:image_gen edit, generate2dmedia adoption',
    'required_invariants':['stationary boots','no per-frame scale fitting','no nodding','same standing pose'],
    'generation_pending':True},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'edit_targets':3,'runtime_hashes_saved':len(baseline),'preview_only':True}))
