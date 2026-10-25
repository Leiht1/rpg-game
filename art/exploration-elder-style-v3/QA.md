# 当前角色画风重绘与批准

2026-10-25。上一版误用了早期 art/reference/hero.png，用户指出与正式白T主角违和，已退出运行。新版参考从 assets/hero/cartoon/character.tscn 实际渲染的正/侧/背主角，见 current-hero-reference.png；第二张旧老者只约束坐姿和握竿，第三张实际场景约束空间。最新ART_STYLE.md、VIEW_REFERENCE.md为依据。

路线 generate2dsprite → route_media.py → local:codex-cli / codex-image_gen。真实回执 source/job.json；精确底层图像模型未公开，estimateUsd=0.0表示本地订阅路线。原图、提示词、引用、处理参数和SHA均留档。单次重画，原透明1254×1254，经single/native_alpha/both整理为1024×1024。没有用调色滤镜将旧水彩图伪装成新稿。

用户明确“老者素材可以了”，批准仅限当前v3具体PNG；后续只改运行尺寸、生成地点与空间表现，PNG字节保持。当前运行 assets/exploration/v3/elder.png 与 processed/clean.png 哈希一致；批准原话见 provenance.json。

原图全部非通过项：

| ID | 状态 | value | threshold | 文件 |
|---|---|---|---|---|
| safe_frame | warn | 1 | 0 | raw-qc/sheet-qc.json |
| faint_specks | warn | floor_px=10223, detached_components=1 | 0 | raw-qc/sheet-qc.json |

原15%安全框不足但人物/凳脚/竿尖完整，原图不触边；整理补输出边距并清低透明雾点，processed/pipeline-meta.json qa.status=pass，源/输出触边、夹断与空帧均空。单张不验证逐帧运动相位，数值不能替代解剖或主观画风检查。环境工具缺项沿上轮doctor记录，不声称所有媒体环境全绿。

实际默认1280×720检查过当前主角正/侧同屏、放大、人物前后遮挡、凳脚与持竿。用户后续要求比主角略大并出现在地图边缘岸边，最终尺寸和左右外岸实景、17项定向检查见 reports/exploration-elder-coast-v4。旧小尺寸测试图按已确认素材/已关闭问题的清理约定移除；本轮外岸实景尚待查看，继续临时保留。原图/生成参考/QC图不清理。
