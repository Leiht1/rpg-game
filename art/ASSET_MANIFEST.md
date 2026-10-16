> 当前生效规范为根目录 ART_STYLE.md 2.1、CHARACTER_SEQUENCE_WORKFLOW.md 与 SCENE_ART_WORKFLOW.md。下方旧完整帧/程序关节说明仅约束历史资源，不是当前生成入口。

# 当前正式素材登记 · 2026-10-16
角色：assets/hero/cartoon，用户已确认V4简化短腿白T部件；本轮复用角色与已确认动作，15条原生动画。
场景：assets/environment/cartoon_v2，已接入可玩候选、等待用户验收。两树、两石、草、草花、镜像草变体、木材和新斧，地表笔刷为本轮草色块模糊派生。一次受控图片调用，route=local:codex-cli、art_source=host_image、model=codex-image_gen；底层精确模型和实际费用未知，无外部商业游戏图。适用生成服务/账户条款，不宣称第三方CC0许可。
来源与QA见 scene_cartoon_v2/generated/job.json、prompt.txt、processing.json、QA.md。旧环境保留但不再加载；禁止正式使用的实验道具未复用。

---
以下为历史登记，accepted只指当时版本，不改变当前正式路线。

# 素材来源与验收登记

生成日期：2026-10-15。所有任务先读取根目录 ART_STYLE.md。

## 历史角色 · accepted：v11 侧视行走接入（模板 5）

2026-10-15 用户看过 v11 预览后授权“接入游戏吧”。当前 `../assets/hero/final_sprite/side_walk_00..07.png` 与 `hero_v08_pose_redraw_preview_v11/right_walk_preview/frames/` 八张 PNG 字节一致，take2 索引 0..7；按 v08 原姿势统一重绘，保留第 5 帧低位收腿及第 6 帧左手在背后少量露出的要求。左向整帧镜像。正背行走 v04 的 16 张及呼吸 v05 的 12 张均保持模板 4 原文件。全部 128×128 RGBA、原点 (64,112)，此次没有重采样、改姿势或改变播放速度。

接入 art_source=existing，新增图片/视频调用均 0；v11 制作阶段的两次 host:image_gen / generate2dmedia adopt 及供应方/账户条款、模型/费用未知边界继续追溯至原 provenance.json。模板 4 完整备份、接受记录、源哈希与未改写的 skill 输出在 `hero_v11_runtime_v05/`。Godot 4.7.2 / OpenGL 3.3 / RTX 5060 实际导入、短移动/走停专项及四方向 48 个固定姿势渲染通过；没有新性能基准。六动作/36 帧 warnings=0，工具仍 needs-visual-review，用户接受不改写自动美术 QA；质量边界见该目录 QC_FINDINGS.md。更早候选与接入记录保持原样。

## 待确认修订候选 v07：侧视相位与第 6 帧近远腿

`hero_side_phase_preview_v07/` 仅预览。重新绘制完整第 2、3、5、6 帧，改善 1→2→3 与 4→5 的相位分配，修正第 6 帧前景腿及手臂回摆；1/4/7/8 PNG 字节保留，左侧完整镜像。128×128 / (64,112) / 八帧，原速 13.8 FPS 对应当前 115 px/s，另有半速及 12 FPS 参考。游戏、呼吸及正式模板 4 未替换。

art_source=host_image，实际 route=host:image_gen + generate2dmedia adopt，共 6 次整身图片编辑、0 视频；模型及费用未知，适用供应方/账户许可条款。四张选入单人源共用固定参考画布尺度及完整帧刚性对齐，无逐姿态身高拟合、局部补丁或变形。提示词、回执、来源、弃选与最终哈希均留存。

Gorest 新增两个独立 confirmed=false 的 v07 条目，原 57 条及场景保留，总数 59。最小图像/图集/镜像/保留帧/动图时序验证通过；未重跑引擎、地图、性能、网页构建及长浏览器检查。仍 needs-visual-review，由用户手动循环验收；保留轻微轮廓和相对身长差异，见该目录 RESULT.md / QC_FINDINGS.md。

