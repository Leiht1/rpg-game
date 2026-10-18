from pathlib import Path
from PIL import Image
import json,html
base=Path(__file__).resolve().parents[2]
study=base/'prototypes/environment-variety-v01';out=base/'reports/environment-variety-v01'
manifest=json.loads((study/'runtime/manifest.json').read_text(encoding='utf8'))
runtime=json.loads((out/'runtime.json').read_text(encoding='utf8'))
for n,x in enumerate([220,500,780,1060],1):
    files=sorted(out.glob(f'tree-{n}-hit-[0-9][0-9].png'))
    frames=[Image.open(p).convert('RGB').crop((x-128,115,x+128,402)) for p in files]
    source=Image.new('RGB',(256,287*len(frames)))
    for i,f in enumerate(frames):source.paste(f,(0,287*i))
    palette=source.quantize(colors=256)
    images=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    images[0].save(out/f'tree-{n}-hit.gif',save_all=True,append_images=images[1:]+[images[-1]],duration=[40]*len(images)+[600],loop=0,optimize=True)
warnings=[];qa={}
for p in sorted((study/'art').glob('*/sheet-qc.json'))+sorted((study/'art').glob('*/pipeline-meta.json')):
    data=json.loads(p.read_text(encoding='utf8'));envelope=data.get('qa',data)
    qa[str(p.relative_to(base))]=envelope
    for c in envelope.get('checks',[]):
        if c['status'] in ['fail','warn']:warnings.append({'file':str(p.relative_to(base)),**c})
current=[w for w in warnings if any(s in w['file'] for s in ['trees-spill-02','rocks-spill','trees-processed-02','rocks-processed-02'])]
archived=[w for w in warnings if w not in current]
jobs=[json.loads((study/'art'/name/'job.json').read_text(encoding='utf8')) for name in ['trees-01','trees-02','rocks-01']]
(out/'provenance.json').write_text(json.dumps({'art_source':'host_image via controlled route_media','route':'local:codex-cli','model':'codex-image_gen','precise_backend':'unknown','estimateUsd':0,'cost_note':'subscription quota; not a verified quota-use measurement','jobs':jobs,'qa':qa,'warnings_and_failures':warnings,'manifest':manifest,'status':'pending_user','selected_sources':['trees-02','rocks-01'],'not_used':['trees-01 crossed cell boundaries','trees-processed initial defective extraction','rocks-processed default trim warning; superseded without cropping']},ensure_ascii=False,indent=2),encoding='utf8')
def warntext(items):
    return '\n'.join(f"{w['status'].upper()} {w['id']} value={w['value']} threshold={w['threshold']} file={w['file']}" for w in items)
