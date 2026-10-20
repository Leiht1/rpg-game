from pathlib import Path
p=Path('prototypes/biome-v02')
labels={-1:'全图',0:'森林',1:'山地',2:'原野',3:'水岸',4:'林缘过渡',5:'山麓过渡',6:'林山过渡',-2:'出生地'}
html='<meta charset="utf-8"><title>风栖原野 V0.2 实际运行预览</title><style>body{background:#21382f;color:#edf3df;font:18px sans-serif;margin:32px}img{max-width:100%;display:block;margin:12px 0 28px}a{color:#ccebc0}</style><h1>风栖原野 V0.2</h1><p>Godot 4.7.2 实际截图 · 新地表待验收 · 可移动入口 preview.tscn / 启动预览.ps1</p>'
for seed in [271828,81273,902106]:
 html+=f'<h2>Seed {seed}</h2>'
 for view,label in labels.items():html+=f'<details {"open" if view==-1 else ""}><summary>{label}</summary><img loading="lazy" src="seed-{seed}-view-{view}.png"></details>'
(p/'index.html').write_text(html,encoding='utf-8')
