# 验证记录与质量边界

- `clips/animation-clips.json`：6 clips / 36 frames，warnings=0，qa.status=needs-visual-review。
- 原非 pass 检查完整字段：`{"id":"telegraph","threshold":28,"status":"skipped","value":null}`；`{"id":"loop_seam","status":"needs-visual-review","value":1.533159,"threshold":null}`。源检查未提供 files 字段。本次没有 WARN / FAIL 检查，未将上述原状态改写为 pass。
- `engine/engine-export.json`：qa.status=pass，794×794 单图集 / 36 帧，Godot 帧/时长/图集回读通过。
- `../../reports/character-art-tests.json`：pass，0 failures；每张运行 PNG 与已确认来源及模板哈希一致，统一 128×128 / (64,112)，导出文件和未修改的游戏脚本/场景/工程配置一致。
- `../../reports/character-smoke-tests.json`：pass，0 failures；Godot 4.7.2，八方向短移动、20 个呼吸边界、完整八帧 walk、实际位移相位、停步与短呼吸通过。12 tick 实测范围 22.9921875～23.00390625 px，目标为 115×12/60=23 px。
- `godot-import.log`、`godot-smoke.log`：导入/实际 GPU 渲染正常，无 ERROR / SCRIPT ERROR / WARNING。实际渲染共八姿势采样在 `../../reports/character-smoke-poses.png`，不是连续动作录像。
- 本轮只做必要接入检查，没有重跑历史 180 次走停、全碰撞、地图或性能测试；旧报告保留但不冒充本次结果。没有本版性能基准或新压缩包。
- 用户已确认该完整帧集合；数字及节点静止不能证明图像零漂移、解剖正确或步态完全连续。仍保留细微轮廓、颜色、身长/投影与镜像光照差异，最终操作体验由用户手动验证。