tree_cards=''.join(f'<figure><img src="tree-{i+1}-hit.gif"><figcaption>{e["name"]} · 只晃动，无闪白</figcaption></figure>' for i,e in enumerate(manifest[:4]))
rows=''.join(f'<tr><td>{e["id"]}</td><td>{e["name"]}</td><td>{e["display_bbox"][2]-e["display_bbox"][0]} × {e["display_bbox"][3]-e["display_bbox"][1]}</td></tr>' for e in manifest)
page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>风栖原野 · 树与普通石头候选</title><style>body{{background:#edf1e8;color:#28392c;font:16px/1.8 "Microsoft YaHei",sans-serif;margin:0}}main{{max-width:1320px;margin:auto;padding:30px}}section{{background:white;border-radius:12px;padding:24px;margin:24px 0}}h1{{font-size:28px}}h2{{font-size:21px}}img{{display:block;max-width:100%;height:auto;border-radius:6px}}.grid{{display:grid;grid-template-columns:repeat(4,1fr);gap:18px}}figure{{margin:0}}figcaption{{padding:8px 0;font-size:14px}}a{{color:#366d43}}table{{border-collapse:collapse}}td,th{{border-bottom:1px solid #dde5d9;padding:7px 28px 7px 0;text-align:left}}pre{{font-size:12px;background:#f3f5ef;padding:16px;white-space:pre-wrap;word-break:break-all}}.tag{{background:#ffebbb;padding:5px 12px;border-radius:20px}}@media(max-width:800px){{.grid{{grid-template-columns:1fr 1fr}}main{{padding:15px}}}}</style><main>
<span class="tag">独立候选 · 待选定 · 未接入正式世界</span><h1>四种树 · 六种普通石头</h1><p>受击与消失的提亮路径已移除：受击只晃动回弹，砍完原地0.3秒透明渐隐。没有闪白、倒树或树桩。</p>
<section><h2>实际游戏尺度同屏</h2><a href="lineup.png" target="_blank"><img src="lineup.png"></a><p>Godot 4.7.2 / 原白T角色 / 原地表Shader / 1280×720 / Camera2D 1×。固定布置样板；点击可看原图。</p><p>树的区别来自独立冠形、枝干结构、干粗与高宽比例；石头区别来自轮廓、体积、顶侧面和缺口。树内部统一等比整理尺度0.72，石头内部统一0.24，没有对同一张图拉伸挤压凑变体。</p></section>
<section><h2>四种树的受击表现</h2><div class="grid">{tree_cards}</div><p>动图为同一1×渲染画面的原尺寸裁切。固定下段不动，中上部渐进晃动后归零。<a href="../environment-v01/tree-fade.gif">查看无闪白的原地渐隐</a> · <a href="../environment-v01/index.html">原三地表样板（已更新）</a></p></section>
<section><h2>运行与验证</h2><p>双击 <a href="../../prototypes/environment-variety-v01/Start-Preview.cmd">Start-Preview.cmd</a>；← →选择树，H受击，F渐隐，空格重置。</p><p>{html.escape(runtime['engine'])} / {html.escape(runtime['adapter'])}：{len(runtime['checks'])}项专项，失败{runtime['failures']}。逐棵检查16帧根部/碰撞固定、RGB调制保持白色、回弹归零、渐隐只改alpha且不旋转，以及Shader中不存在flash或RGB混色路径。原样板另外150项专项通过。<a href="runtime.json">检查记录</a> · <a href="runtime.log">日志</a>。</p><table><tr><th>编号</th><th>造型</th><th>可见画稿宽高（世界单位）</th></tr>{rows}</table></section>
<section><h2>来源与质量记录</h2><p>generate2dsprite受控route_media → <b>local:codex-cli</b>真实生成。trees-01为初稿，trees-02只修正排布；rocks-01为六种独立石头。已附上当前角色同屏及树石原图作实际参考。回执模型codex-image_gen，精确后端未知；本地订阅估算USD0，不代表没有额度消耗。没有外部下载资产。</p><p>当前整理结果trees-processed-02与rocks-processed-02均为pass，opaque_key_px=0、outer_ring_spill_fraction=0。原图仍有以下留白/边界邻近警告，均保留：</p><pre>{html.escape(warntext(current))}</pre><details><summary>已废弃初稿及首次整理的完整失败/警告</summary><pre>{html.escape(warntext(archived))}</pre><p>树初稿跨格，未用于当前候选；修订后无跨格。石头首次整理使用默认4px裁边触发source_edge_touch，最终取消裁边保留原画，未删主体。以上失败不隐去，也不当作已通过。</p></details><p><a href="provenance.json">提示词/参考哈希/回执/全部QA</a> · <a href="../../prototypes/environment-variety-v01/runtime/manifest.json">素材注册与哈希</a> · <a href="../../ENVIRONMENT_OBJECT_STYLE.md">更新后的规范</a></p></section>
<section><h2>本轮边界</h2><p>这十种新造型仅做草地接触版。林下、裸土、雪地版本待造型选择后再制作，避免未选定就批量推广。未新增玩法、正式生成规则或新生态；正式资源、角色、E键和采集收益保持。样板碰撞只验证受击不漂移，尚未为新形态逐种制作正式精细碰撞，也没有正式密集森林性能结论。</p><p>四棵树仍属于同一绿色阔叶体系，窄高石较直立，均留给本轮视觉选择。根草的密度、色彩和新造型是否合适需你判断；新素材状态pending_user。本轮到此停止。</p></section></main></html>'''
(out/'index.html').write_text(page,encoding='utf8')
print(json.dumps({'checks':len(runtime['checks']),'failures':runtime['failures'],'current_warnings':current},ensure_ascii=False))
