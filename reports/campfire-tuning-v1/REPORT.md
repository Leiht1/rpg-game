# 篝火与食物局部修订 · 2026-10-17

按用户四项反馈完成，不扩展其他玩法。

- 火焰：原flame PNG不改，以campfire_flame.gdshader只形变上部，UV.y≥.82的底部固定；不再改变整图scale/position/alpha。画稿底缘与木柴接点不移动，无新PNG或图片生成。
- 食物：现有野生浆果/棕蘑菇饥饿+3，野胡萝卜/野苹果+4，野花保持+1；烤胡萝卜+12、烤蘑菇+10。原生命收益（浆果1、胡萝卜与烤胡萝卜2）保持。全部通过现有ItemInventory/BodyState使用与饱腹判定，其他身体参数不改。数据库无“椰果”，没有虚构新ID。
- 提示：成功投料静默，不再显示增加秒数或其他成功通知，原错误/失败原因继续显示。
- 雨天：晴1倍、小雨1.5倍、雷暴2倍燃耗，按现有雨量和雷暴混合值平滑过渡。烹饪仍按正常模拟秒推进；例如风暴仅有3秒燃料时，2倍燃耗最多支持1.5秒烹饪，然后熄灭暂停。暂停、调试一天预览、未点燃均不扣燃料。原燃料容量、投料价值、照明、存档路径与字段版本不变。

## 文件职责

`scripts/campfire_flame.gdshader`新增上部形变；`campfire.gd`改为固定Sprite变换/透明度、仅推进shader相位；`campfire_throw.gd`去成功通知；`campfire_service.gd`按雨天倍率扣燃料但按实际可燃烧时间推进烹饪；`environment_view.gd`传递既有天气混合；`data/campfire_rules.json`集中雨天倍率；`data/items.json`调整七种已有食物收益。原PNG、角色动画、库存及存档格式未改。

同步AGENTS、BODY_SYSTEM、ITEM_SYSTEM、CAMPFIRE_SYSTEM、WORLD_ENVIRONMENT、DEVLOG。新增`tests/test_campfire_tuning_v1.gd`；原核心/身体断言更新为新食物数值，拖拽专项补静默通知断言。

## 实际验证

Godot4.7.2 Stable / Windows / Compatibility / NVIDIA RTX5060：

| 实际运行 | 结果 | 证据 |
|---|---|---|
| 新专项真实窗口 | 32项，0失败 | ../campfire-tuning-window-first.log、window.json |
| 原篝火核心必要依赖（无头） | 74项，0失败 | ../campfire-core-tuning.log |
| 原生拖拽/投掷必要依赖（无头） | 49项，0失败 | drag.log，包含成功投料静默断言 |
| 身体系统必要依赖（无头） | 533项，0失败 | body.log，原食用断言按+3浆果更新 |

新专项实际调用七种食物原库存使用，每种均核对真实饥饿收益、消耗及饱腹保留；晴/雨/雷暴燃耗、混合过渡、燃尽时的实际烹饪秒数、不点燃/暂停/预览不扣，以及实际environment_view适配均运行通过。

真实GPU画面对比phase0与.35：底部区域235像素取样，变化0；上部区域变化470像素。两帧完整游戏实景`flame-a.png`/`flame-b.png`，同时运行核对整图transform/modulate不变。它证明本次取样/镜头下底部固定且上部实际变化，不冒称所有缩放或每个像素已穷举。没有本轮脚本运行失败；不做无关全量回归、全图/FPS基准或长期平衡结论。主观动效和新食物节奏待玩家试玩。

上一轮reports/campfire-v1中的食物42/32及成功投料秒数截图为历史方案；当前以本文与正式数据为准。本轮完成后停止。
