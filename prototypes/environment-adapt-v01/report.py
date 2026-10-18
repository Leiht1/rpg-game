from pathlib import Path
from PIL import Image
import numpy as np,json,html
base=Path(__file__).resolve().parents[2];study=base/'prototypes/environment-adapt-v01';out=base/'reports/environment-adapt-v01'
runtime=json.loads((out/'runtime.json').read_text(encoding='utf8'))
manifest=json.loads((study/'runtime/manifest.json').read_text(encoding='utf8'))
selection=json.loads((study/'selection.json').read_text(encoding='utf8'))
for n,x in enumerate([280,640,1000],1):
    frames=[Image.open(p).convert('RGB').crop((x-135,115,x+135,403)) for p in sorted(out.glob(f'tree-{n}-hit-[0-9][0-9].png'))]
    sample=Image.new('RGB',(270,288*len(frames)))
    for i,frame in enumerate(frames):sample.paste(frame,(0,288*i))
    palette=sample.quantize(colors=256);frames=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    frames[0].save(out/f'tree-{n}-hit.gif',save_all=True,append_images=frames[1:]+[frames[-1]],duration=[40]*len(frames)+[600],loop=0,optimize=True)
warnings=[];qa={}
for p in sorted((study/'art').glob('*/sheet-qc.json'))+sorted((study/'art').glob('*/pipeline-meta.json')):
    j=json.loads(p.read_text(encoding='utf8'));q=j.get('qa',j);qa[str(p.relative_to(base))]=q
    for c in q.get('checks',[]):
        if c['status'] in ['warn','fail']:warnings.append({'file':str(p.relative_to(base)),**c})
alpha_checks=[]
for e in manifest:
    a=np.asarray(Image.open(study/'runtime'/e['file']).convert('RGBA')).astype(float)
    magenta=(a[...,3]>128)&(a[...,0]-a[...,1]>40)&(a[...,2]-a[...,1]>40)
    alpha_checks.append({'file':e['file'],'opaque_magenta_px':int(magenta.sum()),'upper_unchanged':e['registration']['body_unchanged']})
jobs=[json.loads((study/'art'/k/'job.json').read_text(encoding='utf8')) for k in ['trees-01','rocks-01']]
(out/'provenance.json').write_text(json.dumps({'selection':selection,'art_source':'host_image through controlled route_media','route':'local:codex-cli','model':'codex-image_gen','precise_backend':'unknown','estimateUsd':0,'cost_note':'local subscription; no independent quota measurement','jobs':jobs,'qa':qa,'warnings_and_failures':warnings,'final_alpha_checks':alpha_checks,'registered_assets':manifest,'body_policy':'original chosen upper art copied byte-for-byte; only contact drawings used from new image generation','source_exception':'Full generated tree crowns cross cells and are NOT used. Explicit lower-cell root ownership extraction has no cross-cell FAIL; its safe_frame WARN remains. Generated upper crowns are discarded, not approved.'},ensure_ascii=False,indent=2),encoding='utf8')
warntext='\n'.join(f"{w['status'].upper()} {w['id']} value={w['value']} threshold={w['threshold']} file={w['file']}" for w in warnings)
sections=''
for key,name in [('grass','草地 · 沿用已选原图'),('forest','林下 · 新接触候选'),('dirt','裸土 · 新接触候选')]:
    sections+=f'<section><h2>{name}</h2><a href="{key}.png" target="_blank"><img src="{key}.png"></a><details><summary>查看对应脚底碰撞</summary><img loading="lazy" src="{key}-collision.png"></details></section>'
