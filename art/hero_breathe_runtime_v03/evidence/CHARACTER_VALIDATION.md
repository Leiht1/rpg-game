# V0.1 已确认呼吸 v02 接入验收

2026-10-15。Godot `4.7.2.stable.official.ed1daf0bf`，Windows，Compatibility OpenGL 3.3 / NVIDIA RTX 3060。当前角色模板 `windrest-character-template-3`，地图生成器仍为 `windrest-0.1.0`。

| 验收项 | 结果与证据 |
| --- | --- |
| 已确认素材 | 用户批准 `art/hero_idle_breathe_preview_v02/`；front/back/right 各四张 128×128 RGBA 原样复制为 front/back/side_idle；左向整帧镜像，不反转时间 |
| 循环与时长 | 每帧 750 ms，四帧 3000 ms；读取 SpriteFrames 相对帧时长，44 个四方向边界采样全部正确 |
| 实际停步呼吸 | 四方向各采样 180 个物理 tick，覆盖全部四帧，各姿势计数 [44,46,45,45]，相邻边界含浮点 / 采样顺序的 ±1 tick；物理位置不变、朝向不变 |
| 走停及转向 | 停步进入朝向对应的呼吸基准帧，移动后切回八帧 walk；180 次快速转向 / 停步检查通过，左向镜像和相位正常 |
| 已有移动 | 24 张 walk PNG 字节不变；速度仍 100 px/s，周期距离仍 200/3 px，八方向 30 tick 实测 49.9805～50.0098 px |
| 根点与显示 | 36 张完整帧共用 128×128 画布、(64,112) 原点；运行时 offset=(0,-48)、scale=(1,1)，呼吸不移动角色节点；不另行修正已知 idle/walk 比例差 |
| 必要依赖 | WASD、树石阻挡后进入 idle、湖岸阻挡、相机缩放 / 平滑及 Y 排序通过；其他脚本、场景和 project.godot 基线哈希不变 |
| Godot 导出 | 794×794 单图集、36 帧、六循环；回读及源帧哈希匹配，导出时长误差最大 0.6667 ms（walk 整数毫秒取整），idle 时长精确 |

## 当前证据

- `character-art-tests.json`：pass，0 failures，36 帧 / 六动作；已确认呼吸源哈希、24 张旧 walk、透明留白、模板哈希及实际发布的引擎文件检查通过。
- `player-tests.json` / `breathe-character-player.log`：pass，0 failures；四方向呼吸、44 个时间边界、180 次走停转向及上述物理依赖。
- `breathe-character-import.log`：Godot 导入成功，无脚本 / 纹理错误。
- `breathe-character-render.log` / `character-godot-poses.png`：实际 GPU 渲染，四行 front/back/right/left，12 列 idle00～03、walk00～07；固定位置采样姿势，真实移动另由物理测试验证。
- `character-breathe-godot.gif` / `.webp`：从上述实际引擎图中截取四帧，按原速 750 ms 拼接的四向预览；不是连续游戏录像，源图哈希与拼接说明见 `../art/hero_breathe_runtime_v03/engine-preview-source.json`。
- `character-world.png`：当前呼吸基准帧在原野中的实际场景截图。
- `../art/hero_breathe_runtime_v03/clips/animation-clips.json`：六循环 / 36 帧、warnings=0；工具原状态 needs-visual-review。
- `../art/hero_breathe_runtime_v03/engine/engine-export.json`：Godot 导出 pass；完整 QA 见同目录上一级 `QC_FINDINGS.md`。

首次以 `--fixed-fps 60` 无节流运行物理测试时，1200 个 process-frame 等待预算在后台地图加载完成前耗尽，触发启动失败及依赖该场景的连锁失败；原日志和失败报告保留于 `../art/hero_breathe_runtime_v03/attempt_fast_start_player*`。改用正常节奏 `--max-fps 60` 后，同一测试通过；没有因此修改地图或游戏加载逻辑。

## 素材质量与验证范围

本次直接使用已确认 v02，没有新图像或视频调用，也未在 Gorest 再次编辑。三套独立呼吸，左向镜像；旧三张静态 idle 和整套模板 2 备份于 `../art/hero_breathe_runtime_v03/previous_runtime/`。

实际引擎逐帧画面未见明显抬脚、点头或整身摆动，保持用户确认的胸肩变化。轻微线条重绘、四关键帧阶段感、较克制的背面幅度、idle/walk 比例差及镜像光照仍保留；物理节点稳定和数值检查不能证明图像零漂移或自然度。循环工具仍为 needs-visual-review（loop_seam 最大 1.099650、threshold=null），未改成自动通过。

本轮只验证呼吸及必要角色依赖，没有重跑全地图回归、性能压力测试或打包；无本轮 FPS / 帧耗时基准，历史性能和旧压缩包不代表此版。完成即停止。
