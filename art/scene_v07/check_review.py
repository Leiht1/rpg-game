from pathlib import Path
import hashlib,json
from PIL import Image,ImageDraw
p=Path('art/scene_v07/unchanged-before.json')
b=json.loads(p.read_text())
a={k:hashlib.sha256(Path(k).read_bytes()).hexdigest() for k in b}
result={'same_game_files':a==b,'hashes':a,'status':'pending_user','asset_scope':'birth clearing review only','route':'local:codex-cli','model':'codex-image_gen (underlying image model unknown)','actual_cost':None,'warnings':['raw_sheet: requested equal grid not respected; manual ownership rectangles required','raw_sheet: colored translucent glow; alpha<210 discarded during cleanup']}
Path('prototypes/scene-study-v07/review.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
# Inspect processed alpha at actual game resolution on light and dark backgrounds.
out=Image.new('RGB',(700,250),'#84b46f')
for i,name in enumerate(['tree_0','tree_1','rock_0','rock_1','flowers','leaves']):
 im=Image.open('prototypes/scene-study-v07/'+name+'.png')
 x=[0,185,380,470,550,610][i]
 out.paste(im,(x,220-im.height),im)
out.save('prototypes/scene-study-v07/asset-review.png')
print(json.dumps({'same_game_files':result['same_game_files'],'status':result['status']}))
