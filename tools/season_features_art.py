from PIL import Image
from pathlib import Path
import json,hashlib
root=Path.cwd(); src=root/'art/season-features-v1/generated/generated.png'; im=Image.open(src).convert('RGBA'); out=root/'prototypes/season-features-v1';out.mkdir(exist_ok=True)
rows=[(0,455),(455,825),(825,1280)]
files=[]
for r,(top,bottom) in enumerate(rows):
 for c in range(4):
  cell=im.crop((c*320,top,(c+1)*320,bottom));canvas=Image.new('RGBA',(512,512));cell.thumbnail((460,460));canvas.alpha_composite(cell,((512-cell.width)//2,(512-cell.height)//2));p=out/f'frame-{r*4+c:02}.png';canvas.save(p);files.append({'path':str(p.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(out/'provenance.json').write_text(json.dumps({'status':'pending_user','art_source':'local:codex-cli','source':str(src.relative_to(root)),'prompt':'art/season-features-v1/prompt.txt','files':files,'qa':'Actual row ownership; snow crosses equal cell borders, interior grain used only.'},indent=2),encoding='utf-8')
