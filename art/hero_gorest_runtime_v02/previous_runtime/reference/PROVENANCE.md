# 角色来源与交付说明

当前唯一身份：identity.png；三方向身份参考：turnaround.png，均为工程原有已确认原创生成图。

本轮实际使用本机 generate2dsprite skill，调用受控 route_media.py 图片路由 local:codex-cli，共 6 次成功生成；最终整身帧不是旧身体零件拼接或程序关节烘焙。图生视频无可用路由，未声称生成视频。

实际生成源图、完整提示词、引用图哈希、job 回执与导出报告保留在工程 `art/hero_rebuild_v01/`，汇总为 provenance.json；registration.json 保存整图尺度及脚底注册参数。底层图像模型未知；包装器名 codex-image_gen 不是底层模型保证。estimateUsd=0 表示订阅配额没有单次美元报价。

未使用商业游戏或第三方下载素材；生成图适用账户及工具供应方条款，不标为开源或公共领域。当前限制及 QA 明细见工程 art/hero_rebuild_v01/ACCEPTANCE.md / QC_FINDINGS.md。

当前 15 张完整 PNG、六动作、128×128、原点 (64,112)，可直接使用 animation/hero.tres。未来逐帧模块重绘以根目录 CHARACTER_MODULAR_RULES.md 和 modular_plan/template.json 为准；本轮不包含正式换装系统。

frame-review.png 为逐帧对照，animation-preview.webp 为四方向循环预览。reference/ 已通过 .gdignore 排除引擎导入，游戏只加载 animation/ 下的 PNG 图集与配置。