## 历史角色 · accepted：整套 v04/v05/v06 修订接入（模板 4，侧视由模板 5 替换）

2026-10-15 用户确认“好多了，把这一版都接入游戏吧”。当时 `../assets/hero/final_sprite/` 36 张 PNG：front/back walk 来源 `hero_consistency_preview_v04/`，side walk 来源 `hero_side_spacing_preview_v06/`，front/back/side idle 来源 `hero_sequence_repair_preview_v05/`。right 对应 side，left 完整镜像；全部已确认 128×128 RGBA 字节原样复制，共用 (64,112)。呼吸 450 ms×4=1.8 秒；移动 115 px/s，位移步频 13.8 帧/秒、周期距离 200/3 px。

本轮 art_source=existing，图片/视频新增调用 0 次；沿用原 host:image_gen / generate2dmedia adopt 来源与供应方/账户许可边界，用 generate2dsprite 打包和 Godot 导出。模板 3 完整备份、接受记录、源哈希与导出在 `hero_approved_runtime_v04/`。六动作/36 帧 warnings=0、原工具状态仍 needs-visual-review（loop_seam=1.533159），引擎导出及最小实际游戏专项通过；不将用户接受改写成工具的自动美术通过。细微重绘和镜像光照边界继续保留，详见该目录 RESULT.md / QC_FINDINGS.md。下方为生成、预览及历史接入记录。

## 待确认修订候选 v06：侧视第 3、5 帧相位微调

`hero_side_spacing_preview_v06/` 仅预览。只替换 v05 右侧第 3、5 帧的完整人物图，收小 2→3 的手脚变化、增加 4→5 的收步承重变化；左向完整镜像。其余六帧 PNG 字节保留，呼吸预览不变。128×128 / (64,112)，8 帧 / 12 FPS，未替换当前运行模板 3。

新增 1 次 host:image_gen 整身图片编辑，generate2dsprite / generate2dmedia adopt 留存来源；共同源尺度、整帧刚性对齐，无局部补丁/变形/程序绘肢体。模型和费用未知，许可沿用供应方及账户条款。Gorest 仅更新原两条未确认侧视行走，57 条 ID/顺序、其余 55 条及场景数据保留。最小图片/镜像/原样帧/动图时序检查通过，仍 needs-visual-review，由用户手动循环确认，详见该目录 RESULT.md / QC_FINDINGS.md。

## 待确认修订候选 v05：侧视手脚衔接与呼吸脚底对齐

`hero_sequence_repair_preview_v05/` 仅预览。侧视保留 v04 第 1、2、4 帧，修订第 3、5～8 帧并检查双手的近远遮挡、反向摆臂及回环；左侧完整镜像。正面/左右呼吸使用 v04 既有完整原画，仅以双脚重新刚性注册，背面不变。128×128 / (64,112)，呼吸 1.8 秒、walk 12 FPS，未替换当前模板 3。

新增 4 次内置 image_gen 完整姿势编辑，经 generate2dmedia adopt 留存；没有视频、代码绘肢体、拼贴冻结或局部变形。模型/实际费用未知，许可沿用供应方及账户条款。选帧、弃用理由、提示词、回执、尺度与完整帧变换见该目录 provenance.json。

Gorest 原五条未确认条目更新为 v05，57 条总数/ID/顺序及其余内容保持不变。最小图片/镜像/时间轴检查通过，skill 仍 needs-visual-review（loop_seam=1.533159）。仍有细小轮廓、投影、身长和相位间距变化；脚部对齐后上身原有呼吸收缩仍存在。不宣称最终动作通过；按用户要求由其手动循环验收，详见 RESULT.md / QC_FINDINGS.md。

## 待确认修订候选 v04：完整眼睛、摆正头部、呼吸/行走统一

`hero_consistency_preview_v04/` 仅预览，尚未替换下方模板 3。front/back/right 各 4 帧呼吸 + 8 帧行走独立制作，left 整帧镜像，共 48 张导出。128×128 / (64,112)，呼吸 450 ms×4=1.8 秒，行走 12 FPS，服装与头身以修订行走为基准；侧面小步幅，完整眼型，头部自然直立。

