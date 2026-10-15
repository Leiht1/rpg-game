# V0.1 八帧行走接入及移动提速验收

2026-10-15。Godot `4.7.2.stable.official.ed1daf0bf`，Windows，Compatibility OpenGL 3.3 / NVIDIA RTX 3060。当前模板 `windrest-character-template-2`，地图生成器 `windrest-0.1.0`。

| 验收项 | 当前结果与证据 |
| --- | --- |
| 已确认行走资源接入 | front/back/side 各八张完整帧，来自 gorest_side_lowstep_v03；侧面第 3、7 帧为低抬腿版，左向整帧镜像；旧三张中性 idle 原文件保留 |
| 常规移动提速 | 80→100 px/s，+25%；八方向每 30 物理 tick 实测 49.9805～50.0098 px，斜向不加速 |
| 动画推进与切向 | 碰撞后实际位移推进；真实行走覆盖全部八帧；180 次切向 / 停步检查相位保留、方向、镜像与正确朝向 idle，全部通过 |
| 碰撞及必要依赖 | WASD、树 / 石阻挡、受阻后步态停止、湖岸阻挡、相机缩放和平滑、Y 排序检查通过 |
| 画布与脚底原点 | 27 张 128×128 RGBA，原点 (64,112)；全部 walk 同缩放 140/256、同偏移 (-6,7)，无可见裁切；运行时 offset=(0,-48) |
| 实际引擎运行 | Godot 导入 / 角色专项真实物理 / OpenGL 场景渲染成功，相关日志未见脚本或纹理错误 |
| 未来换装契约 | 根目录规则和随包副本同步为模板 2，保存全部帧哈希、相位、时间轴、统一变换及姿态模板；不交付正式换装系统 |

## 证据

- `character-art-tests.json`：pass，六动作、27 帧，源文件哈希、透明留白、统一变换、模板哈希、保留 idle 与实际发布的引擎文件检查通过。
- `player-tests.json` / `gorest-character-player.log`：pass，0 failures；速度 100 px/s，周期距离 200/3 px，八方向、完整周期、180 次转向停步及碰撞验证。
- `gorest-character-import.log`：当前 25 张新增 / 更新图片导入成功，无脚本或纹理错误。
- `gorest-character-render.log` / `character-godot-poses.png`：实际 GPU 渲染，四行 front/back/right/left，九列 idle、walk00～walk07。固定位置展示姿势，真实移动另由物理测试验证。
- `character-world.png`：主角中性待机在现有原野中的实际画面。
- `../assets/hero/reference/animation-preview.webp`：四列 front/back/right/left，上排 idle、下排八帧 walk；参考周期 667 ms，游戏直接读取 PNG 图集并按实际位移推进。
- `../art/hero_gorest_runtime_v02/clips/animation-clips.json`：PNG 字节拷贝 27、WebP 时间轴 6、tick_grid 最大误差 0.333 ms、near_duplicate_holds=0、manifest_lint=0，均 pass；整体原状态 needs-visual-review。
- `../art/hero_gorest_runtime_v02/engine/engine-export.json`：pass，794×662 单图集、27 帧 RGBA 回读匹配；六循环，导出时长误差最大 0.6667 ms。
- 上一运行资源、脚本、规范和验收报告保留在 `../art/hero_gorest_runtime_v02/previous_*`。

## QA 与质量边界

循环工具保留 needs-visual-review，loop_seam=1.034748，threshold=null；本轮已发布的循环 / 引擎 QA 没有 WARN / FAIL。原始 JSON 未改为人工通过；完整记录见 `../art/hero_gorest_runtime_v02/QC_FINDINGS.md`。数字检查不能认证解剖、身份、零滑步或脚底像素固定，实际游戏显示另行核对。

用户已确认此版行走并授权接入。当前待机仍是单帧中性姿势，与新行走的头部比例及线条有细小变化；行走有轻微轮廓与侧面两组姿势的投影 / 节奏差异，左向光照随整帧镜像翻转。整体角色帧作为未来重绘模板，不代表已制作隐藏身体和衣物模块。本轮接入 art_source=existing，没有新图像或视频生成调用。

只验证本轮角色及速度变更和必要依赖；没有重跑全地图生成回归、性能压力测试或重新打包。历史性能报告与旧压缩包不能代表本版本。本轮完成即停止。
