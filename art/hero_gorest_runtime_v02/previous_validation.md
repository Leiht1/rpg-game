# V0.1 角色修正专项验收

日期：2026-10-15。运行版本：Godot `4.7.2.stable.official.ed1daf0bf`，Windows，Compatibility OpenGL 3.3 / NVIDIA RTX 3060。模板：`windrest-character-template-1`。

| 用户验收项 | 当前结果与证据 |
| --- | --- |
| front / back / side 正确方向 | 已核对完整帧与实际地图四向姿势；真背视无脸，真侧视有单眼/鼻尖/近远肢体；左向为侧面整帧镜像 |
| idle / walk 循环 | 六动作；每方向 1 idle + 4 个独立 walk，接触/经过两侧交替；真实移动 96 物理 tick 覆盖全部行走帧；导出 loop=true |
| 快速切向及停步 | player-tests.json pass，180 次转向/停步；正确动画、左镜像、相位保留与对应朝向 idle |
| 脚底原点一致 | 全帧 128×128、(64,112)；运行时 offset=(0,-48)，180 次切向原点保持；模板与最终帧 SHA256 匹配；不把动作中的鞋底像素当作固定原点 |
| Godot 正常运行 | 最终导入无脚本/纹理错误；实际 GPU 场景渲染成功，character-import-final.log / character-render.log |
| 地图探索可用 | 8 方向每 30 tick 约 40 px、斜向归一化、WASD、树石碰撞、湖岸阻挡和必要相机依赖通过 |
| 模块规则文档 | 根目录 CHARACTER_MODULAR_RULES.md 已创建，副本随 modular_plan 保存 |
| 未来模板保留 | template.json 固定身份、方向、15 张帧、哈希、相位/时序、原点和源帧注册；pose-templates.png 可对照重绘；先补全身体再逐帧绘制衣物 |

## 图像与运行证据

- `character-art-tests.json`：六动作、15 张不同完整 PNG、画布/透明边界、统一尺度/注册与模板哈希 pass。身高 CV front=0.00848、back=0.01245、side=0.00695；该指标不等于解剖质量。
- `player-tests.json` / `character-player.log`：pass，0 failures；8 向移动距离 39.99～40.02 px/30 tick，180 次转向与停步。
- `character-godot-poses.png`：Godot 实际地图渲染，四行 front/back/right/left，五列 idle/walk00/walk01/walk02/walk03。这里固定位置展示姿势，实际物理播放由上项独立测试证明。
- `character-world.png`：主角在现有原野中的实际画面。
- `../assets/hero/reference/animation-preview.webp`：四列 front/back/right/left，上排 idle、下排 walk 的循环预览；只是预览文件，游戏直接读取 PNG 图集。
- `../art/hero_rebuild_v01/engine/engine-export.json`：pass，六动作/15 帧 530×530 图集 RGBA 回读匹配。实际导入/运行证据独立保留。

## QA 状态和质量边界

原始候选的 boundary_band、safe_frame、faint_specks WARN 没有隐去；完整 id/value/threshold/files 见 `../art/hero_rebuild_v01/QC_FINDINGS.md`。最终透明处理与导出为 pass，循环工具保留 needs-visual-review。帧间/循环数值只能发现症状，本轮另外核对了完整姿态、方向和实际地图渲染，未将数字检查等同于零滑步认证。

当前是可运行的 V0.1 四关键姿势版本：待机为单帧，无呼吸/眨眼；行走节拍与轻微轮廓变化仍可见；左向光照随镜像翻转。完整帧不是已完成的裸体基体或衣物模块。更密集动作、待机微动作和正式换装留待后续单独任务，本轮不开展。

只验证本轮角色与必要依赖，没有重跑地图生成全量回归、压力测试或重新打包旧压缩包。旧性能报告和 dist 文件不能代表本次角色版本。地图生成器仍为 windrest-0.1.0。
