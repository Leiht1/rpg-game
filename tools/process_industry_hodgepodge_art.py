from pathlib import Path
from PIL import Image
import subprocess,sys,shutil,json,hashlib
R=Path(__file__).resolve().parents[1];source=R/'art/industry-v1/hodgepodge-generated/generated.png';im=Image.open(source)
final=R/'prototypes/industry-v1/final';xs=[0,575,1254];ys=[0,627,1254]
for i,name in enumerate(['small_hodgepodge','large_hodgepodge','rotten_small_hodgepodge','rotten_large_hodgepodge']):
 x=i%2;y=i//2;crop=R/f'art/industry-v1/crops/{name}.png';im.crop((xs[x],ys[y],xs[x+1],ys[y+1])).save(crop)
 out=R/f'art/industry-v1/processed/{name}'
 if not out.exists():
  p=subprocess.run([sys.executable,str(Path.home()/'.codex/skills/generate2dsprite/scripts/generate2dsprite.py'),'process','--input',str(crop),'--target','asset','--mode','single','--single-size','256','--key-quality','soft','--despill-radius','1','--resampler','lanczos','--fit-scale','.68' if x==0 else '.85','--strict-qc','--output-dir',str(out)],capture_output=True,text=True,encoding='utf-8')
  if p.returncode:raise RuntimeError(p.stdout+p.stderr)
 shutil.copyfile(out/'clean.png',final/(name+'.png'))
p=final/'provenance.json';m=json.loads(p.read_text(encoding='utf-8'));m['hodgepodge_source']=str(source.relative_to(R));m['hodgepodge_source_sha256']=hashlib.sha256(source.read_bytes()).hexdigest();m['hodgepodge_ownership']={'x':xs,'y':ys};m['files']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in final.glob('*.png')};p.write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf-8')
print('processed four hodgepodge candidate assets')
