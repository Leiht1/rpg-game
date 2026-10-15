# v11 侧视行走接入验收 · 模板 5

2026-10-15。用户看过 v11 后批准“接入游戏吧”。实际引擎为 Godot 4.7.2 Stable（ed1daf0bf），Compatibility / OpenGL 3.3 / NVIDIA RTX 5060；地图生成器仍 windrest-0.1.0。

| 项目 | 当前结果 |
| --- | --- |
| 接入范围 | side_walk 八帧=v11 take2，按 v08 原姿势、原顺序；left 整帧镜像 |
| 保留资源 | front/back walk=v04、全部 idle=v05，共 28 张 PNG 与模板 4 字节一致 |
| 画布及原点 | 36 张完整 RGBA PNG 均为 128×128、(64,112)；直接复制已确认帧，scale=1、offset=(0,0) |
| 时间与移动 | 呼吸四帧各 450 ms、共 1.8 秒；速度 115 px/s、周期距离 200/3 px、实际步频 13.8 帧/秒，均保持 |
| 资源专项 | character-art-tests.json：pass，0 failures；源哈希、模板 5、留白、导出文件、28 张保留帧及运行代码/场景/配置哈希核对 |
| 实际游戏短专项 | character-smoke-tests.json：pass，0 failures；八方向各 12 tick 移动 22.9922～23.0039 px，20 个呼吸边界、左右镜像、位移驱动相位、走停切换、完整八帧周期通过 |
| 实际渲染 | character-godot-poses.png：front/back/right/left 四行，各 4 idle + 8 walk，共 48 个固定姿势；character-smoke-poses.png 为四向 inhale / walk 第 5 帧 |
| 构建及导出 | generate2dsprite：6 clips / 36 frames / warnings=0；794×794 单图集，36 帧回读匹配，导出 pass，时长误差最多 0.6667 ms |

接入 art_source=existing，没有新图片或视频生成、重新缩放或姿势修改。v11 原图、提示词、来源/许可、模型及费用未知边界仍在 `../art/hero_v08_pose_redraw_preview_v11/`。模板 4 资源及此前文档、测试结果、截图完整备份至 `../art/hero_v11_runtime_v05/previous_*`。接受记录、staging、未改写的 skill 输出和引擎日志均在同目录。

工具 QA 保持原状态：telegraph=skipped（value=null，threshold=28），loop_seam=needs-visual-review（value=1.533159，threshold=null）。来源的 pose_redraw_variation、anatomical_part_consistency、loop_and_contact 仍 needs-visual-review；用户批准接入不改写自动 QA，不宣称像素相同、零滑步或全部关节角度一致。完整记录见该目录 QC_FINDINGS.md。

本轮短专项约 7 秒，渲染采样约 3 秒；固定姿势表不是连续动作录像。运行脚本、场景、工程配置均未修改；没有重跑历史 180 次切换、树石/湖岸、全地图、性能压力测试或工程打包。`player-tests.json`、`character-breathe-godot.gif` 仍是历史版本证据，无本版 FPS / 帧耗时基准。
