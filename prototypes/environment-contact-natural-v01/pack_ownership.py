"""Lossless cell ownership from empty gutters; no painting or silhouette deletion."""
from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,math,sys,os
root=Path(__file__).resolve().parent
for surface in (sys.argv[1:] or ['grass','forest','dirt']):
    take=os.environ.get('CONTACT_DIRT_TAKE','02') if surface=='dirt' else '02'
    p=root/'art'/f'{surface}-{take}/generated.png';im=Image.open(p).convert('RGBA')
    a=np.asarray(im).astype(float)
    backdrop=(a[...,0]-a[...,1]>65)&(a[...,2]-a[...,1]>65)&(np.abs(a[...,0]-a[...,2])<85)
    ink=(~backdrop)&(a[...,3]>32)
    def cuts(counts):
        length=len(counts);result=[0]
        for n in [1,2]:
            expected=length*n/3
            lo=round(expected-length*.17);hi=round(expected+length*.17)
            runs=[];start=None
            for i in range(max(0,lo),min(length,hi)):
                if counts[i]==0:
                    if start is None:start=i
                elif start is not None:
                    if i-start>=6:runs.append((start,i))
                    start=None
            if start is not None and hi-start>=6:runs.append((start,min(length,hi)))
            if not runs:raise RuntimeError(f'{surface}: no clean ownership gutter at {n}/3')
            run=min(runs,key=lambda r:abs((r[0]+r[1])/2-expected)-min(r[1]-r[0],80)*.25)
            result.append(round((run[0]+run[1])/2))
        return result+[length]
    xs=cuts(ink.sum(axis=0));ys=cuts(ink.sum(axis=1))
    cell=math.ceil((max(max(np.diff(xs)),max(np.diff(ys)))+64)/16)*16
    canvas=Image.new('RGBA',(cell*3,cell*3),(255,0,255,255));records=[]
    for row in range(3):
        for col in range(3):
            box=(xs[col],ys[row],xs[col+1],ys[row+1]);part=im.crop(box)
            xy=(col*cell+(cell-part.width)//2,row*cell+(cell-part.height)//2)
            canvas.paste(part,xy)
            records.append({'cell':[row,col],'source_box':box,'paste':xy,'source_art_pixels_unchanged':True})
    out=root/'art'/f'{surface}-owned.png';canvas.save(out)
    (root/'art'/f'{surface}-ownership.json').write_text(json.dumps({'source':str(p.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'source_size':im.size,'cell_size':cell,'cuts_x':xs,'cuts_y':ys,'cells':records,'method':'copy complete rectangles at empty painted-art gutters, no rescale or art redraw'},indent=2),encoding='utf8')
    print(surface,im.size,'->',canvas.size)
