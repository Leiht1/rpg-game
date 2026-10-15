# 已确认 Gorest 八帧行走的游戏接入

2026-10-15，用户确认前轮预览并授权接入游戏。本轮只使用已有完整帧，没有调用图像或视频生成模型；美术来源为 existing。源生成路由及回执沿用 gorest_walk_trial_v01、gorest_directions_v02 的 local:codex-cli 与 gorest_side_lowstep_v03 的内置 image_gen 整身编辑，底层图像模型未知，不推算新增费用。

- 输入为 `../gorest_side_lowstep_v03/` 的 front/back/right 各八帧；side 第 3、7 帧为低抬腿版。左向为完整侧面镜像。旧三张 idle 字节不变，旧资源完整备份在 previous_runtime。
- 当前 128×128 RGBA，脚底 (64,112)；全部 walk 共用缩放 140/256、整画布偏移 (-6,7)，源脚底 (128,192) 对应目标原点。无局部补丁、肢体切片、变形或逐帧缩放。
- skill 循环构建原始 QA 为 needs-visual-review；engine-export.json 为 pass。没有把自动工具状态改为人工通过。当前数值检查无 WARN/FAIL，完整状态见 QC_FINDINGS.md 和原 JSON。
- Godot 4.7.2 实际导入 / OpenGL 渲染成功。`../../reports/character-godot-poses.png` 展示四向 idle 及全部八帧，主体未裁切，方向与低抬腿版一致。`player-tests.json` 真实移动覆盖八帧，并验证移动提速、斜向等速、180 次切向停步及碰撞；具体证据见 `../../reports/CHARACTER_VALIDATION.md`。
- 已检查现有游戏尺寸下的轮廓、透明边缘、方向、脚底原点与角色/场景比例。单帧 idle 与新 walk 仍有小幅头部比例/绘制差异；步态有轻微轮廓与侧面半周期投影变化，左向镜像光照翻转。原点统一和数值指标不能证明每帧鞋底固定或零滑步。

运行资源为 `../../assets/hero/`，当前模板 windrest-character-template-2，速度 100 px/s。这里只交付一套完整角色，不是隐藏身体及换装模块。未进行性能压力测试、全量地图回归或重打包。本轮到此停止。
