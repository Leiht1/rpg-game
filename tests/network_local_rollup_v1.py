"""Targeted integration of recent local rules through the original private host."""
import copy
import json
import os
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
os.environ["WINDREST_GODOT"] = "D:/Godot/Godot_v4.7.2-stable_win64.exe"
from test_network_game_host import RulesHostTests


class LocalRollup(RulesHostTests):
    def test_copper_tools_advance_double_work_once_per_strike(self):
        positions = json.loads((ROOT / "reports/network-gameplay-v5/positions.json").read_text(encoding="utf-8"))
        definitions = {row["item_id"]: row for row in json.loads((ROOT / "data/items.json").read_text(encoding="utf-8"))}
        for action, tool in (("chop", "copper_axe"), ("mine", "copper_pickaxe"), ("dig", "copper_shovel")):
            state = copy.deepcopy(self.baseline)
            target = positions["targets"][action]
            state["player_position"] = target["position"]
            state["combat_personal"]["phase"] = "alive"
            state["equipment"] = {"main_hand": {"item_id": tool, "count": 1, "instance_id": "rollup-"+tool,
                                                  "state": {}, "durability": definitions[tool]["durability"]}}
            result = self.host.execute(state, operation="interact", args=[target["target"]])
            self.assertTrue(result["ok"], result.get("error"))
            after = result["snapshot"]
            self.assertEqual(after["equipment"]["main_hand"]["durability"], definitions[tool]["durability"]-1)
            if action == "chop":
                identity = target["target"]["prop_id"]
                self.assertEqual(after["tree_hits"][identity], 2)
            else:
                normal_tool = "stone_pickaxe" if action == "mine" else "simple_shovel"
                state["equipment"]["main_hand"].update(item_id=normal_tool, durability=definitions[normal_tool]["durability"])
                normal = self.host.execute(state, operation="interact", args=[target["target"]])["snapshot"]
                # The existing harvest progress is in the shared world snapshot.
                copper_progress = after["resource_hits"]
                normal_progress = normal["resource_hits"]
                self.assertTrue(copper_progress)
                for identity, count in copper_progress.items():
                    self.assertEqual(count, normal_progress[identity]*2)

    def test_shelter_posts_block_authoritative_movement(self):
        state = self.fixture_building("rain_shelter")
        row = state["buildings"]["objects"]["fixture"]
        post = json.loads((ROOT / "data/weather_body_rules.json").read_text())["shelter_posts"][0]
        character = {"x": row["x"]+post[0]-18, "y": row["y"]+post[1],
                     "gameplay": {"body": state["body"], "combat_personal": {"phase": "alive"}}}
        result = self.host.movement({"gameplay": state}, character, [{"dx": 1, "dy": 0, "dt": .05, "run": False}])
        self.assertLess(result["x"], row["x"]+post[0]-14)

    def test_lantern_lifetime_and_personal_fuel(self):
        for item, duration in (("field_lantern", 1350), ("silver_lantern", 2700)):
            state = copy.deepcopy(self.baseline)
            state["combat_personal"]["phase"] = "alive"
            state["slots"][8] = {"item_id": item, "count": 1, "lamp_id": "test-"+item,
                                   "fuel": 1800. if item == "field_lantern" else 3600.}
            on = self.host.execute(state, operation="lamp", args=[8])
            self.assertTrue(on["ok"], on.get("error"))
            before = on["snapshot"]
            self.assertTrue(before["network_lamp_on"])
            after = self.host.execute(before, elapsed=5, shared=False)["snapshot"]
            capacity = before["slots"][8]["fuel"]
            self.assertAlmostEqual(capacity - after["slots"][8]["fuel"], capacity / duration * 5, places=5)
            self.assertEqual(before["body_environment"], after["body_environment"])
            restored = self.host.execute(after)["snapshot"]
            self.assertEqual(restored["slots"][8], after["slots"][8])
            self.assertTrue(restored["network_lamp_on"])

    def test_weather_movement_is_authoritative(self):
        state = copy.deepcopy(self.baseline)
        state["body"]["weather_body"] = {"version": 1, "wetness": 100., "felt_temperature": -10., "cold_level": 3, "extreme_minutes": 0.}
        state["combat_personal"]["phase"] = "alive"
        character = {**state["player_position"], "gameplay": {"body": state["body"], "combat_personal": state["combat_personal"]}}
        result = self.host.movement({"gameplay": state}, character, [{"dx": 1, "dy": 0, "dt": .05, "run": False}])
        factor = json.loads((ROOT / "data/weather_body_rules.json").read_text())["move_factors"][3]
        self.assertLessEqual(abs(result["x"] - character["x"]), 200 * .05 * factor + .00001)

    def test_sleep_recovers_at_current_rate(self):
        state = self.fixture_building("straw_mat", {"sleep_state": "PLACED"})
        state["body"]["energy"] = 40.
        state["combat_personal"]["phase"] = "alive"
        started = self.host.execute(state, operation="sleep", args=["fixture", "maximum"], player_id="first")
        self.assertTrue(started["ok"], started.get("error"))
        before = started["snapshot"]
        after = self.host.execute(before, elapsed=5, shared=False, player_id="first")["snapshot"]
        self.assertGreater(after["body"]["energy"], before["body"]["energy"])
        self.assertEqual(before["body_environment"], after["body_environment"])
        self.assertEqual(after["body"]["sleep_session"]["rate"], 25.)


if __name__ == "__main__":
    names = ["test_copper_tools_advance_double_work_once_per_strike", "test_shelter_posts_block_authoritative_movement",
             "test_lantern_lifetime_and_personal_fuel", "test_weather_movement_is_authoritative",
             "test_sleep_recovers_at_current_rate", "test_sleep_occupancy_second_character_and_wake",
             "test_network_torch_fuel_and_field_weapon", "test_guide_progress_is_personal_and_survives_restore",
             "test_crop_seed_fertilizer_and_harvest", "test_personal_tick_does_not_advance_shared_world_twice",
             "test_database_restore_discards_uncommitted_mutation", "test_building_place_consumes_materials_and_rejects_repeat"]
    result = unittest.TextTestRunner(verbosity=2).run(unittest.TestSuite(LocalRollup(name) for name in names))
    sys.exit(not result.wasSuccessful())
