"""Technical pose guides for the image route; never used as character art."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art/hero_rebuild_v01/guides'
OUT.mkdir(parents=True, exist_ok=True)

# Joint labels describe screen positions, never arbitrary cutout transforms.
front = [
    {'a': [(157,155),(145,186),(143,208)], 'b': [(227,155),(242,193),(239,226)],
     'l': [(170,235),(168,285),(166,337)], 'r': [(214,235),(216,279),(216,315)]},
    {'a': [(157,155),(149,189),(151,217)], 'b': [(227,155),(235,189),(233,217)],
     'l': [(170,235),(170,282),(168,323)], 'r': [(214,235),(214,271),(217,305)]},
]
front += [{key: [(384-x,y) for x,y in points] for key,points in p.items()} for p in front[:2]]
side = [
    {'a': [(187,155),(208,190),(229,209)], 'b': [(197,155),(172,186),(152,208)],
     'l': [(192,235),(219,283),(244,337)], 'r': [(188,235),(166,283),(143,326)]},
    {'a': [(187,155),(194,190),(202,220)], 'b': [(197,155),(190,190),(181,218)],
     'l': [(192,235),(190,282),(184,337)], 'r': [(188,235),(208,270),(210,307)]},
    {'a': [(187,155),(166,187),(146,208)], 'b': [(197,155),(220,189),(240,209)],
     'l': [(192,235),(167,283),(143,326)], 'r': [(188,235),(217,283),(244,337)]},
    {'a': [(187,155),(181,190),(173,218)], 'b': [(197,155),(204,190),(212,220)],
     'l': [(192,235),(208,270),(210,307)], 'r': [(188,235),(190,282),(184,337)]},
]
for pose in side:
    pose['a'], pose['b'] = pose['b'], pose['a']
for direction, poses in [('front',front),('back',front),('side',side)]:
    im=Image.new('RGB',(768,768),'#f3f1e8')
    d=ImageDraw.Draw(im)
    for i,p in enumerate(poses):
        ox,oy=(i%2)*384,(i//2)*384
        def pts(values): return [(x+ox,y+oy) for x,y in values]
        d.line(pts([(110,340),(274,340)]),fill='#b6b4ac',width=1)
        d.line(pts([(192,20),(192,354)]),fill='#d3d1c8',width=1)
        d.text((ox+12,oy+10),f'{i}  '+['CONTACT A','PASS A / B SWING','CONTACT B','PASS B / A SWING'][i],fill='#323a32')
        for key,color in [('r','#9aa3aa'),('b','#9aa3aa')]:
            d.line(pts(p[key]),fill=color,width=18,joint='curve')
        if direction=='side':
            body=[(179,148),(207,148),(213,218),(207,242),(178,242),(171,218)]
            head=(157+ox,42+oy,231+ox,142+oy)
        else:
            body=[(157,148),(227,148),(220,218),(214,242),(170,242),(164,218)]
            head=(147+ox,42+oy,237+ox,142+oy)
        d.polygon(pts(body),fill='#bcbdb5',outline='#5b635c')
        for key,color in [('l','#586e81'),('a','#586e81')]:
            d.line(pts(p[key]),fill=color,width=18,joint='curve')
        for key in ['l','r']:
            x,y=p[key][-1]; x+=ox;y+=oy
            d.ellipse((x-13,y-5,x+15,y+3),fill='#44515a' if key=='l' else '#7e8991')
        d.ellipse(head,fill='#d6d1c0',outline='#5b635c',width=2)
        if direction=='side':
            d.polygon(pts([(229,91),(242,105),(229,108)]),fill='#d6d1c0',outline='#5b635c')
        d.text((ox+16,oy+359),direction.upper()+'  root=(192,340), same body scale',fill='#5b635c')
    im.save(OUT/f'{direction}.png')
(OUT/'poses.json').write_text(json.dumps({'purpose':'technical pose guide, not final art','canvas':[384,384],
    'root':[192,340],'front':front,'back':front,'side':side},indent=2),encoding='utf-8')
