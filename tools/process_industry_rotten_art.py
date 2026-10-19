from pathlib import Path
from PIL import Image
import subprocess,sys,shutil,json,hashlib
R=Path(__file__).resolve().parents[1]
names=['herb_roasted_mushroom','roasted_fruit_platter','field_harvest_platter','roasted_potato','roasted_cabbage','egg_vegetable_bake']
source=R/'art/industry-v1/rotten-generated/generated.png';img=Image.open(source)
final=R/'prototypes/industry-v1/final'
for i,n in enumerate(names):
 name='rotten_'+n;crop=R/f'art/industry-v1/crops/{name}.png'
 x=i%3;y=i//3;xs=[0,512,1003,1536] if y else [0,512,1024,1536];img.crop((xs[x],y*512,xs[x+1],(y+1)*512)).save(crop)
 out=R/f'art/industry-v1/processed/{name}{"-v2" if y and x>0 else ""}'
 if not out.exists():
  p=subprocess.run([sys.executable,str(Path.home()/'.codex/skills/generate2dsprite/scripts/generate2dsprite.py'),'process','--input',str(crop),'--target','asset','--mode','single','--single-size','256','--key-quality','soft','--despill-radius','1','--resampler','lanczos','--fit-scale','.85','--strict-qc','--output-dir',str(out)],capture_output=True,text=True,encoding='utf-8')
  if p.returncode:raise RuntimeError(p.stdout+p.stderr)
 shutil.copyfile(out/'clean.png',final/(name+'.png'))
p=final/'provenance.json';m=json.loads(p.read_text(encoding='utf-8'));m['rotten_source']=str(source.relative_to(R));m['rotten_source_sha256']=hashlib.sha256(source.read_bytes()).hexdigest();m['files']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in final.glob('*.png')};p.write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf-8')
print('processed six spoiled food candidates')
