# 云服务器部署记录

2026-10-28。目标 47.118.18.98，独立目录 /opt/apps/haotian，Compose 项目 haotian，TCP24870。

源码提交 b3b1b121 已推送 origin/main，包含墙边耕地、雨棚旋转和第29天探索条件。沿用已有23项窗口专项及此前第29天验证，本轮没有重复运行这些检查。git diff --check 报现有CRLF新增行尾空白提示，未改写整文件行尾。

使用 SQLite backup API 从公司部署 dist/network-v0.1.0/Data/state.sqlite3 读取一致快照，不停止或修改旧服务。迁移副本保留10账号及全部密码哈希，清空各账号world_id及worlds/characters/receipts。证书和Accounts迁移；原始快照、迁移包与构建文件仅本地私有目录，已通过.git/info/exclude排除，禁止提交。

程序按已提交运行文件打包，经SSH上传；未上传旧世界、玩家目录和历史备份。Linux Godot 4.7.2官方程序已下载，资源导入无ERROR/Parse Error/SCRIPT ERROR。Docker基础镜像已下载，依赖构建进行中；尚未宣称启动或公网验收通过。

最终：容器镜像构建完成，独立haotian-game-1已运行，restart: unless-stopped。容器重启后严格原证书TLS/API及数据库核对通过；10账号精确匹配迁移副本，正式世界/人物均为0。隔离临时目录完成激活/昵称/256格地形生成/角色创建/玩法快照/退出；最初测试遗漏昵称前置失败，补齐后通过，不曾写正式库。未测正式1536格新世界的完整性能和实际玩家密码登录。

公司电脑公网TCP24870连接超时；云机127.0.0.1严格TLS和API成功。云安全组/系统防火墙待管理员确认放行TCP24870，本账户sudo -n返回需密码，未修改系统防火墙。不能声称公网部署已验收。朋友原六个容器仍保持运行。

客户端 dist/Windrest-Cloud-2026.10.28.zip 使用当前代码构建，原公开证书，连接https://47.118.18.98:24870；尚未真实窗口连云验证。未发布旧自动更新地址，未切换公司服务器或其客户端配置。私有快照和迁移包不进入Git。

运维：ssh deploy-haotian@47.118.18.98，cd /opt/apps/haotian；docker compose ps / logs --tail 80 / restart game / stop game。所有docker命令无需sudo；不可在朋友项目运行清理命令。
