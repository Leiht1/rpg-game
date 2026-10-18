from pathlib import Path
import json
from PIL import Image
p=Path(__file__).resolve().parent
r=p.parents[1]/'reports/environment-contact-natural-v01'
if (p.parents[1]/'assets/environment/contact_v01/provenance.json').exists():
    (r/'index.html').write_text('<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=../environment-game-v01/index.html"><p>景物已正式接入，泥地恢复连续相连版本。<a href="../environment-game-v01/index.html">查看正式游戏截图与检查</a></p>',encoding='utf8')
    raise SystemExit(0)
qa=json.loads((r/'runtime.json').read_text(encoding='utf8'))
manifest=json.loads((p/'runtime/manifest.json').read_text(encoding='utf8'))
parts=['''<!doctype html><html lang="zh"><meta charset="utf-8"><title>接地布局修正候选</title><style>body{background:#f5efdF;color:#363b28;font:17px system-ui;margin:24px auto;max-width:1280px}button{font:inherit;padding:10px;margin:5px}img.scene{width:100%}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}.grid img{width:100%;image-rendering:auto}figure{margin:0;background:#ddd6bd;padding:10px}small{display:block}a{color:#396e40}</style><h1>接地布局修正 · 待确认</h1><p>泥土保持同一地平面，薄土边贴住树根、石底。连续围边通过减少覆盖、局部断开处理，不做高低错落或悬空土块。草叶与落叶恢复较丰富数量，各种形态采用不同疏密和组合。</p><p>保留已认可配色、三种树和六种普通石头；矮胖阔冠树不加入。树受击只晃动，砍完渐隐，无闪光。普通石头只碰撞。本页为候选，尚未推广至正式地图。</p><p>按钮对比旧的成对布局与本轮布局，二者均使用已认可的地面配色。</p>''']
for surface,label in [('dirt','泥地'),('grass','草地'),('forest','林下')]:
    parts.append(f'<h2>{label}</h2><button onclick="document.getElementById(\'{surface}\').src=\'{surface}-before.png\'">旧布局</button><button onclick="document.getElementById(\'{surface}\').src=\'{surface}-after.png\'">本轮布局</button><img class="scene" id="{surface}" src="{surface}-after.png"><div class="grid">')
    im=Image.open(r/f'{surface}-after.png')
    for i,item in enumerate([x for x in manifest if x['surface']==surface]):
        x=[280,640,1000][i] if i<3 else [200,376,552,728,904,1080][i-3]
        y=355 if i<3 else 540
        crop=im.crop((x-72,y-58,x+72,y+16));name=f'{surface}-root-{i}.png';crop.resize((432,222)).save(r/name)
        parts.append(f'<figure><img src="{name}"><small>{item["name"]} · 根部放大</small></figure>')
    parts.append('</div>')
parts.append(f'<h2>检查记录</h2><p>Godot {qa["engine"]} 实际渲染，{len(qa["checks"])} 项检查，{qa["failures"]} 项失败。覆盖接地固定、碰撞形状、石头不可选中、树晃动无闪光与渐隐。未测帧率。</p><p>27 张候选图保留原树冠、树干及石体的不透明上部像素；石头背后新增少量草叶。配色沿用已认可公式，草叶适配区域扩展至石头后缘。泥土移除不与主体连接的独立片段，不移动土块高度。</p><p>三组最终图的切格及处理检查均通过。过稀初稿、连续底座泥土、脱离主体泥土均已弃用并保留记录。图片通过 generate2dsprite 受控流程生成，路线 local:codex-cli，回执模型 codex-image_gen，底层精确型号未知；订阅额度估算费用 0 美元，不代表未消耗额度。</p><p><a href="runtime.json">运行检查</a> · <a href="../../prototypes/environment-contact-natural-v01/runtime/manifest.json">素材与来源记录</a></p></html>')
(r/'index.html').write_text(''.join(parts),encoding='utf8')
print(json.dumps({'checks':len(qa['checks']),'failures':qa['failures'],'opaque_upper_body_preserved':all(x['opaque_upper_body_preserved'] for x in manifest),'assets':len(manifest)}))
