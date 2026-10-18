# 身体系统 V1 与五项先行调整

## 已正式接入

五项调整均已落入正式入口；身体状态、食物、体力行动限制、可逆疾病、单人照料、连续局部体型、左下HUD/详情、原子存档均已接入。完整参数和恢复规则见 [BODY_SYSTEM.md](../../BODY_SYSTEM.md)。正式角色实际是 Godot 原生部件动画，没有 Spine。

## 文件职责

- 新增 `data/body_rules.json`、`scripts/body_rules.gd`、`body_state.gd`：配置和唯一身体模型。
- 新增 `scripts/body_shape.gd`：头部显示 Sprite 与衣身 Sprite 的绝对局部宽度。
- 新增 `scripts/body_ui.gd`：身体HUD、详情输入拦截、提灯图标燃时条。
- 修改 `player.gd`：体力/休养限制和动画后局部体型；`world_interaction.gd`：动作入口验证、去采集数字提示；`chunk_stream.gd`：有效砍树结算耗力。
- 修改 `item_service.gd`：共享身体、每盏灯身份和燃时、成功采掘耗力、存档兼容/保护、去中途进度通知；`item_inventory.gd`：食用实际收益、每盏灯字段保留；`field_lantern.gd`：当前灯移出自动关闭。
- 修改 `environment_view.gd` / `world_environment.gd`：同源身体时钟、灯燃时、260半径、更深夜色；`environment_dial.gd`：四方数字。
- 修改 `item_ui.gd`：去快捷栏叶饰、灯右键文字、身体面板输入联动、正面预览同步体型；`data/items.json`：四食物实际效果、灯说明。
- 新增三图 `assets/ui/body_v1`、受控源 `art/body-v1`、整理工具 `tools/package_body_ui.py`、三份专项测试。
- 更新 DEVLOG、AGENTS、UI_ART、ITEM_SYSTEM、WORLD_ENVIRONMENT、CHARACTER_MODULAR_RULES 和 BODY_SYSTEM。

## 实际运行结果

Godot 4.7.2 Stable，Windows Compatibility，真实窗口 NVIDIA RTX5060。

| 专项 | 已运行结果 | 范围 |
|---|---:|---|
| 身体专项无头原生运行 | 533项通过 | 初值/疾病/恢复/食用、真实奔跑、权威采掘耗力、暂停与预览、体型/持握、UI输入、三尺寸、旧档 |
| 同一专项真实窗口 | 533项通过 | GPU实际绘制，循环四向/左右镜像及动作相位，三种工具走跑与握点检查，截图 |
| 身体边界专项 | 19项通过 | 灯丢弃拾取燃时、砍树耗力、状态详情尺寸、非法燃时与隐藏采集数字 |
| 原制作工具实用依赖 | 16项通过 | 原生E砍树、完整开矿和挖掘、制作工具与拾取 |
| 原制作计时依赖 | 37项通过 | 进度/批量原子提交/取消/输入 |
| 原目标提示时序 | 9项通过 | 原2秒、不随进度/面板重新计时 |
| 独立进程写/读 | 1+8项通过 | 属性/体型/疾病计时/灯燃时/装备快捷引用/采集记录及未来版本源档保护 |

同一专项窗口与无头不是不同功能数量，不将1066次断言说成1066项独立功能。完整机器结果 `headless-checks.json`、`window-checks.json`，日志同目录；跨进程 `persistence-write/read.json`。

第一轮 `reports/body-v1-first.log` 保留1项失败：连续推进25秒模拟奔跑时，测试错误地要求在耗尽后已经发生恢复的时间点仍恰好为零；夹具改为20秒耗尽时点，再单独验证恢复。后续未隐去首次失败。没有把静态扫描当实际运行通过。

原生动画实际经过 AnimationPlayer seek 的多个播放相位并提交渲染帧，覆盖正常/胖/瘦、四向、呼吸/砍伐/开矿/挖掘；另三工具逐一装备，播放四向walk/run多个相位，验证局部体型不改变Grip世界坐标。不是只比较静态人物图。窗口截图使用测试夹具调用原接口，不冒充人工桌面鼠标试玩；没有逐像素穷举全部衣服（当前无已注册新服装）。

## 实景

- [身体HUD 1280](hud-1280.png)、[960](hud-960.png)、[1600](hud-1600.png)
- [详情](details.png)
- [夜晚不开灯](night-off.png)、[夜晚开灯](night-on.png)
- [偏瘦](shape--1.0.png)、[正常](shape-0.0.png)、[偏胖](shape-1.0.png)
- [石镐动作](stone_pickaxe-motion.png)、[铲子动作](simple_shovel-motion.png)、[石斧动作](stone_axe-motion.png)

已检查真实窗口图，文字区清洁，三尺寸身体HUD/灯条不与快捷栏重叠；夜晚与灯的差别明显，工具和头身关节在抽查相位保持。主观美术与长期轻压力平衡仍需用户试玩。

## 美术来源与QA

`generate2dsprite → route_media.py → local:codex-cli` 真实生成，返回model为codex-image_gen，底层精确模型/实际费用未暴露；estimateUsd=0是订阅通道估算。源图、prompt、job、哈希与裁片见 `art/body-v1` / `assets/ui/body_v1/provenance.json`。每个图标完整位于自己的三分之一区域，整轮廓色键、等比缩小、96画布留透明安全边；无代码绘制或新角色图。

WARN source_size_mismatch: value=2172x724, requested=1536x1024; file=art/body-v1/candidate-01/generated.png。依实际尺寸完整归属整理，未裁断。环境诊断还报告默认python别名、scipy缺失（可用numpy整理）、GBK编码、非ASCII路径；缺resvg/ffmpeg及未配置视频/API键不影响此次PNG流程。详见doctor.json，不声称诊断全部通过。

## 尚未验证或未实现

- 未做数小时连续人工饮食/体型平衡试玩、全地图压力/FPS测试或全部未来装备兼容；本轮无实测性能基准。
- 没有 Spine 运行时、多人/队友救援，因此这些不存在的路径未实现、未验证。实际有自动单人照料。
- 没有新增倒地动画、药物、灯燃料补充、战斗、死亡掉落、烹饪、种植、NPC等；灯耗尽可制作另一盏，旧灯不自动补满。
- 本轮主观图标风格和胖瘦幅度待用户复查；未声称用户已验收。