使用 generate2dsprite、host:image_gen + generate2dmedia adopt，完成 8 次整身图片编辑，另有 1 次中断未收录；没有视频、局部零件拼贴/变形、逐帧缩放或第三方下载素材。模型和实际费用未知，遵循供应方及账户适用条款，不标为公共领域/开源。提示词、引用、原图、选择、回执与哈希在本轮 provenance.json。

Gorest 新增 8 条 confirmed=false 候选，原 49 条及其他场景保留。最终 skill 包为 clips_final，技术检查通过但仍 needs-visual-review，loop_seam=1.577771；少量重绘、亚像素头脚变化、颜色差和循环阶段感保留，详见 RESULT.md / QC_FINDINGS.md。当前 60 个运行相关文件哈希不变，没有游戏内替换或新素材切换验收。

## 历史角色：已确认呼吸 v02 接入（模板 3，现由模板 4 替换）

2026-10-15 用户确认并授权接入 `hero_idle_breathe_preview_v02/`。接入当时的运行资源为 front/back/side 各 4 idle + 8 walk，共 36 张 128×128 RGBA；左向整帧镜像。12 张呼吸 PNG 与当时已确认预览字节一致，四帧各 750 ms、3 秒循环。24 张 walk、100 px/s 速度和 200/3 px 周期距离保留，当时未额外调整 idle/walk 比例差。

接入采用 generate2dsprite clip / Godot 导出，art_source=existing，无新图像 / 视频调用，也无 Gorest 新细调。角色模板为 `windrest-character-template-3`，原模板 2 运行资源保存于 `hero_breathe_runtime_v03/previous_runtime/`。原 v02 提示词、来源与许可记录继续有效，原预览报告仅说明当时状态；本轮批准不改写历史 QA。

Godot 4.7.2 导入、资源专项、真实走停 / 四向呼吸测试通过；完整证据、保留的质量边界和未通过的首次过快启动记录见 `hero_breathe_runtime_v03/RESULT.md`、`QC_FINDINGS.md` 与 `../reports/CHARACTER_VALIDATION.md`。下方为历史制作记录。

## 呼吸修订候选 v02：增强胸肩、抑制位移（生成时仅预览，现已接入）

`hero_idle_breathe_preview_v02/` 为当前待确认预览，四方向各 4 帧 / 128×128 RGBA / 750 ms / 3 秒循环。正、背、右三套完整人物独立图像编辑，左向整帧镜像；引用上版中性完整人物，并沿用当前 idle 的高度。v01 因动作太小与明显位移被用户拒绝，保留原图记录，不能作为已通过验收的素材。

本轮实际使用内置 image_gen 3 次、generate2dmedia adopt 来源管理、generate2dsprite clip 打包。三套 1254×1254 原图、提示词、引用图、回执、统一方向尺度、完整帧亚像素注册与哈希留存。Gorest 只整理和预览；没有视频、局部像素绘制、肢体拼接、局部变形或逐帧体型拟合。模型/实际费用未公开，生成素材沿用供应方及账户条款，不标为公共领域或开源。

头部/下肢图像匹配估计残余偏移≤0.1001 px，正面和侧面胸肩变化增强；背面仍克制。这些数字不能证明零位移或自然呼吸。工具 4 clips / 16 frames / warnings=0，仍 needs-visual-review（loop_seam 最大 1.099650）。逐帧重绘差、四帧节奏、背面幅度与镜像光照保留为待确认项。明暗背景、1:1、旧/新 GIF/WebP、QA 和实际 Gorest 截图见该目录。

Gorest 原四条呼吸预览在原 ID/位置更新为 v02，confirmed=false，其他 45 条资产与场景保持不变。没有接入游戏，51 个运行相关文件哈希保持不变；当前模板 2、速度、旧 idle 和 walk 均保留。

## 呼吸待机候选：四方向四帧（2026-10-15，仅预览）

