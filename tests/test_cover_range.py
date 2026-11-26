"""Tests for tools/cover_range.py: python3 -m unittest discover -s tests

The Portal cover length's lower end lives in ramp_geometry.lua (LID_MIN).
1.1.1 raised it from 6m (at 6m the top of the game's tunnel portal piece
showed past the cover; the user: 「下限を上げて隠す、ということですね」);
e2e picks 8, 10 or 12. These tests hold the files the game's Lua cannot
read (mod.json, the texts) to that value, and show that changing it is the
constant plus one run of the tool.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import cover_range  # noqa: E402

GEOMETRY_LINE = re.compile(r"^(M\.LID_MIN,\s*M\.LID_MAX,\s*M\.LID_DEFAULT\s*=\s*)\d+", re.M)


class UpToDateTest(unittest.TestCase):
    def test_every_file_follows_lid_min(self):
        self.assertEqual(cover_range.stale(ROOT), [],
                         "run python3 tools/cover_range.py")

    def test_check_mode_exits_0(self):
        r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "cover_range.py"), "--check"],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_mod_json_is_the_range(self):
        lo, hi, default = cover_range.lid_range(ROOT)
        with open(os.path.join(ROOT, "mod.json"), encoding="utf-8") as f:
            p = json.load(f)["params"][0]
        self.assertEqual(p["values"], ["%dm" % n for n in range(lo, hi + 1)])
        self.assertEqual(p["values"][p["defaultIndex"]], "%dm" % default)


class FixTest(unittest.TestCase):
    def test_only_cover_ranges_ending_on_the_max(self):
        text = ("| Portal cover length | 6–24 m in 1 m steps; 13–25 m |\n"
                "| Underground depth | 13–25 m, 6–24 m |\n"
                "ポータル天蓋の長さ 6〜24 m、15〜40 m で 12〜16 m\n"
                "cover (6-24 m), ground (−20 to +20%), 16–24 m across\n")
        want = ("| Portal cover length | 10–24 m in 1 m steps; 13–25 m |\n"
                "| Underground depth | 13–25 m, 6–24 m |\n"
                "ポータル天蓋の長さ 10〜24 m、15〜40 m で 12〜16 m\n"
                "cover (10-24 m), ground (−20 to +20%), 10–24 m across\n")
        self.assertEqual(cover_range.fix_ranges(text, 10, 24), want)
        # "124 m" or "1.6–24 m" are not a range's start
        self.assertEqual(cover_range.fix_ranges("cover 1.6–24 m", 10, 24), "cover 1.6–24 m")

    def test_changelog_released_sections_stay(self):
        text = ("# Changelog\n\n## [Unreleased]\n\n### Fixed\n- cover now 6–24 m\n\n"
                "## [1.1.0] - 2026-11-26\n\n- cover 6–24 m\n")
        out = cover_range.fix_changelog(text, 12, 24)
        self.assertIn("- cover now 12–24 m\n", out)
        self.assertIn("## [1.1.0] - 2026-11-26\n\n- cover 6–24 m\n", out)

    def test_mod_json_keeps_its_layout(self):
        with open(os.path.join(ROOT, "mod.json"), encoding="utf-8") as f:
            text = f.read()
        out = cover_range.fix_mod_json(text, 8, 24, 18)
        p = json.loads(out)["params"][0]
        self.assertEqual(p["values"][0], "8m")
        self.assertEqual(len(p["values"]), 17)
        self.assertEqual(p["defaultIndex"], 10)
        self.assertEqual(p["values"][p["defaultIndex"]], "18m")
        # only those two lines change
        diff = [a for a, b in zip(text.splitlines(), out.splitlines()) if a != b]
        self.assertEqual(len(text.splitlines()), len(out.splitlines()))
        self.assertEqual(len(diff), 2, diff)


def copy_repo(dst):
    shutil.copytree(ROOT, dst, ignore=shutil.ignore_patterns(".git", "dist", "__pycache__"))


@unittest.skipUnless(shutil.which("luajit"), "luajit not installed")
class ChangeLidMinTest(unittest.TestCase):
    """8 or 12 instead of 10: the constant, then the tool, and every test
    that holds the range passes again (in a copy of the repository)."""

    def change(self, lid_min):
        with tempfile.TemporaryDirectory() as tmp:
            root = os.path.join(tmp, "repo")
            copy_repo(root)
            geo = os.path.join(root, cover_range.GEOMETRY)
            with open(geo, encoding="utf-8") as f:
                text = f.read()
            text, n = GEOMETRY_LINE.subn(lambda m: m.group(1) + str(lid_min), text)
            self.assertEqual(n, 1)
            with open(geo, "w", encoding="utf-8") as f:
                f.write(text)
            self.assertEqual(cover_range.stale(root),
                             sorted(["mod.json", "README.md", os.path.join("docs", "modio_description.md"),
                                     os.path.join("_metadata", "modinfo.json"), "CHANGELOG.md"]))
            tool = os.path.join(root, "tools", "cover_range.py")
            r = subprocess.run([sys.executable, tool], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertEqual(cover_range.stale(root), [])
            with open(os.path.join(root, "mod.json"), encoding="utf-8") as f:
                p = json.load(f)["params"][0]
            self.assertEqual(p["values"][0], "%dm" % lid_min)
            self.assertEqual(p["values"][p["defaultIndex"]], "18m")
            with open(os.path.join(root, "CHANGELOG.md"), encoding="utf-8") as f:
                log = f.read()
            self.assertIn("%d–24 m" % lid_min, log.split("## [1.1.0]")[0])
            self.assertIn("6–24 m", log.split("## [1.1.0]")[1], "1.1.0's section as released")
            r = subprocess.run(["luajit", "tests/run.lua"], cwd=root, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stdout[-3000:] + r.stderr)
            r = subprocess.run([sys.executable, "-m", "unittest", "test_mod_params", "test_strings"],
                               cwd=os.path.join(root, "tests"), capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr[-3000:])

    def test_8(self):
        self.change(8)

    def test_12(self):
        self.change(12)


if __name__ == "__main__":
    unittest.main()
