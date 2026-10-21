# 启动绿色背景修复 V6

2026-10-21，Godot4.7.2，默认1280×720。

## 根因和修复

实际玩家日志与普通启动均复现 launcher.gd:232 的解析错误：启动器继承Node，不存在get_viewport_rect()。脚本无法加载，因此看不到登录页，仅显示默认绿色背景。

将加载就绪条件中的视口尺寸读取改成 get_viewport().get_visible_rect().size，其余玩法及等待逻辑保持。上一轮双客户端测试直接实例化network_game_world，绕过了launcher，不能作为正常启动入口通过的证据。

## 验证与交付

- 修复前：正常主入口明确复现上述解析错误；修复后：同一普通主入口无错误。
- tests/launcher_startup_smoke.gd 按project.godot主场景配置加载：检查PackedScene可加载、登录页可见、账号/密码控件存在且可见，共4项通过。
- 原生1280×720运行并检查login.png，登录页面正常呈现。
- 打包客户端重新导出，再检查正常主入口和同一登录控件回归；结果见packaged-main.log、packaged-controls.log。
- 客户端BUILD.txt增加 Launcher startup fix V6。dist/Windrest-Client-v0.1.0.zip 已重新生成，保留10.215.26.56配置及公开证书。服务器程序、独立服务器包、账号、世界与玩家存档均未修改，不需要重新初始化或迁移。

没有重复全玩法回归、多分辨率或负载测试，没有提交推送。截图为本轮临时验证输出，用户确认后清理。

## V7 登录连接修复

服务器未运行导致登录等待；已启动现有部署。登录/激活连接超时上限改为8秒，HTTP连接使用工作线程并移除同步DNS查询（localhost仍明确走IPv4），失败显示目标地址并释放按钮。源码真实TLS登录错误回复及不可达地址超时恢复通过（约6秒），不使用真实账号密码，不改账号或世界数据。客户端重新构建并更新ZIP；服务器程序未改。

新增 tests/login_connection_smoke.gd；实际点击事件回归另见 tests/launcher_click_smoke.gd。未使用真实密码验证成功登录；未做异机测试。