`hero_idle_breathe_preview_v01/`：front/back/right/left_idle_breathe 各 4 帧、128×128 RGBA、脚底 (64,112)、每帧 750 ms、3000 ms 循环。正/背/右三套基于当前对应 idle 独立生成，左侧整帧镜像；新 neutral 保留站姿但并非旧 idle 像素复制。

使用 generate2dsprite / generate2dmedia 管理来源与打包；实际内置 image_gen 整身透明图片编辑 3 次，并 adopt 收录，不包含视频。底层模型与实际费用未知。原图、提示词、引用图、回执、整帧注册参数、QA、明暗背景动图及 Gorest 网页截图齐全；未采用第三方商业游戏资源。生成素材按工具供应方及账户适用条款使用，不标为公共领域或开源。

Gorest 只负责整理/预览，新增四条 confirmed=false 素材，旧素材与场景保留。有效 skill 输出为 `clips_fixed_feet/`；loop_seam 最高 1.932789，needs-visual-review 原样保留。少量重绘轮廓与四帧慢循环节奏仍待用户确认；不宣称零脚滑、完美循环或最终美术验收。

按用户要求先看效果，**没有接入游戏**。下方模板 2、三张旧 idle、八帧 walk、速度与已知尺寸差均保留。本次默认流程另见根目录 `CHARACTER_SEQUENCE_WORKFLOW.md`。

## 历史角色：Gorest 八帧行走接入（模板 2，已由模板 3 替代）

用户于 2026-10-15 确认 `gorest_side_lowstep_v03/` 的正面、背面及侧面低抬腿版本，并授权接入游戏。当前 front/back/side 各 1 idle + 8 walk，共 27 张 128×128 RGBA；左向整帧镜像，单角色图集与六动作 SpriteFrames。旧三张中性 idle 原文件保留。

- 已确认行走输入：`gorest_side_lowstep_v03/front/frames/`、`back/frames/`、`right/frames/`，均按索引 0～7；右侧第 3、7 帧为低抬腿修正版。原始候选、提示词、生成回执与处理记录仍在 `gorest_walk_trial_v01/`、`gorest_directions_v02/`、`gorest_side_lowstep_v03/`。此前使用 `local:codex-cli` 图片路由和一次内置 image_gen 整身编辑；本次接入没有新生成调用，也没有视频生成。
- 全部 24 张 walk 共用 256→140 等比采样及 (-6,7) 平移，映射脚底 (128,192)→(64,112)；仅舍弃透明外边，无肢体切片、局部变形或逐帧拟合。
- 当前帧、图集、模板与源哈希：`../assets/hero/`；导入脚本及 skill 输出：`hero_gorest_runtime_v02/`。旧运行资源完整保留于其中 `previous_runtime/`，新模板为 `windrest-character-template-2`。
- 常规速度 100 px/s，行走参考 12 FPS，8 帧周期距离 200/3 px，由碰撞后实际位移驱动。四向完整图、透明留白、源哈希、skill 图集回读与 Godot 实际显示见 `../reports/CHARACTER_VALIDATION.md`。
- 用户已接受此版用于当前探索；单帧 idle 与 walk 的头身/线条细微变化、侧面半周期投影差异和左向镜像光照仍是边界。工具循环 QA 原样保留 needs-visual-review；导出 pass 不等于解剖或零滑步认证。

未引入第三方或商业游戏素材；沿用生成工具及账户适用条款，不将生成图标为公共领域或开源素材。

## 历史角色：完整帧重建（模板 1，已由上方替代）

旧拆件 / 14 层程序关节动作已停止。根因是独立裁片没有统一身体、方向投影和逐帧动作基体；静态透明边界检查通过也不能证明拼装后的透视和步态正确。旧 `assets/hero/*.png` / `actor.json` 已移至 `hero_rebuild_v01/legacy_runtime/`，只留追溯，当前游戏没有加载它们。

