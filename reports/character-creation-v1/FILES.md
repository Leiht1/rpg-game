# 本轮文件清单

## 修改已有文件

- `.gitignore`
- `CHARACTER_MODULAR_RULES.md`
- `DEVLOG.md`
- `EQUIPMENT_SYSTEM.md`
- `PROJECT_STATUS.md`
- `scripts/environment_view.gd`
- `scripts/item_inventory.gd`
- `scripts/item_service.gd`
- `scripts/item_ui.gd`
- `scripts/player.gd`
- `scripts/sleep_head_cover.gd`

## 新增实现与规范

- `CHARACTER_CREATION_SYSTEM.md`
- `scenes/character_creation_preview.tscn`
- `scripts/character_catalog.gd`
- `scripts/character_catalog.gd.uid`
- `scripts/character_creation.gd`
- `scripts/character_creation.gd.uid`
- `scripts/character_look.gd`
- `scripts/character_look.gd.uid`
- `scripts/character_preview_world.gd`
- `scripts/character_preview_world.gd.uid`
- `scripts/character_skin.gdshader`
- `scripts/character_skin.gdshader.uid`
- `tests/test_character_contracts_v1.gd`
- `tests/test_character_creation_v1.gd`
- `tests/test_character_gallery_v1.gd`
- `tests/test_character_resume_v1.gd`
- `tests/test_character_ui_capture.gd`
- `tools/Start-Character-Creation-Preview.ps1`

## 资源与验收

- `prototypes/character-creation-v1/`：catalog及60张候选PNG，不覆盖assets。
- `art/character-creation-v1/`：提示、原图、真实生成回执、所有权重排、处理元数据、源/候选哈希及历史/最终QA。
- `reports/character-creation-v1/`：本报告、HTML预览、4份最终断言结果与待确认临时媒体；自动存档/日志按规则忽略。
- 本地 `Start-Character-Creation-Preview.cmd`、`Reset-Character-Creation-Preview.cmd`；原普通Start-Playtest.cmd按更新前内容恢复，仅本地。

未修改：任务原文、project.godot、正式角色场景/原图/动作库、商人正式定义与交易价格。
