# v02 检查记录

状态 **needs-visual-review**。v01 已被用户拒绝，不能以旧数字/目视结论代替此次预览。

## Skill 原始 QA

`clips/animation-clips.json`：build_animation_clips 0.4.0，4 clips / 16 frames / warnings=0。PNG byte copy、WebP 时间轴/回读、tick 网格、near_duplicate_holds 和 manifest_lint 通过；telegraph skipped。没有 WARN / FAIL；以下非通过项保留原值，未改为 pass：

| id | status | value | threshold | files |
| --- | --- | --- | --- | --- |
| loop_seam | needs-visual-review | 1.09965 | null | 原检查未提供 files 字段；来源 clips/animation-clips.json |

完整 QA envelope 保留在 animation-clips.json。各循环 wrap_ratio：front 1.099650，back 0.926677，right/left 0.847831；不是人体或自然度认证。

## 位移与幅度分别检查

`comparison_metrics.json` 保留旧/新全部静止区域残差、零偏移 RMS、胸区变化和横带宽度。头部 y15:51、下肢/骨盆 y81:116（横向 x24:105），对首帧估计额外刚性偏移。新版最大片段残差 front 0.1000 / back 0.0221 / 左右 0.0928 px。原理与采样会影响估计，不能宣称零漂移、像素冻结或真实脚底位置绝对相等。

胸区 y52:77 单独检查。正面、侧面吸气形变更可见；背面仍偏小，不声称全部方向的真实胸腔幅度都增强。源图重绘仍会改变衣褶和边缘；没有用代码扩张胸部或复制头脚掩盖变化。四帧慢循环的自然程度需要用户确认。

16 PNG 均为 128×128 RGBA，四张不同帧，alpha>16 余量至少 16 px；正背可见高度各89、左右91，整帧无逐帧缩放。图集回读、左右镜像、GIF/WebP 4 帧 / 3000 ms 检查通过。共享原点 (64,112) 为声明的画布原点，并非物理脚底测量。

## Gorest 与未变范围

实际浏览器检查四方向、4帧/2×2网格/128画布；正面 Frame2/Frame4、右侧 Frame2 暂停检查后恢复播放。原四条呼吸候选在原ID/顺序更新至v02；49条总量和其他45条数据保留。截图见 gorest_*.png。

lint/build 退出码 0，日志 gorest_lint.log、gorest_build.log。保留既有构建提示原文：

> (!) Some chunks are larger than 500 kB after minification. Consider:
> - Using dynamic import() to code-split the application
> - Use build.rolldownOptions.output.codeSplitting to improve chunking: https://rolldown.rs/reference/OutputOptions.codeSplitting
> - Adjust chunk size limit for this warning via build.chunkSizeWarningLimit.

files=dist/assets/index-Bib4ba-7.js，value=599.71 kB（gzip170.16 kB），threshold=500 kB。未修改应用代码。

51个角色运行资源/脚本/场景/配置哈希不变；没有接入呼吸或运行 Godot 切换/性能测试。无本轮游戏性能数据。未重跑无关回归，也未重跑或重新发布旧环境 doctor；其历史结果仍在 v01 目录。
