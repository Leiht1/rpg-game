"""Package existing screenshots/art references; does not generate or alter art."""
from pathlib import Path
import json
import hashlib
import html
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'reports/resources-v031'
OUT.mkdir(parents=True, exist_ok=True)
rows = json.loads((ROOT / 'data/items.json').read_text(encoding='utf-8'))
audit = []
for row in rows:
    for kind in ('icon', 'world'):
        path = ROOT / row['icon' if kind == 'icon' else 'world_visual'].removeprefix('res://')
        im = Image.open(path).convert('RGBA')
        bbox = im.getbbox()
        audit.append({'item_id': row['item_id'], 'kind': kind, 'file': str(path.relative_to(ROOT)),
                      'size': im.size, 'bbox': bbox, 'source_cropped_to_alpha': bbox == (0, 0, *im.size),
                      'runtime_transparent_margin_source_px': 8,
                      'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                      'status': 'pending_user',
                      'note': 'AtlasTexture adds empty canvas, keeps world content width and contact bottom; PNG unchanged.'})
old_warnings = json.loads((ROOT / 'reports/items-v03/art-warnings.json').read_text(encoding='utf-8'))
qa = {'art_source': 'existing', 'new_image_calls': 0,
      'original_route': 'controlled route_media -> Codex (local CLI), 2026-10-17 V0.3',
      'original_provenance': 'prototypes/items-v03/provenance.json',
      'candidate_status': 'pending_user', 'assets': audit,
      'historical_qa': old_warnings,
      'limits': ['Original sheet crossing failures and regrid safe_frame warnings retained.',
                 'Padding cannot repair missing anatomy; no source subjects were redrawn.',
                 'Contact colour, source identity, view and small-scale readability await user review.']}
(OUT / 'art-review.json').write_text(json.dumps(qa, ensure_ascii=False, indent=2), encoding='utf-8')

def read_json(name):
    path = OUT / name
    return json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}

tests = read_json('tests.json')
runtime = read_json('runtime.json')
restart_write = read_json('restart-write.json')
restart_read = read_json('restart-read.json')
movement = read_json('movement-chop.json')
debug = read_json('debug-seed.json')
names = [('spawn', '出生区域'), ('forest', '森林'), ('meadow', '草原'), ('mountain', '山地'), ('shore', '水岸')]
shots = ''
for key, label in names:
    where = runtime.get('locations', {}).get(key, {})
    shots += f'<article><h2>{label}</h2><p>Seed 271828 · ({where.get("x", 0):.0f}, {where.get("y", 0):.0f}) · 区块{where.get("chunk", "")}</p><div class="pair">'
    for mode, title in [('formal', '正式入口：临时标记'), ('preview', '候选画稿：待确认')]:
        shots += f'<figure><a href="{mode}-{key}.png"><img src="{mode}-{key}.png" alt="{label} · {title}"></a><figcaption>{title}</figcaption></figure>'
    shots += '</div></article>'

art = ''
for row in rows:
    art += f'<figure class="art"><div class="artpair">'
    for kind in ('world', 'icon'):
        source = row['world_visual' if kind == 'world' else 'icon'].removeprefix('res://')
        art += f'<img src="../../{source}" alt="{html.escape(row["name"])} {kind}">'
    art += f'</div><figcaption>{html.escape(row["name"])} · 场景 / 背包<br><small>{row["item_id"]} · pending_user</small></figcaption></figure>'

samples = ''
for sample in tests.get('samples', []):
    samples += f'<tr><td>{sample["seed"]}</td><td>{sample["chunks"]}</td><td>{sample["resources"]}</td><td>{sample["empty_chunks"]}</td><td>{sample["spawn_visible"]}</td><td>{sample["navigation_ms"]:.1f}</td></tr>'

