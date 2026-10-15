# 本轮接入 QA 状态

本轮美术来源 existing，没有新生成候选。前轮候选及其 WARN / FAIL 保留在原工作目录；旧运行资源与验收报告在 previous_runtime / previous_validation.md，不将历史质量结论套到新模板。

`clips/animation-clips.json`：原始 qa.status 为 needs-visual-review。png_byte_copy=27、webp_timeline=6、tick_grid=0.333 ms、near_duplicate_holds=0、manifest_lint=0 均为 pass；telegraph 为 skipped（没有攻击动作）。没有 WARN / FAIL。

```json
{"id":"loop_seam","status":"needs-visual-review","value":1.034748,"threshold":null,"files":["art/hero_gorest_runtime_v02/clips/animation-clips.json"]}
```

`engine/engine-export.json`：原始 qa.status 为 pass；godot_spriteframes_roundtrip=6 animations、godot_spriteframes_duration_error_ms=0.6666666666666714（threshold 1.0）、atlas_max_side_px=794（threshold 4096）、source_frame_hashes=27/27 均 pass。没有 WARN / FAIL。

数字检查不评判解剖、身份和动作观感。独立的实际地图渲染 / 物理移动检查见 ACCEPTANCE.md 和 reports/CHARACTER_VALIDATION.md；原始 QA 状态保持不变。仍有 idle/walk 头部比例、绘制轮廓和侧面半周期投影的小幅差异，左向光照随整帧镜像翻转。
