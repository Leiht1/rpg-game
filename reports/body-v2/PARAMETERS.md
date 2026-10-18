# 身体参数对照 · 2026-10-18

修改前从正式 data/body_rules.json、body_state.gd 与 items.json 读取；原件保存在 baseline/。本表不是沿用历史日志。

| 配置键 | 修改前 | V2 |
|---|---|---|
| `hunger_per_day` | 65.0 | 80.0 |
| `hunger_severe` | 5.0 | 5.0 |
| `hunger_low` | 25.0 | 25.0 |
| `hunger_recovery` | 35.0 | 35.0 |
| `hunger_optimal` | 65.0 | 65.0 |
| `nutrition_recovery_per_day` | 2.0 | 2.0 |
| `illness_threshold` | 0.45 | 0.45 |
| `illness_recovery_per_day` | 0.8 | 0.8 |
| `health_recovery_game_minutes` | 120.0 | 120.0 |
| `reserve_response_days` | 2.0 | 2.0 |
| `reserve_balance_hunger` | 55.0 | 55.0 |
| `reserve_activity_cost` | 0.35 | 0.35 |
| `run_per_second` | 2.0 | 2.0 |
| `recovery_per_second` | 1.5 | 1.5 |
| `recovery_delay_seconds` | 2.0 | 2.0 |
| `resume_stamina` | 12.0 | 12.0 |
| `labor_cost` | {"chop": 1.5, "mine": 2.5, "dig": 1.5} | {"chop": 1.5, "mine": 2.5, "dig": 1.5} |
| `malnutrition_days` | 0.75 | 0.75 |
| `illness_days` | 1.5 | 1.5 |
| `disease_damage_interval_minutes` | 60.0 | 60.0 |
| `disease_damage` | 2.0 | 2.0 |
| `down_health` | 15.0 | 15.0 |
| `revive_health` | 30.0 | 30.0 |
| `rescue_game_minutes` | 30.0 | 30.0 |
| `body_response_days` | 3.0 | 3.0 |
| `torso_width_range` | [0.9, 1.12] | [0.9, 1.12] |
| `head_width_range` | [0.95, 1.06] | [0.95, 1.06] |
| `lantern_seconds` | 1800.0 | 1800.0 |
| `hunger_activity_multiplier` | 无 | 1.15 |
| `energy_per_hour` | 无 | 3.2 |
| `energy_activity_multiplier` | 无 | 1.15 |
| `sleep_energy_per_hour` | 无 | 13.0 |
| `sleep_min_minutes` | 无 | 180.0 |
| `sleep_wake_energy` | 无 | 30.0 |
| `sleep_nap_minutes` | 无 | 180.0 |
| `sleep_max_minutes` | 无 | 600.0 |
| `sleep_morning_minute` | 无 | 360.0 |
| `sleep_speed` | 无 | 120.0 |
| `energy_tired` | 无 | 35.0 |
| `energy_severe` | 无 | 15.0 |
| `energy_drowsy` | 无 | 60.0 |
| `tired_efficiency` | 无 | 0.88 |
| `severe_efficiency` | 无 | 0.7 |
| `hunger_warning` | 无 | 35.0 |
| `hunger_obvious` | 无 | 20.0 |
| `sleep_night_minute` | 无 | 1200.0 |
| `sleep_need_energy` | 无 | 99.0 |

其他职责：health/hunger/stamina 上限仍100；新增energy上限100。移动基础200/310不改，精力效率只乘实际速度及劳动逻辑进度。疾病营养不足累计从低于25改为仅饥饿到0才积累；旧严重饥饿疾病扣血门槛<25、正常恢复、单人照料均保留。reserve/build与体型响应参数不改。
