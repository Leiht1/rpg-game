from pathlib import Path
import json
checks=json.loads(Path('reports/sleep-fit-v10/checks.json').read_text(encoding='utf8'));assert len(checks)==185 and all(c['pass'] for c in checks)
entry='''## 2026-10-18 · 睡眠放置、稳定头部与原尺寸适配 V10

修复睡眠设施每个占地采样点额外40单位距离排斥导致的围墙内误判：已有建筑按真实碰撞检查，资源保留设施矩形与必要近距保护，真实重叠仍拒绝。头部不再乘0.64缩小，恢复原角色侧视头纹理的实际比例；床、草席、睡袋的空闲图、占用图、建造预览及物理占地同步按1/0.64等比适配，数据来源data/sleep_rules.json。已放实例不移动、成本/ID/存档格式不改，旧实例加载也采用当前尺寸。

睡眠头部体型连续变化曾令显示子树按微小scale差异反复销毁重建，现外观指纹不包含姿势/体型变换，体型宽度在原显示节点就地同步；固定睡眠显示分支关闭物理插值，避免渲染/物理更新时间混合。角色醒来仍走原姿势，无新美术或PNG修改。

Godot4.7.2默认1280×720原生窗口185项0失败，其中150条是五设施方向各30个真实物理/渲染步的头节点身份、位置及可见性稳定断言；其余为紧围墙净空允许、实际墙重叠拒绝、放置/入睡/原头尺寸/醒来验证。初轮测试发现scale变化触发的节点重建并修正；测试墙替身的交互回调干扰也已隔离，最终window-clean.log无脚本错误，历史失败日志保留。测试隔离不读写玩家档，不重复全量或多分辨率检查。报告reports/sleep-fit-v10/REPORT.md。

'''
p=Path('DEVLOG.md');s=p.read_text(encoding='utf8');at=s.find('\n');p.write_text(s[:at+1]+'\n'+entry+s[at+1:],encoding='utf8')
p=Path('SLEEP_SYSTEM.md');s=p.read_text(encoding='utf8');at=s.find('\n');p.write_text(s[:at+1]+'\n'+'''## 当前适配修订 V10

设施显示尺度及占地以 `data/sleep_rules.json` 为准。头部保留原角色侧视尺寸，不再缩为64%；设施空闲、占用及建造预览同步等比适配，旧实例不移动，沿用原存档格式。睡眠显示分支无物理插值；外观指纹不包含姿势/连续体型尺度，体型宽度原节点同步，避免重复重建闪动。睡眠设施邻近建筑只按真实碰撞判断，资源保留矩形近距保护；真实占地重叠仍拒绝。验证范围及历史失败说明见 [V10报告](reports/sleep-fit-v10/REPORT.md)。

'''+s[at+1:],encoding='utf8')
p=Path('PROJECT_STATUS.md');s=p.read_text(encoding='utf8')
a=s.index('- 当前待确认事项是睡眠占用造型');b=s.index('\n',a);s=s[:a]+'- 睡眠设施V9已获用户授权正式接入；本轮V10修复围墙内放置误判、头部闪动，并按原头部大小同步适配设施。当前规则见 [睡眠规范](SLEEP_SYSTEM.md)，定向验证见 [V10报告](reports/sleep-fit-v10/REPORT.md)。'+s[b:]
s=s.replace('- V5睡眠画稿仍待用户本批具体视觉确认；数值QA及历史测试通过不等于美术批准。','- 当前睡眠画稿已正式采用；本轮未新增画稿，未扩大授权到未来素材。')
s=s.replace('等待用户确认睡眠V5候选或提出修订，再只执行获授权范围内的接入或修改。当前未授权新的玩法阶段；本次仅建立文档读取机制，不推进游戏开发。','本轮修复完成，等待用户试玩反馈；不自动进入新的玩法阶段。')
p.write_text(s,encoding='utf8')
Path('reports/sleep-fit-v10/REPORT.md').write_text('# 睡眠设施适配 V10\n\n'+entry,encoding='utf8')
print('185 checks, zero failures; scoped documentation and project status updated.')
