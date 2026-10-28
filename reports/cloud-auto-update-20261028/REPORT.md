# 云服自动更新 · 2026-10-28

已启用https://47.118.18.98:24870/updates/，复用游戏端口。原发布工具、旧冻结启动器及签名密钥沿用，没有修改更新器代码。生产Compose新增./Updates:/srv/Updates:ro；修改前备份backups/sync-v1/compose-before-updates.yaml。只重建本项目game容器。

签名版本2026.10.28.2、sequence2026102802，使用本轮同步修复Client。先上传SHA命名不可变ZIP，再latest.json.new原子替换；私钥仍仅本机构建目录，不上传云端，不进入分发包。服务端更新与匹配客户端签名发布必须共同完成，后续步骤见tools/network/自动更新说明.md。

交付：dist/Windrest-Cloud-AutoUpdate-2026.10.28.2.zip（完整启动器首包），dist/Windrest-Cloud-Config.zip（已有自动更新版的一次迁移，仅Config及说明）。旧内网地址需要覆盖配置一次，后续关闭游戏重新运行WindrestLauncher.exe自动检查/下载；直接Windrest.exe没有检查更新能力。根Config保持，账号记忆和用户存档不在更新包内。

验证：原2026.10.27.1首包冻结启动器的隔离副本，覆盖云Config后，以--check-only从真实公网完整下载155MiB签名包并升级至2026.10.28.2；逐运行文件SHA、签名、旧版本保留及云配置保持通过。再次同版本检查退出0，不重复下载。完整首包ZIP CRC通过，verification.json留档。既有updater单元测试11项通过（签名/受控安装/失败保留及版本清理等），无新代码未额外扩展测试。

生产重建后严格TLS/API通过，10账号哈希2b62c6f249ec369ae825bcb746a70cba54810a2f15c30e825f78daebb9c3f771保持，正式世界/人物0；未用真实玩家登录，不写正式存档。测试副本仅private目录，已Git排除。首次本地打首包读取UTF8清单时使用系统默认编码失败，显式UTF8后完成，未影响线上发布。

实际验证覆盖冻结启动器无界面检查模式的完整下载/安装，没有操控GUI按钮或让更新后的游戏进入正式世界；游戏内容联机测试沿用同步修复报告，不重复。未配置旧公司更新地址重定向，旧用户必须进行一次云配置迁移。未提交推送。
