"""Refresh this candidate batch's provenance and side-by-side inspection image."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json, hashlib
base=Path(__file__).resolve().parent
root=base.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8'))
names=['precision_repair_bench','fuel_supply_box','compost_bin','advanced_smokehouse','compost_fertilizer','smoked_fish']
refs=['art/camp-expansion-v2/generated/generated.png','art/reference/hero.png','art/animals-style-v2/scene-reference.png','assets/environment/view_v01/tree_0.png','assets/environment/view_v01/rock_0.png']
profiles=read(root/'data/camp_volume_v2.json');defs=read(root/'data/camp_buildings.json')
outputs=[];official=[];measurements=[]
for n in names:
    p=root/f'prototypes/camp-expansion-v2/final/{n}.png'
    meta=read(base/f'processed/{n}/pipeline-meta.json')
    outputs.append({'id':n,'path':p.relative_to(root).as_posix(),'sha256':sha(p),'processing':f'art/camp-expansion-v2/processed/{n}/pipeline-meta.json','qa':meta['qa']})
for n,profile in profiles.items():
    if n in names:p=root/f'prototypes/camp-expansion-v2/final/{n}.png'
    elif 'art' in defs[n]:p=root/defs[n]['art'].removeprefix('res://')
    elif n=='signpost':p=root/'assets/buildings/signpost_v1/signpost.png'
    else:p=root/f'assets/buildings/v2/{n}.png'
    image=Image.open(p).convert('RGBA');b=image.getbbox();w,h=b[2]-b[0],b[3]-b[1]
    factor=min(profile['width']/w,profile['max_height']/h)
    size=[round(w*factor,2),round(h*factor,2)]
    if n=='wool_carpet':size=[profile['width'],profile['max_height']]
    measurements.append({'kind':n,'visible_width_height':size,'collision':profile['collision'],'source':p.relative_to(root).as_posix()})
    if n not in names:official.append({'id':n,'path':p.relative_to(root).as_posix(),'sha256':sha(p),'change':'original PNG unchanged; candidate geometry/draw profile only'})
data={'status':'pending_user','approval':None,'scope':'Only isolated camp expansion preview. No official asset replacement.','sources':[{'route':'generate2dsprite -> generate2dmedia route_media -> local Codex CLI','job':'generated/job.json','result':'generated/generated.png','disposition':'rejected equal-grid layout; original retained'},{'route':'local Codex CLI revision','prompt':'revision-prompt.txt','result':'TOOL_UNAVAILABLE: the CLI does not offer its native image tool to this sign-in','run':'7dd333cd33cc41e6b36f0010d87cc147'},{'route':'built-in image_gen image edit','model':'not exposed by host tool','prompt':'builtin-prompt.txt','result':'revised/generated.png','sha256':sha(base/'revised/generated.png'),'billing':'host call; exact cost/token quota not exposed; no API key used'}], 'references':[{'path':r,'sha256':sha(root/r)} for r in refs], 'ownership':'ownership.json','processing_script':'process_art.py','raw_qa':['raw-qc/sheet-qc.json','revised-raw-qc/sheet-qc.json'],'packed_qa':'packed-qc/sheet-qc.json','outputs':outputs,'reused_official_sources':official,'measurements':measurements,'visual_review':'Complete props, light/dark backgrounds and actual 1280x720 scene inspected. Aesthetic acceptance remains pending_user.','retained_acceptance_reference':'art/camp-expansion-v2/acceptance-sheet.png','temporary_media':'reports/camp-expansion-v2/*.png; remove after user confirms this batch, unless explicitly retained'}
(base/'provenance.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
sheet=Image.new('RGB',(1200,700),'#eee7d6');draw=ImageDraw.Draw(sheet)
labels=['精密维修台','自动燃料供给箱','发酵堆肥桶','高级熏制房','肥料','烟熏鱼']
for i,n in enumerate(names):
    x=(i%3)*400;y=(i//3)*350
    draw.rectangle((x+200,y,x+400,y+350),fill='#353b42')
    im=Image.open(root/f'prototypes/camp-expansion-v2/final/{n}.png').convert('RGBA');im=im.crop(im.getbbox());im.thumbnail((175,265),Image.Resampling.LANCZOS)
    for dx in [0,200]:sheet.paste(im,(x+dx+(200-im.width)//2,y+35+(265-im.height)//2),im)
    draw.text((x+10,y+312),labels[i],font=font,fill='#302a22')
sheet.save(base/'acceptance-sheet.png')
print(json.dumps({'outputs':len(outputs),'profiles':len(measurements),'provenance':'art/camp-expansion-v2/provenance.json'}))
