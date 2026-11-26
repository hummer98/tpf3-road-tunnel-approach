"""Tests for mod.json's mod setting: python3 -m unittest discover -s tests"""
import json
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import cover_range  # noqa: E402


def load(name):
    with open(os.path.join(ROOT, name), encoding="utf-8") as f:
        return json.load(f)


class ModParamsTest(unittest.TestCase):
    # 2026-11-26, the user: 「1.1.0にMODの設定を入れてOKです」: the initial
    # Portal cover length, 18m initially; from 1.1.1 its lower end is the
    # slider's (ramp_geometry.lua LID_MIN), no longer 6m
    def test_initial_cover_length_setting(self):
        mod = load("mod.json")
        params = mod["params"]
        self.assertEqual([p["key"] for p in params], ["rtr_cover_length_default"])
        p = params[0]
        self.assertEqual(p["uiType"], "Slider")
        lo, hi, default = cover_range.lid_range(ROOT)
        self.assertIn(lo, (8, 10, 12))
        self.assertEqual((hi, default), (24, 18))
        self.assertEqual(p["values"], ["%dm" % n for n in range(lo, hi + 1)])
        self.assertNotIn("6m", p["values"])  # 1.1.0's lower end showed the portal piece
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
