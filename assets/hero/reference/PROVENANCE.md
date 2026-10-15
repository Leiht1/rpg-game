# 角色来源与交付说明

当前唯一身份：identity.png；三方向身份参考：turnaround.png，均为工程原有已确认原创生成图。

当前行走源为用户已确认的 `art/gorest_side_lowstep_v03/`，正面/背面/右面各八帧，侧面第 3、7 帧已降低抬腿。来源生成沿用 generate2dsprite / generate2dmedia 的 local:codex-cli 路由，侧面两帧采用一次内置 image_gen 整身编辑；Gorest 整理过程、提示词与回执分别在 art/gorest_walk_trial_v01/、gorest_directions_v02/、gorest_side_lowstep_v03/。本次接入没有新图像或视频生成调用，没有身体零件拼接或程序关节烘焙。

三张中性 idle 保留自上一运行版本；其生成源、完整提示词、引用图哈希与 job 回执在 art/hero_rebuild_v01/。新版本的 staging、skill 循环构建 / 引擎导出、旧资源备份在 art/hero_gorest_runtime_v02/；animation/registration.json 保存当前全部源文件哈希和整图变换。底层图像模型未知；包装器名 codex-image_gen 不是底层模型保证。回执 estimateUsd=0 表示订阅配额没有单次美元报价，不代表实付账单。

未使用商业游戏或第三方下载素材；生成图适用账户及工具供应方条款，不标为开源或公共领域。当前限制及 QA 明细见 art/hero_gorest_runtime_v02/ACCEPTANCE.md / QC_FINDINGS.md 和 reports/CHARACTER_VALIDATION.md。

当前 27 张完整 PNG、六动作、128×128、原点 (64,112)，可直接使用 animation/hero.tres。24 张 walk 全部采用相同缩放 140/256、偏移 (-6,7)，不逐帧改变比例；idle 保持原文件。常规速度 100 px/s，8 张 walk 每张参考 5/60 秒，实际按距离推进。未来逐帧模块重绘以模板 windrest-character-template-2、根目录 CHARACTER_MODULAR_RULES.md 和 modular_plan/template.json 为准；本轮不包含正式换装系统。

frame-review.png 为逐帧对照，animation-preview.webp 为四方向循环预览。reference/ 已通过 .gdignore 排除引擎导入，游戏只加载 animation/ 下的 PNG 图集与配置。
