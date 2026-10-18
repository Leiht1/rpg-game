# UI美术来源与整理QA

## core-ui-art-2.0.0

源图尺寸：[1536, 1024]。运行切片的透明外沿、内容区alpha/亮度QA均通过，详见来源记录。

WARN `nominal_cell_margin`: value=29px, requested>=48px; asset=assets\ui\rework_v1\panel.png; source=art\ui-rework-v1\candidate-01\generated.png。名义格线不用于裁图，实际完整归属框已记录且不截可见像素。

WARN `nominal_cell_margin`: value=12px, requested>=48px; asset=assets\ui\rework_v1\button.png; source=art\ui-rework-v1\candidate-01\generated.png。名义格线不用于裁图，实际完整归属框已记录且不截可见像素。

WARN `nominal_cell_margin`: value=18px, requested>=48px; asset=assets\ui\rework_v1\tooltip.png; source=art\ui-rework-v1\candidate-01\generated.png。名义格线不用于裁图，实际完整归属框已记录且不截可见像素。

## core-ui-art-2.1.0

源图尺寸：[1254, 1254]。运行切片的透明外沿、内容区alpha/亮度QA均通过，详见来源记录。

WARN `source_size_mismatch`: value=1254×1254, requested=1024×1024; file=art/ui-rework-v1/refine-01/generated.png。使用真实尺寸整理。

WARN `nominal_cell_margin`: value=-37px, requested>=40px; asset=assets\ui\refine_v1\button.png; source=art\ui-rework-v1\refine-01\generated.png。名义格线不用于裁图，实际完整归属框已记录且不截可见像素。

无发布的最终切片FAIL；上述生成排版WARN保留，不以数字QA代替主观美术验收。