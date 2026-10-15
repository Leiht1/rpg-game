# 已确认呼吸 v02 · Godot 接入

2026-10-15，用户授权：“可以 这一版可以接入游戏了”。运行 Godot `4.7.2.stable.official.ed1daf0bf`，角色模板 `windrest-character-template-3`；地图生成器 `windrest-0.1.0` 不变。

front/back/right 各四张已确认 v02 PNG 原样复制到运行目录，right 对应 side，left 使用同序整帧镜像。每帧 750 ms，完整循环 3 秒。六个原动画名保留，其中 `front/back/side_idle` 现在播放呼吸；停步保留方向，开始实际移动后切回原 walk。脚底原点 (64,112)、128×128 RGBA、显示比例和偏移保持统一。

24 张 walk PNG 哈希、100 px/s 常规速度、200/3 px 步态周期距离均保留。玩家待机推进改为读取 SpriteFrames 相对时长与 speed，正确处理每帧 45 个 60 Hz tick；没有用运行时缩放、平移或局部形变生成呼吸。

本次沿用 generate2dsprite 的 clip 构建及 Godot 导出流程，art_source=existing，图像 / 视频调用均 0 次，Gorest 无新细调。原图、提示词和三次整身图像编辑来源继续以 `../hero_idle_breathe_preview_v02/provenance.json` 为准，底层图像模型与历史费用未知；本次不新增外部素材或许可。

## 验证与追溯

- skill：六循环 / 36 帧，warnings=0，循环原状态 needs-visual-review；Godot 导出 pass，794×794 单图集，36 张 PNG 回读匹配。完整数值见 `QC_FINDINGS.md`。
- 资源专项 pass、Godot 导入成功；真实物理角色测试 pass / 0 failures，含四向各一轮呼吸、44 个时序边界、180 次转向停步、原速度和必要碰撞检查。
- 实际 OpenGL 3.3 / RTX 3060 渲染采样见 `../../reports/character-godot-poses.png`，四向呼吸预览见 `../../reports/character-breathe-godot.gif`；固定位置姿势采样不冒充连续游戏录像。
- 验收说明：`../../reports/CHARACTER_VALIDATION.md`。本轮最终报告 / 日志副本在 `evidence/`，验收文档副本中的相对路径以根目录 reports 为基准。
- 模板 2 完整资源：`previous_runtime/`；原脚本、规则、验收报告：`previous_*`。首次测试过快启动造成的失败报告：`attempt_fast_start_player*`，最终正常节奏重跑通过，记录不删改。
- `acceptance.json` 保存用户批准；`staged/` 为已确认源和清单，`clips/`、`engine/` 为未篡改的 skill 结果。根目录规则与随包规则已同步模板 3。

保留已确认素材的轻微轮廓重绘、四帧阶段感、背面呼吸较轻、idle/walk 比例差和镜像光照。不宣称图像零漂移或完整美术无缺陷。本轮无性能基准或工程打包，未改无关系统，完成后停止。
