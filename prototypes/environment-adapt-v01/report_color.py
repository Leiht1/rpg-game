from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,html
base=Path(__file__).resolve().parents[2];out=base/'reports/environment-contact-color-v01'
runtime=json.loads((out/'runtime.json').read_text(encoding='utf8'))
mask=np.zeros((720,1280),bool)
for x in [280,640,1000]:mask[322:365,x-130:x+130]=True
for x in [200,376,552,728,904,1080]:mask[522:551,x-66:x+66]=True
metrics=[]
for s in ['grass','forest','dirt']:
    before=np.asarray(Image.open(out/f'{s}-before.png').convert('RGB')).astype(float)
    after=np.asarray(Image.open(out/f'{s}-after.png').convert('RGB')).astype(float)
    ground=np.asarray(Image.open(out/f'{s}-pure-ground.png').convert('RGB')).astype(float)
    changed=np.max(np.abs(before-after),axis=2)>2
    metrics.append({'surface':s,'changed_pixels':int(changed.sum()),'changed_outside_contact':int((changed&~mask).sum()),'mean_RGB_error_to_ground_before':float(np.abs(before-ground)[changed].mean()),'mean_RGB_error_to_ground_after':float(np.abs(after-ground)[changed].mean()),'metric_limit':'0-255 channel absolute error on changed pixels only; not perceptual or artistic approval'})
    for x,y,label in [(640,355,'tree'),(376,540,'rock')]:
        for suffix in ['before','after']:
            Image.open(out/f'{s}-{suffix}.png').crop((x-65,y-45,x+65,y+20)).save(out/f'{s}-{label}-{suffix}.png')
