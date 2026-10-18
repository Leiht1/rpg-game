# 美术 QA 原始异常记录

原始留白警告保留；透明处理器检查通过。frame-qc 将这张包含岩石、骨片、根茎、补给包和碎屑的混合道具图集当成同一人物动画，人物头部比例、躯干漂移、脚底和帧间接缝指标不适用于本图集。该诊断原样保留，不宣称所有 QA 通过，也不将它当作角色动作检查。本轮角色动作来自原生支点关键帧，实际检查见 native-actions.gif。

```json
{
  "file": "art/harvest-v05/raw-qc/sheet-qc.json",
  "id": "safe_frame",
  "status": "warn",
  "value": 18,
  "threshold": 0,
  "cells": [
    [
      0,
      0
    ],
    [
      0,
      1
    ],
    [
      0,
      2
    ],
    [
      0,
      3
    ],
    [
      1,
      0
    ],
    [
      1,
      1
    ],
    [
      1,
      2
    ],
    [
      1,
      3
    ],
    [
      2,
      1
    ],
    [
      2,
      2
    ],
    [
      2,
      3
    ],
    [
      3,
      0
    ],
    [
      3,
      1
    ],
    [
      3,
      2
    ],
    [
      4,
      0
    ],
    [
      4,
      1
    ],
    [
      4,
      2
    ],
    [
      4,
      3
    ]
  ],
  "note": "owned art closer than 15% of the cell to its edge; ask for more margin next time"
}
```

```json
{
  "file": "art/harvest-v05/frame-qc/sheet-qc.json",
  "id": "identity_head_ratio",
  "status": "fail",
  "value": {
    "0": 1.0,
    "1": 1.0,
    "2": 1.02,
    "3": 0.9,
    "4": 0.9,
    "5": 0.9,
    "6": 1.1,
    "7": 0.9,
    "8": 1.02,
    "9": 0.9,
    "10": 0.9,
    "11": 1.06,
    "12": 0.9,
    "13": 1.1,
    "14": 1.1,
    "15": 0.9,
    "16": 1.06,
    "17": 1.06,
    "18": 1.06,
    "19": 0.9
  },
  "threshold": [
    0.95,
    1.05
  ],
  "frames": [
    3,
    4,
    5,
    6,
    7,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19
  ],
  "note": "head scale against the median frame (frame 0 template)"
}
```

```json
{
  "file": "art/harvest-v05/frame-qc/sheet-qc.json",
  "id": "torso_drift",
  "status": "warn",
  "value": 89.02,
  "threshold": 2.0,
  "method": "trunk",
  "median_x": 141.4,
  "note": "range of the torso x in game px; scale_frames --root-lock torso-x removes it"
}
```

```json
{
  "file": "art/harvest-v05/frame-qc/sheet-qc.json",
  "id": "row_baseline",
  "status": "warn",
  "value": 24.0,
  "threshold": 0.5,
  "baselines": {
    "0": 236,
    "1": 229,
    "2": 235,
    "3": 212,
    "4": 216
  },
  "note": "ground line of each sheet row; scale_frames --row-baseline aligns them"
}
```

```json
{
  "file": "art/harvest-v05/frame-qc/sheet-qc.json",
  "id": "seam",
  "status": "warn",
  "value": 1.65,
  "threshold": 1.5,
  "transitions": [
    [
      18,
      19
    ],
    [
      5,
      6
    ],
    [
      14,
      15
    ],
    [
      11,
      12
    ],
    [
      10,
      11
    ]
  ],
  "note": "largest frame-to-frame change over the median step; review these joins first"
}
```

