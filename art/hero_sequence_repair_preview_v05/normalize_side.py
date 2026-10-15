from pathlib import Path
import importlib.util,json
import numpy as np
from PIL import Image
OUT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('repair',OUT/'repair_preview.py')
R=importlib.util.module_from_spec(spec);spec.loader.exec_module(R)
P=R.P
def source(take,cols,rows):
    f=OUT/'side_walk'/take; raw=P.clean(Image.open(f/'generated.png'))
    raw.save(f/'clean.png')
    diag=P.N.normalize_sheet(f/'clean.png',f/'gorest.png',cols,rows,128,128,'/generated/v05.png',safe_padding=12,anchor_mode='feet-baseline')
    P.save(f/'gorest.json',diag)
    assert not diag['sourceEdgeRisks'],diag['sourceEdgeRisks']
    cells=[raw.crop(tuple(b)) for b in diag['sourceCells']]
    scale=float(92/np.median([P.bbox(c)[3]-P.bbox(c)[1] for c in cells]))
    fs=[];ts=[]
    for i,c in enumerate(cells):
        ax,ay=P.W.head_anchor(c);offset=[61-ax*scale,20-ay*scale]
        frame=P.clean(P.W.render(c,scale,offset,512).convert('RGBa').resize((128,128),Image.Resampling.LANCZOS).convert('RGBA'))
        fs.append(frame);ts.append({'sourceCell':diag['sourceCells'][i],'scale':scale,'offsetPx':offset})
    P.save(f/'registration.json',{'scale':scale,'transforms':ts})
    return fs,cells,ts
if __name__=='__main__':
    for take,cols,rows in [('take1',4,2),('take2',2,2)]:
        fs,cells,ts=source(take,cols,rows)
        for i,(f,c) in enumerate(zip(fs,cells)):
            f.save(OUT/'side_walk'/take/f'frame_{i:02}.png')
            c.save(OUT/'side_walk'/take/f'cell_{i:02}.png')
        print(take,[P.bbox(f) for f in fs])
