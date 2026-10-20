# 人物创建与换装 V1 · 交付报告

日期：2026-10-20。基于远端 `3fb13dc`（本地 `365111e` 已 fast-forward 同步）。全部新外观仍为候选，等待本批试玩审核；没有提交、推送或替换正式人物美术。

## 试玩

1. 双击根目录 `Start-Character-Creation-Preview.cmd`，选择性别、发型、肤色，查看正/背/左右侧。
2. 点击「进入世界」才生成新随机大陆；打开背包，右键时髦服装 → 装备，服装槽右键 → 卸下。
3. WASD/Shift、转向和已有劳动正常可用。关闭再打开继续原测试世界与角色；不再创建、不重复送衣服。
4. 重新创建时运行 `Reset-Character-Creation-Preview.cmd`。该操作备份精确试玩目录，不删除正式玩家档。CMD按项目约定只在本地；可同步入口为 [PowerShell脚本](../../tools/Start-Character-Creation-Preview.ps1)，支持 `-Reset`。

首次打开尚无试玩档；自动测试的所有世界在本报告目录，未放进给用户使用的试玩档。

## 实际运行图

均为 Godot 4.7.2 / OpenGL Compatibility / 默认1280×720真实GPU绘制，没有另造展示立绘。查看 [预览索引](index.html)。

- [人物创建界面](creation-ui.png)
- [男性四种发型：正背侧](male-hair-gallery.png)
- [女性四种发型：正背侧](female-hair-gallery.png)
- [六种肤色与默认/时髦服装对比](skin-outfit-gallery.png)
- [实际背包与装备](outfit-bag.png)、[世界人物](outfit-world.png)
- [四方向待机/走/跑/拾取/砍/采矿/挖掘](four-way-actions.png)：原 AnimationPlayer、同一服装渲染器及实际 HeldTool 组件。此图是指定相位采样，不能冒称连续人工试玩。
- [当前发型肤色睡眠头部渲染](sleep-current-head.png)：测试调用当前床被头部渲染器，未重跑所有设施的睡眠逻辑回归。

## 实现与存档

详细规则、真实部件结构、服装模板和JSON结构见 [人物系统规范](../../CHARACTER_CREATION_SYSTEM.md)。当前正式角色实际使用 Node2D 关节与 AnimationPlayer，没有 Skeleton2D/Bone2D；本轮保留现有层级和所有动画/碰撞。

独立存档为 `user://character-preview-v1/state.json`，外观按 `characters[角色ID]` 登记，原库存和位置用 `player_state_owner` 标明所有者；世界ID、一次发放标记、实际装备与世界原状态同一笔原子保存。无管理员/房主字段。正式身份/环境/物品旧路径和存档版本不变，原入口不启用新外观。未实现多人或跨玩家存档迁移。

首次保存失败回到选择界面，损坏存档保留源文件并阻止进入；装备保存失败回滚格/实例/别名。退出保存失败保留运行世界供重试。

## 定向验证

| 范围 | 数量 | 失败 | 证据 |
|---|---:|---:|---|
| 默认窗口创建/真实按钮/外观/安全出生/首次失败重试/装备事务/原动作库相位/同进程重进 |183|0|[checks.json](checks.json)|
| 独立新进程读档/四向实际走跑/四向真实采矿挖掘命中/睡眠肤色闭眼/损坏保护/销毁保存 |53|0|[resume-checks.json](resume-checks.json)|
| 再次新进程：服装已销毁不补发、保留归属/Seed/位置/外观 |4|0|[consumed-checks.json](consumed-checks.json)|
| 无头：正式装备回退、候选装备失败回滚、快捷别名及原图/候选哈希 |9|0|[contracts-checks.json](contracts-checks.json)|
| **合计** |**249**|**0**|仅统计最终检查，不累计重复试跑|

真实四方向走跑调用原物理流程，采矿和挖掘各四向实际时序命中一次；原所有动作库共采样多个相位验证握点有限、纹理替换不破坏原数据。装备/卸下含真实背包菜单点击。没有给用户试玩角色添加测试用工具；工具只在自动验收的独立数据内使用。

原正式 user:// 根JSON前后哈希比较通过；九张原人物PNG及六十张候选SHA核对通过，正式角色场景/动作与商人物品定义没有修改。默认窗口专项之外未做全量回归、多分辨率、长期人工平衡、大营地FPS或未来多角色/服务器兼容验收。

运行退出仍有资源释放诊断，最终主专项128个 ObjectDB 实例及2资源占用，读档专项100个及2资源，再次读档44个及2资源；不能将249项通过称为进程退出无警告。未附带重构既有生命周期；完整运行日志留在本地并按规则忽略。

## 美术与 QA

- 候选：[prototypes/character-creation-v1](../../prototypes/character-creation-v1)；数据入口 [catalog.json](../../prototypes/character-creation-v1/catalog.json)。8种发型各3向×2层48图、3底头、9服装部件，共60图。
- 来源：[provenance.json](../../art/character-creation-v1/provenance.json)，含原角色参考及60候选SHA；原图/提示/回执同目录。路由：generate2dsprite → route_media → **Codex（本地CLI）**。模型回执codex-image_gen，精确修订未知，订阅额度折算费用未知。首个服装请求TOOL_UNAVAILABLE，三参考图重试成功。
- 生成图没有严格等分，初版直接等分出现真实裁边和邻行碎片，未用于最终候选。已按实际空白边界重排，[所有权坐标](../../art/character-creation-v1/ownership.json)及[最终注册坐标](../../art/character-creation-v1/registration.json)可追溯。侧分短发另做明确单向梳拢轮廓，避免与自然短发近似。
- 最终 male-final、female-final、outfit-final 与 bald-processed 四套结构QA均pass，见 [QA汇总](../../art/character-creation-v1/qa-summary.json)。人体比例变异等用于动作的统计项标记skipped，不将不同发型/部件当作同动作帧评估；并非所有可能指标均已测。
- 初版历史警告完整保留：`male-processed/pipeline-meta.json` 的 `source_edge_touch_frames` WARN，value=`[[0,0],[0,2],[1,0],[1,1],[1,2],[2,0],[2,1],[2,2],[3,0],[3,1],[3,2]]`，threshold=`[]`；`female-processed/pipeline-meta.json` 同项WARN，value=`[[0,0],[0,1],[0,2],[1,0],[1,1],[1,2],[2,0],[2,1],[2,2],[3,0],[3,1],[3,2]]`，threshold=`[]`。最终重排后该项均pass，旧警告不是忽略或删除。
- 环境自检仍提示PATH上的Python别名、缺scipy、非ASCII路径；未安装的视频/矢量依赖本轮未使用。实际使用捆绑Python、Pillow/numpy及PNG原生动作，不依赖视频生成。

需要人工审核：发型轮廓和左右镜像自然度、长发肩颈/睡眠被沿关系、现代服装接缝与劳动极端相位、六种肤色观感。现有服装图标蓝色、身体候选青绿/橙条，颜色身份也待审核。结构QA不代替本批画风确认，正式采用前不覆盖原图。

## 文件清单

[本轮文件清单](FILES.md)列出新增/修改实现与资源目录。任务原文保持不改。临时截图按项目规则保留到本轮确认，确认后可清理；提示词、生成原图、来源和文字报告长期保留。
