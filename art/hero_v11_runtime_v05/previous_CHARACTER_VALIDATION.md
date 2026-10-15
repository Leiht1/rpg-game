# 已确认整套角色接入验收 · 模板 4

2026-10-15。用户批准整套当前修订接入游戏并略微提速。Godot 4.7.2 Stable，Compatibility OpenGL 3.3 / NVIDIA RTX 3060；地图生成器仍 windrest-0.1.0。

| 项目 | 当前结果 |
| --- | --- |
| 已确认来源 | front/back walk=v04；side walk=v06；front/back/side idle=v05（背面继承 v04）；left 整帧镜像 |
| 实际资源 | 36 张已确认 PNG 原样复制，128×128 RGBA，(64,112)，scale=1、offset=(0,0)；模板 windrest-character-template-4 |
| 呼吸 | 四帧各 450 ms，共 1800 ms；读取 SpriteFrames 相对时长与 speed，不新增图像位移 |
| 移动 | 100→115 px/s（+15%），八方向速度归一化；周期距离仍 200/3 px，实际步频为 13.8 帧/秒 |
| 资源检查 | character-art-tests.json：pass / 0 failures，36 个来源/模板哈希、透明留白、图集及导出文件匹配 |
| 真实游戏短专项 | character-smoke-tests.json：pass / 0 failures；八方向各 12 tick，22.9922～23.0039 px（目标 23）；20 个呼吸边界、八张 walk 全周期、实际位移相位与停步/短呼吸通过 |
| 实际显示 | character-smoke-poses.png：四列 front/back/right/left，两行 inhale / walk 第 5 帧；character-world.png 为当前实际场景。固定姿势采样，不是连续动作录像 |
| 构建/导出 | generate2dsprite：6 clips / 36 frames / warnings=0，原 QA 仍 needs-visual-review；Godot 单图集导出 pass |

本轮仅导入既有已确认图片，art_source=existing，没有新图片/视频生成，也没有重新对齐或绘制。历史 host:image_gen / generate2dmedia adopt 来源、许可边界及模型/费用未知状态继续沿用。

本轮实际短专项约 6 秒；导入日志和短专项日志在 `../art/hero_approved_runtime_v04/`。没有重跑历史 180 次快速切换、树石/湖岸专项、全地图、性能压力测试或工程打包，无本版 FPS / 帧耗时基准。

旧 `player-tests.json`、`character-godot-poses.png`、`character-breathe-godot.gif` 等保留为历史模板 3 证据，不能当作此版完整回归结果。原验收报告及模板 3 完整资源备份在 `../art/hero_approved_runtime_v04/previous_*`；本版接受记录、staging、源帧哈希、未改写的 skill 输出及完整质量边界见同目录 `RESULT.md` / `QC_FINDINGS.md`。

工具原非 pass 项保留：telegraph=skipped（value=null，threshold=28）；loop_seam=needs-visual-review（value=1.533159，threshold=null）。用户已接受素材，不将人工接受改写成自动 QA 通过。细微轮廓、颜色/投影和镜像光照差异保留；不宣称零滑步或图像零漂移，最终手动体验由用户进行。
