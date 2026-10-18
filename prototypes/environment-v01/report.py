from pathlib import Path
from PIL import Image,ImageChops
import json,hashlib,html
base=Path(__file__).resolve().parents[2]
out=base/'reports/environment-v01';study=base/'prototypes/environment-v01'
data=json.loads((out/'runtime.json').read_text(encoding='utf8'))
for prefix in ['tree-hit','tree-fade']:
    paths=sorted(out.glob(prefix+'-[0-9][0-9].png'))
    frames=[Image.open(p).convert('RGB').crop((340,160,890,510)) for p in paths]
    sample=Image.new('RGB',(550,350*len(frames)))
    for i,f in enumerate(frames):sample.paste(f,(0,350*i))
    pal=sample.quantize(colors=256)
    indexed=[f.quantize(palette=pal,dither=Image.Dither.NONE) for f in frames]
    # GIF durations are integer multiples of ten milliseconds.
    durations=([30,40]*(len(frames)//2)) if prefix=='tree-hit' else [30]*len(frames)
    indexed[0].save(out/(prefix+'.gif'),save_all=True,append_images=indexed[1:]+[indexed[-1]],duration=durations+[700],loop=0,optimize=True,disposal=1)

fixed=[]
ref=Image.open(out/'grass-new.png').convert('RGB').crop((445,366,525,390))
for p in sorted(out.glob('tree-hit-[0-9][0-9].png')):
    probe=Image.open(p).convert('RGB').crop((445,366,525,390))
    fixed.append({'frame':p.name,'fixed_root_pixels_identical':ImageChops.difference(ref,probe).getbbox() is None})
(out/'pixel-checks.json').write_text(json.dumps({'region':[445,366,525,390],'checks':fixed,'limit':'visible fixed root band only; does not prove subjective art quality'},indent=2),encoding='utf8')

hashes={}
for rel in ['scripts/world_generator.gd','scripts/chunk_stream.gd','scripts/player.gd','scripts/grounded_prop.gd','scripts/terrain.gdshader','project.godot','assets/hero/cartoon/character.tscn']+[f'assets/environment/view_v01/{k}_{i}.png' for k in ['tree','rock'] for i in [0,1]]:
    hashes[rel]=hashlib.sha256((base/rel).read_bytes()).hexdigest()
jobs=[json.loads((study/'art'/name/'job.json').read_text(encoding='utf8')) for name in ['take-01','take-02','stumps-01']]
qa={}
warnings=[]
for name in ['spill-01','spill-02','spill-stumps']:
    p=study/'art'/name/'sheet-qc.json';j=json.loads(p.read_text(encoding='utf8'));qa[name]=j
    for c in j['checks']:
        if c['status'] in ['warn','fail']:
            warnings.append({'file':str(p.relative_to(base)),'id':c['id'],'value':c['value'],'threshold':c['threshold'],'status':c['status']})
for name in ['processed-01','processed-02','processed-stumps']:
    j=json.loads((study/'art'/name/'pipeline-meta.json').read_text(encoding='utf8'));qa[name]={'qa':j['qa'],'matte':j.get('matte',{})}
    for c in j['qa']['checks']:
        if c['status'] in ['warn','fail']:warnings.append({'file':f'prototypes/environment-v01/art/{name}/pipeline-meta.json',**c})
provenance={'status':'pending_user','art_source':'host_image through controlled route_media','route':'local:codex-cli','model_reported':'codex-image_gen','exact_backend_model':'unknown','estimateUsd':0,'cost_note':'local subscription quota; no independent price/usage measurement','jobs':jobs,'current_art':'take-02; processed-02; runtime six tree/rock PNGs','out_of_scope':'stumps-01 generated before user narrowed scope; archived, not loaded or shown','external_assets':'none downloaded; approved local references only','formal_hashes_at_delivery':hashes,'qa':qa,'warnings':warnings}
(out/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf8')

warning_text='\n'.join(f"{w['status'].upper()} {w['id']} value={w['value']} threshold={w['threshold']} file={w['file']}" for w in warnings)
cards=''
for key,label in [('grass','草地'),('forest','森林地'),('dirt','裸土地 · 使用原岸土画稿')]:
    cards+=f'''<section><h2>{label}</h2><div class="pair"><figure><img loading="lazy" src="{key}-old.png"><figcaption>旧 view_v01 画稿（未复现正式取色融合）</figcaption></figure><figure><img loading="lazy" src="{key}-new.png"><figcaption>新候选 · 对应地表接触结构</figcaption></figure></div><a href="{key}-new.png" target="_blank">打开1280×720原图</a></section>'''
count=len(data['checks']);pix=sum(x['fixed_root_pixels_identical'] for x in fixed)
page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>风栖原野 · 景物根部与受击样板</title>
<style>body{{margin:0;background:#edf1e8;color:#29362b;font:16px/1.75 "Microsoft YaHei",sans-serif}}main{{max-width:1500px;margin:auto;padding:32px}}h1{{font-size:28px;margin:0}}h2{{font-size:21px}}section{{background:#fff;padding:24px;margin:24px 0;border-radius:12px}}.tag{{display:inline-block;padding:4px 13px;border-radius:20px;background:#fff0c7}}.pair{{display:grid;grid-template-columns:1fr 1fr;gap:18px}}figure{{margin:0}}img{{display:block;width:100%;height:auto;border-radius:6px}}figcaption{{font-size:14px;color:#65745e;padding:8px}}a{{color:#376b43}}pre{{white-space:pre-wrap;word-break:break-all;font-size:13px;background:#f4f5f1;padding:16px}}.clips{{display:grid;grid-template-columns:1fr 1fr;gap:22px}}li{{margin:7px 0}}@media(max-width:800px){{.pair,.clips{{grid-template-columns:1fr}}main{{padding:16px}}}}</style>
<main><span class="tag">独立候选 · 待用户确认 · 未接入正式地图</span><h1>树根衔接与受击回弹</h1><p>根据最新范围：专注根部与地表连接、树受击、砍完原地渐隐。无倒树动作、无树桩。三组真实 Godot 截图使用原角色、原地表 Shader、原逻辑画布及1280×720 / Camera2D 1×；固定布置样板，不读写世界存档。石头只作静态接地参照。</p>
<section><h2>交互演示</h2><div class="clips"><figure><img src="tree-hit.gif"><figcaption>受击与回弹：根部固定，中上部逐渐增强；原始画面局部裁切，未放大。约0.50秒纯晃动，无闪白，末帧停留。</figcaption></figure><figure><img src="tree-fade.gif"><figcaption>砍完：0.3秒原地渐隐，根部覆盖与冠影一起消失，无旋转、无树桩。末帧停留。</figcaption></figure></div><p>H受击，F模拟砍完渐隐，空格重置；1/2/3切地表，Tab切旧/新画稿。<a href="../../prototypes/environment-v01/Start-Preview.cmd">运行本地Godot样板</a>（浏览器可能下载脚本，请在项目文件夹双击）。</p></section>
{cards}
<section><h2>结构与检查结果</h2><ul><li>地表 → 独立柔冠影 → 按脚底Y排序的主体与角色。树内主体网格 → 固定根/草接触片；无独立绿色底座。</li><li>树主体225顶点、384三角形，底部24世界单位固定，切片重叠1单位。变形权重从根部0逐渐增长，冠顶最大横移5单位，回弹归零；不是整树节点转动。</li><li>沿用原树脚底碰撞，受击不变动。静止无每树持续_process，渐隐同时清理整树和阴影。</li><li>{html.escape(data['engine'])} / {html.escape(data['adapter'])}，{count}项专项，失败{data['failures']}。固定根部画面区域{pix}/{len(fixed)}帧逐像素相同。<a href="runtime.json">运行检查</a> / <a href="pixel-checks.json">像素证据</a> / <a href="runtime.log">日志</a>。</li><li>两对象小场景120FPS上限下，120帧静止帧间隔中位数{data['idle_frame_median_ms']:.3f}ms，P95 {data['idle_frame_p95_ms']:.3f}ms。此值包含限帧等待，只证明本机样板未出现明显帧间隔异常，不代表正式密集森林或GPU开销。</li></ul></section>
<section><h2>实际检查发现</h2><p>正式chunk_stream.chop_tree通过旋转整个tree节点反馈，根部与覆盖一起运动；原grounded_prop覆盖来自取地面色的程序多边形，缺真实草叶交错。原生成器已有生态密度、水域排除及通道净空，但无独立地表语义；每个景物是一次整图绘制，不能独立控制主体与接触。</p><p>本轮新画稿直接绘制草叶/落叶/土唇，按接触高度拆为静止下段与渐进变形主体。正式V0.6生成器、分块流、主角移动与动画、E键和采集收益保持。两Seed的独立surface_policy草案工作器复现已验证；它未推广、没有改变正式资源分布。</p></section>
<section><h2>来源与QA</h2><p>受控 generate2dsprite → route_media → <b>local:codex-cli</b>。回执模型codex-image_gen，精确后端未知；本地订阅额度，记录估算USD0，不代表没有额度消耗。初稿、定向修订、参考哈希、完整回执和整理参数均保留。未下载外部素材。</p><p>当前take-02去色后opaque_key_px=0、outer_ring_spill_fraction=0；数值不替代视觉验收。原画留白有以下警告，未跨格/裁断；最终候选与初稿均如实保留：</p><pre>{html.escape(warning_text)}</pre><p><a href="provenance.json">来源/哈希/全部QA</a> · <a href="../../prototypes/environment-v01/runtime/registration.json">等比整理与原点记录</a> · <a href="../../ENVIRONMENT_OBJECT_STYLE.md">景物规范草案</a> · <a href="../../prototypes/environment-v01/README.md">运行和范围说明</a></p></section>
<section><h2>待确认与限制</h2><ul><li>需要确认新树石与角色的视角、草叶覆盖量、林下叶片色及泥地接触是否自然；所有新画稿仍pending_user。</li><li>裸土复用shore画稿，偏砂石；未生产专门泥地、裸岩或雪地接触素材。新石头比旧画稿更扁，仍需视觉选择。</li><li>目前只做一个树形/石形的三地表样板，未批量推广第二树种/石种。</li><li>旧图对照是画稿比较，不是正式第二版接地Shader的完整画面对比。当前候选未验证正式密林冠后淡化、真实分块重载及跨块间距，因此没有全地图接入结论。</li><li>没有新增音效/落叶木屑粒子、石头采集或玩法；生态策略仅草案，待本轮视觉确认后另行处理。已取消的倒树/树桩只保留来源归档，不在运行资源和本报告展示。</li></ul><p>本轮到此停止，等待对根部衔接和受击观感的确认。</p></section></main></html>'''
(out/'index.html').write_text(page,encoding='utf8')
print(json.dumps({'runtime_checks':count,'failures':data['failures'],'root_pixel_checks':pix,'root_pixel_frames':len(fixed),'warnings':warnings},ensure_ascii=False))
