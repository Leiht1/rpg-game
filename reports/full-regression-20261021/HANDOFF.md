# 换设备续测交接 · 2026-10-21

**当前已暂停；主批次结束，补测未开始。** 用户要求先写日志并推送，换设备后再继续。本文件是待办，不是已通过记录。

## 接续准备

1. 拉取`origin/main`，按项目规则读`AGENTS.md`、`PROJECT_STATUS.md`与 [REPORT.md](REPORT.md)。游戏源码测试基线为`a77c659b764f0de916b678a8f2920ba649ed6590`，交接提交只增加文档/测试记录与入口，没有修复游戏。
2. 当前137组：77通过、40未通过、19未完成、1依赖受阻，共144次尝试。证据见 [SUITES.md](SUITES.md)、[results.json](results.json)。只补缺口，没有相关改动或新证据不重复通过项；默认1280×720。
3. 原引擎路径`D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`，需匹配新设备。`run_regression.py`还有本机工作台Python路径，见 [environment.json](environment.json)。
4. 原沙箱`reports/.tmp/full-regression-20261021/project`、缓存、测试快照、私有账号/证书、LoginVault.exe本地构建副本及完整日志均未推送。重新建立源码副本/导入缓存、独立用户目录与新设备玩家JSON/tmp指纹；测试后再核对，不用真实账号，不动正式服务。
5. 主执行器直接运行会重跑主批次；`--resume`假定旧沙箱存在，并会重跑失败的旧脚本。应创建新的续测目录/记录，保留本轮证据，按待办选择运行。`run_supplemental.py`依赖原沙箱、前置快照和save-protection文件，**从未执行/验证，不能当作新设备一键续跑工具**。先读依赖、准备前置，保留`bootstrap.gd`延迟入口；只在副本适配旧夹具。

## 待测清单

### 放置夹具缺口：12组及两组重启

先核验旧脚本围绕`generator.spawn`摆放而当前加载区不同的原因。补测脚本提出在副本`tests/world_v06_formal_fixture.gd`覆盖`choose_entry_point()`返回`generator.spawn`，此方案尚未验证；不改正式出生规则或降低断言。

- `test_camp_build_v4 --formal`
- `test_camp_door_hinge_transaction_v3`
- `test_camp_h_damage_window_v4 --formal`
- `test_inventory_chest_v1`
- `test_chest_ui_v2`，成功建前置后再跑`restart`
- `test_cooking_build_v2`
- `test_campfire_drag_v1`
- `test_planting_v1`
- `test_seed_selector_v2`，成功建前置后再跑`read-destroyed`
- `test_sleep_formal_v9`
- `test_sleep_fit_v10`
- `test_sleep_collision_v11`

门面/正式铺面等独立建筑管理器缺service的脚本，还需另补测试初始化，出生点适配不保证解决。

### 入口、遗漏与跨进程前置

- `test_animal_art_formal_v2 --capture`：原交互模式超时，不算通过。
- `test_camp_expansion_front_v2 preview`：原window参数未进入测试主体。
- `test_build_shortcut_v2`：未跑；旧双尺寸循环只在副本收敛默认尺寸。
- `test_floor_running_v2`、`test_mushroom_density_v2`：未跑。
- `test_character_resume_v1`与`--consumed`：均未跑，需先生成隔离创建快照。人物创建主组183条中1条仍要求旧1024格，修订该旧断言后单独核验。
- `login_connection_smoke`：本轮私有HTTPS错误回复/不可达地址超时恢复未跑，需临时服务/端口/证书/虚拟账号，不连正式服务。
- 种植持久化仅写入2条通过，读取中止、收获后重进失败。需重新建立当前地图、加载区及作物时长前置，不能沿用失败前置认定收获成功。

### 失败核验与诊断

- **先复核220ms双客户端**：本轮两端退出1，普通及550ms通过。每次独立保留客户端/服务端摘要，避免日志覆盖。原包装日志无具体失败断言，根因未知。
- 按`suites.csv`分离旧配方/数量/音效/层级断言，与未解释的矿石持续采集/奖励、装备交换/原子保存、动物繁殖/剪毛、身体睡眠时钟/输入、料理工业结算回滚等。旧断言修订也需实际执行才能更新结论。
- 修测试入口/夹具：`test_player`的`phase_frame`推断错误、部分生态/路标缺键、采集前置资源/缺键、独立管理器缺service。保留原始失败证据。
- 数量投放完成检查后`ui_fade.gd::animate_window`已释放参数错误，以及各组ObjectDB/资源/RID退出诊断，未定位修复。
- 音效工作台缺soundfile、PySide6、mutagen，未装依赖，按工具requirements准备专用环境后再测。

### 长脚本和性能

- V3分布六组只完成前四组，待1536格Seed 271828、902106，并按当前鱼群规则调整旧上限断言。
- V3窗口后半段长时间地形采样/相关图形检查未完成；原150秒上限不代表游戏死锁。
- 新性能数据仅1024格及V4缓存/移动；1536格未重新采样。副本`perf-1536.json`为旧RTX 5060记录，不可当本轮RTX 3060测量。

## 保留边界

多分辨率当前不要求；旧版被替代的广泛回归及历史候选美术脚本未逐一执行，美术未因此获批。长期人工平衡/探索、满缓存、大营地/低配、16人负载、异机外网、新设备构建包与真实听感未完成。先处理具体缺口，不自动扩展额外验收。

本机结束时22份真实玩家文件数量/集合/内容未变、正式服务未动，见 [save-protection.json](save-protection.json)。新设备需重建自己的存档保护基线。临时媒体/日志/快照留本地；保留文字结论、失败摘要和指标。
