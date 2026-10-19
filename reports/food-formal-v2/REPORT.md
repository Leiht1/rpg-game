# 四道料理图标正式接入

2026-10-19。用户确认原话：“还不错，接入游戏吧”。仅本批四图获准。

prototypes/food-v2/final中的烤土豆、烤卷心菜、蔬菜汤、炖杂蔬四张128×128透明PNG按SHA原样迁入assets/cooking/v2，data/items.json的icon/world_visual均改为正式路径；背包、食谱、领取获得提示与地面显示复用现有统一纹理入口。未生成或修改画稿、未改变食谱/数值/存档，不需要预览开关。

Godot4.7.2、默认1280×720原生窗口隔离验证17项0失败：正式模式1、四图正式引用/哈希/三纹理入口加载12、四张食谱卡图标4。结果checks.json，测试tests/test_food_formal_v2.gd。未重跑前轮已通过的身体、睡眠、拾取、存档与烹饪全套逻辑；无玩家存档读写，无提交/推送。

来源及批准范围记录在assets/cooking/v2/provenance.json。保留原route=local:codex-cli、model=codex-image_gen、提示词、原图及候选预览。原图boundary_band=118/threshold0、safe_frame=4/threshold0警告继续留档；处理后结构QA通过，本次未再生成或加工。不扩大批准到未来素材。

按AGENTS用户确认后清理规则，已删除前轮reports/food-v2/hallucination-book.png、normal-book.png两张临时测试图，清单cleanup.json；保留前轮文字报告、指标、正式素材、原图和prototypes/food-v2/preview.png。本轮未另生成截图。完成停止。
