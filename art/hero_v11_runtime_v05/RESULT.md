# v11 已接入游戏

用户在查看预览后批准“接入游戏吧”。模板 5 已发布至 assets/hero/：仅替换八张 side_walk，直接复制 v11 take2 的最终 128×128 PNG，原点 (64,112)、尺度 1、位移 (0,0)，姿势和顺序不变。左侧使用完整帧镜像。正背行走与全部呼吸共 28 张保持原文件。

当前为 Godot 4.7.2 Stable / windrest-character-template-5 / 115 px/s / 1.8 秒呼吸，地图生成器 windrest-0.1.0。运行脚本、场景和配置无变更。接受记录见 acceptance.json，旧模板 4 完整资源见 previous_runtime/，旧规范、文档、测试与截图见 previous_*。

generate2dsprite 的 build_animation_clips 和 export_engine 实际输出六动作、36 帧、794×794 图集；本轮 art_source=existing，新图片/视频调用均为 0。原 v11 来源、提示词、take 选择、许可及未知模型/费用仍可追溯，未改写原预览记录。

资源专项与 Godot 实际游戏短专项均 pass / 0 failures。实际渲染四方向全部 48 个姿势；八方向短移动、镜像、位移相位、走停及呼吸边界通过。证据见 godot-*.log 和 ../../reports/CHARACTER_VALIDATION.md。自动几何与引擎检查不认证零滑步或解剖一致性，原 needs-visual-review 保留，详见 QC_FINDINGS.md。

本轮不含全地图、性能压力或重新打包；历史性能不作本版数据。接入完成后停止。
