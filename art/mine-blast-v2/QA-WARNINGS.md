# 原始/处理中间QA记录

## raw-qc

```json
{
  "id": "cross_cell_components",
  "status": "fail",
  "value": 7,
  "threshold": 0,
  "cells": [
    [
      0,
      3
    ],
    [
      1,
      3
    ],
    [
      1,
      0
    ],
    [
      1,
      0
    ],
    [
      1,
      2
    ],
    [
      1,
      1
    ],
    [
      1,
      1
    ]
  ],
  "note": "solid parts crossing a cell line are cut or misassigned when the sheet is sliced"
}
```

```json
{
  "id": "cross_cell_visible",
  "status": "fail",
  "value": 8,
  "threshold": 0,
  "note": "the same test on the visible edge (alpha > 16)"
}
```

```json
{
  "id": "boundary_band",
  "status": "warn",
  "value": 1979,
  "threshold": 0,
  "note": "solid pixels within 6 px of a cell line; a different crop or rounding can cut them"
}
```

```json
{
  "id": "safe_frame",
  "status": "warn",
  "value": 12,
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
      0
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
    ]
  ],
  "note": "owned art closer than 15% of the cell to its edge; ask for more margin next time"
}
```

## registered-qc

```json
{
  "id": "cross_cell_components",
  "status": "fail",
  "value": 8,
  "threshold": 0,
  "cells": [
    [
      0,
      3
    ],
    [
      1,
      2
    ],
    [
      1,
      1
    ],
    [
      1,
      0
    ],
    [
      1,
      0
    ],
    [
      1,
      0
    ],
    [
      1,
      3
    ],
    [
      1,
      0
    ]
  ],
  "note": "solid parts crossing a cell line are cut or misassigned when the sheet is sliced"
}
```

```json
{
  "id": "cross_cell_visible",
  "status": "fail",
  "value": 9,
  "threshold": 0,
  "note": "the same test on the visible edge (alpha > 16)"
}
```

```json
{
  "id": "boundary_band",
  "status": "warn",
  "value": 1816,
  "threshold": 0,
  "note": "solid pixels within 8 px of a cell line; a different crop or rounding can cut them"
}
```

```json
{
  "id": "safe_frame",
  "status": "warn",
  "value": 13,
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
      0
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
    ]
  ],
  "note": "owned art closer than 15% of the cell to its edge; ask for more margin next time"
}
```

## final-qc

```json
{
  "id": "safe_frame",
  "status": "warn",
  "value": 6,
  "threshold": 0,
  "cells": [
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
      3
    ],
    [
      2,
      0
    ]
  ],
  "note": "owned art closer than 15% of the cell to its edge; ask for more margin next time"
}
```

## padded-qc

最终：cross_cell_components=0、cross_cell_visible=0、sheet_edge=0、boundary_band=0、safe_frame=0，所有切片检查pass。
