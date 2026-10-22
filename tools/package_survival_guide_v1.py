from pathlib import Path
from PIL import Image
import subprocess,sys,json,hashlib,shutil
root=Path(__file__).resolve().parents[1]
source=root/'art/survival-guide-v1/generated/generated.png'
image=Image.open(source)
regions={'letter':(0,70,1050,930),'letter_icon':(1080,50,1490,465),'arrow':(1120,460,1450,720),'ring':(1030,715,1536,990)}
base=root/'art/survival-guide-v1'
processor=Path('C:/Users/雷/.codex/skills/generate2dsprite/scripts/generate2dsprite.py')
runtime=root/'assets/ui/survival_guide_v1'
manifest={'art_source':'host_image','route':'local:codex-cli','model':'codex-image_gen','estimateUsd':0,'visual_approval':'pending_user_visual_review','request':'2026-10-22 user requests letter paper, arrow, ring and local first-entry survival guide','source':str(source.relative_to(root)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'regions':regions,'files':{}}
for name,box in regions.items():
 crop=base/(name+'-ownership.png');image.crop(box).save(crop)
 out=base/(name+'-processed')
 if not out.exists():subprocess.run([sys.executable,str(processor),'process','--input',str(crop),'--target','asset','--mode','single','--rows','1','--cols','1','--cell-size','1024','--single-size','1024','--background-mode','chroma_key','--key-quality','soft','--despill-radius','1','--fit-scale','0.94','--align','center','--resampler','lanczos','--output-dir',str(out),'--strict-qc'],check=True)
 frames=list((out/'frames').glob('*.png'))
 if not frames:frames=list(out.glob('single-*.png'))
 print(name,[str(f) for f in frames])
 assert len(frames)==1
 rgba=Image.open(frames[0]).convert('RGBA');bounds=rgba.getbbox();rgba=rgba.crop(bounds)
 # Uniform scale preserves every full source contour. Tight alpha crop is not a repaint.
 if name=='letter':rgba.thumbnail((1024,1024),Image.Resampling.LANCZOS)
 else:rgba.thumbnail((512,512),Image.Resampling.LANCZOS)
 path=runtime/(name+'.png');rgba.save(path)
 manifest['files'][name]={'path':str(path.relative_to(root)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':rgba.size,'ownership':box,'qa':str((out/'pipeline-meta.json').relative_to(root))}
font=runtime/'LXGWWenKai-Regular.ttf'
manifest['font']={'family':'LXGW WenKai','source':'https://github.com/lxgw/LxgwWenKai','download':'https://raw.githubusercontent.com/lxgw/LxgwWenKai/main/fonts/TTF/LXGWWenKai-Regular.ttf','license':'OFL.txt','sha256':hashlib.sha256(font.read_bytes()).hexdigest(),'modification':'none; complete original font, no subset'}
(runtime/'provenance.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
