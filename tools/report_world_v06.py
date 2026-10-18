"""Package data-only map comparisons; no new game art."""
import json,html
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
root=Path(__file__).resolve().parents[1]
out=root/'reports/world-v06'
data=json.loads((out/'generation.json').read_text(encoding='utf-8-sig'))
font_path='C:/Windows/Fonts/msyh.ttc'
font=ImageFont.truetype(font_path,20)
small=ImageFont.truetype(font_path,16)
sheet=Image.new('RGB',(1600,5*465),(32,48,42));d=ImageDraw.Draw(sheet)
cards=[]
for i,r in enumerate(data['seeds']):
    seed=r['seed'];x=(i%4)*400;y=(i//4)*465
    # All ten maps have identical scale: 384 px = 49152 world units.
    im=Image.open(out/f'seed-{seed}-overview.png').convert('RGB').resize((384,384))
    sheet.paste(im,(x+8,y+34));d.text((x+8,y+5),f'Seed {seed}',font=font,fill='#f0eccf')
    d.text((x+8,y+421),f"陆地 {r['land_fraction']:.1%}  连通 {r['mainland_reachable_fraction']:.1%}",font=small,fill='#f0eccf')
    d.text((x+8,y+443),f"分支 {r['branches']}  环路 {r['loops']}  湖/河 {r['lakes']}/{r['rivers']}",font=small,fill='#f0eccf')
    debug=Image.open(out/f'seed-{seed}-overview.png').convert('RGB');dd=ImageDraw.Draw(debug)
    scale=768/r['extent']
    for e in r['edges']:
        a=r['nodes'][e['a']];b=r['nodes'][e['b']]
        dd.line((a['x']*scale,a['y']*scale,b['x']*scale,b['y']*scale),fill='#ffdc75',width=3)
    for n in r['nodes']:
        px=n['x']*scale;py=n['y']*scale
        dd.ellipse((px-10,py-10,px+10,py+10),fill='#233c39',outline='#fff5cf',width=2)
        dd.text((px+10,py-15),str(n['id']),font=font,fill='#fff5cf',stroke_width=2,stroke_fill='#233c39')
    px,py=[v*scale for v in r['spawn']]
    dd.rectangle((px-6,py-6,px+6,py+6),fill='#ff635e')
    dd.text((px+8,py), '出生',font=font,fill='#fff5cf',stroke_width=2,stroke_fill='#233c39')
    debug.save(out/f'seed-{seed}-debug.png')
    biome='/'.join(f'{v/sum(r["biome_land_cells"]):.1%}' for v in r['biome_land_cells'])
    runtime=f'<a href="seed-{seed}-M-full-world.png">真实 M 地图截图</a>' if i<5 else ''
    cards.append(f'''<article><h2>Seed {seed}</h2><img src="seed-{seed}-overview.png"><details><summary>区域连接图 / 编号 / 出生点</summary><img src="seed-{seed}-debug.png"></details><p>陆地 {r['land_fraction']:.2%} · 主陆地连通 {r['mainland_reachable_fraction']:.2%} · 长宽比 {r['land_aspect']:.2f}<br>分叉节点 {r['branches']} · 末端 {r['leaves']} · 图环路 {r['loops']}<br>森林 / 山地 / 草原 {biome}<br>湖泊 {r['lakes']} · 河流 {r['rivers']} · 出生 {r['spawn']}<br>{runtime}</p></article>''')
sheet=sheet.crop((0,0,1600,1395));sheet.save(out/'comparison-all-10.png')
page='''<!doctype html><html lang="zh"><meta charset="utf-8"><title>风栖原野 V0.6 候选验收</title><style>body{background:#20302a;color:#eee9d2;font:16px system-ui;margin:32px}a{color:#f8da87}.grid{display:grid;grid-template-columns:repeat(2,minmax(400px,1fr));gap:24px}article{background:#2a3e34;padding:18px}img{width:100%;height:auto}h1,h2{font-weight:600}p{line-height:1.7}</style><h1>风栖原野 V0.6 · 待确认候选</h1><p>正式 V0.5 与存档保持。全部 10 个连续随机 Seed 均展示，无挑选替换。所有全图同尺度：768 像素 = 49,152 世界单位。绿：草原 / 深绿：森林 / 灰褐：山地 / 蓝：海洋与内陆水。调试图黄线是结构连接，不是游戏道路，红方块是出生点。</p><p><a href="generation.json">生成验收原始记录</a> · <a href="runtime.json">真实游戏验收</a> · <a href="coast-runtime.json">海岸碰撞专项</a> · <a href="visual-review.json">视觉弱例与原因</a> · <a href="comparison-all-10.png">10 Seed 同比例总览</a></p><p>连通率是 384² 采样并使用 25 单位脚底半径的专项证据，不是任意像素证明。环路为抽象区域图的独立环数，不代表每条环都围出可见内海。自然程度仍需人工确认。Seed 1671081329 陆地仅11.40%，呈细长链状，是保留的质量弱例；其树长链与包围盒适配导致腹地较少，不能因图环数达标就判为探索体验达标。</p><div class="grid">'''+''.join(cards)+'</div></html>'
(out/'index.html').write_text(page,encoding='utf-8')
print('Packaged',len(cards),'seeds')

