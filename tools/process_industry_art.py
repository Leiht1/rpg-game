from pathlib import Path
from PIL import Image
import subprocess,sys,shutil,json,hashlib
R=Path(__file__).resolve().parents[1]
names=['stone_furnace','metal_workbench','copper_oven','copper_lamp','reinforced_cabinet','feed_trough','refrigerator','wool_carpet','copper_ingot','silver_ingot','gold_ingot','copper_plate','copper_parts','metal_connector','copper_axe','copper_pickaxe','copper_shovel','copper_hammer','silver_lantern','fishing_rod','egg_vegetable_bake','rotten_roasted_carrot','rotten_roasted_mushroom','rotten_vegetable_soup','rotten_stewed_vegetables']
source=R/'art/industry-v1/generated/generated.png';img=Image.open(source)
xs=[0,260,512,767,1005,1254];ys=[0,272,508,736,988,1254]
final=R/'prototypes/industry-v1/final';final.mkdir(parents=True,exist_ok=True)
for n,name in enumerate(names):
 crop=R/f'art/industry-v1/crops/{name}.png';crop.parent.mkdir(parents=True,exist_ok=True)
 x=n%5;y=n//5;bounds=[0,270,515,744,1003,1254] if y==4 else xs
 img.crop((bounds[x],ys[y],bounds[x+1],ys[y+1])).save(crop)
 out=R/('art/industry-v1/processed/'+name+('-v2' if y==4 else ''))
 if not out.exists():
  result=subprocess.run([sys.executable,str(Path.home()/'.codex/skills/generate2dsprite/scripts/generate2dsprite.py'),'process','--input',str(crop),'--target','asset','--mode','single','--single-size','256','--key-quality','soft','--despill-radius','1','--resampler','lanczos','--fit-scale','.85','--strict-qc','--output-dir',str(out)],capture_output=True,text=True,encoding='utf-8')
  if result.returncode:raise RuntimeError(name+': '+result.stdout+result.stderr)
 png=out/'clean.png'
 if not png.exists(): png=next(out.rglob('*.png'))
 shutil.copyfile(png,final/(name+'.png'))
manifest={'approval':'pending_user','route':'local:codex-cli','model':'codex-image_gen','source':str(source.relative_to(R)),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'ownership_x':xs,'ownership_y':ys,'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in final.glob('*.png')}}
(final/'provenance.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print('processed',len(manifest['files']),'candidate assets')
