# 世界资源生态优化 V1 + 路标系统 V1

日期：2026-10-19。正式工程增量接入；Godot 4.7.2 stable，原生窗口 1280×720。未提交或推送。

## 本轮实现

- 岩石区使用原世界噪声生成连续陆地区域；不改变大陆、湖岸、树木坐标及世界 Seed。地表采用平坦灰米色手绘岩纹，无独立凸起岩头；地图增加对应地貌颜色。原泥地地表仍保留。
- 自然资源配置 0.4.0、矿物/埋藏物配置 2.2.0：草原偏花叶、胡萝卜与浆果；森林偏枝木、蘑菇与果实；泥地偏根茎与埋藏物；岩石区为主要矿区；湖岸降低密度。非岩石区保留少量石矿、燧石和自然燧石。
- 保持原坐标资源 ID、采集结算与消耗记录；接受此前资源版本。迁移时用旧算法重建已有未完成采集记录的原种类和位置，写入原 ore_nodes，避免因分布改变而替换正在采集的目标；已消耗资源继续过滤。背包、建筑及原快照路径保持。
- 新增正式路标配方：木头×3、植物纤维×2。合法选址后输入 1–6 字；确认时重新检查原库存快照、合法性及保存结果，取消、空名、材料变化或保存失败均不生成、不扣料。内容随建筑保存，不提供改名入口；靠近显示内容，沿原锤击拆除体系移除。
- M 地图每帧读取同一建筑 states 的路标位置/名称，无第二份标记存档；支持缩放、拖动、区块卸载、拆除与重载。

## 修改文件

- 地形：scripts/world_generator_base.gd、world_generator.gd、terrain.gdshader、chunk_stream.gd；assets/environment/ecology_v1。
- 生态与兼容：data/natural_resources.json、harvest_resources.json；scripts/harvest_distribution.gd、item_service.gd。
- 路标：data/camp_buildings.json、buildings.json、items.json；scripts/camp_buildings.gd、camp_building.gd、campfire_ui.gd、item_ui.gd、world_map.gd；assets/buildings/signpost_v1。
- 定向测试：tests/test_ecology_signpost_v1.gd、test_ecology_signpost_visual_v1.gd、test_ecology_compat_v1.gd；隔离快照忽略规则。
- 规范：NATURAL_RESOURCE_ECOLOGY.md、ORE_SYSTEM.md、MAP_SYSTEM.md、CAMP_BUILD_SYSTEM.md、ART_STYLE.md、PROJECT_STATUS.md、DEVLOG.md。本报告只说明本轮；保留已有其他改动。

## 验证

| 记录 | 结果 | 覆盖 |
|---|---:|---|
| headless.json | 48/48 | 数据、事务、分布、迁移、保存与采集 |
| window.json | 54/54 | 默认原生窗口、命名、取消、6字限制、不可改名、扣料及失败回滚、锤拆、地图、矿物真实掉落 |
| supplement-window.json | 14项有效检查通过 | 原生字母输入不触发快捷键、Escape、GUI确认、靠近提示、完整地图、滚轮与拖动、自然拾取、埋藏物挖掘/重载、实际资源落点 |
| restart.json | 5/5 | 独立新进程恢复路标、库存、已采集及部分采集矿物 |
| compat-corrected.json | 6/6 | 旧版部分挖掘目标精确恢复种类/位置/进度及保存重载 |

补充窗口记录中另有 1 项失败：测试任意指定的旧埋藏物 ID 在旧算法下并不存在，属于无效夹具。已修正为先寻找真实旧目标，并以 compat-corrected.json 定向复核通过；未重跑已通过的其他窗口检查。保留原记录，不将其描述为全绿。

三 Seed 粗采样：20,087 个陆地采样格、3,589 个岩石区格；3,380 个矿物候选中 3,060 个位于岩石区（90.5%），旧泥地区 45 个（1.3%）。连续性检查通过。实际 25 个陆地区块完成原间距/遮挡等筛选后，33 个矿物中 26 个位于岩石区（78.8%），旧泥地 1 个；五矿种均出现。候选统计与最终生成统计分开记录，不能视为所有 Seed 的保证。

真实窗口截图已查看：岩石区平面岩纹及矿物、路标世界提示、命名窗口、完整地图标记。截图临时留在本报告目录，等待本轮效果确认后按规则清理。全部测试使用隔离世界和隔离快照，不写玩家档；无全量回归或多分辨率检查。

## 美术来源与边界

新图通过 generate2dmap / generate2dsprite → generate2dmedia route_media.py → Codex local CLI 生成。首张地表含凸起小石而弃用，最终平坦版本原样迁入 rocky.png；路标为独立正面空白木牌，经软抠与 256 画布处理。提示词、原图、来源 SHA、处理命令与 provenance 保留在 art/ecology-signpost-v1 及正式资产目录。路标 strict QA 通过，无残留不透明底色；环境 doctor 有可选依赖缺失、编码/非 ASCII 路径警告，未阻塞生成，不宣称全部环境 QA 无警告。

本轮任务授权正式接入，不伪记为用户已确认新图视觉。新地表和路标主观美术效果仍待试玩评价。未验证长期平衡、所有 Seed、大营地 FPS、长期人工游玩或全分辨率；未扩展动物、任务、传送、寻路、改名或其他建造功能。没有已知未解决的本轮功能故障。本轮完成停止。