本轮实际使用 `generate2dsprite` skill，经 `generate2dmedia/route_media.py image` 的 **local:codex-cli** 路由，调用本地登录账户的图像工具。共 6 次成功图片调用；requestedModel 为包装器名 `codex-image_gen`，底层图像模型不可核实。job 的 `estimateUsd=0.0` 表示订阅配额、没有单次美元报价，并非确认实际账单为零。图生视频实际 no-route，没有伪造视频或骨骼动画。

| 来源（hero_rebuild_v01/ 下） | 结果与用途 |
| --- | --- |
| raw_front/ | 12 格完整角色候选，腿部相位不合格，拒绝作为运行帧 |
| front_walk_take2/ | 完整正面四姿势，验收顺序 0、3、2、1 |
| back_walk/ | 真背面整身四姿势，使用 0、2、3；原第 1 格支撑脚重复，未采用 |
| side_walk/ | 真右侧整身四姿势，近远腿交换，顺序 0、1、2、3 |
| back_passing_edit/ | 重新生成缺少的完整背面经过姿势，替代背面第 1 格；没有粘贴肢体 |
| side_idle_edit/ | 基于已接受侧面行走图整身编辑为中性站姿，统一头身比例 |
| 原 reference/hero.png 与 candidates/hero-turnaround.png | 保留已确认身份；三视图中的完整正/背中性站姿用于当前 idle |

最终资源：`assets/hero/final_sprite/` 共 15 张完整角色 PNG；三方向各 1 idle + 4 walk，六个循环。Godot 单图集 / SpriteFrames 为 `assets/hero/animation/hero.tres`；未来逐帧模块模板为 `assets/hero/modular_plan/template.json`，规则以根目录 `CHARACTER_MODULAR_RULES.md` 为准。

逐字提示词、引用图 SHA256、实际输出、调用回执均在每个生成目录的 `prompt.txt`、`job.json`、`generated.png`。汇总为 `hero_rebuild_v01/provenance.json`；完整图的注册参数在 `registration.json`。归一化仅做整身统一缩放、刚性注册和透明边缘清理，没有旧零件、局部旋转、拉伸或关节烘焙。图像模型生成素材按账户及工具供应方条款使用，本轮无第三方下载资产、无商业游戏资产；不将生成图标为公共领域或开源素材。

数值检查通过；原候选 WARN 与工具 `needs-visual-review` 状态原样保留在 `hero_rebuild_v01/QC_FINDINGS.md`，人工逐帧及 Godot 渲染检查结论、质量限制见 `hero_rebuild_v01/ACCEPTANCE.md` 和 `reports/CHARACTER_VALIDATION.md`。四关键帧流畅度、单帧待机和左侧镜像光照为当前边界。

## 初版记录（下方角色结论已被本轮替代）

工作流：本地 `C:/Users/HT/.codex/skills/generate2dsprite/SKILL.md` → 能力检查 → 无已配置图片 API key → skill 允许的调用方 `host:image_gen` 图片路由 → 目视候选筛选 → 透明裁片整理 → 同步图集 → Godot 实际运行。

主机图像工具未返回可核实的模型名和单次费用，因此模型与 estimateUsd 均记录为 unknown，不从提示词推测。没有使用商业游戏图像或网上下载的补充美术。生成素材按工具供应方及用户账户适用条款使用，不将其误标为第三方开源或公共领域资产。

| 资产 | 候选 / 源图 | 接受与用途 |
| --- | --- | --- |
| 主角身份 A | candidates/hero-a.png | rejected：眼睛偏大、笔触过密 |
| 主角身份 B | candidates/hero-b.png、reference/hero.png | accepted：长期主角风格基准；当前运行使用完整角色序列帧 |
| 三视图 | candidates/hero-turnaround.png | accepted：身份和方向参考，静态参考而非动画 |
| 正、背、右方向部件 | candidates/parts-front.png、parts-back.png、parts-right.png | superseded/rejected for animation：静态裁片曾通过边界 QC，但不满足角色透视、动作和一致性；仅留历史 |
| 基础下身内衬 | candidates/base-pelvis.png | accepted：三视角贴身内衬补全骨盆，被外裤覆盖；原始部件单独保留 |
| 两棵树 | candidates/trees.png | accepted after alpha cleanup；运行文件 assets/environment/tree_0.png、tree_1.png |
| 两块石头 | candidates/rocks.png | accepted after cleanup；运行文件 rock_0.png、rock_1.png |
| 草地纹理 | candidates/meadow.png | accepted：使用周期/平滑分解消除平铺边界；运行文件 meadow.png |
| 草丛、叶丛、雏菊 | candidates/tufts.png | accepted after cleanup；运行文件 tuft_0.png～tuft_2.png |
| 主角 8 动作 / 14 同步层 | hero_rebuild_v01/legacy_runtime/ | retired：错误拆件与程序关节烘焙，仅留历史，当前不加载 |

