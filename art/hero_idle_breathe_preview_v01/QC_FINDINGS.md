# 检查记录与未决项

本轮为美术预览，状态 needs-visual-review。数值通过不能代替动作验收。

## 有效 skill 输出

`clips_fixed_feet/animation-clips.json`：build_animation_clips 0.4.0，4 clips / 16 frames / warnings=0，manifest_lint=0。PNG byte copy、WebP 时间轴/回读、tick 网格、重复/近重复检查通过；telegraph 与本轮无关，skipped。

| id | status | value | threshold | files |
| --- | --- | --- | --- | --- |
| loop_seam | needs-visual-review | 1.932789 | null | clips_fixed_feet/animation-clips.json，front/frames/front_idle_breathe_00.png…03.png |

各 clip 的 wrap_ratio：正面 1.932789，背面 1.231737，左右均 1.154970。正面首尾像素差高于微小的相邻差，但差异也含生成线条和 alpha；不能仅据比例认定通过或拒绝。保留完整 seam 数据供复查。

## 几何与人工观察

统一 128×128、原点 (64,112)，所有帧 alpha>16 的 bbox 下边界为 112，最小透明余量 16 px，无切断。身高：正面 89/89/90/90；背面 90/90/89/89；侧面 91/92/92/92。头部固定区域 alpha 重心变化不足 0.57 px，脚部横向重心变化不足 0.48 px；该测量受轮廓与透明度变化影响，不是解剖/脚滑认证。

接触表、明暗背景、onion 图及 Gorest 已目视检查。未发现明显新站姿、抬脚、踏步、大摆臂或点头；微小胸肩变化仍混有轻微线条重绘。原 neutral 比候选柔和，候选更清晰，不能声称像素级身份完全不变。正面收尾细小变化、背面轮廓变化、镜像光照和四帧节奏保留为待用户确认项。

首次注册的 y 轴舍入会让背/侧鞋底出现 1 px 差，已改为对采样后的可见鞋底边界作整帧整数注册，未拉伸或修改局部美术。历史 `clips/` 与 `qa_summary_first_registration.json` 留存，不作为当前候选。

## Gorest 构建提示

lint / build 退出码均 0。未修改应用代码。既有构建提示原文：

> (!) Some chunks are larger than 500 kB after minification. Consider:
> - Using dynamic import() to code-split the application
> - Use build.rolldownOptions.output.codeSplitting to improve chunking: https://rolldown.rs/reference/OutputOptions.codeSplitting
> - Adjust chunk size limit for this warning via build.chunkSizeWarningLimit.

`dist/assets/index-Bib4ba-7.js` = 599.71 kB，gzip 170.16 kB。此项不影响本轮序列预览；没有附带重构。

## 能力检查 WARN 原样保留

`doctor.json` overall=WARN，以下环境 WARN 的 threshold 均未提供（null），不是图像验收结果：

- python.path: other python.exe on PATH: ~/AppData/Local/Microsoft/WindowsApps/python.exe
- encoding.stdout: stdout=gbk: non-ASCII text can be garbled in pipes
- encoding.files: open() and read_text() without encoding= use cp936
- paths.cwd: the working folder has spaces or non-ASCII characters

本轮实际脚本均使用明确路径与 UTF-8 文件读写。可选 API keys / Grok CLI、ffmpeg、resvg-py 缺失状态保留于原始报告；本轮使用内置图片编辑和 PNG 输入，不依赖这些能力。没有额外安装软件或伪造视频。

## 未验证范围

没有接入 Godot，未验证停步/起步切换、实机循环与性能；当前静态 idle / walk 尺寸差按用户要求保留。不要把预览构建通过作为运行验收。
