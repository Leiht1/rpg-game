# 呼吸接入 QA 记录

2026-10-15。输入为用户批准的 v02 呼吸及原 24 张 walk；本次无图像 / 视频生成。所有自动 QA 状态保持原输出，不用用户批准覆盖工具状态。

## skill 循环构建

`clips/animation-clips.json`：6 clips / 36 frames，warnings=0，整体 **needs-visual-review**。

| check | status | value | threshold |
| --- | --- | --- | --- |
| png_byte_copy | pass | 36 | null |
| webp_timeline | pass | 6 | null |
| tick_grid | pass | 0.333 ms | null |
| telegraph | skipped | null | 28 |
| near_duplicate_holds | pass | 0 | 0 |
| loop_seam | needs-visual-review | 1.099650 | null |
| manifest_lint | pass | 0 | 0 |

呼吸 wrap_ratio：front=1.099650、back=0.926677、side=0.847831。loop_seam 是像素变化诊断，不是稳定性或自然度认证；没有自动阈值，需看图。已发布构建及引擎 QA 中无 WARN / FAIL，needs-visual-review 如实保留。

## skill Godot 导出

`engine/engine-export.json`：**pass**，794×794 单图集、36 cells、六循环。

| check | status | value | threshold |
| --- | --- | --- | --- |
| godot_spriteframes_roundtrip | pass | animations=6 | null |
| godot_spriteframes_duration_error_ms | pass | 0.6666666666666714 | 1 |
| atlas_max_side_px | pass | 794 | 4096 |
| source_frame_hashes | pass | verified=36 / frames=36 | null |

idle 每帧导出精确 750 ms / 45 tick，循环 3000 ms / 180 tick；walk 保留 5 tick / 帧，整数毫秒表示造成最大 0.6667 ms 误差。

## 游戏专项与实际画面

资源哈希 / 透明边界 / 模板 / 导出回读检查 pass；呼吸 12 张已确认 PNG 和 24 张旧 walk 字节匹配，非玩家游戏脚本、场景及 project.godot 基线哈希不变。Godot 4.7.2 实际导入和 GPU 渲染成功。

正常节奏物理测试 pass / 0 failures。四向每轮 180 tick 覆盖四张呼吸帧，姿势计数均 [44,46,45,45]（相邻边界 ±1 tick），节点位置不变；44 个精确时间边界采样、180 次走停转向、八向原移动速度及必要碰撞检查通过。实际场景姿势采样与拼接预览源哈希均留存。

首次 `--fixed-fps 60` 无节流启动在地图后台加载完成前耗尽 process-frame 等待预算，产生启动失败及连锁失败；原报告 / 日志保留 `attempt_fast_start_player*`。改用 `--max-fps 60` 后相同专项通过，未修改游戏加载逻辑，不能把首次记录描述为通过。

用户已接受 v02。实际引擎图未见明显点头、抬脚或整身晃动，但四帧阶段感、轻微轮廓重绘、背面幅度、idle/walk 比例与镜像光照仍是边界。固定脚底原点 / 节点位置不等于所有可见像素零漂移。无新 FPS 或帧耗时测量，无全量地图回归或工程打包。
