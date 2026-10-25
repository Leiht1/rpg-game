from PIL import Image,ImageOps
from pathlib import Path
import numpy as np,json,hashlib
base=Path('art/hair-night-local-v1');out=Path('prototypes/bun-exact-fit-v3');out.mkdir(exist_ok=True)
source_folder='bun-exact-refined-keyed' if (base/'bun-exact-refined-keyed/raw-sheet-clean.png').exists() else 'bun-exact-keyed'
raw=Image.open(base/source_folder/'raw-sheet-clean.png').convert('RGBA')
guide=np.array(Image.open(base/'exact-native-head-guide.png').convert('RGBA')).astype(float)
head_paths=['prototypes/character-creation-v1/heads/front.png','prototypes/character-creation-v1/heads/back.png','prototypes/character-hair-v2/heads/side.png']
boxes=[[(0,115,38,160),(186,115,224,160)],[(0,114,38,160),(186,114,224,160)],[(47,96,105,153)]]
records=[]
for col,view in enumerate(['front','back','side']):
    boundaries=[0,500,980,1536];left=boundaries[col];right=boundaries[col+1]
    a=np.array(raw.crop((left,0,right,1024))).astype(float);g=guide[:,left:right]
    green=(a[:,:,1]>a[:,:,0]+90)&(a[:,:,1]>a[:,:,2]+90)&(a[:,:,3]>100)
    target_green=(g[:,:,1]>g[:,:,0]+90)&(g[:,:,1]>g[:,:,2]+90)&(g[:,:,3]>100)
    sy,sx=np.where(green);ty,tx=np.where(target_green)
    cyan=(np.minimum(a[:,:,1],a[:,:,2])-a[:,:,0]>80)&(a[:,:,3]>100)
    cy,cx=np.where(cyan)
    scale_x=(tx.max()-tx.min())/(sx.max()-sx.min())
    source_ear_y=(sy.max()+sy.min())/2;target_ear_y=(ty.max()+ty.min())/2
    scale_y=(760-target_ear_y)/(cy.max()+1-source_ear_y)
    shift_x=(tx.max()+tx.min())/2-scale_x*(sx.max()+sx.min())/2
    shift_y=760-scale_y*(cy.max()+1)
    # Map the generated GREEN original-ear marks to the real head; chin is the second Y anchor.
    dx=scale_x*.5;dy=scale_y*.5;px=68+(shift_x-(512*col+32-left))*.5;py=130+(shift_y-400)*.5
    dominance=np.maximum(0,a[:,:,1]-a[:,:,0])
    alpha=np.clip((45-dominance)/30,0,1);a[:,:,3]*=alpha
    fringe=dominance>3
    a[:,:,1][fringe]=np.minimum(a[:,:,1][fringe],a[:,:,0][fringe]+2)
    a[:,:,2][fringe]=np.minimum(a[:,:,2][fringe],a[:,:,0][fringe]+2)
    a[a[:,:,3]<4]=0
    clean=Image.fromarray(a.astype('uint8'),'RGBA');clean.save(base/f'bun-exact-{view}-hair-source.png')
    canvas=clean.transform((360,440),Image.Transform.AFFINE,(1/dx,0,-px/dx,0,1/dy,-py/dy),Image.Resampling.BICUBIC)
    canvas.save(out/f'{view}.png')
    if view=='side':ImageOps.mirror(canvas).save(out/'left.png');canvas.save(out/'right.png')
    # Quantify coverage of original real ear ink, rather than merely testing texture existence.
    h=np.array(Image.open(head_paths[col]).convert('RGBA'));ear=np.zeros((440,360),bool)
    for x0,y0,x1,y1 in boxes[col]:
        mask=(h[y0:y1,x0:x1,:3].max(2)<120)&(h[y0:y1,x0:x1,3]>100)
        ear[130+y0:130+y1,68+x0:68+x1]|=mask
    hair=np.array(canvas)[:,:,3]
    covered=int(((hair>127)&ear).sum());total=int(ear.sum())
    record={'view':view,'source':source_folder,'ownership':[left,right],'scale':[dx,dy],'translation':[px,py],'source_green_bbox':[int(sx.min()),int(sy.min()),int(sx.max()+1),int(sy.max()+1)],'target_green_bbox':[int(tx.min()),int(ty.min()),int(tx.max()+1),int(ty.max()+1)],'ear_ink_total':total,'ear_ink_covered':covered,'ear_visible_fraction':1-covered/total,'hair_bbox':canvas.getbbox()}
    # Front/back broad ear rectangles include the vertical skull attachment ink.
    # Record that overlap above, and separately check the actual protruding ear arcs.
    ear_arc=ear.copy()
    if view!='side':ear_arc[:,68+33:68+191]=False
    record['ear_arc_total']=int(ear_arc.sum())
    record['ear_arc_covered']=int(((hair>127)&ear_arc).sum())
    if view=='side':
        tested=0;covered_rear=0
        for y in range(50,151):
            xs=np.where(h[y,:,3]>127)[0]
            if not len(xs):continue
            tested+=1;covered_rear+=bool(hair[130+y,68+int(xs.min())]>127)
        record['rear_contour_coverage']=[covered_rear,tested]
    records.append(record)
(base/'bun-exact-registration.json').write_text(json.dumps(records,indent=2),encoding='utf-8',newline='\n')
qa={'ear_outer_arcs_visible':all(r['ear_arc_covered']==0 for r in records),'side_ear_fully_visible':records[2]['ear_ink_covered']==0,'rear_skull_fully_covered':records[2]['rear_contour_coverage']==[101,101],'records':records}
(base/'bun-exact-fit-qa.json').write_text(json.dumps(qa,indent=2),encoding='utf-8',newline='\n')
print(json.dumps(records,ensure_ascii=True))