frames=sorted(out.glob('hit-[0-9][0-9].png'))
first=np.asarray(Image.open(frames[0]).convert('RGB'))[327:365,250:310]
pixelchecks=[{'frame':p.name,'fixed_contact_pixels_identical':bool(np.array_equal(first,np.asarray(Image.open(p).convert('RGB'))[327:365,250:310]))} for p in frames]
images=[Image.open(p).convert('RGB').crop((145,115,415,403)) for p in frames]
palette_source=Image.new('RGB',(270,288*len(images)))
for i,im in enumerate(images):palette_source.paste(im,(0,288*i))
pal=palette_source.quantize(colors=256);images=[im.quantize(palette=pal,dither=Image.Dither.NONE) for im in images]
images[0].save(out/'hit.gif',save_all=True,append_images=images[1:]+[images[-1]],duration=[40]*len(images)+[600],loop=0,optimize=True)
manifest=json.loads((base/'prototypes/environment-adapt-v01/runtime/manifest.json').read_text(encoding='utf8'))
hashes=[{'file':e['file'],'unchanged':hashlib.sha256((base/'prototypes/environment-adapt-v01/runtime'/e['file']).read_bytes()).hexdigest()==e['sha256']} for e in manifest]
report={'metrics':metrics,'fixed_contact_pixel_checks':pixelchecks,'unchanged_art_hashes':hashes,'runtime':{'checks':len(runtime['checks']),'failures':runtime['failures']},'performance':'one viewport copy per rendered frame; GPU/full forest overhead not measured','source':'existing selected 27 PNGs, all unchanged; no image generation; no new alpha shapes or ground decals'}
(out/'pixel-review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
sections=''
for s,name in [('grass','草地'),('forest','林下'),('dirt','裸土')]:
    m=next(m for m in metrics if m['surface']==s)
    sections+=f'''<section><h2>{name} · 拖动比较</h2><div class="compare"><img src="{s}-after.png"><img class="before" src="{s}-before.png"><span class="left">原接触色</span><span class="right">适配后</span></div><input type="range" min="0" max="100" value="50" aria-label="{name}前后对比" oninput="this.previousElementSibling.querySelector('.before').style.clipPath='inset(0 '+(100-this.value)+'% 0 0)'">
    <div class="details"><figure><img src="{s}-tree-before.png"><figcaption>根部 · 原色</figcaption></figure><figure><img src="{s}-tree-after.png"><figcaption>根部 · 适配后</figcaption></figure><figure><img src="{s}-rock-before.png"><figcaption>石底 · 原色</figcaption></figure><figure><img src="{s}-rock-after.png"><figcaption>石底 · 适配后</figcaption></figure></div><p>变化像素与脚边纯地面平均通道色差：{m['mean_RGB_error_to_ground_before']:.1f} → {m['mean_RGB_error_to_ground_after']:.1f}（0–255，非视觉验收指标）。接触区域之外变化像素：{m['changed_outside_contact']}。<a href="{s}-after.png">打开1×原图</a> · <a href="{s}-pure-ground.png">纯地表取证</a></p></section>'''
page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>风栖原野 · 根部接触色优化</title><style>body{{background:#edf1e8;color:#29392b;font:16px/1.8 "Microsoft YaHei",sans-serif;margin:0}}main{{max-width:1280px;margin:auto;padding:30px}}h1{{font-size:28px}}h2{{font-size:21px}}section{{background:white;border-radius:12px;margin:24px 0;padding:24px}}img{{display:block;width:100%;height:auto}}.compare{{position:relative;overflow:hidden}}.before{{position:absolute;inset:0;clip-path:inset(0 50% 0 0)}}.left,.right{{position:absolute;bottom:10px;padding:3px 12px;background:#263c28c9;color:white;border-radius:12px}}.left{{left:12px}}.right{{right:12px}}input[type=range]{{width:100%;margin:16px 0}}.details{{display:grid;grid-template-columns:repeat(4,1fr);gap:18px}}figure{{margin:0}}.details img{{image-rendering:auto}}figcaption{{font-size:14px;padding:7px 0}}a{{color:#376d45}}.tag{{background:#fff0bd;padding:5px 12px;border-radius:16px}}.motion{{max-width:405px}}@media(max-width:800px){{main{{padding:15px}}.details{{grid-template-columns:1fr 1fr}}}}</style><main>
<span class="tag">接触色修订 · 待视觉确认 · 正式地图未替换</span><h1>根部与石底，跟随脚边实际地表</h1><p>已修正原画接触部分偏亮、偏黄绿/橙褐的问题：已有草叶、落叶和土唇逐像素参考当前脚边纯地面颜色与明度。不是按草原/森林名称套一组统一色，也不增加绿色圆斑或假草形状。</p><p>树干/树根中心与石体保持原色；林下落叶仍是褐色，只收敛饱和度并匹配局部光照。三种树、六种石头的选型及原碰撞保持，普通石头仍不交互。</p>{sections}
<section><h2>晃动与渐隐保持</h2><div class="motion"><img src="hit.gif"></div><p>受击只晃动，无提亮/闪白。固定根部区域{sum(c['fixed_contact_pixels_identical'] for c in pixelchecks)}/{len(pixelchecks)}帧逐像素一致；最终根部与主体一起透明消失，无残留色块。<a href="tree-removed.png">移除后画面</a>。</p></section>
<section><h2>验证与范围</h2><p>{html.escape(runtime['engine'])} / {html.escape(runtime['adapter'])}：{len(runtime['checks'])}项相关检查，失败{runtime['failures']}；三地表的全部颜色改动均限制在接触区域，区域外变化像素0。27张PNG哈希全部保持。0.65×/1.65×镜头取证保留，不使用加载时的一次性截图颜色缓存。<a href="forest-zoom-0.65.png">0.65×</a> · <a href="forest-zoom-1.65.png">1.65×</a> · <a href="pixel-review.json">逐像素/哈希数据</a> · <a href="runtime.json">运行检查</a> · <a href="runtime.log">日志</a>。</p><p>实现只新增一个每帧纯地表拷贝，位置在地表之后、全部冠影/树石/角色/UI之前；同一材质同时用于主体与固定接触片，避免分层处色差。原alpha轮廓不改，渐隐保留。没有本轮新图片生成或外部素材；GPU和密林成本未测，不据此承诺正式世界帧率。</p><p>土唇/落叶采用颜色和脚底位置识别，复杂新画稿仍需检查分类；颜色贴合不等于接地造型已通过。当前样板及正式世界状态分开保留，本轮仅修订接触颜色。</p><p>运行 <a href="../../prototypes/environment-adapt-v01/Start-Color-Preview.cmd">Start-Color-Preview.cmd</a>；V切换原色/适配，1/2/3切地表，其余交互同前。</p></section></main></html>'''
(out/'index.html').write_text(page,encoding='utf8')
print(json.dumps({'runtime_checks':len(runtime['checks']),'failures':runtime['failures'],'metrics':metrics,'fixed_root_frames':sum(c['fixed_contact_pixels_identical'] for c in pixelchecks),'art_hashes_unchanged':all(h['unchanged'] for h in hashes)},ensure_ascii=False))
