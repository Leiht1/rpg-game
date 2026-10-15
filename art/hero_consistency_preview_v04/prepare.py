"""Prepare complete-frame references for generated art; no synthetic poses."""
from pathlib import Path
import hashlib, json
from PIL import Image

OUT=Path(__file__).resolve().parent; ROOT=OUT.parents[1]
REF=OUT/'references'; REF.mkdir(exist_ok=True)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sheet(images,cols):
    canvas=Image.new('RGBA',(cols*512,((len(images)+cols-1)//cols)*512))
    for i,im in enumerate(images):
        im=im.convert('RGBa').resize((512,512),Image.Resampling.LANCZOS).convert('RGBA')
        canvas.alpha_composite(im,((i%cols)*512,(i//cols)*512))
    return canvas

baseline={p.relative_to(ROOT).as_posix():sha(p) for folder in ['assets/hero','scripts','scenes']
          for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix not in ['.import','.uid']}
baseline['project.godot']=sha(ROOT/'project.godot')
assert not (OUT/'game_files_before.json').exists(), 'Preserve first baseline'
save(OUT/'game_files_before.json',baseline)
for d in ['front','back','side']:
    walks=[Image.open(ROOT/f'assets/hero/final_sprite/{d}_walk_{i:02}.png').convert('RGBA') for i in range(8)]
    idles=[Image.open(ROOT/f'assets/hero/final_sprite/{d}_idle_{i:02}.png').convert('RGBA') for i in range(4)]
    sheet(walks,4).save(REF/f'{d}_walk_edit_target.png')
    sheet(idles,2).save(REF/f'{d}_breathe_edit_target.png')

eye=Image.open(ROOT/'art/candidates/hero-a.png').convert('RGBA')
eye.save(REF/'eye_design_reference_A.png')
# Reference crop only, never pasted into final artwork.
eye.crop((480,250,755,405)).resize((825,465),Image.Resampling.LANCZOS).save(REF/'eye_design_detail.png')
common='''Use case: identity-preserve, precise-object-edit. Production hand-painted 2D cartoon game sprite edit. Preserve the current character's exact hair, face proportions, skin, sage olive green jacket, cream shirt and rolled cuffs, ochre yellow scarf, brown shorts, cream socks, brown boots, line weight and soft upper-left warm light. No realism, anime redesign, new accessories, hard highlights or extra texture. Native transparent RGBA, no painted checkerboard, ground, shadow, text, numbers, panel borders or guide lines. All complete figures must have generous transparent margins. Equal grid cells, fixed orthographic oblique game camera, one scale and one root throughout; never vary head size or jacket colors between frames.
'''
eyes='''Change ONLY the eye design to the complete eyes of the separate EARLY A reference: small visible off-white sclera around warm brown iris and dark pupil, tiny light highlight and a clean soft brown upper lid. Keep current face shape, spacing, expression and moderate eye size. The A image is for EYES ONLY; do not copy its different outfit brush texture, proportions, stance or head shape. Clear full eyes, no solid black dots and no huge anime eyes. Eyes stay identical in all frames, no blink.
'''
front=common+'''EDIT TARGET image 1 is the existing 4-column by 2-row eight-pose FRONT walk sheet. Preserve every existing complete walk pose, arm/leg phase, per-cell placement, root, head size, height, body proportions and clothing colors. Row-major chronological cycle 00..07. Both eyes face the camera, same head angle, no turning into three-quarter view. Change the eyes as specified below; do not redesign the motion or enlarge the head. Output one transparent 4x2 sheet with all eight complete poses at the original per-cell scale. Image 2 supplies the eye design only.
'''+eyes
side=common+'''EDIT TARGET image 1 is the existing 4-column by 2-row eight-pose RIGHT SIDE walk sheet. Keep its exact character size, head and pelvis placement, colors and eight chronological phases, but make a SMALLER NATURAL WALK. At both contact poses (00 and 04), reduce horizontal boot-to-boot separation to roughly two-thirds of the target sheet, bringing the feet under the hips. Reduce forward and backward leg swing through the ENTIRE cycle, including poses 03 and 07; do not leave the extreme wide splits there. Feet stay close to the ground, relaxed bent knees, short casual steps, no marching, kicking, running, big back-knee fold or high step. Moderate the arm counter-swing to fit small steps. Draw genuine opposite near/far leg phases: 00 contact near leg forward; 01 weight/down; 02 passing; 03 lifting toward opposite contact; 04 opposite leg contact; 05 weight/down; 06 opposite passing; 07 lifting toward 00. Never duplicate/reverse a half cycle. Always a TRUE RIGHT PROFILE with one visible full eye and the same nose/head orientation. No head bob or twist, no change of perspective at mid-cycle. Output one transparent 4x2 sheet, all eight complete original-size figures and generous space in every cell. Image 2 supplies the eye design only.
'''+eyes
(OUT/'front_walk_prompt.txt').write_text(front,encoding='utf-8')
(OUT/'side_walk_prompt.txt').write_text(side,encoding='utf-8')
save(OUT/'plan.json',{'previewOnly':True,'status':'generation_pending','request':'Match breathe/walk scale and palette; quicker breathing; smaller side stride; full eyes',
    'art_source':'host_image','route':'host:image_gen + generate2dmedia adopt','eyeReference':'art/candidates/hero-a.png (eyes only)',
    'idleFrames':4,'idleFrameMs':450,'idleCycleMs':1800,'walkFrames':8,'walkFrameTicks':5,'walkCycleMs':2000/3,
    'canvas':[128,128],'root':[64,112],'speedUnchanged':100,
    'generationPlan':['front_walk: full eyes, preserve motion and colors','side_walk: full eyes and shorter steps','front/back/side breathe: match walk scale/colors'],
    'leftPolicy':'mirror complete right frames in unchanged time order','noLocalPatches':True,'noPerFrameScale':True})
print(json.dumps({'references':str(REF),'baselineFiles':len(baseline)}))
