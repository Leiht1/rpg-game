# 素材 QC 记录

原始候选的失败保留以便追溯；整理后是否通过必须查看对应 final 报告。

## back-final · pass

无 FAIL / WARN。

## front-clean · warn

```json
{"id": "faint_specks", "status": "warn", "value": {"floor_px": 5924, "detached_components": 0}, "threshold": 0, "files": ["art\\qc\\front-clean\\sheet-qc.json"]}
```

## front-final · pass

无 FAIL / WARN。

## front-spill · fail

```json
{"id": "cross_cell_components", "status": "fail", "value": 4, "threshold": 0, "files": ["art\\qc\\front-spill\\sheet-qc.json"]}
```

```json
{"id": "cross_cell_visible", "status": "fail", "value": 4, "threshold": 0, "files": ["art\\qc\\front-spill\\sheet-qc.json"]}
```

```json
{"id": "boundary_band", "status": "warn", "value": 2548, "threshold": 0, "files": ["art\\qc\\front-spill\\sheet-qc.json"]}
```

```json
{"id": "safe_frame", "status": "warn", "value": 5, "threshold": 0, "files": ["art\\qc\\front-spill\\sheet-qc.json"]}
```

```json
{"id": "faint_specks", "status": "warn", "value": {"floor_px": 19542, "detached_components": 2}, "threshold": 0, "files": ["art\\qc\\front-spill\\sheet-qc.json"]}
```

## right-final · pass

无 FAIL / WARN。

## tree-spill · fail

```json
{"id": "cross_cell_components", "status": "fail", "value": 1, "threshold": 0, "files": ["art\\qc\\tree-spill\\sheet-qc.json"]}
```

```json
{"id": "cross_cell_visible", "status": "fail", "value": 1, "threshold": 0, "files": ["art\\qc\\tree-spill\\sheet-qc.json"]}
```

```json
{"id": "boundary_band", "status": "warn", "value": 2354, "threshold": 0, "files": ["art\\qc\\tree-spill\\sheet-qc.json"]}
```

```json
{"id": "safe_frame", "status": "warn", "value": 2, "threshold": 0, "files": ["art\\qc\\tree-spill\\sheet-qc.json"]}
```

```json
{"id": "faint_specks", "status": "warn", "value": {"floor_px": 29830, "detached_components": 3}, "threshold": 0, "files": ["art\\qc\\tree-spill\\sheet-qc.json"]}
```
