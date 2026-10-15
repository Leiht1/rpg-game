# v08 检查与限制

## 用户反馈及诊断修正

- 用户目视反馈仍忽大忽小，本版体型一致性未通过；包装 pass 不等于动作或体型 pass。
- 第3/4/7帧对照显示头型、胸腹轮廓与头身比例的来源重绘差异。当前仅固定头高及地面，没有证明肩髋结构、躯干长度和肢段长度一致。
- 90～94px的全身可见高度差混有动作、定位及来源体型因素，不能全部归于自然起伏。必须先统一源帧结构，再完成最终共同尺度和注册。

- 包装检查 pass：16 张不同方向 PNG，128×128 RGBA、安全透明边界、图集逐像素回读、左右整帧镜像、8 个动图各八帧解码。原速 580 ms、半速 1160 ms；Gorest 使用 13.8 FPS。
- Gorest 实际网格/alpha 诊断 sourceEdgeRisks=[]。`gorest_diagnostic.png` 是通用自动布局的诊断输出，最终采用有记录的手动语义注册；通用脚部重心对齐不适合直接抵消交替步态。
- 8 帧共享 (64,112) 原点，支撑地面线 Y=112。已按本轮用户“统一每帧大小尺寸”对高分辨率整帧作等比源尺度校准，依据固定头顶至下颌区域，不按全身动作包围盒高度拟合、不拉伸或拼贴肢体。最终显示缩放共同为 1/4；每个源校准值在 registration.json 中公开，不能误称源图原始缩放完全相同。
- 重新测量注册后的头部尺寸 34.500～35.250 px，差 0.750 px；头部水平中心 61.125～61.250 px。完整姿势可见高度 90～94 px，包含屈膝/迈步起伏及原图比例差异，不能等同体型缩放误差。
- 原第5帧的右腿过度折叠已减轻，第6帧远侧左手已从前方移到背后少量露出；完整图片编辑仍有轻微线条/细节重绘差异，不能宣称未编辑区域逐像素一致。
- visualStatus=needs-visual-review：循环的解剖自然度、余留比例差异及实际节奏仍需用户验收。没有把数值检查当成动作通过。
- 没有接入游戏、导出新的运行 SpriteFrames 或更改动作模板；没有本轮 Godot/地图/性能测试。

## 能力检查原始警告与缺失

以下逐项沿用 doctor.json 的 id/status/detail（无数值 threshold 的能力检查保留 null）。不把可选视频、代码绘画或 API 能力缺失当成本轮 PNG 流程失败：

- `python.path` status=WARN; value=other python.exe on PATH: ~/AppData/Local/Microsoft/WindowsApps/python.exe; threshold=null; files=[doctor.json]
- `deps.scipy` status=WARN; value=not installed; needed for faster labelling and keying (forge_core falls back to numpy); threshold=null; files=[doctor.json]
- `deps.resvg-py` status=MISSING; value=not installed; needed for codeart2d SVG rendering (PixelSpec needs only numpy and Pillow); threshold=null; files=[doctor.json]
- `encoding.stdout` status=WARN; value=stdout=gbk: non-ASCII text can be garbled in pipes; threshold=null; files=[doctor.json]
- `encoding.files` status=WARN; value=open() and read_text() without encoding= use cp936; threshold=null; files=[doctor.json]
- `paths.cwd` status=WARN; value=the working folder has spaces or non-ASCII characters; threshold=null; files=[doctor.json]
- `ffmpeg` status=MISSING; value=ffmpeg is not on PATH; video decode and encode are unavailable (PNG-frame input still works); threshold=null; files=[doctor.json]
- `media.api.openai` status=MISSING; value=OPENAI_API_KEY is not configured; threshold=null; files=[doctor.json]
- `media.api.gemini` status=MISSING; value=GOOGLE_API_KEY or GEMINI_API_KEY is not configured; threshold=null; files=[doctor.json]
- `media.api.xai` status=MISSING; value=XAI_API_KEY is not configured; threshold=null; files=[doctor.json]
- `media.api.byteplus` status=MISSING; value=ARK_API_KEY is not configured; threshold=null; files=[doctor.json]
- `media.api.fal` status=MISSING; value=FAL_KEY is not configured; threshold=null; files=[doctor.json]
- `cli.grok` status=MISSING; value=Grok Build CLI not found on PATH or in $GROK_HOME/bin; threshold=null; files=[doctor.json]
- `route.codex-cli:image_gen` status=UNKNOWN; value=PRESENT: no proof for this version; threshold=null; files=[doctor.json]
