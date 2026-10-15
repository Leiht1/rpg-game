# gorest 主角帧动画试验

结果：生成了新的主角正面行走完整帧，整理为 8 帧 / 8 FPS / 1 秒循环，并已在 http://localhost:3000/ 的 Spritesheet Only 页面播放。素材是试作，未接入 Godot，也未替换现有运行资源。

## 来源与处理

- 身份参考：`art/reference/hero.png`，SHA256 `b5cf99577c02c053236d86760b9654b7c3fc88210d606dbacf8a2bf6de6dcdbf`。
- 图片生成经过 generate2dsprite / generate2dmedia 的受控路由，实际路由为 **Codex (local CLI)** / `local:codex-cli`。回执模型标识为 `codex-image_gen`，底层图像模型未公开。2 次真实图片调用，非视频生成。订阅配额回执的 0 美元估计没有逐次美元报价含义。
- 第一版实际输出 1254×1254、16 格；相位顺序与摆臂不合格，保留在 `take1/`，不交付为动作。
- 修正版实际输出 1774×887、4×2 共 8 格；完整源图、修改提示词、输入哈希、回执保留在 `take2/`、`correction_prompt.txt`。
- 使用 gorest 自带 `scripts/normalize_spritesheet.py` 去色键、检测实际格子边界、统一缩放和上身锚点。全局缩放 0.4100135614；未拆肢体、绘制补丁、逐帧缩放、镜像或变形。
- 源图顺序仍有错，将完整帧按零基索引 `[0,5,6,7,3,2,1,4]` 重排为双步循环。接触姿势的两张近似绘制均保留，因此存在停顿节拍。

## 交付

- `front_walk_preview.gif`：浅色 / 深色背景并排动画预览，8 帧，1 秒循环。
- `front_walk_preview.webp`：无损动画预览。
- `front_walk_sheet.png`：1024×512 RGBA 透明图集，单帧 256×256。
- `frames/front_walk_00.png` 至 `front_walk_07.png`：完整透明单帧。
- `front_walk_contact.png`：带帧号的静态核对图。
- `gorest_preview.png`：gorest 实际预览页截图。
- gorest 素材项：`asset_windrest_hero_front_walk_trial_v01`，名称“风栖原野主角 · 正面行走试作（8帧）”；`confirmed=false`。只新增此素材及可复用动作，不修改已有素材或场景。

## 实际核对与限制

- 8 张不同完整帧，透明边界最少 25 px；源格子边缘风险 0。完整身高 CV=0.005079，首尾像素差 / 中间相邻差中位数=0.822276。这些数字不代表步态、解剖或循环的美术验收。
- 目视可见左右脚交替与抬脚，但接触帧停顿、摆臂过渡和少量脸/头发绘制变化仍然存在。新绘制线条比原图略硬；未标为最终游戏素材。详见 `take1/review.json` 和 `take2/review.json`。
- 已打开实际 gorest 页面，核对 1024×512 源图、4×2 网格、256×256 单帧、8 个帧按钮及播放时帧计数推进；浏览器留在循环播放状态。
- gorest `npm.cmd run lint`、`npm.cmd run build` 均通过。构建保留原有打包体积提示：JS 599.71 kB，超过 500 kB 提示阈值；本轮未修改应用代码或处理该提示。
- 未运行无关 Godot 回归或性能测试；当前游戏运行版本仍是既有 V0.1 角色完整帧重建。

本轮试验完成，到此停止。
