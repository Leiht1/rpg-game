from PIL import Image
import pathlib
p=pathlib.Path('reports/mine-blast-v4'); files=sorted(p.glob('fx-*.png'))
frames=[Image.open(f).resize((768,432)).convert('P',palette=Image.Palette.ADAPTIVE,colors=128) for f in files]
frames[0].save(p/'blast-preview.gif',save_all=True,append_images=frames[1:],duration=50,loop=0)