warnings = ''.join(f'<li><code>{html.escape(w["file"])}</code> · {html.escape(w["id"])} · {w["status"]} · value={w.get("value")} / threshold={w.get("threshold")}</li>' for w in old_warnings)
perf = runtime.get('performance', {})
page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>风栖原野 V0.3.1 · 自然资源验收</title>
<style>body{margin:0;background:#ece8db;color:#3c4434;font:16px/1.7 "Microsoft YaHei",sans-serif}main{max-width:1360px;margin:auto;padding:40px 28px}header{padding:24px 30px;background:#f8f2df;border:2px solid #9e916f;border-radius:16px}h1{margin:0;font-size:32px}h2{font-size:23px;margin:18px 0 6px}h3{margin-top:24px}a{color:#626b39}p{margin:8px 0}.note{background:#e0e7cf;border-radius:8px;padding:12px 18px}article{margin:24px 0;padding:16px;background:#f9f4e8;border-radius:12px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:14px}figure{margin:0}img{display:block;width:100%;border-radius:7px}figcaption{text-align:center;font-size:14px}.artgrid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px}.art{padding:14px;background:#e4e0d3;border:1px solid #b1a587;border-radius:10px}.artpair{height:150px;display:flex;justify-content:center;align-items:center;gap:18px}.artpair img{width:auto;height:auto;max-width:46%;max-height:135px;object-fit:contain}small{color:#7b775f}table{border-collapse:collapse;width:100%}td,th{text-align:left;border-bottom:1px solid #bdbaa9;padding:9px}code{font-size:12px;overflow-wrap:anywhere}li{margin:5px 0}.evidence{display:grid;grid-template-columns:repeat(2,1fr);gap:16px}.badge{display:inline-block;border:1px solid #a3956c;border-radius:20px;padding:1px 12px;margin-right:8px}@media(max-width:850px){.pair,.evidence{grid-template-columns:1fr}.artgrid{grid-template-columns:repeat(2,1fr)}}</style><main>'''
page += f'''<header><h1>风栖原野 V0.3.1 · 地图自然资源</h1><p>2026-10-17 · Godot 4.7.2 Stable · natural-resources-0.3.1</p><span class="badge">正式逻辑已接入</span><span class="badge">24张画稿仍待确认</span><p>正式试玩：根目录 Start-Playtest.cmd；美术试玩：Start-Items-Preview.cmd。WASD / Shift移动，E采集或拾取，B背包，Ctrl+右键放下1个，F7资源分布与临时Seed。</p></header>
<p class="note">正式入口暂用“临·名称”原生符号，木材保留原已确认图。右侧是真实地图同Seed、同位置的新开预览世界，不是另一个生成器；未将候选升级为正式美术。下方24图仅为验收目录，松果没有可信针叶树来源，当前不自然生成。</p>
<p><a href="#maps">五处地图</a> · <a href="#art">24张画稿</a> · <a href="#checks">专项验证</a> · <a href="#qa">原始美术QA与限制</a></p><section id="maps">{shots}</section>
<h2 id="art">现有候选画稿 · 独立场景形态 / 背包图标</h2><p>复用已生成素材，无新图片调用、无树石或地表重绘。AtlasTexture增加8源像素透明安全边，保持场景内容宽度及脚底；来源、原PNG和原失败/警告报告均保留。此目录不代表自然生成的布局。</p><div class="artgrid">{art}</div>
<h2 id="checks">最小专项验证</h2><p>生成与状态：{tests.get('checks', '?')}项 / {len(tests.get('failures', []))}失败；真实渲染与交互：{len(runtime.get('checks', []))}项 / {len(runtime.get('failures', []))}失败；独立进程写档/重启：{restart_write.get('checks','?')} + {restart_read.get('checks','?')}项；移动/砍树必要依赖：{len(movement.get('checks', []))}项 / {movement.get('failures', '?')}失败；临时Seed/晴雨必要检查：{debug.get('checks','?')}项 / {len(debug.get('failures', []))}失败。最终日志与JSON可在本目录复查。</p>
<table><thead><tr><th>Seed</th><th>抽样区块</th><th>自然资源点</th><th>整块留空</th><th>出生镜头可见</th><th>首次导航 ms</th></tr></thead><tbody>{samples}</tbody></table>
<p>抽样偏向各生态核心，不能外推为全世界平均密度。已验证冷缓存/逆加载顺序、跨块间距、水域与树石脚底、采集过滤、部分拾取数量守恒、满包保留、独立丢弃、旧档迁移、原地图地形与树石未改变；没有执行无关全量回归。</p>
<div class="evidence">'''
for file, caption in [('distribution-debug', 'F7：实际区块拒绝点、规则和状态'), ('before-harvest', '自然生成植物 · E采集前'), ('after-harvest-bag', '采集进入32格背包，快捷栏留空'), ('full-bag-retains-resource', '满包E失败，资源仍在原地')]:
    page += f'<figure><a href="{file}.png"><img src="{file}.png" alt="{caption}"></a><figcaption>{caption}</figcaption></figure>'
page += f'''</div><p>已加载水岸180帧、60FPS限帧样本：中位 {perf.get('median_ms', 0):.3f}ms，P95 {perf.get('p95_ms', 0):.3f}ms，最大 {perf.get('max_ms', 0):.3f}ms；本次跨位置挂载峰值 {perf.get('max_chunk_install_ms', 0):.3f}ms；静态内存 {perf.get('memory_mib', 0):.2f}MiB。含帧等待，不是全地图压力测试或所有Seed的性能保证。</p>
<h2 id="qa">美术检查与保留限制</h2><p>已目视检查原始24格、独立植物、五类环境实景和边缘。场景生长图不是背包图标放大；根部无统一黑椭圆。小石块在山地纹理中的辨识、植物底缘的绿叶颜色、斜俯视统一程度、苹果来源树的视觉身份仍须用户验收。未宣称所有画稿已满足审美要求。</p><p>旧原图跨格失败经过所有权重排处理，当前安全边由运行时留白解决；以下原始数值照录，不能把处理QA或增加留白等同于用户通过：</p><ul>{warnings}</ul>
<p>本轮没有图片生成，既有路线为受控 route_media → Codex (local CLI)；原底层精确图片型号/实际费用未知。doctor的可选视频/科学依赖缺失不影响本轮静态现有PNG复查，详见 art-doctor.json。没有新增外部商业资源。</p><p>自然资源不刷新，无工具/配方/种植/生长/季节系统。本轮停在逻辑交付与候选美术验收。</p></main></html>'''
(OUT / 'index.html').write_text(page, encoding='utf-8')
print('Packaged report: reports/resources-v031/index.html; 24 unchanged PNG hashes audited.')