clips=''.join(f'<figure><img src="tree-{i+1}-hit.gif"><figcaption>{name} · 固定根部 / 无闪白</figcaption></figure>' for i,name in enumerate(['高瘦幼树','高大开展树','疏冠分叉树']))
page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>风栖原野 · 已选景物地表与碰撞</title><style>body{{margin:0;background:#edf1e8;color:#29392b;font:16px/1.8 "Microsoft YaHei",sans-serif}}main{{max-width:1280px;padding:30px;margin:auto}}h1{{font-size:28px}}h2{{font-size:21px}}section{{padding:24px;background:white;border-radius:12px;margin:24px 0}}img{{display:block;width:100%;height:auto;border-radius:5px}}a{{color:#386b46}}.tag{{background:#ffefc2;border-radius:16px;padding:5px 13px}}.clips{{display:grid;grid-template-columns:repeat(3,1fr);gap:25px}}figure{{margin:0}}figcaption{{padding:8px;font-size:14px}}pre{{background:#f3f4ee;padding:15px;white-space:pre-wrap;word-break:break-all;font-size:12px}}details{{margin-top:15px}}@media(max-width:800px){{main{{padding:15px}}.clips{{grid-template-columns:1fr}}}}</style><main>
<span class="tag">选型已记录 · 新接触部位待确认 · 正式地图未替换</span><h1>三种树 · 六种静态普通石头</h1><p>保留高瘦幼树、高大开展树、疏冠分叉树及六种普通石头；<b>矮胖阔冠树已排除</b>，不在当前资源清单、碰撞或交互场景中。普通石头只碰撞，不受击、不采集、不移除。</p>
<p>本轮下一步完成：九种造型的草地/林下/裸土接触对照、逐种脚底多边形、真实物理探针与正式reach picker检查。沿用原角色和地面Shader，真实1280×720 / Camera2D 1×；这是独立固定布置场景，尚未覆盖正式世界。</p>
{sections}
<section><h2>树木受击</h2><div class="clips">{clips}</div><p>局部动图为原尺寸画面裁切。根部下段40世界单位固定，网格中上部渐进晃动；只晃动不提亮。最终整树/根部/阴影原地0.3秒降低透明度，无倒树或树桩。石头没有此动画入口。</p></section>
<section><h2>碰撞和交互结果</h2><p>{html.escape(runtime['engine'])} / {html.escape(runtime['adapter'])}，<b>{len(runtime['checks'])}项专项、失败{runtime['failures']}</b>。九种对象×三地表×四方向，10单位脚底圆通过真实move_and_collide被正确对象挡住；树冠高度处可通过。六种石头不会被正式interaction_target选中，调用受击/渐隐/移除也不生效；碰撞保持。</p><p>逐棵树14帧固定根部、RGB不改色、回弹归零通过；采集演示沿用细/中树2击1木、粗干树4击2木的两档节奏，主动拾取通过。E在样板中直接调用交互逻辑，这不是正式角色挥砍命中/分块回归。<a href="runtime.json">专项数据</a> · <a href="runtime.log">运行日志</a>。</p><p>双击 <a href="../../prototypes/environment-adapt-v01/Start-Preview.cmd">Start-Preview.cmd</a>：1/2/3切地表，左右选对象，E砍树/拾取，H晃动，F渐隐，C显示碰撞，空格重置。石头对E/H/F均无受击或采集响应。</p></section>
<section><h2>画稿与来源</h2><p>27张运行画稿。树上部216行、石上部76行与已选原图逐像素保持，不改变树冠、枝干或石块上部。只使用本轮真实生成的底部结构，按等比注册对接；树接缝6行、石4行预乘alpha过渡，不整图染色或非等比压缩。林下增加少量落叶，裸土去掉草叶并使用不连续土唇。裸土背景仍复用原shore砂石画稿，不代表新增正式泥地/裸岩材质。</p><p>generate2dsprite受控route_media → <b>local:codex-cli</b>，回执codex-image_gen，精确后端未知。本地订阅估算USD0，不代表没有额度消耗，无外部下载素材。提示词、实际参考哈希、回执、原图、注册坐标、草地原图及失败/警告完整保留。最终27张opaque_magenta_px均0，上部原图保持检查全部通过。</p><p>树的新原始图上部冠幅跨格，不能用作完整树资源；本轮按明确所有权只取各格底128行的完整根部，生成的新树冠全部弃用。根部区域独立检查无cross_cell FAIL，但留白WARN仍在。数值不代替用户视觉判断。</p><details><summary>全部QA失败和警告（不隐去原图上部跨格问题）</summary><pre>{html.escape(warntext)}</pre></details><p><a href="provenance.json">完整来源与QA</a> · <a href="../../prototypes/environment-adapt-v01/selection.json">本轮选择记录</a> · <a href="../../prototypes/environment-adapt-v01/runtime/manifest.json">27图注册表</a> · <a href="../../prototypes/environment-adapt-v01/README.md">实现与范围</a></p></section>
<section><h2>本轮边界</h2><p>新林下/裸土接触部分仍需视觉确认；用户已选定的九种形态保持。裸土土唇仍可能读成小土块，接缝与嵌入是否自然请看同屏；不提前标为已批准。雪地未生产，山地生长条件、跨分块间距、世界分布及密林性能本轮未扩展，正式生成器windrest-continent-0.6.0、世界身份、角色、按键和收益文件均保持。</p><p>未测新样板或密林GPU/FPS；没有拿小样板物理检查当全世界通行证明。当前新增碰撞只验证已选固定布置，不保证所有未来缩放/地形条件。完成这一轮新接地部位与碰撞样板即停止，确认后再正式推广。</p></section></main></html>'''
(out/'index.html').write_text(page,encoding='utf8')
print(json.dumps({'checks':len(runtime['checks']),'failures':runtime['failures'],'assets':len(manifest),'upper_preserved':all(e['registration']['body_unchanged'] for e in manifest),'opaque_magenta_px':sum(e['opaque_magenta_px'] for e in alpha_checks),'warnings_and_failures':warnings},ensure_ascii=False))
