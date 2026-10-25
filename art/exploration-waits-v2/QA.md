# 垂钓老者与纸张 V2

路线：generate2dsprite → route_media.py → local:codex-cli / codex-image_gen。两次真实图像生成：主图和仅去掉固定鱼线的编辑。具体底层图像模型未公开；路线回执 estimateUsd=0.0（本地订阅路线）。参考项目 art/reference/hero.png。原图、编辑原图、提示词、job.json、处理结果及 SHA 均保留，见 provenance.json。

1254×1254 原图经 single/native_alpha/alpha-hygiene both 整理为1024×1024，完整保留人物、凳子和鱼竿。游戏显示画布高112，实际可见高约101；脚锚点和竿尖按最终图测量。鱼线由竿尖连向持久化的真实河中钓点，浮标轻微起伏；人物极轻待机伸缩，无新动画框架。

原图 QC 的所有非通过项（不改写为全绿）：

| ID | 状态 | value | threshold | 文件 |
|---|---|---|---|---|
| safe_frame | warn | 1 | 0 | elder-raw-qc/sheet-qc.json |
| faint_specks | warn | floor_px=14214, detached_components=1 | 0 | elder-raw-qc/sheet-qc.json |

原图完整，无输出或源图触边；原始15%安全边不足的警告保留。整理去除低透明雾点并补入输出边距；最终 elder-final/pipeline-meta.json 的 qa.status=pass，空帧、夹断、源图/输出触边均空。单张图不验证动画相位与解剖，不以结构通过替代画风确认。环境 doctor.json 仍有 Python PATH/编码、可选 scipy/resvg/ffmpeg 及未配置其他媒体路线提醒。

纸张直接复用现有 letter.png 的纸纤维底图，通过游戏原生多边形轮廓及纹理坐标显示；没有重画原图。地图增加低对比手绘支流、山形、断续路线与模糊人影；残页为撕缺轮廓；瓶内信为轻折痕信纸。没有通用厚边框。

正常1280×720与相机放大实景已查看人物比例、双脚/凳脚、竿尖、鱼线落水、玩家前后遮挡及E交谈。960×540和1600×900的三种阅读页也已实际渲染，作为用户本轮明确要求的专项尺寸；不扩展全分辨率回归。待用户主观确认老者造型、贴合画风及纸张自然程度。临时实景在 reports/exploration-waits-v2，用户未确认前保留。
