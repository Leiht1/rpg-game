"""Register the image-generated broad cuff, retaining native hand pixels."""
import hashlib
import json
from pathlib import Path
import shutil
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'art/wool-sleeve-v2'
OUT=ROOT/'assets/season_gear/sleeve-v2'
ART.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
generated=Path('C:/Users/雷/.codex/generated_images/01a16d62-9987-7fa3-a5de-058d6b6222a5')
for original,name in [('exec-7b756b71-9e21-409a-a947-a1c481b15818.png','sleeve-first.png'),('exec-e0fc2a21-6f09-4774-abc9-0c3d45799560.png','sleeve-source.png')]:
    shutil.copy2(generated/original,ART/name)
source=Image.open(ART/'sleeve-source.png').convert('RGBA')
alpha=source.getchannel('A').point(lambda value:255 if value>=24 else 0)
source=source.crop(alpha.getbbox())
sleeve=source.resize((38,86),Image.Resampling.LANCZOS)
checks=[];files=[]
for view in ('front','back','side'):
    native='side' if view=='side' else 'front'
    arm=Image.open(ROOT/f'assets/hero/cartoon/art/{native}_arm.png').convert('RGBA')
    # Sprite2D is centered. Symmetric 4px padding keeps every native hand pixel
    # at exactly the same local/world coordinate, while allowing a wider cuff.
    canvas=Image.new('RGBA',(40,100))
    canvas.paste(arm.crop((0,82,32,100)),(4,82))
    canvas.alpha_composite(sleeve,(1,0))
    assert canvas.crop((4,86,36,100)).tobytes()==arm.crop((0,86,32,100)).tobytes()
    cuff=[x+1 for x in range(38) if sleeve.getpixel((x,82))[3]>=128]
    hand=[x for x in range(40) if canvas.getpixel((x,87))[3]>=128]
    assert min(cuff)<=min(hand) and max(cuff)>=max(hand),(view,cuff,hand)
    path=OUT/f'wool_sweater-{view}-arm.png';canvas.save(path)
    files.append({'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    checks.append({'view':view,'canvas':list(canvas.size),'cuff_span':[min(cuff),max(cuff)],'hand_span':[min(hand),max(hand)],'hand_pixels_unchanged':True})
registry=json.loads((ROOT/'data/equipment_visuals.json').read_text(encoding='utf-8'))
for view in ('front','back','side'):
    for row in registry['clothing:wool_sweater'][view]:
        if row['texture'].endswith('-arm.png'):row['texture']='res://'+(OUT/f'wool_sweater-{view}-arm.png').relative_to(ROOT).as_posix()
(ROOT/'data/equipment_visuals.json').write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
provenance={'art_source':'host_image','route':'image_gen','model':'Built-in image_gen; exact revision and cost unavailable','estimateUsd':None,'user_request':'羊毛衫的袖子比手细，跟手没有很好的衔接；继续','scope':'Local correction of existing sweater cuffs; no new clothing or hand geometry. Subjective visual review remains available.','sources':['art/wool-sleeve-v2/sleeve-first.png','art/wool-sleeve-v2/sleeve-source.png'],'references':['art/season-gear-v1/sleeve-source.png','assets/season_gear/v1/wool_sweater-front-arm.png'],'prompt':'Preserve ivory cable knit and brown contour; upright centered sleeve; rounded shoulder; broad ribbed cuff at least 95% of maximum sleeve width, covering the original hand; no taper, hand, skin, halo or cast shadow; native transparent background.','processing':'Native alpha, bbox from alpha>=24; LANCZOS register sleeve to 38x86 at (1,0) on 40x100 canvas. Original 32px hand copied at x=4, preserving centered-Sprite local coordinates. Original hand at y>=86 is byte-identical; original y82..85 is overlapped by cloth cuff. Original v1 PNGs preserved.','checks':checks,'files':files}
(OUT/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(ART/'prompt.txt').write_text(provenance['prompt']+'\n',encoding='utf-8')
print(json.dumps(checks,ensure_ascii=False))
