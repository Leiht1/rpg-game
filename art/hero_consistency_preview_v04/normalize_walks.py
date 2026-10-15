"""Gorest grid detection, one scale per sheet and complete-frame registration."""
from pathlib import Path
import hashlib, importlib.util, json
import numpy as np
from PIL import Image

OUT=Path(__file__).resolve().parent; ROOT=OUT.parents[1]
APP=Path(r'C:\Users\HT\Documents\Codex\2026-10-15\https-github-com-0x0funky-agent-sprite\outputs\gorest-2d-animation-spritesheet-generator-main')
spec=importlib.util.spec_from_file_location('gorest',APP/'scripts/normalize_spritesheet.py')
N=importlib.util.module_from_spec(spec); spec.loader.exec_module(N)
N.remove_chroma_key=lambda im:im.convert('RGBA')
def save(p,v): p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def clean(im):
    a=np.array(im.convert('RGBA')); a[a[:,:,3]<=8]=0
    return Image.fromarray(a)
def bbox(im):return im.getchannel('A').point(lambda a:255 if a>16 else 0).getbbox()
def head_anchor(im):
    b=bbox(im); a=np.array(im.getchannel('A'),dtype=float)
    a[b[1]+round((b[3]-b[1])*.34):]=0
    yy,xx=np.indices(a.shape)
    return float((a*xx).sum()/a.sum()),float(b[1])
def render(cell,scale,offset,side=128):
    factor=side/128
    hi=cell.convert('RGBa').transform((side,side),Image.Transform.AFFINE,
        (1/(scale*factor),0,-offset[0]/scale,0,1/(scale*factor),-offset[1]/scale),Image.Resampling.BICUBIC)
    return clean(hi.convert('RGBA'))

def main():
    for direction in ['front','back','side']:
        folder=OUT/f'{direction}_walk'; source=folder/'take1/generated.png'
        raw=clean(Image.open(source)); raw.save(folder/'native_alpha_clean.png')
        diag=N.normalize_sheet(folder/'native_alpha_clean.png',folder/'gorest_diagnostic.png',4,2,128,128,
            '/generated/v04.png',safe_padding=12,anchor_mode='feet-baseline')
        assert not diag['sourceEdgeRisks']
        save(folder/'gorest_diagnostic.json',diag)
        cells=[raw.crop(tuple(b)) for b in diag['sourceCells']]
        boxes=[bbox(c) for c in cells]; scale=92/np.median([b[3]-b[1] for b in boxes])
        frames=[]; transforms=[]; reference=Image.new('RGBA',(2048,1024))
        (folder/'frames').mkdir(exist_ok=True)
        for i,c in enumerate(cells):
            ax,ay=head_anchor(c); offset=[(61 if direction=='side' else 64)-ax*scale,20-ay*scale]
            high=render(c,scale,offset,512)
            frame=clean(high.convert('RGBa').resize((128,128),Image.Resampling.LANCZOS).convert('RGBA'))
            frame.save(folder/'frames'/f'{direction}_walk_{i:02}.png'); frames.append(frame)
            reference.alpha_composite(high,((i%4)*512,(i//4)*512))
            transforms.append({'sourceCell':diag['sourceCells'][i],'scale':float(scale),'offsetPx':offset})
        reference.save(OUT/f'references/{direction}_walk_corrected_reference.png')
        save(folder/'normalization.json',{**diag,'globalScale':float(scale),'sourceSha256':sha(source),
            'transforms':transforms,'frameBboxes':[bbox(f) for f in frames],'root':[64,112],
            'policy':'one sheet scale from median whole-body height; complete-frame translation fixing head-band centroid x/top; no local patches or per-frame scale',
            'targetMedianHeight':92,'status':'needs-visual-review','artSource':'host:image_gen'})
        print(direction,raw.size,'scale',round(float(scale),6),'heights',[bbox(f)[3]-bbox(f)[1] for f in frames])

if __name__=='__main__':main()
