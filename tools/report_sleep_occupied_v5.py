from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
report=Path('reports/sleep-occupied-v5')
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
small=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',17)
card=Image.new('RGB',(1060,750),'#eee5cf');d=ImageDraw.Draw(card)
d.text((24,14),'睡眠效果预览 · 立体被面 + 当前角色头部',font=font,fill='#58442d')
entries=[('wood_bed-horizontal','横床 · 原橙色被子',0,0),('straw_mat-horizontal','横草席 · 米白被子',1,0),('sleeping_bag-horizontal','睡袋 · 固定占用造型',2,0),('wood_bed-vertical','竖床 · 弧形领口',0,1),('straw_mat-vertical','竖草席 · 同枕头色',1,1)]
for name,label,col,row in entries:
    shot=Image.open(report/(name+'-detail.png')).convert('RGB')
    box=(480,205,800,425) if 'horizontal' in name else (480,105,800,405)
    crop=shot.crop(box)
    x=20+col*350;y=62+row*345
    card.paste(crop,(x,y+32))
    d.text((x,y),label,font=small,fill='#58442d')
d.text((724,495),'被子遮住颈部以下',font=small,fill='#58442d')
d.text((724,535),'头部复用角色外观',font=small,fill='#58442d')
d.text((724,575),'被面轻微呼吸起伏',font=small,fill='#58442d')
d.text((724,615),'E 入睡 · 任意键醒来',font=small,fill='#58442d')
card.save(report/'comparison.png')
checks=json.loads((report/'window-checks.json').read_text(encoding='utf8'))
assert len(checks)==125 and all(c['pass'] for c in checks)
(report/'REPORT.md').write_text('''# 睡眠占用造型 V5 候选

用户最新要求：被子要能看出盖着身体，轮廓和颈部开口为自然弧线；床被保留原橙色，草席另画与枕头同色的米白被，睡袋使用固定占用造型。此前完整人物睡姿 V3 和矩形截取被面 V4 均被否定，不能把旧数值检查当作视觉批准。

五张新画稿经 generate2dsprite → route_media → Codex (local CLI) 实际生成；横向三件、竖向两件，软抠及结构 QA 均 pass。完整原图、提示词、回执、裁片、等比注册和 SHA 见 art/sleep-occupied-v5 与 prototypes/sleep-occupied-v5/provenance.json。床被橙色、席被米白、袋为鼠尾草绿；颜色按对应参考生成，非逐像素色值一致承诺。

仅在隔离候选试玩使用。占用画稿没有角色头、皮肤或衣服；运行时读取原侧视头部子树及头部附加层，横向头部朝上，颈部以下不显示角色部件。只让布料胸腹区域轻微连续形变，头部和世界锚点固定。醒来同帧恢复原设施画面和站立人物；袋实例按原已提交 IN_USE 生命周期移除。没有新增换装系统，未来各头部仍须提供侧视及闭眼坐标配置。

Godot 4.7.2 原生窗口最终125项、0失败。覆盖五种设施/方向、三窗口尺寸、完整占用画稿无矩形裁切、当前头纹理、朝向、被面呼吸与固定头锚点、即时入睡/任意新按键唤醒、睡袋清除/床席复用、正常时间/暂停、建造R及徒手/工具台配方分离。测试使用隔离 fixture，不读写玩家存档。首轮暴露玩家父节点并非世界节点，已改为显式传入原建筑管理器；失败日志保留，最终窗口日志无脚本错误。之前的125项通过后，为头部尺寸与睡眠阴影改动重复了最终专项，未扩大为全量回归。

未做长期人工试玩、大营地FPS、完整未来换装兼容测试；新美术仍 pending_user，未迁入正式 assets 或开放正式新配方。预览入口 Start-Sleep-Facilities-Preview.cmd。
''',encoding='utf8')
latest='''## 2026-10-18 · 睡眠占用造型 V5（当前候选）

最新用户要求已替代下方历史原生部件睡姿及整身新画人物方案：颈部以下由有身体隆起、自然弧形领口和垂落褶皱的被子完全遮住，只复用当前角色侧视头部子树；横向头部脸朝上，竖向保留侧视闭眼。床被沿原橙色，草席独立米白被与枕头同色，睡袋为绿色固定占用造型。被面局部呼吸，头和根点固定。尚未开发换装系统，未来头部需侧视和闭眼位置配置。

E交互同帧入睡，不弹选项，无躺下/起身过程；任意新按键同帧醒来并消费该输入，睡袋入睡后退出立即移除。床席 R 横竖方向、睡袋工具台独占制作入包、工具台包含徒手配方而徒手不包含工具台配方保持。睡眠采用正常世界流速、渐进恢复，不加速或跳时；旧阶段只兼容校验并安全结束，不重播。

新五张占用画稿位于 prototypes/sleep-occupied-v5/final，generate2dsprite→route_media→Codex(local CLI)，pending_user。Start-Sleep-Facilities-Preview.cmd 使用同Seed独立临时世界，不写玩家存档。正式新图/配方尚未推广；报告 reports/sleep-occupied-v5/REPORT.md，最终原生窗口125项0失败。旧 V1/V3/V4 描述与截图仅为被替代的历史，主观视觉尚待本批确认。

'''
p=Path('SLEEP_SYSTEM.md');old=p.read_text(encoding='utf8');p.write_text('# 睡眠设施与交互\n\n'+latest+'---\n\n# V1 历史实现记录（以下被当前候选覆盖的内容不再生效）\n\n'+old,encoding='utf8')
for name in ['DEVLOG.md','AGENTS.md']:
    p=Path(name);old=p.read_text(encoding='utf8');split=old.find('\n')
    p.write_text(old[:split+1]+'\n'+latest+old[split+1:],encoding='utf8')
print('125 checks passed. Created comparison, report, current specification and changelog.')
