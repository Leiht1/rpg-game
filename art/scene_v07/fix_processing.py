from pathlib import Path
p=Path('art/scene_v07/process_props.py')
s=p.read_text(encoding='utf-8-sig').replace("for i,(name,size) in enumerate(zip(names,sizes)):","ownership=[(28,50,595,685),(600,60,1025,685),(1080,375,1505,690),(165,775,465,978),(695,780,905,974),(1100,775,1420,978)]\nfor i,(name,size) in enumerate(zip(names,sizes)):")
s=s.replace("x0=round((i%3)*w/3);x1=round((i%3+1)*w/3)\n y0=round((i//3)*h/2);y1=round((i//3+1)*h/2)","x0,y0,x1,y1=ownership[i]")
s=s.replace("a[a[:,:,3]<=8]=0","a[a[:,:,3]<210]=0")
s=s.replace("'warnings':[]","'warnings':['raw_sheet: requested equal grid not respected; manual ownership rectangles required', 'raw_sheet: colored translucent glow; alpha<210 discarded during cleanup']")
p.write_text(s,encoding='utf-8')
