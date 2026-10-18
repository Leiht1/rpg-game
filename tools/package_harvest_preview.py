from pathlib import Path
from PIL import Image
p=Path('reports/harvest-v05/action-frames')
frames=[Image.open(f).convert('RGB') for f in sorted(p.glob('*.png'))]
frames[0].save('reports/harvest-v05/native-actions.gif',save_all=True,append_images=frames[1:],duration=20,loop=0,optimize=False)
# Latest directional keyframe montage is assembled from actual native animation frames.
ids=[0,16,22,28,36,55]
out=Image.new('RGB',(800,frames[0].height*len(ids)),(232,225,199))
for i,idx in enumerate(ids):out.paste(frames[idx],(0,i*frames[0].height))
out.save('reports/harvest-v05/native-actions-latest.png')

