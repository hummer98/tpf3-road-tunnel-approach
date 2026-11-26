"""Tests for tools/make_tram_templates.py: python3 -m unittest discover -s tests

The Tram track setting lays each street as a copy with TRAM (and
ELECTRIC_TRAM) on its outer car lanes (2026-11-26). The copies are written by
the tool; these tests hold the files to what it writes, so a changed source
template (the mod's own, or the base game's after an update) shows here.
"""
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import make_tram_templates as mtt  # noqa: E402


class UpToDateTest(unittest.TestCase):
    def test_files_match_the_tool(self):
        with_base = os.path.exists(mtt.STREET_ZIP)
        out = mtt.outputs(mtt.STREET_ZIP, with_base)
        self.assertEqual(len(out), (15 if with_base else 8) * 6)
        for name, text in out.items():
            with open(os.path.join(mtt.STREETS, name), encoding="utf-8") as f:
                self.assertEqual(f.read(), text, name)

    def test_no_stray_copies(self):
        # every tram_* file is one the tool writes (90: 15 streets x 3 lane
        # sets x 2 powers)
        stems = {s for s, _ in mtt.SOURCES}
        names = [n for n in os.listdir(mtt.STREETS) if n.startswith("tram_")]
        self.assertEqual(len(names), 90)
        for n in names:
            m = re.match(r"tram_(\w+)_([bfk])_(e?tram)\.street_template\.lua$", n)
            self.assertTrue(m, n)
            self.assertIn(m.group(1), stems, n)

    def test_lane_sets(self):
        text = ("laneConfigs = {\n"
                "{ forward = false, transportModes = { \"PERSON\", }, width = 3, },\n"
                "{ forward = false, transportModes = { \"CAR\", }, width = 5, },\n"
                "{ forward = false, transportModes = { \"CAR\", }, width = 4, },\n"
                "{ forward = true, transportModes = { \"CAR\", }, width = 4, },\n"
                "{ forward = true, transportModes = { \"CAR\", }, width = 5, },\n"
                "{ forward = true, transportModes = { \"PERSON\", }, width = 3, },\n}")
        self.assertEqual(mtt.track_lanes(text, "b"), [1, 4])
        self.assertEqual(mtt.track_lanes(text, "f"), [4])
        self.assertEqual(mtt.track_lanes(text, "k"), [1])
        one = ("laneConfigs = {\n"
               "{ forward = true, transportModes = { }, width = 2, },\n"
               "{ forward = true, transportModes = { \"CAR\", }, width = 5, },\n"
               "{ forward = true, transportModes = { }, width = 2, },\n}")
        for lanes in "bfk":
            self.assertEqual(mtt.track_lanes(one, lanes), [1])


if __name__ == "__main__":
    unittest.main()
