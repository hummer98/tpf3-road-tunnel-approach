"""Tests for mod.json's mod setting: python3 -m unittest discover -s tests"""
import json
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load(name):
    with open(os.path.join(ROOT, name), encoding="utf-8") as f:
        return json.load(f)


class ModParamsTest(unittest.TestCase):
    # 2026-11-26, the user: 「1.1.0にMODの設定を入れてOKです」: the initial
    # Portal cover length, 6-24m, 18m initially
    def test_initial_cover_length_setting(self):
        mod = load("mod.json")
        params = mod["params"]
        self.assertEqual([p["key"] for p in params], ["rtr_cover_length_default"])
        p = params[0]
        self.assertEqual(p["uiType"], "Slider")
        self.assertEqual(p["values"], ["%dm" % n for n in range(6, 25)])
        self.assertNotIn("numbers", p)  # arrives as the 1-based position
        # mod.json's defaultIndex counts from 0 (the base game's own
        # mod.json: map.format 0 is its first value), unlike a .con's
        self.assertEqual(p["values"][p["defaultIndex"]], "18m")
        strings = load("strings.json")
        for lang, table in strings.items():
            self.assertIn(p["name"], table, lang)
            self.assertIn(p["tooltip"], table, lang)

    def test_run_script_is_the_mod_script(self):
        mod = load("mod.json")
        ref = mod["runScript"]["fileName"]
        m = re.match(r"^road_tunnel_ramp::/(.+)@(\w+)$", ref)
        self.assertTrue(m, ref)
        path = os.path.join(ROOT, "content", m.group(1) + ".lua")
        self.assertTrue(os.path.isfile(path), path)
        with open(path, encoding="utf-8") as f:
            self.assertIn(m.group(2) + " = function", f.read())
        self.assertEqual(mod["preRunScript"]["fileName"], "")
        self.assertEqual(mod["postRunScript"]["fileName"], "")
