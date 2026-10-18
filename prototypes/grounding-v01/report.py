"""Package existing framebuffer captures; does not generate or edit game art."""
from pathlib import Path
import hashlib,json
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[2]
out=root/'reports/grounding-v01'
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',20)
items=[('tree','树根近景',(400,120,880,610)),('rock','石头近景',(470,260,810,500)),('mixed','树石混合场景',None),('normal','正常游戏视角 · 1×',None)]
sections=[]
for key,title,crop in items:
    imgs=[]
    for state,label in [('before','修改前'),('after','接地候选 · 待确认')]:
        img=Image.open(out/f'{key}-{state}.png').convert('RGB')
        if crop:img=img.crop(crop)
        else:img=img.resize((768,432),Image.Resampling.LANCZOS)
        panel=Image.new('RGB',(img.width,img.height+42),'#f4f3e9')
        panel.paste(img,(0,42));ImageDraw.Draw(panel).text((12,8),label,font=font,fill='#25382c')
        imgs.append(panel)
    pair=Image.new('RGB',(imgs[0].width*2,imgs[0].height),'white')
    pair.paste(imgs[0],(0,0));pair.paste(imgs[1],(imgs[0].width,0));pair.save(out/f'{key}-comparison.png')
    sections.append(f'''<section><h2>{title}</h2><p>同 Seed、同位置、同机位。左右拖动分界线；下方可查看并排图。</p><div class="compare"><img src="{key}-before.png"><img class="after" src="{key}-after.png"><span class="line"></span></div><input aria-label="前后比较分界" type="range" min="0" max="100" value="50" oninput="this.previousElementSibling.style.setProperty('--cut',this.value+'%')"><div class="labels"><span>左：修改前</span><span>右：候选</span></div><details><summary>并排对比</summary><img class="pair" src="{key}-comparison.png"></details></section>''')
data=json.loads((out/'runtime.json').read_text(encoding='utf-8'))
revisions=[]
for key,title,crop in items[:2]:
    panels=[]
    for path,label in [(out/'revision-01'/f'{key}-after.png','上一版候选'),(out/f'{key}-after.png','本次：更多遮挡 · 取脚边地表色')]:
        img=Image.open(path).convert('RGB').crop(crop)
        panel=Image.new('RGB',(img.width,img.height+42),'#f4f3e9');panel.paste(img,(0,42))
        ImageDraw.Draw(panel).text((10,8),label,font=font,fill='#25382c');panels.append(panel)
    pair=Image.new('RGB',(panels[0].width*2,panels[0].height),'white')
    for i,panel in enumerate(panels):pair.paste(panel,(i*panel.width,0))
    pair.save(out/f'{key}-revision-comparison.png')
    revisions.append(f'<section><h2>{title} · 本次调整</h2><img class="pair" src="{key}-revision-comparison.png"></section>')
sections=revisions+sections
sources={str(p.relative_to(root)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in (root/'assets/environment/view_v01').glob('*.png')}
(out/'provenance.json').write_text(json.dumps({'art_source':'existing','route':'none: approved assets reused; Godot procedural rendering explicitly requested','generation_calls':0,'source_sha256':sources,'derived_images':'Godot framebuffer screenshots, crops and side-by-side comparisons only','status':'pending_user'},ensure_ascii=False,indent=2),encoding='utf-8')
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>风栖原野 · 接地融合阶段 A</title><style>body{margin:0;background:#e9eee4;color:#263b2c;font:16px/1.7 "Microsoft YaHei",sans-serif}main{max-width:1200px;margin:auto;padding:32px}h1{font-size:28px}section{background:#fffdf7;border-radius:16px;padding:22px;margin:26px 0}.compare{position:relative;--cut:50%;line-height:0}.compare img{width:100%}.compare .after{position:absolute;inset:0;clip-path:inset(0 0 0 var(--cut))}.line{position:absolute;left:var(--cut);top:0;bottom:0;width:2px;background:#fff}input{width:100%;accent-color:#57794a}.labels{display:flex;justify-content:space-between}.pair{width:100%}p{max-width:1050px}summary{cursor:pointer}</style><main><h1>树木与石头接地融合 · 阶段 A 候选</h1><p>仅处理当前真实 V0.6 场景中的四个对象（两种树、两种石头），未推广正式世界。Seed 447349832。原图、地图分布、角色动作和碰撞保持；全部截图来自 Godot 4.7.2 实际渲染。</p><p>主要问题：原单层多边形阴影边缘明显、位置按通用宽度计算，未追随实际树根/石底；缺少局部底缘遮挡；地面高对比纹理与主体争抢。现有岩石具备顶面及前侧厚度，本轮未重画。</p><p>候选：按 PNG 实际底缘生成渐隐接触带；树冠低对比短影单独位于地面层；不规则、轻微的环境色过渡和少量局部底缘覆盖；仅对象附近约 100 世界单位内弱化纹理。没有增加花草密度，也没有统一深色圆盘。</p>'''+''.join(sections)+f'''<section><h2>验证边界</h2><p>{len(data['checks'])} 项专项检查，失败 {sum(not x['pass'] for x in data['checks'])}。原点/碰撞保持，实际区块卸载并用新工作器数据重建后，坐标、接地采样、Seed 参数一致。共享地面采样采用世界坐标，不按区块裁切。尚未完成多 Seed、多生态实景或全世界密度下性能验收；不据此声称阶段 B 通过。</p><p>候选存在取舍：底缘覆盖是少量简化程序形状；近景放大仍可看出原 PNG 的显示精度。局部纹理弱化在正常视角较克制，是否足够减少贴图感需用户视觉判断。阶段 A 完成即停止。</p><a href="runtime.json">专项记录</a> · <a href="provenance.json">素材来源与哈希</a></section></main></html>'''
html=html.replace('阶段 A 候选</h1>','阶段 A · 第二版候选</h1><p>本次根据反馈稍增底缘遮挡：树3处、石4处，宽约4–6世界单位、高约2.5–5.1世界单位，保留间隙。遮挡每个顶点直接取脚边实际地表渲染颜色（纯地面离屏采样，排除树石/阴影/UI），不再用生态预设色统一染底。上一版已归档。</p>')
(out/'index.html').write_text(html,encoding='utf-8')
print(json.dumps({'checks':len(data['checks']),'failures':sum(not x['pass'] for x in data['checks']),'objects':len(data['objects']),'max_install_ms':data['max_install_ms']},ensure_ascii=False))
