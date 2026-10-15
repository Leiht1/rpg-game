# 已确认整套修订接入 · 模板 4

2026-10-15，用户授权：“好多了，把这一版都接入游戏吧，另外把游戏里的移动速度再调快一点”。

正面/背面行走采用 v04，侧视行走采用 v06，四向呼吸采用 v05（背面保留 v04）。front/back/right 映射为 front/back/side，left 由 side 整帧镜像。全部 36 张已确认 128×128 RGBA PNG 原样复制，scale=1、offset=(0,0)，原点 (64,112)，没有重绘、局部编辑或重新注册。来源与每帧哈希在 `staged/animation/registration.json`。

呼吸为 27 个 60 Hz tick/帧，即 450 ms×4=1.8 秒。速度从 100 提高至 115 px/s（+15%）；行走仍由碰撞后实际位移驱动，周期距离 200/3 px 不变，因此实际步频为 13.8 帧/秒，约 0.5797 秒/周期。导出中的 12 FPS / speed_ref=100 是参考时间轴，不覆盖游戏位移时钟。斜向归一化、停步朝向、左右镜像与转向相位保留。

采用 generate2dsprite 的既有素材构建与 Godot 导出，本轮 art_source=existing，图片/视频调用均 0 次；原来源为 host:image_gen / generate2dmedia adopt，历史模型及费用未公开，许可边界沿用原目录。角色模板升为 windrest-character-template-4，地图生成器仍 windrest-0.1.0。模板 3 全资源备份在 `previous_runtime/`，原脚本/规范/报告在 `previous_*`，接受记录在 `acceptance.json`。

最小验证通过：六动作 / 36 帧源哈希、模板、透明边界、图集与导出文件匹配；Godot 4.7.2 实际导入成功。OpenGL 3.3 / NVIDIA RTX 3060 渲染四向呼吸及行走共八姿势。短游戏专项约 6 秒、0 failures：八方向 12 tick 实测 22.9922～23.0039 px，目标 23 px；20 个呼吸边界样本，实际走完八帧、位移相位、停步和短呼吸检查通过。

当前证据为 `../../reports/character-smoke-tests.json`、`character-smoke-poses.png`、`character-world.png` 和本目录 Godot 日志。没有重跑历史长玩家专项、树石/湖岸专项、地图、性能或打包。旧 `player-tests.json`、`character-godot-poses.png` 等历史证据不能当作本版完整回归结果。

工具原 QA 仍 needs-visual-review（loop_seam=1.533159，threshold=null），warnings=0，Godot 导出 pass。用户确认的细微线条/颜色/投影变化、身体起伏和镜像光照继续保留，不宣称零滑步或完美连续；详见 QC_FINDINGS.md。接入完成，重新运行游戏即可体验。
