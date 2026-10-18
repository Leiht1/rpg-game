from pathlib import Path
import json,html
root=Path('reports/items-v03')
qa=[]
for p in [Path('art/items-v03/spill-01/sheet-qc.json'),Path('art/items-v03/spill-02/sheet-qc.json'),Path('art/items-v03/processed-01/pipeline-meta.json')]:
 d=json.loads(p.read_text(encoding='utf-8')); envelope=d.get('qa',d)
 if 'checks' not in envelope and 'qa' in d: envelope=d['qa']
 for c in envelope.get('checks',[]):
  if c.get('status') in ('warn','fail'): qa.append(dict(file=str(p),**c))
print(json.dumps(qa,ensure_ascii=False,indent=2))
qa_text=html.escape(json.dumps(qa,ensure_ascii=False,indent=2))
parts=['''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>风栖原野 · 物品系统 V0.3</title><style>body{background:#f5f0e3;color:#3e4939;font:16px/1.7 system-ui;margin:32px auto;max-width:1180px}img{max-width:100%;border:2px solid #aa9875;border-radius:12px}section{margin:28px 0}a{color:#557445}pre{white-space:pre-wrap;background:#e8dfcb;padding:16px;border-radius:10px}.tag{background:#d9e4cb;padding:8px 14px;border-radius:8px}</style><h1>风栖原野 · 物品系统 V0.3</h1><p class="tag">功能与 UI 已实现；新增物品美术 pending_user，未正式批量推广。</p><p>背包 B · 8 个快捷格初始留空 · 只通过玩家拖动放入 · 1–8直接使用 · 右键食用 · F6 图鉴。拾取优先补快捷栏已有同类堆叠，空快捷格只由玩家拖入；右侧小背包按钮对齐，悬停0.15秒。格子约52px，无格内名称；背包/快捷栏底座/悬停卡统一实底、描边和圆角。</p><p><a href="../../Start-Items-Preview.cmd">启动独立物品预览</a> · <a href="../../ITEM_SYSTEM.md">规则与限制</a> · <a href="tests.json">专项测试</a> · <a href="capture.log">实景与交互日志</a></p>''']
for title,file in [('新版背包：32格，快捷栏保持空白','bag-empty-hotbar.png'),('统一边框的悬停信息卡','item-hover-card.png'),('拖放后右键食用：只减少一份','bag-drag-and-eat.png'),('独立快捷栏底座','hotbar.png'),('同一套图鉴界面','catalog.png'),('真实游戏镜头中的12种地面候选（角色下方两排为展示摆放，其余为自然生成）','world-candidates.png')]:
 parts.append(f'<section><h2>{title}</h2><img src="{file}" alt="{title}"></section>')
parts.append('<section><h2>生成与美术检查</h2><p>Codex (local CLI) 受控 route_media，一次订阅额度调用；模型名 codex-image_gen，底层精确型号未知，账本0美元为额度口径，不代表实际成本确定。24张切格与去底通过 process QA；视觉仍须用户确认。原始排版跨格，保留失败报告，按实测所有权矩形重排后无跨格；safe_frame 14项超过建议安全区警告仍保留。以下为全部已发布美术检查 WARN/FAIL：</p><pre>'+qa_text+'</pre><p><a href="../../prototypes/items-v03/provenance.json">来源与哈希</a> · <a href="../../art/items-v03/processed-01/pipeline-meta.json">24帧处理QA</a> · <a href="../../art/items-v03/doctor.json">能力检查（含环境缺项）</a></p></section><p>未新增生命值/饥饿值、制作、装备或其他玩法。苹果来源只关联固定现有树，没有专门挂果树画稿；松果也未新增针叶树种。未测本轮FPS/全Seed长时性能，不将功能验证当作美术验收。</p></html>')
root.joinpath('index.html').write_text(''.join(parts),encoding='utf-8')
root.joinpath('art-warnings.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2),encoding='utf-8')
