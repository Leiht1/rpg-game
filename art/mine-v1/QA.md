# 矿洞素材与实际场景检查 · 2026-10-25

路线：generate2dmap / generate2dsprite → generate2dmedia route_media.py → local:codex-cli；模型标识 codex-image_gen，精确后端修订不可得。所有源图、提示词、用户反馈参考、处理与SHA见 provenance.json。不是程序绘制替代矿洞美术；仅引线火星/烟尘复用轻量运行表现。

首稿失败：外部矿洞描边过粗、与周围环境岩石不同，用户指出像贴图；内部下方暖色光斑给人从洞内往外照的印象。保留首稿与提示词追溯，运行已改用 entrance-v2-source 和 interior-v2-source。新洞口降低粗轮廓，灰蓝/沙色细碎面跟随用户截图；保留三道斜痕、低木支架、独立封堵。底部没有地色补丁或整张地面蒙版。内部把门口设为外部日光源，光斑向洞内上方拓宽衰减，门柱阴影向内；后侧小提灯为单独弱暖光。

PNG按固定所有权裁开、等比显示，洋红抠除与边缘净化。运行入口/岩块/工具箱/包独立，人物沿原Y排序，房间地板背景与人物分离。实际1280×720场景核对封堵/安放/开启/进入/返回、真实角色尺度、接地、光向；具体证据在 reports/mine-v1。

内部QA地图只是 mine_rules.gd 的可行走矩形投影，非第二套运行地图。bundle-final-qa.json 0错误0警告；nav-final-qa 的3个起点到2个目标均可达、thinGaps=[]。浏览器预览产出成功，但 verify=SKIPPED：未安装 playwright 对应 chromium_headless_shell-1234。此项不冒充通过；原生Godot真实移动/碰撞/进出另有验证。

forge_doctor 原始诊断保留：WARN python.path（WindowsApps别名，实际使用依赖内Python）、deps.scipy（未安装，未使用）、encoding.stdout/files（后续PYTHONUTF8=1且显式UTF-8）、paths.cwd（中文路径，均引号传入）；MISSING resvg-py、ffmpeg、可选API密钥、Grok。此轮使用已验证的Codex本地图像路线，不依赖这些缺项。完整原文、值和建议见 doctor.json；不把环境检查称全绿。

这些修订PNG已按用户本轮开发/修图要求用于运行，尚无本批具体审美确认。临时实景截图保留到用户确认；生成原图、来源及参考不属于待清理测试媒体。
