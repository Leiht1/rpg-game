# 木箱开盖正式接入

2026-10-19，用户确认“接入吧”，仅批准上一轮展示的本批开盖木箱图。

- 原样复制prototypes/chest-open-v1/final/wood_chest_open.png至assets/buildings/chest-open-v1/wood_chest_open.png；SHA256双方均为c0f83ff97ca8bb495a890d9ac230b29a97dd2c4c5664e2fdb6aa01563040b1bb。来源、生成路线、授权原话与范围见正式provenance.json。
- scripts/camp_building.gd移除开盖图预览开关条件，改用正式路径；闭合PNG、宽80、底部Y=8及现有九宫格布局保持。普通Start-Playtest.cmd直接生效，旧档按原open状态显示，无存档迁移、物品投放或PNG重绘。
- 新增tests/test_chest_open_formal_v1.gd；工程资源导入完成。Godot4.7.2默认1280×720原生窗口、关闭chest_open_preview，合法放置/闭合图/开盖正式路径/九宫格尺寸与层级/关闭/隔离保存9项0失败；独立新进程恢复open、物品和正式画稿3项0失败。截图open.png。
- 测试使用同Seed隔离fixture与本报告目录save.json，不读写玩家档。本轮仅验证资源推广及开关/持久化必要路径，未重复上一轮66项与播种20项，未做多分辨率、长期人工或大营地性能。
- 更新ART_STYLE.md、CAMP_BUILD_SYSTEM.md、PROJECT_STATUS.md和DEVLOG.md；旧候选报告保留历史并添加正式接入入口。批准不扩展到未来图，完成本轮停止。
