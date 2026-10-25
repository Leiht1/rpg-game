from PIL import Image,ImageDraw
import pathlib,json,hashlib
p=pathlib.Path('reports/mine-blast-v4');sheet=Image.new('RGB',(1152,648))
for j,i in enumerate([1,4,12,24,48,80]):
 im=Image.open(p/f'fx-{i:03}.png').resize((384,216));sheet.paste(im,(j%3*384,j//3*216))
sheet.save(p/'contact.png')
root=pathlib.Path('assets/exploration/mine-blast-v4');checks=[]
for path in sorted(root.glob('*.png')):
 im=Image.open(path);a=im.getchannel('A');checks.append({'file':path.name,'size':im.size,'alpha_extrema':a.getextrema(),'bbox':a.getbbox(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(p/'assets-qc.json').write_text(json.dumps(checks,indent=2),encoding='utf8')
