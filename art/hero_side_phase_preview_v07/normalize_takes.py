"""Gorest cells, one common scale per source, complete-frame registration only."""
from pathlib import Path
import importlib.util,json,hashlib
import numpy as np
from PIL import Image
OUT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('v6',OUT.parent/'hero_side_spacing_preview_v06/package_preview.py')
M=importlib.util.module_from_spec(spec);spec.loader.exec_module(M);P=M.P

def normalize(name,cols,rows,indices):
    take=OUT/name;raw=P.clean(Image.open(take/'generated.png'));raw.save(take/'native_alpha_clean.png')
    diag=P.N.normalize_sheet(take/'native_alpha_clean.png',take/'gorest_diagnostic.png',cols,rows,128,128,
        '/generated/windrest_hero_side_phase_v07.png',safe_padding=12,anchor_mode='feet-baseline')
    assert not diag['sourceEdgeRisks'],diag['sourceEdgeRisks']
    P.save(take/'gorest_diagnostic.json',diag)
    cells=[raw.crop(tuple(b)) for b in diag['sourceCells']]
    # Singleton edits all have the same 512-pixel registered reference canvas.
    # Keep their reference-to-source canvas ratio: never fit each pose height.
    scale=float(512/(raw.width*4)) if len(cells)==1 else float(92/np.median([P.bbox(c)[3]-P.bbox(c)[1] for c in cells]))
    if len(cells)==1:assert raw.size==(1254,1254)
    transforms=[]
    for ci,(index,c) in enumerate(zip(indices,cells)):
        hx,hy=P.W.head_anchor(c);offset=[61-hx*scale,20-hy*scale]
        hi=P.W.render(c,scale,offset,512)
        frame=P.clean(hi.convert('RGBa').resize((128,128),Image.Resampling.LANCZOS).convert('RGBA'))
        c.save(take/f'cell_{ci:02}.png');hi.save(take/f'high_frame_{index:02}.png');frame.save(take/f'frame_{index:02}.png')
        transforms.append({'sourceCellIndexZeroBased':ci,'outputIndexZeroBased':index,
            'sourceCell':diag['sourceCells'][ci],'scale':scale,'offsetPx':offset})
    P.save(take/'registration.json',{'globalScale':scale,'transforms':transforms,
        'sourceSha256':hashlib.sha256((take/'generated.png').read_bytes()).hexdigest(),
        'policy':'All four singleton edits use identical 512/1254 reference-canvas ratio then 1/4 display scale. No individual body-height fitting. Full-frame rigid head registration only, no local manipulation.',
        'referenceCanvas':[512,512] if len(cells)==1 else None})
    print(name,raw.size,scale)

if __name__=='__main__':
    import sys
    if len(sys.argv)==1:normalize('take1',2,2,[1,2,4,5])
    else:normalize(sys.argv[1],1,1,[int(sys.argv[2])])
