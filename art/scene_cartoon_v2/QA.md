# 场景素材 QA · 2026-10-16

实际路线 local:codex-cli / codex-image_gen；一次图片生成、无视频。原图为真实RGBA。按8个独立物件完整边界裁片，清除alpha<=8，预乘透明Lanczos等比缩放；草变体镜像，地表笔刷取本轮草色区域模糊派生。无角色重画。

以下逐字保留工具所有WARN/FAIL的id/status/value/threshold和所在文件。原格线切割方案未采用；整理后无跨格/边缘切断/雾点，但safe_frame余量警告仍保留，不把它写成全通过。

{"file": "spill/sheet-qc.json", "id": "cross_cell_components", "status": "fail", "value": 2, "threshold": 0}

{"file": "spill/sheet-qc.json", "id": "cross_cell_visible", "status": "fail", "value": 2, "threshold": 0}

{"file": "spill/sheet-qc.json", "id": "boundary_band", "status": "warn", "value": 1427, "threshold": 0}

{"file": "spill/sheet-qc.json", "id": "safe_frame", "status": "warn", "value": 5, "threshold": 0}

{"file": "spill/sheet-qc.json", "id": "faint_specks", "status": "warn", "value": {"floor_px": 15677, "detached_components": 0}, "threshold": 0}

{"file": "ownership-qc/sheet-qc.json", "id": "safe_frame", "status": "warn", "value": 2, "threshold": 0}

能力检查doctor.json的环境警告/缺失原样保留；未安装resvg、API和视频路由不影响此次已执行图片与原生动画流程。

实际Godot游戏尺寸目视检查完成：新草地/树/石/草花/木材与当前角色同屏；砍树遮挡修正后再次观察，可见人物和斧刃接触树干；拾取木材随手显示。所有素材仍待用户视觉验收。无全Seed/长时间性能压力测试。