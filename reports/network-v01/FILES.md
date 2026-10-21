# 本轮文件清单

修改：`.gitignore`、`project.godot`、`scripts/character_creation.gd`、`CHARACTER_CREATION_SYSTEM.md`、`PROJECT_STATUS.md`、`DEVLOG.md`。

新增运行实现（相应Godot UID一并保留）：

- `scenes/launcher.tscn`
- `scripts/launcher.gd`
- `scripts/network_client.gd`
- `scripts/network_world.gd`
- `scripts/network_actor.gd`
- `scripts/network_terrain_worker.gd`
- `scripts/network_inventory_worker.gd`
- `config/network-client.json`、`config/network-server.json`
- `tools/network/server.py`、`build.py`、`pack_candidates.gd`、`requirements.txt`
- `tools/Start-LAN-Server.ps1`、`Stop-LAN-Server.ps1`、`Prepare-LAN-Client.ps1`、`Allow-LAN-Server.ps1`
- `MULTIPLAYER_V01.md`、`tools/network/部署说明.md`

新增候选：`prototypes/network-menu-v1/background.png`、`logo.png`；原图/提示/生成回执/哈希/QA在`art/network-menu-v1/`。既有正式美术与已有候选PNG保持原样。

新增验证：`tests/test_network_server.py`、`run_network_native.py`、`network_native_smoke.gd`、`network_reconnect_smoke.gd`，相应UID；本报告、FILES、terrain-performance.json及包清单/指标。测试代码中的固定测试密码仅用于临时隔离服务，不是部署默认密码；实际部署没有默认密码。

不提交：`dist/`运行包和本机Data、`server-data/`、`config/server-public.crt`、reports/network-v01/private内隔离账号/数据库/测试配置、临时截图/日志/构建缓存。公开证书在客户端ZIP中用于TLS验证；私钥不进入客户端。
