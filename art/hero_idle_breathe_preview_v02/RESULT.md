# 呼吸待机 v02 · 仅预览

> 状态更新（2026-10-15）：用户已确认本版并授权接入，已原样纳入 Godot 模板 3。当前接入结果见 `../hero_breathe_runtime_v03/RESULT.md` 和 `../../reports/CHARACTER_VALIDATION.md`；下文保留制作时的预览记录及原始 QA，不代表当前仍未确认。原 PNG、提示词与 provenance 未改。

2026-10-15。针对用户反馈“起伏太小、人物明显位移”，重新生成 front/back/side 的完整人物四帧，left 整帧镜像。当前候选尚未获用户接受，未接入游戏。

- 128×128 RGBA，2×2 图集 256×256，四帧各 750 ms，循环 3000 ms。相位：基准、吸气、过渡、呼气。
- 采用 generate2dsprite 来源/打包流程；实际内置 image_gen 三次整身透明图片编辑，经 generate2dmedia adopt 留存。没有视频。底层模型、实际图像调用费用未知；adopt 收录本身的 0 美元不代表图像调用免费。
- 编辑参考由 v01 中性完整人物按照当前 idle 高度一次整体缩放构成；四个相同参考格只用于锁定站姿，并非最终动画。实际最终帧全部来自新生成图。当前 idle 原图单独保留，新的 frame00 不是旧 idle 的像素复制。
- Gorest 检测实际格子、保留原生 alpha，仅清除 alpha≤8 残留；每方向四帧采用同一尺度。完整帧按静止头部和骨盆/下肢共同进行亚像素刚性注册，再统一采样；没有局部冻结、剪贴、变形或逐帧缩放。全部变换、哈希见各方向 normalization.json。

## 查看

- `four_directions_preview.gif` / `.webp`：四方向、明暗背景、2 倍显示、原速循环。
- `game_size_preview.gif` / `.webp`：128 画布 1:1，非 Godot 截图。
- `front_before_after.gif`、`back_before_after.gif`、`right_before_after.gif`、`left_before_after.gif`：左旧 v01 / 右新 v02。旧图未为比较重新对齐或改动。
- `before_after_preview.gif` / `.webp`：全部方向的新旧并排。
- `four_directions_contact.png`：全部四帧；`front/back/right/left/frames/` 为 16 张最终候选，`side/` 为右向规范源。
- `clips/animation-clips.json`：有效 skill 时序，四循环 / 16 帧；`QC_FINDINGS.md`、`comparison_metrics.json` 和 `export_verification.json` 为诊断与文件检查。
- Gorest `http://localhost:3000/` → Spritesheet Only，前四条已更新 v02，仍 confirmed=false；各方向播放/暂停/逐帧截图位于本目录。

## 效果与边界

静止区域匹配估计最大偏移旧→新：front 0.6188→0.1000 px、back 0.9851→0.0221 px、左右 0.5348→0.0928 px。该指标描述图像匹配，不是物理解剖位移。旧版 y=112 一致仍有整身漂移，不能再凭鞋底 bbox 或 alpha 重心宣称无位移。

正面和侧面的胸肩变化比旧版清楚，背面依旧克制。肩部横带 alpha 等效宽度范围：正面 0.789→1.384 px，侧面 1.030→2.588 px；这是包含衣袖/轮廓的诊断，不是实际胸围或抬肩幅度。背面该指标反而 1.263→0.606 px，旧版漂移参与旧值，不能声称四向同比增强。

网页逐帧检查未见明显抬脚、踏步、点头或整身大幅摆动，但仍有细微线条/alpha 重绘。四关键帧各停留 750 ms，阶段感仍在；背面幅度、各方向呼吸自然度、镜像光照及首尾衔接仍需用户看预览。skill 维持 needs-visual-review，不能据数值认定最终美术通过。

文件检查通过：16 PNG 与图集回读一致、左右镜像、4 帧/3000 ms；51 个运行相关文件哈希不变。Gorest 仅更新原四条候选，其他 45 条资产、ID/顺序及场景保留，lint/build 通过（既有 599.71 kB 体积提示留存）。当前运行仍 Godot 4.7.2 / 模板 2 / 100 px/s，静帧/行走尺寸差未动；未执行 Godot 呼吸切换或性能测试。

三套提示词、原图、引用图、adopt 回执和 provenance.json 可追溯。没有使用第三方商业游戏素材；生成图使用依供应方与账户适用条款，不声称公共领域或开源许可。本轮完成即停止。
