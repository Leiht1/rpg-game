from pathlib import Path
import json, hashlib, html

root=Path(__file__).resolve().parents[1]
out=root/'reports/item-actions-v031'
test=json.loads((out/'tests.json').read_text(encoding='utf-8'))
provenance=json.loads((root/'assets/items/v03/provenance.json').read_text(encoding='utf-8'))
assert all(hashlib.sha256((root/'assets/items/v03'/name).read_bytes()).hexdigest()==sha for name,sha in provenance['files'].items())
shots=[('formal-resource-art','正式地图：本批资源画稿已接入'),('right-click-menu','右键菜单：使用 / 销毁'),('split-quantity','Ctrl+左键：输入拆分数量'),('draggable-bag','标题栏拖动后的背包'),('drop-in-flight','快捷栏拖到地面：物品下落中'),('drop-landed','轻弹结束：物品留在脚边，可按E拾回')]
cards=''.join(f'<figure><a href="{name}.png"><img src="{name}.png" alt="{caption}"></a><figcaption>{caption}</figcaption></figure>' for name,caption in shots)
checks=''.join(f'<li>{"✓" if row["pass"] else "✗"} {html.escape(row["name"])}</li>' for row in test['checks'])
page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>风栖原野 · 正式资源与物品交互</title><style>body{{margin:0;background:#eae7d9;color:#424a35;font:16px/1.7 "Microsoft YaHei",sans-serif}}main{{max-width:1280px;margin:30px auto;padding:24px}}header{{background:#f8f0dc;border:2px solid #9b8966;border-radius:16px;padding:22px 28px}}h1{{margin:0;font-size:29px}}h2{{font-size:22px}}.grid{{display:grid;grid-template-columns:1fr 1fr;gap:22px;margin:24px 0}}figure{{margin:0;padding:12px;background:#f8f2e4;border-radius:12px}}img{{width:100%;display:block;border-radius:8px}}figcaption{{text-align:center;margin-top:8px}}a{{color:#617a46}}li{{margin:5px 0}}small{{color:#7b765c}}@media(max-width:800px){{.grid{{grid-template-columns:1fr}}}}</style><main><header><h1>资源正式接入 · 物品交互修订</h1><p>2026-10-17 · Godot {test['engine']} · {test['renderer']}</p><p>双击项目根目录 Start-Playtest.cmd 直接试玩。原24张资源画稿已获用户“接入游戏吧”授权；正式路径 assets/items/v03，PNG哈希24/24与来源一致。自然生成与正式存档沿用，无重置。</p></header><ul><li>从背包或快捷栏拖到地面：整组丢在脚边，0.43秒下落/轻弹，落地后可E拾回。拖到界面空白或按钮取消，不误丢弃。</li><li>右键：打开“使用 / 销毁”。使用消耗1份；销毁删除该格整组，不生成掉落。材料使用禁用；Ctrl+右键不再丢弃。</li><li>Ctrl+左键：数量≥2时输入拆分数量（1至原数量减1），新组放入背包空格。无空格、非法输入或取消不改变数量；数字输入不触发快捷使用。</li><li>拖动背包标题栏移动窗口，窗口限制在画面内；格间拖放/合并/交换、B开关与数字键快捷使用保留。</li></ul><div class="grid">{cards}</div><h2>本轮专项：{len(test['checks'])}项 / {len(test['failures'])}失败</h2><p>使用实际鼠标/键盘事件验证原生拖放、菜单、拆分、满包、误投到UI、脚边下落、E拾回及原子保存恢复。未重跑无关的大陆/天气全量检查；地图规则、速度、天气、树石画稿保持。没有新图片生成或图片重绘，没有新增功能系统。</p><details><summary>查看检查条目</summary><ol>{checks}</ol></details><p><small>批准来源与原始生成路线保存在 assets/items/v03/provenance.json。历史原图跨格失败及重排 safe_frame WARN=14/阈值0保留，运行时透明安全边保持；本轮批准不自动覆盖未来新素材。</small></p></main></html>'''
(out/'index.html').write_text(page,encoding='utf-8')
print('Item actions report packaged; 24 approved PNG hashes match.')
