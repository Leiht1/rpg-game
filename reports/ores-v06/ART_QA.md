# 原始与未采用整理稿 QA 记录

原图默认5×2切格会切到矿脚，因此第一次名义切格版本不发布。按物体实际所属区域（空白间隙）完整整理到640格，未裁去可见像素、未旋转或非等比挤压。最终 owned-qc 和 processed-owned 均通过。以下原始异常完整保留，不表述为原图全部QA通过。

```json
{
  "file": "art/ores-v06/raw-qc/sheet-qc.json",
  "id": "cross_cell_components",
  "status": "fail",
  "value": 5,
  "threshold": 0,
  "cells": [
    [
      0,
      2
    ],
    [
      0,
      1
    ],
    [
      0,
      3
    ],
    [
      0,
      4
    ],
    [
      0,
      0
    ]
  ],
  "note": "solid parts crossing a cell line are cut or misassigned when the sheet is sliced"
}
```

```json
{
  "file": "art/ores-v06/raw-qc/sheet-qc.json",
  "id": "cross_cell_visible",
  "status": "fail",
  "value": 5,
  "threshold": 0,
  "note": "the same test on the visible edge (alpha > 16)"
}
```

```json
{
  "file": "art/ores-v06/raw-qc/sheet-qc.json",
  "id": "boundary_band",
  "status": "warn",
  "value": 18375,
  "threshold": 0,
  "note": "solid pixels within 8 px of a cell line; a different crop or rounding can cut them"
}
```

```json
{
  "file": "art/ores-v06/raw-qc/sheet-qc.json",
  "id": "safe_frame",
  "status": "warn",
  "value": 5,
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
      0,
      4
    ]
  ],
  "note": "owned art closer than 15% of the cell to its edge; ask for more margin next time"
}
```

```json
{
  "file": "art/ores-v06/processed/pipeline-meta.json",
  "id": "paste_clamped_frames",
  "status": "warn",
  "value": [
    [
      1,
      3
    ]
  ],
  "threshold": []
}
```

```json
{
  "file": "art/ores-v06/processed/pipeline-meta.json",
  "id": "output_edge_touch_frames",
  "status": "warn",
  "value": [
    [
      1,
      3
    ]
  ],
  "threshold": []
}
```

```json
{
  "file": "art/ores-v06/processed/pipeline-meta.json",
  "id": "source_edge_touch_frames",
  "status": "warn",
  "value": [
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
      0,
      4
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
      1,
      4
    ]
  ],
  "threshold": []
}
```

