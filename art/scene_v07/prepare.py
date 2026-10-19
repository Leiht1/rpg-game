from pathlib import Path
import hashlib,json
from PIL import Image
root=Path('.')
files=['scripts/world_generator.gd','scripts/chunk_stream.gd','scripts/player.gd','scripts/nature_prop.gd','scripts/terrain.gdshader','assets/hero/cartoon/character.tscn','scenes/world.tscn','project.godot']
Path('art/scene_v07/unchanged-before.json').write_text(json.dumps({p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in files},indent=2),encoding='utf-8')
for p in Path('assets/environment/cartoon_v2').glob('*.png'):
 print(p.name,Image.open(p).size)
