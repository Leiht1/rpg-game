"""Lossless ownership extraction, documented repacking, then skill soft-key processing."""
from pathlib import Path
from PIL import Image
import subprocess, json, hashlib, shutil
root=Path(__file__).resolve().parent
source=root/'revised/generated.png'
im=Image.open(source).convert('RGB')
names=['precision_repair_bench','fuel_supply_box','compost_bin','advanced_smokehouse','compost_fertilizer','smoked_fish']
sheet=Image.new('RGB',(1920,1280),(255,0,255))
records=[]
for i,name in enumerate(names):
    col=i%3;row=i//3
    # Empty magenta gap lies between y=449 and y=494. No drawn part is cut.
    box=(col*512,0 if row==0 else 470,(col+1)*512,470 if row==0 else 1024)
    crop=im.crop(box)
    cell=Image.new('RGB',(640,640),(255,0,255))
    cell.paste(crop,((640-crop.width)//2,(640-crop.height)//2))
    sheet.paste(cell,(col*640,row*640))
    path=root/'cells'/f'{name}.png';path.parent.mkdir(exist_ok=True);cell.save(path)
    records.append({'name':name,'ownership_rect':box,'repack':'unscaled, centered in 640x640; no painted pixels added or deleted'})
sheet.save(root/'revised/packed.png')
(root/'ownership.json').write_text(json.dumps({'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'records':records},indent=2),encoding='utf-8')
skill=Path('C:/Users/HT/.codex/skills/generate2dsprite/scripts')
for name in names:
    output=root/'processed'/name
    if not output.exists():
        subprocess.run(['python',str(skill/'generate2dsprite.py'),'process','--input',str(root/'cells'/f'{name}.png'),'--target','asset','--mode','single','--output-dir',str(output),'--single-size','512','--resampler','lanczos','--background-mode','chroma_key','--key-quality','soft','--align','feet','--strict-qc'],check=True)
    final=root.parents[1]/'prototypes/camp-expansion-v2/final';final.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(output/'clean.png',final/f'{name}.png')
