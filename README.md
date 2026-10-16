> 已接入统一斜俯视树石与湖岸 V0.2，搭配多区域节点世界 V0.5；双击 Start-Playtest.cmd 体验。当前已验收的角色、树石与湖岸资源随正式项目提交。

> 当前正式版：多区域节点世界 V0.5。双击 **Start-Playtest.cmd** 游玩；**N** 新世界，正常重启沿用保存的 Seed；WASD / Shift / E / M 保持。当前生成器 `windrest-biome-0.5.0`，详见 MAP_SYSTEM.md。当前验收数据见 reports/world-v05/generation.json 和 runtime.json；截图比较页保留在本地。以下旧版本记录保留追溯。

> 当前场景美术（2026-10-16）：已确认的自然绿轻手绘 V0.7 正式接入。双击 **Start-Playtest.cmd** 游玩；WASD移动、Shift奔跑、E砍树/拾取、M地图。树石、地表和低密度花叶使用 `assets/environment/stylized_v3`，无踏草反馈。主角及玩法保持。专项结果见 `reports/scene-v3-integration-tests.json`，实际出生点画面见 `reports/scene-v3-after.png`。历史预览与下文旧版本记录仅供追溯。

# 风栖原野 · 简化卡通场景体验版
2026-10-16 · Godot 4.7.2 Stable · Windows PC。

## 启动
双击项目根目录 Start-Playtest.cmd，使用本机已有 Godot 4.7.2 启动当前游戏；或在 Godot 导入 project.godot 后 F5。无需 Python、图片服务或 API key。启动入口不是独立打包 EXE，依赖本机已有引擎。

- WASD / 方向键：正常移动 200 px/s。
- 按住 Shift：奔跑 310 px/s；松开恢复行走，无体力系统。
- E：靠近树干左右侧，看到提示后砍树；两次完整挥砍掉落一份木材。靠近木材按 E 拾取。动作期间暂时停步，结束恢复移动。
- 滚轮缩放；F3 查看当前运行指标。

出生点附近布置五棵树、三块石头、稀疏草花和一份测试木材，中央留空用于走跑；外围仍是原有 Seed 大地图与区块加载，不是孤立截图。只做基础砍树掉落/拾取反馈，没有背包、存档或新成长系统。重启场景恢复树和掉落。

## 当前正式方向
已确认的大头短腿白T短裤主角，六个原生部件支点、九张方向图片、15条 AnimationPlayer 动画：正/背/侧 breathe、walk、run、chop、pickup；左侧镜像。行走奔跑共享碰撞后位移相位，每128px一个周期，常速约.64秒，跑速约.413秒；不因按键重置步态。砍树/拾取回用已确认关键帧，不新增人物序列帧。
环境已切换 assets/environment/cartoon_v2：两款圆冠树、两款圆石、小草/草花、木材、新斧头；草地配色和低对比地表笔刷同步更新。旧环境与完整帧资源保留归档，当前加载不再使用它们。实验中禁止正式使用的斧/树/果实未迁入。
树干和石底为六点凸多边形碰撞，树冠不挡路，遮住主角时淡化。木材无物理阻挡，42px内且路径无遮挡才可主动拾取；砍树目标62px内且位于侧向，避免纵深动作对位错误。树砍倒后移除碰撞，当前运行中区块重载也不会复活。

## 地图复现
默认 Seed 271828，1024×1024格，48px/格、24×24格/区块。相同引擎、Seed、尺寸和生成器 windrest-0.1.1-cartoon 复现相同布局。该版升级反映出生点体验区、装饰密度及地表配色调整；河湖生成与基本区块机制保留。
命令行可使用 -- --seed=42 --size=1024。

## 验证与已知边界
本轮实际 Godot 窗口 / Compatibility / RTX3060：tests/test_scene_cartoon.gd 56项检查、0失败，见 reports/scene-cartoon-tests.json。范围包括走跑/Shift、步态、树干与树冠、石底碰撞、砍树命中只执行一次、掉落拾取、倒树后通行、边界和出生区同Seed复现；实际截图见 reports/scene-cartoon-v2.png、scene-cartoon-chop.png、scene-cartoon-pickup.png。
最初无窗口测试在第一段手动步进有2项距离时钟误差，实际60FPS窗口检查通过；未把它当作新性能数据。测试未覆盖所有Seed、长时间跨区块压力或所有岸线形状，原有五点脚下地形检测保留。本轮无新性能基准，不沿用旧版帧率承诺。
单段四肢、左右镜像光照、简化挥砍和拾取仍是当前已确认路线的表现边界。两次砍击后树摇动淡出，不包含物理倒树或树桩玩法。视觉统一与主观手感待用户验收。
图片实际路线 local:codex-cli / codex-image_gen，一次生成，无视频；精确底层图片模型与实际费用未公开。原图格线越界及透明雾点已按物件完整轮廓整理，不按格线硬切；整理后仍有 safe_frame 警告，见 art/scene_cartoon_v2/QA.md，不声明全部美术QC通过。

## 规范与追溯
ART_STYLE.md、CHARACTER_SEQUENCE_WORKFLOW.md、CHARACTER_MODULAR_RULES.md 为当前规范；AGENTS.md 已同步。旧 Gorest、完整帧模板和 prototypes 保留历史记录，不是正式生产默认路线。
art/scene_cartoon_v2 包含提示词、生成回执、来源、完整源图、裁片坐标与哈希、QA、原生动作整理源；assets/hero/cartoon 为当前玩家，assets/environment/cartoon_v2 为当前景物。DEVLOG.md 记录本轮范围。

相关检查：
```
Godot --path . --max-fps 60 --script tests/test_scene_cartoon.gd
Godot --path . --max-fps 60 --script tests/capture_scene_cartoon.gd
```
旧 tests/test_cartoon_player.gd 断言旧六条动画，仅作上次接入历史验证；tests/test_player.gd 等 SpriteFrames 检查也不是当前接口。本轮使用上面的新检查，不默认全量回归。完成后停止等待验收。

## V0.3 当前运行

双击 Start-Playtest.cmd；依赖本机已有 Godot 4.7.2，不是独立免安装EXE。WASD移动、Shift奔跑、E砍树/拾取、M地图、Esc关闭地图；地图可滚轮缩放及左键拖动。当前地表/地图/动作说明见 MAP_SYSTEM.md。专项检查：tests/test_v03.gd；保留原移动/碰撞依赖检查报告 reports/v03-regression.json。

实景：reports/v03-after.png、v03-forest.png、v03-mountain.png、v03-shore.png；前版同位置：v03-before.png。连续砍树与拾取预览：v03-continuous-chop.gif、v03-pickup.gif。美术来源与原图警告：art/ground_v03/QA.md。


当前地面候选预览：双击 Start-Ground-Preview.cmd，1旧版/2A/3B，0出生点、4森林/5山地/6水岸。WASD、Shift、E、M沿用；Start-Playtest.cmd仍为旧地面正式体验。候选生产门槛见 SCENE_ART_WORKFLOW.md，未选定不全图推广。

