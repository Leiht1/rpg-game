# 四方向轻微呼吸待机 · 预览 v01

**后续反馈：用户认为呼吸起伏太小、人物位移明显，本版未获接受。** 仅鞋底基线一致不能证明稳定，下面为当时历史记录；当前修订候选见 `../hero_idle_breathe_preview_v02/`。

2026-10-15。按用户“先预览、先不接入游戏”的要求交付候选。游戏中的原 idle、walk、常规速度、动作模板与已知静帧/行走尺寸差异均未修改。

- front_idle_breathe、back_idle_breathe、right_idle_breathe、left_idle_breathe 各 4 张不同完整帧，128×128 RGBA；2×2 图集为 256×256。
- 每帧 750 ms，每轮 3000 ms；设计相位为自然基准 → 轻微吸气 → 接近中间 → 放松呼气。实际结果以预览为准，不以提示词代替验收。
- 正面、背面、右侧各自基于当前对应 idle 主帧生成；左侧整帧水平镜像右侧，时间顺序不反转。没有另起站姿、使用行走经过帧或做局部肢体拼接。
- 使用 generate2dsprite / generate2dmedia 来源与打包流程。实际调用内置 image_gen 编辑三次，透明完整人物 2×2 序列，通过 cli_media.py adopt 留存；未生成视频，底层模型及实际单次费用未公开。adopt 回执的 0 美元代表本次收录不发起新调用，不是图像调用免费证明。
- Gorest 用于实际格子检测、脚底注册、素材库播放及逐帧检查。保留原生透明，仅清除 alpha≤8 的残留；每个方向四帧共用一个尺度，不逐帧拟合体型。采样后整帧刚性对齐鞋底，原点 (64,112)，有效鞋底边界均为 y=112。

## 查看

- `four_directions_preview.gif` / `.webp`：四方向并排，明暗背景，原速循环，显示放大 1.5 倍。
- `game_size_preview.gif` / `.webp`：128 画布 1:1 预览，非 Godot 实机截图。
- `reference_and_breathe_contact.png`：每行原 idle + 四张新帧，便于比较是否保留站姿。
- `front/`、`back/`、`right/`、`left/`：最终候选单帧、图集、预览、归一化记录与几何检查。`side/` 是右侧的规范源。
- `clips_fixed_feet/animation-clips.json`：本轮有效 skill 输出。`clips/` 与 `qa_summary_first_registration.json` 只留首次注册历史，当时背/侧鞋底存在 1 px 舍入差，不作为交付入口。
- Gorest `http://localhost:3000/` → Spritesheet Only，前四条为“呼吸待机（4帧预览）”。四条均 confirmed=false；未绑定游戏场景。

## 检查与质量边界

已核对同角色、朝向、完整站姿、四张不同帧、透明边界、鞋底基线、左右镜像、图集回读、GIF/WebP 时长及 Gorest 播放/暂停/逐帧。Gorest 原 45 条资产及顺序、其他场景数据保留。lint / build 通过；原有 599.71 kB JS 体积提示保留。

目视变化集中在胸肩及少量衣褶，未看到明显抬脚、点头、大幅摆臂或左右摇晃；不能据此宣称零滑步、完美循环或最终美术验收。脚部透明度重心仍有不足 0.48 px 的横向变化；局部轮廓、鞋子与头发有细小重绘差异。新 neutral 并非原 idle 的逐像素复制，原图已单独保留并列对照。

每方向可见身高仅变化 1 px，鞋底边界不变；这类数字只用于发现异常。工具仍返回 **needs-visual-review**，最高 loop_seam wrap_ratio=1.932789（正面），首尾线条及四帧慢循环的自然程度仍需用户预览确认。详见 QC_FINDINGS.md，不将这项提示消成 pass。

当前游戏仍为 Godot 4.7.2 / windrest-character-template-2 / 100 px/s；本轮未接入呼吸态，因此没有执行或宣称停步进入呼吸、呼吸切 walk 的 Godot 测试，也没有新增游戏性能数据。确认候选后，接入和尺度统一应另行处理；本轮到此停止。

## 来源与留存

三套原始生成图、提示词、引用图和回执位于各方向 `take1/`、根目录 `*_prompt.txt`、`references/`。归一化记录包含源哈希、实际格子、共同尺度、整帧偏移与原点。未使用第三方商业游戏资产，生成素材依工具供应方及账户适用条款使用，不宣称公共领域或开源许可。
