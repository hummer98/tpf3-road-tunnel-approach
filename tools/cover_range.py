#!/usr/bin/env python3
"""Writes the Portal cover length range from ramp_geometry.lua everywhere
the game's Lua cannot read it.

The range lives in one line of content/road_tunnel_ramp/ramp_geometry.lua:

    M.LID_MIN, M.LID_MAX, M.LID_DEFAULT = <min>, <max>, <default>

The two .con sliders, the mod setting's positions (cover_setting.lua) and
the script's reading of a placed ramp's value (lidLengthOf) take it from
there at run time. JSON and the texts cannot, so this tool writes:

- mod.json: the mod setting rtr_cover_length_default's "values"
  ("<min>m" .. "<max>m") and its 0-based "defaultIndex" (the default's);
- the cover range "<a>-<max> m" ("-", "–" or "〜") in README.md,
  docs/modio_description.md, _metadata/modinfo.json's description and
  CHANGELOG.md's Unreleased section (the released sections stay as they
  were released). Only a range ending on <max> is touched, on a line that
  speaks of the cover ("cover" or 天蓋; the whole description for
  modinfo.json, one JSON line).

The in-game tooltips name no lower end (the slider shows it), so
strings.json needs nothing.

tests/test_cover_range.py runs --check, so a new LID_MIN fails the tests
until this has been run.

Usage (from anywhere):
  python3 tools/cover_range.py           # write the files
  python3 tools/cover_range.py --check   # only say what is out of date
"""
import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEOMETRY = os.path.join("content", "road_tunnel_ramp", "ramp_geometry.lua")
MOD_JSON = "mod.json"
MOD_PARAM = "rtr_cover_length_default"
TEXTS = ("README.md", os.path.join("docs", "modio_description.md"))
MODINFO = os.path.join("_metadata", "modinfo.json")
CHANGELOG = "CHANGELOG.md"


def read(root, rel):
    with open(os.path.join(root, rel), encoding="utf-8") as f:
        return f.read()


def write(root, rel, text):
    with open(os.path.join(root, rel), "w", encoding="utf-8", newline="") as f:
        f.write(text)


def lid_range(root=ROOT):
    """(min, max, default) from ramp_geometry.lua."""
    text = read(root, GEOMETRY)
    m = re.search(r"^M\.LID_MIN,\s*M\.LID_MAX,\s*M\.LID_DEFAULT\s*=\s*(\d+),\s*(\d+),\s*(\d+)\s*$",
                  text, re.M)
    if not m:
        raise SystemExit("cover_range: no 'M.LID_MIN, M.LID_MAX, M.LID_DEFAULT = a, b, c' line in " + GEOMETRY)
    lo, hi, default = (int(g) for g in m.groups())
    if not lo <= default <= hi:
        raise SystemExit("cover_range: LID_DEFAULT %d is outside %d..%d" % (default, lo, hi))
    return lo, hi, default


def fix_mod_json(text, lo, hi, default):
    """mod.json with the setting's values and defaultIndex; the layout of
    the file (one line of values) is kept."""
    params = json.loads(text)["params"]
    if [p.get("key") for p in params].count(MOD_PARAM) != 1:
        raise SystemExit("cover_range: mod.json has no single %s param" % MOD_PARAM)
    start = text.index('"key": "%s"' % MOD_PARAM)
    end = text.find("}", start)
    block = text[start:end]
    values = ", ".join('"%dm"' % n for n in range(lo, hi + 1))
    block, n1 = re.subn(r'"values":\s*\[[^\]]*\]', '"values": [ %s ]' % values, block)
    block, n2 = re.subn(r'"defaultIndex":\s*\d+', '"defaultIndex": %d' % (default - lo), block)
    if n1 != 1 or n2 != 1:
        raise SystemExit("cover_range: mod.json's %s needs one values and one defaultIndex" % MOD_PARAM)
    return text[:start] + block + text[end:]


def range_re(hi):
    # "6–24 m", "6-24 m", "6〜24 m"; not "13–25 m" or "−20〜+20%"
    return re.compile(r"(?<![\d.])\d+([-–〜])%d m\b" % hi)


def fix_ranges(text, lo, hi, every_line=False):
    pat = range_re(hi)
    out = []
    for line in text.splitlines(keepends=True):
        if every_line or "cover" in line.lower() or "天蓋" in line:
            line = pat.sub(lambda m: "%d%s%d m" % (lo, m.group(1), hi), line)
        out.append(line)
    return "".join(out)


def fix_changelog(text, lo, hi):
    """Only the Unreleased section: the released ones say what they had."""
    m = re.search(r"^## \[Unreleased\][^\n]*\n", text, re.M)
    if not m:
        raise SystemExit("cover_range: CHANGELOG.md has no Unreleased section")
    nxt = re.search(r"^## \[", text[m.end():], re.M)
    end = m.end() + nxt.start() if nxt else len(text)
    return text[:m.end()] + fix_ranges(text[m.end():end], lo, hi) + text[end:]


def fix_modinfo(text, lo, hi):
    info = json.loads(text)
    desc = info.get("description", "")
    # the description is one JSON string on one line; replace inside the
    # encoded text so the file's own escaping and layout stay
    encoded = json.dumps(desc, ensure_ascii=False)[1:-1]
    if encoded not in text:
        raise SystemExit("cover_range: modinfo.json's description is not written as json.dumps writes it")
    fixed = json.dumps(fix_ranges(desc, lo, hi, every_line=True), ensure_ascii=False)[1:-1]
    return text.replace(encoded, fixed, 1)


def planned(root=ROOT):
    """{relative path: (old text, new text)} for every file this tool writes."""
    lo, hi, default = lid_range(root)
    out = {}
    text = read(root, MOD_JSON)
    out[MOD_JSON] = (text, fix_mod_json(text, lo, hi, default))
    for rel in TEXTS:
        text = read(root, rel)
        out[rel] = (text, fix_ranges(text, lo, hi))
    text = read(root, MODINFO)
    out[MODINFO] = (text, fix_modinfo(text, lo, hi))
    text = read(root, CHANGELOG)
    out[CHANGELOG] = (text, fix_changelog(text, lo, hi))
    return out


def stale(root=ROOT):
    return sorted(rel for rel, (old, new) in planned(root).items() if old != new)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="write nothing; exit 1 when a file is out of date")
    args = ap.parse_args(argv)
    lo, hi, default = lid_range()
    plan = planned()
    changed = sorted(rel for rel, (old, new) in plan.items() if old != new)
    if args.check:
        if changed:
            print("cover_range: out of date for %d..%d m (default %d): %s; run python3 tools/cover_range.py"
                  % (lo, hi, default, ", ".join(changed)))
            return 1
        print("cover_range: up to date (%d..%d m, default %d)" % (lo, hi, default))
        return 0
    for rel in changed:
        write(ROOT, rel, plan[rel][1])
        print("cover_range: wrote " + rel)
    if not changed:
        print("cover_range: nothing to write (%d..%d m, default %d)" % (lo, hi, default))
    return 0


if __name__ == "__main__":
    sys.exit(main())