原始生成图与 SHA256 见 source-hashes.json。提示词、制作简报及逐字记录的留存边界见 prompts/generation-briefs.md。筛选后的环境合照见 reference/environment-lineup.png；角色逐帧与循环预览见 reference/animation-review.png、animation-preview.gif。

## 原始问题与整理

原始生成图不是精确工程网格，正面部件越过名义单元边界，树叶也有跨格。原始 QC 的失败报告保留在 qc/front-spill、qc/tree-spill；没有把这些图直接等分切入游戏。按实际对象所有权定义裁片边界，去除低透明度晕染和微小离散残留，再以充分留白重排。禁止用“只保留最大连通块”掩盖截断的肢体。

整理后的三方向静态部件网格 qc/front-final、back-final、right-final 均无越界、无警告；数字检查仍不能替代身份与动作目视检查。所有保留 QC 的 FAIL/WARN 明细见 QC_FINDINGS.md（包括已修复的原始候选）。

## 能力限制

初版曾改用本地程序关节烘焙，此路线现已停止；`LAYER_CONTRACT.md` 只留历史。当前能力检查见 `hero_rebuild_v01/doctor.json`：图片生成实际可用、视频无可用路由；交付整身生成关键帧，不使用程序关节替代动作。ffmpeg 缺失不阻碍 PNG / Godot SpriteFrames。


## 2026-10-16 地面 V0.4 候选（pending_user）
assets/environment/ground_v04/0..5.png；受控生成1次，真实参考树石及角色同屏，route local:codex-cli / codex-image_gen。原图/提示词/哈希回执/alpha清理/拒选与比较记录位于art/ground_v04。A/B仅可玩测试区，用户未选定，不得批量替换。

## 2026-10-16 · 自然轻手绘场景正式接入（用户已确认）
assets/environment/stylized_v3：tree_0/1、rock_0/1、grass、tuft_0/1/2（实际为小花和落叶碎石，沿用旧kind槽位）。复用用户确认V0.7，不新增生成。源图/提示词/真实参考及哈希/route回执/alpha清理见art/scene_v07；runtime资源哈希和转换说明见integration.json。地面1280×720世界尺度镜像连续采样；树石原画布、脚底、坐标与碰撞保留。正式可玩入口Start-Playtest.cmd；原资产保留历史。原始图集非网格与透明雾边警告仍见QA.md。


## 当前正式资源（2026-10-16 已确认）
- 主角：assets/hero/cartoon，9张部件及原生AnimationPlayer；斧/木材为assets/environment/cartoon_v2/axe.png与wood.png。
- 树石：assets/environment/view_v01/tree_0/1.png、rock_0/1.png；地表为biome_v02四张画稿，点缀为stylized_v3的tuft_0/1/2，原grass及ground_v03/ground_atlas保留运行依赖。
- 上述均为项目已有受控生成、整理并获用户确认的素材，无新增外部商业资源。提示词与处理记录在本地art及prototypes归档中保留；本次按用户要求不推送历史原图、候选、预览与压缩包。当前树石提示词及处理元数据单独随项目保留，运行文件SHA256见CURRENT_ASSET_HASHES.json。
- 已确认水面为scripts/terrain.gdshader，世界生成windrest-biome-0.5.0；旧候选状态只用于历史追溯，不覆盖本节。
