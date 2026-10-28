# 云服新角色发型校验修复 · 2026-10-28

客户端实际catalog有10款发型，但源config/network-server.json和云服Config仍只有旧8款，遗漏unisex_mohawk及unisex_bun。角色创建接口按配置并集校验，因此这两款被拒绝，世界其实已建立（正式库当时1世界、0人物）。没有修改角色美术或放宽非法ID检查。

最小修复：源配置和云配置hair_ids新增unisex分组含这两个ID；原8款、性别自由选发型及6肤色保持。服务端配置热读只在启动时生效，已备份旧配置并重启本项目game。无需新客户端/更新包/签名版本。

测试新增正式配置发型集合与真实catalog完全相等断言，并用两隔离账号实际创建男性莫西干/女性丸子头；test_network_server.py 22项通过，Godot4.7.2。

云机docker exec使用实际项目、修改后配置及临时Data跑Service.create_world/join_world/character：10ID一致，两款真实角色创建成功，非法ID拒绝。测试地形用128格导航fixture，角色库存仍由真实Godot规则进程处理，不代表正式1536地形完整窗口测试；未读写正式玩家库。

正式停服后SQLite backup保存backups/sync-v1/before-appearance.sqlite3；重启前后逻辑payload SHA256一致（cdc2f39c6bfa2cbf083473f031b2f893e2f4afc020f6297aef7abf982480cd24），10账号、1世界、0人物保持。公网真实Godot严格TLS探针通过，复用后48–49ms。未使用玩家密码或操作真实账号角色；用户重新登录并继续原世界创建人物即可，无需删除世界。未提交推送。
