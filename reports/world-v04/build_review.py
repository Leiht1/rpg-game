from pathlib import Path
import json, html, hashlib
from PIL import Image, ImageDraw, ImageFont

root=Path(__file__).resolve().parents[2]
out=root/'reports/world-v04'
data=json.loads((out/'generation.json').read_text(encoding='utf-8-sig'))
seeds=[271828,81273,902106]
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',24)
small=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
canvas=Image.new('RGB',(1596,626),'#f1f0e5')
d=ImageDraw.Draw(canvas)
d.text((20,10),'V0.4 · 三个 Seed 的完整世界布局（M 地图同源数据）',font=font,fill='#253a2e')
for i,seed in enumerate(seeds):
    x=18+i*528
    canvas.paste(Image.open(out/f'seed-{seed}-overview.png').resize((512,512)),(x,54))
    entry=next(v for v in data['seeds'] if v['seed']==seed)
    d.text((x,573),f'Seed {seed}  ·  湖泊 {entry["lakes"]}',font=small,fill='#253a2e')
for i,(label,col) in enumerate([('森林','#6d9c68'),('草原','#adc979'),('山地','#aaa58c'),('水域','#70afb9')]):
    x=1030+i*130;d.rectangle((x,18,x+16,34),fill=col);d.text((x+22,12),label,font=small,fill='#253a2e')
canvas.save(out/'three-seeds.png')
before=json.loads((out/'before-hashes.json').read_text(encoding='utf-8-sig'))
hashes={p:{'before':old,'after':hashlib.sha256((root/p).read_bytes()).hexdigest()} for p,old in before.items()}
for row in hashes.values():row['changed']=row['before']!=row['after']
(out/'scope-hashes.json').write_text(json.dumps(hashes,indent=2),encoding='utf-8')
parts=['''<!doctype html><meta charset="utf-8"><title>风栖原野 · 大型生态区域 V0.4</title>
<style>body{background:#f1f0e5;color:#253a2e;font:17px/1.65 'Microsoft YaHei',sans-serif;margin:30px auto;max-width:1550px;padding:0 24px}h1{font-size:30px}h2{margin-top:40px}img{width:100%;display:block;border-radius:6px} .grid{display:grid;grid-template-columns:repeat(3,1fr);gap:18px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:18px}figure{margin:0}figcaption{margin:8px 0 20px}a{color:#27674d}p{max-width:1100px}</style>
<h1>风栖原野 · 大型生态区域 V0.4</h1>
<p>旧版每8192单位网格独立分配生态，产生14–18块区域。新版先规划世界级生态家族及通行连接，再生成子环境和物件。默认世界49152单位，画面宽1280单位。全图为生成数据可视化；下方为Godot原角色、原相机尺度的实际运行截图。</p>
<img src="three-seeds.png" alt="三个种子全图"><p>颜色：深绿森林、浅绿草原、灰色山地、蓝色水域。每个种子都形成三片连续大区域；本版采用三家族布局，尚未扩展为更多大型独立领地。</p>
<h2>实际 M 键地图</h2><div class="grid">''']
for seed in seeds:parts.append(f'<figure><a href="seed-{seed}-M-map.png"><img src="seed-{seed}-M-map.png"></a><figcaption>Seed {seed} · M 键真实地图</figcaption></figure>')
parts.append('</div><h2>同 Seed 旧版布局对照</h2><div class="grid">')
for seed in seeds:parts.append(f'<figure><img loading="lazy" src="../ecology-v03-seed-{seed}-overview.png"><figcaption>旧 V0.3 · Seed {seed}，保留原报告全图</figcaption></figure>')
parts.append('</div><h2>角色实际移动 · 每个种子约8个画面宽度</h2><p>起点定位后，使用原有200单位/秒速度、真实物理及碰撞持续步行。中途无传送或加速。以下起点、中段、终点保留相同相机尺度。</p>')
for seed in seeds:
    parts.append(f'<h3>Seed {seed}</h3><div class="grid">')
    for label,desc in [('walk-0','起点'),('walk-1','约5000单位'),('walk-end','约10235单位')]:parts.append(f'<figure><a href="seed-{seed}-{label}.png"><img loading="lazy" src="seed-{seed}-{label}.png"></a><figcaption>{desc}</figcaption></figure>')
    parts.append('</div>')
parts.append('<h2>森林内部变化 · 主生态保持森林</h2><div class="pair">')
for label,desc in [('forest-sparse','疏林与林间空地'),('forest-dense','密林')]:parts.append(f'<figure><img loading="lazy" src="seed-271828-{label}.png"><figcaption>{desc}，Seed 271828，原有树木与地表画稿</figcaption></figure>')
parts.append('</div><h2>自然出生点</h2><div class="grid">')
for seed in seeds:parts.append(f'<figure><img loading="lazy" src="seed-{seed}-spawn.png"><figcaption>Seed {seed} · 不覆盖独立绿色草地</figcaption></figure>')
parts.append('''</div><h2>验证与边界</h2><p>生成检查32项：区域连片、区域面积、256单位网格陆地连通、通道无水、同Seed复现、相邻区块共享边框、后台计划一致、自然安全出生及子环境变化。实际运行检查、步行距离和局部耗时见运行报告。网格洪泛不等同于所有Seed每个像素的可达性证明；采样耗时不作呈现帧率承诺。生成32项、真实运行41项均通过；退出时仍有RID/ObjectDB释放警告，原始runtime.log如实保留。</p><p>正式树石美术未替换。湖岸斜俯视候选继续单独等待确认：<a href="../../prototypes/view-v01/index.html">查看美术前后对照</a>。</p><p><a href="generation.json">生成报告</a> · <a href="runtime.json">真实运行报告</a> · <a href="scope-hashes.json">改动范围记录</a> · <a href="view-compatibility.log">旧美术预览兼容检查</a></p>''')
(out/'index.html').write_text(''.join(parts),encoding='utf-8')
print('Review gallery and three-seed overview ready.')
