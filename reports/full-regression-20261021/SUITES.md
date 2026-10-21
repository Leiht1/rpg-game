# 本轮逐组测试结果

同名重试仅展示最后一次结果；全部尝试保留在 results.json。不同重启阶段分别计组。

pass 表示该组断言/退出结果通过，仍需查看报告中的资源清理和延迟回调诊断。incomplete 表示超时或脚本中止；未执行部分不算通过。

| 测试组 | 结果 | 秒 | 已记录断言/失败 | 失败或诊断摘要 |
|---|---|---:|---:|---|
| project-import | pass | 51.7 | — | — |
| test_network_server.py | pass | 15.99 | — | — |
| test_network_game_host.py | pass | 37.72 | — | — |
| test_network_game_job.py | pass | 13.95 | — | — |
| audio-workbench | blocked-dependencies | 0.21 | — | ERROR: test_workbench (unittest.loader._FailedTest.test_workbench) ; Traceback (most recent call last): ; FAILED (errors=1) |
| network_game_compile | pass | 2.23 | — | — |
| launcher_startup_smoke | pass | 3.67 | — | — |
| launcher_click_smoke | pass | 3.58 | — | ERROR: 2 RID allocations of type 'N5GLES37TextureE' were leaked at exit. ; ERROR: 1 RID allocations of type 'PN18TextServerAdvanced12FontAdvancedE' were leaked at exit. ; ERROR: Texture with GL ID of 37: leaked 174762 bytes. ; ERROR: Texture with GL ID of 39: leaked 174762 bytes. |
| login_memory_smoke | pass | 0.66 | — | — |
| login_prefill_smoke-write | pass | 0.59 | — | — |
| login_prefill_smoke-read | pass | 2.36 | — | — |
| login_prefill_smoke-clear | pass | 2.38 | — | — |
| test_player | fail | 0.42 | — | SCRIPT ERROR: Parse Error: Cannot infer the type of "phase_frame" variable because the value doesn't have a set type. ; ERROR: Failed to load script "res://tests/test_player.gd" with error "Parse error". |
| test_world_v06 | pass | 120.66 | 83/0 | — |
| test_ore_distribution_v06 | fail | 29.87 | 162/15 | metal restricted to stable mud interior mineral:2:28:27:10 ; metal restricted to stable mud interior mineral:2:29:27:6 ; metal restricted to stable mud interior mineral:2:29:27:12 ; metal restricted to stable mud interior mineral:2:29:28:3 ; metal restricted to stable mud interior mineral:2:29:28:4 ; metal restricted to stable mud interior mineral:2:45:29:8 ; metal restricted to stable mud interior mineral:2:46:29:1 ; metal restricted to stable mud interior mineral:2:49:48:1 ; metal restricted t…（完整内容见 results.json / suites.csv） |
| test_random_entry_v1 | pass | 63.21 | 78/0 | — |
| test_ecology_v03 | incomplete | 62.78 | — | ERROR: no tiny independent macro regions seed 902106 ; SCRIPT ERROR: Invalid access to property or key 'position' on a base object of type 'Nil'. |
| test_resources_v031 | fail | 73.04 | — | ERROR: player drop API ; ERROR: player drop namespace separate |
| test_crafting_v1 | fail | 24.09 | 210/1 | five valid real recipes, no invalid items |
| test_equipment_v04 | fail | 23.66 | 69/9 | database keeps 12 items and adds three tools ; occupied equipment swaps into source cell ; instance state and identity survive restoration ; bag left and equipment right ; F6 developer ore can be placed on clear loaded ground ; atomic save reload restores same equipment instance and capabilities ; ore state survives same snapshot reload ; movement through open equipment bag ; registered head appearance updates world and portrait together |
| test_food_v2 | fail | 21.46 | 191/1 | all nine recipes appear in scrolling book |
| test_food_edges_v2 | pass | 21.27 | 9/0 | — |
| test_world_map_v3_logic | fail | 47.74 | 35/3 | bounded fish populations 81273 ; bounded fish populations 271828 ; bounded fish populations 902106 |
| test_world_map_v3_storage | pass | 3.64 | 17/0 | — |
| test_world_map_v3_distribution | incomplete | 150.46 | — | ERROR: fish total 1024/81273 ; ERROR: fish total 1024/271828 ; ERROR: fish total 1024/902106 ; ERROR: fish total 1536/81273 |
| test_map_population_v4_logic | pass | 30.29 | 261/0 | — |
| test_character_contracts_v1 | pass | 1.61 | 9/0 | — |
| test_movement_regression | fail | 23.27 | 20/3 | chop still starts ; chop commits exactly once ; chop does not duplicate hit |
| test_movement_jitter | pass | 20.86 | — | — |
| test_grounding_interactions | incomplete | 150.61 | — | ERROR: chop still starts ; ERROR: chop commits exactly once ; ERROR: chop does not duplicate hit |
| test_ore_runtime_v06 | fail | 88.08 | 49/5 | 21 stable item definitions including three raw metal ores ; one exact configured reward batch stone_outcrop ; held E completes exactly configured hits gold_outcrop ; one exact configured reward batch gold_outcrop ; new ore inventory persists gold_ore |
| test_harvest_v05 | incomplete | 132.52 | — | ERROR: unique database: existing 15 plus bone/relic/pouch ; ERROR: damage/reveal stage advances stone_outcrop ; ERROR: exactly one configured reward batch stone_outcrop ; ERROR: damage/reveal stage advances flint_outcrop ; ERROR: damage/reveal stage advances copper_outcrop ; ERROR: damage/reveal stage advances silver_outcrop ; ERROR: damage/reveal stage advances gold_outcrop ; ERROR: resource finishes after configured hit count gold_outcrop ; ERROR: exactly one configured reward batch gold_outcr…（完整内容见 results.json / suites.csv） |
| test_harvest_edges_v05 | fail | 13.04 | 17/0 | SCRIPT ERROR: Invalid access to property or key '(17, 12)' on a base object of type 'Dictionary'. |
| test_harvest_followup_v051 | fail | 24.48 | 119/1 | held E completes resource once mine |
| test_harvest_contact_layer_v051 | pass | 13.84 | 20/0 | — |
| test_buried_solid_v052 | pass | 13.25 | 68/0 | — |
| test_item_actions_followup_v051 | fail | 15.65 | 113/5 | bag title drag moves panel and releases ; native bag drag onto ground discards whole stack ; player drop visible ; native item drag starts ; hotbar drag onto ground discards whole stack |
| test_broadleaf_v1 | fail | 31.08 | 119/1 | explicit version and one-dig/four-leaf definition |
| test_crafting_progress_v1 | pass | 17.05 | 37/0 | — |
| test_crafted_tools_runtime_v1 | pass | 19.26 | 16/0 | — |
| test_drop_quantity_v1 | pass | 12.84 | 19/0 | ERROR: Error calling deferred method: 'Node(ui_fade.gd)::animate_window': Cannot convert argument 1 from Object to Object. ; ERROR: Error calling deferred method: 'Node(ui_fade.gd)::animate_window': Cannot convert argument 1 from Object to Object. |
| test_bag_organize_v1 | pass | 14.04 | 29/0 | — |
| test_bag_organize_v1-restart | pass | 13.04 | 17/0 | — |
| test_recipe_hint_ui_v1 | pass | 14.24 | 24/0 | — |
| test_front_tool_layer_v13 | pass | 18.26 | 491/0 | — |
| test_back_tool_layer_v6 | pass | 7.03 | 133/0 | — |
| test_camp_build_v4 | fail | 12.25 | 41/3 | formal startup exposes ten buildings and hammer without preview ; nine new buildings and existing campfire ; find legal real terrain building site |
| test_camp_door_hinge_transaction_v3 | incomplete | 27.06 | — | SCRIPT ERROR: Invalid access to property or key 'corner' on a base object of type 'Dictionary'. |
| test_camp_gate_surface_v4 | fail | 145.54 | — | SCRIPT ERROR: Invalid access to property or key 'industry' on a base object of type 'Nil'. ; SCRIPT ERROR: Invalid access to property or key 'vertical' on a base object of type 'Dictionary'. ; SCRIPT ERROR: Invalid access to property or key 'vertical' on a base object of type 'Dictionary'. ; SCRIPT ERROR: Invalid access to property or key 'kind' on a base object of type 'Dictionary'. ; SCRIPT ERROR: Invalid access to property or key 'vertical' on a base object of type 'Dictionary'. ; SCRIPT ERRO…（完整内容见 results.json / suites.csv） |
| test_camp_h_damage_window_v4 | fail | 11.23 | — | SCRIPT ERROR: Invalid access to property or key 'h:gate' on a base object of type 'Dictionary'. |
| test_floor_formal_v3 | incomplete | 17.41 | — | SCRIPT ERROR: Invalid access to property or key 'industry' on a base object of type 'Nil'. ; SCRIPT ERROR: Invalid access to property or key 'industry' on a base object of type 'Nil'. ; SCRIPT ERROR: Invalid access to property or key 'industry' on a base object of type 'Nil'. ; SCRIPT ERROR: Invalid access to property or key 'industry' on a base object of type 'Nil'. ; SCRIPT ERROR: Invalid access to property or key 'industry' on a base object of type 'Nil'. ; SCRIPT ERROR: Invalid access to pro…（完整内容见 results.json / suites.csv） |
| test_floor_under_buildings_v1 | pass | 17.04 | 198/0 | — |
| test_camp_effects_v11 | incomplete | 26.97 | — | SCRIPT ERROR: Invalid access to property or key 'fx:torch' on a base object of type 'Dictionary'. |
| test_inventory_chest_v1 | incomplete | 27.79 | — | ERROR: mouse movement cannot drag bag ; ERROR: place real legal chest ; SCRIPT ERROR: Invalid access to property or key of type 'String' on a base object of type 'Dictionary'. |
| test_chest_ui_v2 | incomplete | 26.8 | — | ERROR: place legal formal chest ; SCRIPT ERROR: Invalid access to property or key of type 'String' on a base object of type 'Dictionary'. |
| test_chest_ui_v2-restart | fail | 0.61 | — | — |
| test_chest_volume_render_v2 | pass | 14.24 | 20/0 | — |
| test_cooking_build_v2 | fail | 12.23 | 5/1 | a legal real-world dry placement found near spawn |
| test_cooking_discovery_v1 | fail | 16.44 | 117/24 | exactly four active recipes ; hunger-only brown_mushroom ; carrot remains twelve ; legacy mushroom remains ten ; new hunger herb_roasted_mushroom ; new hunger roasted_fruit_platter ; new hunger field_harvest_platter ; reverse order matches ; old mushroom combination disabled ; legacy start refused without debit ; invalid combination unchanged ; start disk failure rollback ; hidden combination starts ; four recipe cards plus future placeholders ; hidden card has no real name or icon ; closed wind…（完整内容见 results.json / suites.csv） |
| test_cooking_discovery_v1-restart | fail | 13.84 | 7/2 | fresh process discoveries retained ; fresh process claimed herb output retained |
| test_campfire_drag_v1 | incomplete | 28.61 | — | ERROR: real dry legal fire location available ; ERROR: test fire placed with original item consumption ; SCRIPT ERROR: Invalid access of index '0' on a base object of type: 'Array'. |
| test_campfire_flame_v2 | fail | 14.24 | 32/8 | actual food benefit wild_carrot +4 ; actual food benefit wild_apple +4 ; actual food benefit wild_berry +3 ; actual food benefit brown_mushroom +3 ; actual food benefit roasted_carrot +12 ; actual food benefit roasted_mushroom +10 ; actual environment adapter supplies small rain exposure ; actual environment adapter supplies storm exposure |
| test_planting_v1 | fail | 14.24 | 21/1 | legal plot location found |
| test_planting_dependencies_v1 | pass | 14.04 | 15/0 | — |
| test_planting_layout_v1 | pass | 14.64 | 16/0 | — |
| test_seed_selector_v2 | incomplete | 29.0 | — | ERROR: place real legal soil ; SCRIPT ERROR: Invalid access to property or key 'abandoned:v1:0:0' on a base object of type 'Dictionary'. |
| test_seed_selector_v2-restart | fail | 14.04 | 3/2 | new process restores destroyed plot as absent ; new process does not refund planted seed |
| test_abandoned_fish_v1 | pass | 19.86 | 114/0 | — |
| test_abandoned_fish_v1-restart | pass | 13.84 | 6/0 | — |
| test_roasted_fish_formal_v1 | pass | 13.63 | 5/0 | — |
| test_food_formal_v2 | pass | 13.64 | 17/0 | — |
| test_hallucination_visual_v3 | pass | 15.04 | 6/0 | — |
| test_animal_art_formal_v2 | incomplete | 150.46 | — | — |
| test_animal_art_formal_shear_v2 | pass | 15.24 | 33/0 | — |
| test_animals_v1 | fail | 20.05 | 95/3 | shears require workbench ; newly tamed sheep not instantly harvestable ; repeat shearing refused |
| test_animals_edges_v1 | fail | 15.04 | 33/6 | unloaded pair reproduces with same game-time rules ; unloaded chickens produce persistent ground eggs ; first birth immediately consumes last population slot ; cooldown and population cap prevent extra birth ; unloaded unconfined wild animal migrates physically ; unfenced tame animal can drift away but never disappears |
| test_animal_drag_feed_v1 | pass | 14.03 | 37/0 | — |
| test_animal_debug_button_v1 | pass | 13.04 | 15/0 | — |
| test_scissors_exploration_v1 | fail | 16.24 | 34/2 | front hand and scissors before clothing; palm grips handle false ; front hand and scissors before clothing; palm grips handle true |
| test_scissors_restart_v1 | pass | 11.83 | 7/0 | — |
| test_shear_sign_map_v1 | fail | 15.44 | 32/2 | GPU map is identical when hidden spawn changes; no marker or label remains ; map zoom unchanged |
| test_body_v2 | fail | 62.54 | 181/13 | all ten actual edible foods enumerated ; eight hours restores full clamps ; real labor clock synced 100 ; real labor clock synced 25 ; real labor clock synced 10 ; wakeup unlock and accelerated overshoot discarded ; forced total three hours world time ; reserved sleep implementation without a player UI entry ; night sleep next morning six ; sleep closes storage without hiding reusable root ; storage usable after waking ; engine loops wake and restore input without duplicate hit ; modal detail av…（完整内容见 results.json / suites.csv） |
| test_body_ui_revision_v2 | pass | 17.45 | 13/0 | — |
| test_sleep_formal_v9 | incomplete | 27.21 | — | ERROR: native placement site sleeping_bag-horizontal ; ERROR: place sleeping_bag-horizontal ; SCRIPT ERROR: Invalid access of index '0' on a base object of type: 'Array'. |
| test_sleep_fit_v10 | fail | 12.43 | 5/5 | clear enlarged footprint site wood_bedfalse ; clear enlarged footprint site wood_bedtrue ; clear enlarged footprint site straw_matfalse ; clear enlarged footprint site straw_mattrue ; clear enlarged footprint site sleeping_bagfalse |
| test_sleep_collision_v11 | fail | 12.43 | 5/5 | valid offset footprint placement ["wood_bed", false] ; valid offset footprint placement ["wood_bed", true] ; valid offset footprint placement ["straw_mat", false] ; valid offset footprint placement ["straw_mat", true] ; valid offset footprint placement ["sleeping_bag", false] |
| test_industry_v1 | fail | 19.65 | 275/48 | formal building art refrigerator ; formal inventory art refrigerator ; formal inventory art precision_repair_bench ; formal inventory art fuel_supply_box ; formal inventory art compost_bin ; formal inventory art advanced_smokehouse ; powered furnace advances ; copper completes ; failed claim restores output and inventory ; claim successful ; claim uses unified obtained event ; queued silver completes ; silver claimed ; start metal_copper_plate ; claim metal_copper_plate ; start metal_copper_part…（完整内容见 results.json / suites.csv） |
| test_industry_v1-restart | fail | 11.83 | 7/1 | restart retains fallback recipe and paid quantities |
| test_industry_refine_v2 | fail | 16.24 | 115/3 | one actual completion emits small chimney smoke ; metal painted width equals ordinary workbench 80 units ; GPU small smoke appears at chimney |
| test_industry_polish_v3 | pass | 13.83 | 55/0 | — |
| test_camp_expansion_v2 | pass | 21.65 | 210/0 | ERROR: 13 RID allocations of type 'P11GodotBody2D' were leaked at exit. ; ERROR: 11 RID allocations of type 'N5GLES37TextureE' were leaked at exit. ; ERROR: 5 RID allocations of type 'PN18TextServerAdvanced22ShapedTextDataAdvancedE' were leaked at exit. ; ERROR: 1 RID allocations of type 'PN18TextServerAdvanced12FontAdvancedE' were leaked at exit. ; ERROR: Texture with GL ID of 194: leaked 131072 bytes. ; ERROR: Texture with GL ID of 196: leaked 174762 bytes. ; ERROR: Texture with GL ID of 197: …（完整内容见 results.json / suites.csv） |
| test_camp_expansion_v2-restart | pass | 11.83 | 7/0 | — |
| test_camp_expansion_geometry | pass | 1.61 | 21/0 | — |
| test_camp_expansion_front_v2 | incomplete | 150.43 | — | — |
| test_camp_food_polish_v2 | pass | 16.44 | 83/0 | — |
| test_camp_formal_drag_v2 | pass | 15.44 | 66/0 | — |
| test_camp_interaction_polish_v3 | pass | 18.85 | 80/0 | — |
| test_build_freshness_v1 | pass | 12.23 | — | — |
| test_fishing_formal_v1 | fail | 24.46 | 107/2 | all candidate textures imported and loaded ; formal lake points generated sparsely |
| test_fishing_population_v2 | fail | 20.65 | 66/6 | formal world: global cap 20 ; replacement preserves cap, spacing and lake limits ; seed 271828: global cap 20 ; seed 271828: no lake exceeds 3 ; seed 123456: global cap 20 ; seed 123456: no lake exceeds 3 |
| test_merchant_v1 | pass | 19.05 | 124/0 | — |
| test_merchant_formal_legacy | pass | 11.83 | — | — |
| test_ui_fade_v1 | pass | 16.85 | 34/0 | — |
| test_target_tip_timeout | pass | 15.65 | — | — |
| test_world_environment | pass | 37.32 | 47/0 | — |
| test_world_map_v3_window | incomplete | 150.39 | — | — |
| test_world_map_v3_markers | pass | 28.09 | 10/0 | — |
| test_world_map_v3_perf | pass | 29.72 | — | — |
| test_map_population_v4_window | pass | 27.67 | 57/0 | — |
| test_map_population_v4_window-restart | pass | 14.06 | 5/0 | — |
| test_map_population_v4_movement | pass | 26.29 | 9/0 | — |
| test_audio_selected_v6 | incomplete | 29.31 | — | ERROR: sfx_build_stone actual player starts ; ERROR: Can't take value from empty array. ; SCRIPT ERROR: Invalid access to property or key 'stream' on a base object of type 'Nil'. |
| test_audio_ui_open_v7 | fail | 14.64 | 9/3 | actual backpack open plays shortened event ; map open uses same shortened event ; close variants retained |
| test_audio_ui_single_v8 | fail | 13.44 | 62/1 | both user-selected close variants retained, never layered |
| test_audio_close_only_v9 | pass | 13.44 | 16/0 | — |
| test_character_creation_v1 | fail | 40.32 | 183/1 | original full continent generator |
| test_character_hair_v2 | pass | 8.83 | 154/0 | — |
| test_character_hair_world_v2 | pass | 15.05 | 35/0 | — |
| test_ponytail_side_v3 | pass | 4.43 | 25/0 | — |
| test_ecology_compat_v1 | pass | 12.84 | 6/0 | — |
| test_ecology_signpost_revision_v1 | incomplete | 37.69 | — | SCRIPT ERROR: Invalid access to property or key 'x' on a base object of type 'Dictionary'. |
| test_ecology_signpost_revision_ui_v1 | incomplete | 27.63 | — | SCRIPT ERROR: Invalid access to property or key 'x' on a base object of type 'Dictionary'. |
| test_ore_ground_density_v1 | pass | 34.91 | 220/0 | — |
| test_equipment_persistence_v04-phase1 | pass | 18.66 | 1/0 | — |
| test_equipment_persistence_v04-phase2 | pass | 18.66 | 6/0 | — |
| test_crafting_persistence_v1-phase1 | pass | 19.87 | 8/0 | — |
| test_crafting_persistence_v1-phase2 | pass | 18.86 | 9/0 | — |
| test_body_persistence_v2-phase1 | pass | 22.47 | 2/0 | — |
| test_body_persistence_v2-phase2 | pass | 23.48 | 12/0 | — |
| test_body_persistence_v2-phase3 | pass | 18.66 | 6/0 | — |
| test_body_persistence_v2-phase4 | pass | 18.26 | 5/0 | — |
| test_planting_persistence_v1-phase1 | pass | 19.88 | 2/0 | — |
| test_planting_persistence_v1-phase2 | incomplete | 28.6 | — | ERROR: four plot states survive process restart ; ERROR: maturity restored ; SCRIPT ERROR: Invalid access to property or key 'plot-2' on a base object of type 'Dictionary'. |
| test_planting_persistence_v1-phase3 | fail | 13.24 | 5/3 | third process loads harvested snapshot ; harvested mature crop remains roots after another restart ; one harvest reward restored exactly once |
| network-two-clients | pass | 69.73 | — | — |
| network-two-clients-delay-220ms | fail | 47.09 | — | — |
| network-two-clients-delay-550ms | pass | 68.32 | — | — |

完整失败断言、报告位置、重试次数与原始日志相对路径见 suites.csv。日志和截图按项目规则仅本地临时保留。
