# 《风栖原野》V0.1

原创温暖手绘随机原野，当前只包含大地图、完整序列帧主角、移动与性能调试。主角保留未来逐帧模块换装模板，当前只有一套服装。

## 打开和操作

1. 使用 **Godot 4.7.2 Stable** 导入本目录的 `project.godot`。
2. 等待首次图片导入完成，按 **F5** 运行主场景。初次进入显示短暂地图加载画面。
3. **WASD / 方向键** 八方向移动；**鼠标滚轮** 缩放；**F3** 显示/隐藏 FPS、帧耗时、区块、对象和 Godot 内存指标。

运行游戏不需要 Python、图片生成服务或任何 API key。工程不依赖项目目录以外的美术文件。

## 地图参数

在 `scenes/world.tscn` 的根节点 Inspector 中修改 `World Seed`、`Map Cells`，保存后运行。默认 Seed 为 271828、地图为 1024×1024 格；支持 128～1024 格。每格 48 px，区块为 24×24 格；地图不会一次性实例化所有对象。

也可从命令行启动（将 `godot` 替换为本机控制台版 Godot 可执行文件）：

```powershell
godot --path . -- --seed=42 --size=1024
```

相同 Godot 版本、相同生成器版本 `windrest-0.1.0`、相同 Seed 和地图尺寸应得到相同结果。更改尺寸也会影响河湖位置，复现时请一并记录尺寸。水域不可通行，河流的浅滩可步行跨越。

## 主角及美术

当前使用一个完整角色 AnimatedSprite2D，front/back/side 各四张呼吸待机及八张行走帧，左向复用完整侧面镜像。正/背行走沿用已确认 v04，侧面采用按 v08 原姿势统一重绘并确认的 v11，呼吸沿用 v05 脚底修订，450 ms×4=1.8 秒。常规速度为 **115 px/s**，斜向速度归一化。统一 128×128 画布、(64,112) 脚底原点；行走按碰撞后实际位移推进，周期距离仍为 200/3 px，当前步频为 13.8 帧/秒。旧 14 层裁片与关节烘焙已停用，不能作为未来服装的模板。

`assets/hero/` 下 `reference/` 保存身份、三视图与当前帧预览，`final_sprite/` 保存 36 张完整帧，`animation/hero.tres` 是可直接加载的 Godot SpriteFrames，`modular_plan/` 保存模板 5 的哈希和相位。后续身体、发型、上衣、裤装、鞋子及饰品须按同方向、同帧模板逐帧重绘；完整规则见 `CHARACTER_MODULAR_RULES.md`。本轮没有正式换装系统。

全部图片经 `generate2dsprite` skill 的受控图片工作流生成，经过候选筛选、透明裁片整理和实际导入；未使用外部商业游戏素材。详见 `art/ASSET_MANIFEST.md`。新增素材前必须读取 `ART_STYLE.md`。

**动画质量：侧视 v11 经用户确认后接入。** 本轮仅原样替换 8 张侧面行走 PNG，其余 28 张运行帧保持字节一致，没有新图片或视频调用，也没有重新缩放。源图由 host:image_gen 生成、generate2dmedia adopt 留存并用 Gorest 整理；本次采用 generate2dsprite 的现有素材打包/导出。仍保留轻微轮廓、颜色和侧面投影变化，左向光照随镜像翻转。未宣称零滑步、人工逐帧手绘或图生视频成果。

![当前主角实际场景](reports/character-world.png)

## 验证和性能

本轮仅做匹配接入范围的最小验证：36 PNG 源哈希/模板/图集及 28 张保留帧核对，Godot 4.7.2 导入、四方向全部 48 个固定姿势渲染、八方向短移动、完整行走周期及走停呼吸通过。没有重跑历史 180 次切换、树石/湖岸专项、地图或性能回归；详见 `reports/CHARACTER_VALIDATION.md`。早期地图与性能验证保留在 `reports/VALIDATION.md`。

以下为角色重建前的历史性能数据，本轮未重跑压力测试：RTX 3060、1280×720、关闭垂直同步的 90 秒加速跨区块测试 P95 1.32 ms、P99 1.849 ms、最大 18.444 ms；加载 230 / 卸载 200 区块，未记录缺地面或可视缺块。Godot 静态内存峰值 62.79 MiB。不能将其作为本轮角色版本的实测性能或所有配置稳定 60 FPS 的承诺。

只验证本轮和必要依赖，无额外玩法与全量回归。

## 相关文件

- `ART_STYLE.md`：长期美术规范与参考色。
- `AGENTS.md`：后续执行边界与美术流程。
- `DEVLOG.md`：交付、实际验证、能力和遗留问题。
- `art/`：生成候选、样板、源部件、动作预览、来源、QC。
- `assets/`：运行时透明图集及环境图片。
- `reports/`：机器可读测试结果、性能原始数据、Godot 实际截图。

复现相关验证：

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_world.gd
godot --headless --path . --script tests/test_player.gd
godot --path . --max-fps 60 --script tests/test_character_smoke.gd
godot --path . -- --benchmark --seconds=90 --report=stress-1024
```

最后一条会运行渲染压力测试并结束，报告写入 `reports/`；加速穿越仅用于测试，不影响正常移动。`--capture` 会增加 GPU 读回开销，性能测试时不要使用。

当前角色导入记录为 `tools/integrate_side_walk_v11.py`，检查为 `tools/verify_character.py`；staging、skill 循环整理 / Godot 导出及模板 4 备份保存在 `art/hero_v11_runtime_v05/`。历史导入脚本与旧 art 目录仅供追溯，不能发布为当前模板。旧 `prepare_art.py` / `verify_art.py` 已明确停用。离线工具需要 Python、Pillow、NumPy 等；游戏运行不需要。`tools/package_project.py` 可生成工程压缩包，本轮未重新打包，旧压缩包不包含此次侧视替换。
