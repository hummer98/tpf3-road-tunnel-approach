#!/usr/bin/env python3
"""Writes the tram copies of the full-width ramp's and the median centre's
streets (content/road_tunnel_ramp/streets/tram_<stem>_<lanes>_<power>).

The Tram track setting (rtr_tram, both constructions) lays the track on the
flat approach, the descent and the tunnel stub, on the same lane. The track
comes with the street template, as the base game's tram streets carry it
(town_new_small_tram_electrified: TRAM and ELECTRIC_TRAM on its outer car
lanes; town_old_small_tram: TRAM only), not as the edges' tramTrackType:
given that, the engine put the track on the outer car lane of both
directions and none on the tunnel edges [measured 2026-11-23 PT E1, on the
median of then], and it has no way to pick one side [source: the edge's
params carry tramTrackType NO / YES / ELECTRIC only; StreetType
busAndTramRight is one flag for the whole template]. The base underground
tram station builds its TUNNEL edges from a template with tram lanes
[source: stations street.zip underground_station.script.lua, as read for
the median's tram, 2026-11-23].

For each source below, six copies (four for a one-way street, which has no
b: Both on it is its outer lane, f or k by the traffic side): the lanes
  b  the outer car lane of each direction, the base game's tram streets'
     lanes
  f  the last car lane (two-way: the outer lane carrying traffic forward)
  k  the first car lane (two-way: the outer lane carrying traffic backward)
and the power
  tram   TRAM (a track without catenary)
  etram  TRAM and ELECTRIC_TRAM (with catenary)
ramp_geometry.lua M.tramRef names them; which of f and k is the right or
left lane depends on the traffic side (M.spec).

The copies are the sources as they are, but hidden from the build menu
(availability 0 / 0, no menuCategory) and not built by towns (no
simBuildable); they keep the sources' names, so a handed-over approach still
reads as a Small Street.

Usage: python3 tools/make_tram_templates.py [--check] [street.zip]
(street.zip defaults to the installed game's; without it only the copies of
the mod's own templates are written or checked.)
"""
import os
import re
import sys
import zipfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
STREETS = os.path.join(ROOT, "content", "road_tunnel_ramp", "streets")
STREET_ZIP = os.path.expanduser(
    "~/.local/share/Steam/steamapps/common/Transport Fever 3/base/content/"
    "infrastructure/street.zip")

# (output stem, source): "base:" a path in street.zip, "mod:" a template in
# STREETS. ramp.con.lua's streets (ref) and their descents.
SOURCES = [
    ("highway_new_small", "base:street/highway/highway_new_small.street_template.lua"),
    ("country_new_small", "base:street/country/country_new_small.street_template.lua"),
    ("town_new_small", "base:street/town/town_new_small.street_template.lua"),
    ("highway_new_medium", "base:street/highway/highway_new_medium.street_template.lua"),
    ("country_new_medium", "base:street/country/country_new_medium.street_template.lua"),
    ("town_new_medium", "base:street/town/town_new_medium.street_template.lua"),
    ("town_new_large", "base:street/town/town_new_large.street_template.lua"),
    ("ramp_car_only", "mod:ramp_car_only"),
    ("ramp_descent_highway_small", "mod:ramp_descent_highway_small"),
    ("ramp_descent_country_small", "mod:ramp_descent_country_small"),
    ("ramp_descent_town_small", "mod:ramp_descent_town_small"),
    ("ramp_descent_highway_medium", "mod:ramp_descent_highway_medium"),
    ("ramp_descent_country_medium", "mod:ramp_descent_country_medium"),
    ("ramp_descent_town_medium", "mod:ramp_descent_town_medium"),
    ("ramp_descent_town_large", "mod:ramp_descent_town_large"),
]
LANES = ("b", "f", "k")
POWERS = (("tram", ("TRAM",)), ("etram", ("TRAM", "ELECTRIC_TRAM")))

LANE = re.compile(r"forward\s*=\s*(true|false),(?:(?!forward\s*=)[\s\S])*?"
                  r"transportModes\s*=\s*\{([^}]*)\}")


def read_source(source, street_zip=STREET_ZIP):
    kind, name = source.split(":", 1)
    if kind == "base":
        with zipfile.ZipFile(street_zip) as z:
            return z.read(name).decode("utf-8")
    with open(os.path.join(STREETS, name + ".street_template.lua"),
              encoding="utf-8") as f:
        return f.read()


def laneblock(text):
    start = text.index("laneConfigs = {")
    depth, i = 0, text.index("{", start)
    for j in range(i, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[start:j + 1], start, j + 1
    raise ValueError("laneConfigs not closed")


def track_lanes(text, lanes):
    """Indexes (0-based, over the laneConfigs) of the car lanes that get the
    track: b the outer car lane of each direction, f the last car lane, k
    the first."""
    cars = [(i, m.group(1) == "true")
            for i, m in enumerate(LANE.finditer(laneblock(text)[0]))
            if '"CAR"' in m.group(2)]
    assert cars, "no car lane"
    first, last = cars[0][0], cars[-1][0]
    if lanes == "f":
        return [last]
    if lanes == "k":
        return [first]
    return sorted({first, last})


def drop_block(text, key):
    """text without the `key = { ... },` block (nested braces)."""
    m = re.search(r"\n([ \t]*)" + key + r"\s*=\s*\{", text)
    if not m:
        return text
    depth = 0
    for j in range(m.end() - 1, len(text)):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                end = j + 1
                if text[end:end + 1] == ",":
                    end += 1
                return text[:m.start()] + text[end:]
    raise ValueError(key + " not closed")


def make(text, lanes, modes, source):
    block, start, end = laneblock(text)
    want = set(track_lanes(text, lanes))
    out, last = [], 0
    for i, m in enumerate(LANE.finditer(block)):
        if i in want:
            assert "TRAM" not in m.group(2), source + ": already has tram"
            body = m.group(2).rstrip()
            assert body.endswith(","), source + ": unexpected modes " + body
            new = body + "".join(' "%s",' % x for x in modes) + " "
            out.append(block[last:m.start(2)] + new)
            last = m.end(2)
    out.append(block[last:])
    text = text[:start] + "".join(out) + text[end:]
    assert len(re.findall(r"availability\s*=", text)) == 1, source + ": availability"
    assert not re.search(r"simBuildable\s*=\s*false", text), source + ": simBuildable"
    text = drop_block(text, "menuCategory")
    text = re.sub(r"\n[ \t]*simBuildable\s*=\s*true,", "", text)
    text = re.sub(r"availability\s*=\s*\{[^}]*\}",
                  "availability = { yearFrom = 0, yearTo = 0, }", text, count=1)
    if "initiallyLocked" not in text:
        text = text.replace("availability = { yearFrom = 0, yearTo = 0, }",
                            "availability = { yearFrom = 0, yearTo = 0, },\n"
                            "\t\tinitiallyLocked = true", 1)
    head = ("-- Generated by tools/make_tram_templates.py from %s: the same "
            "street with %s on\n-- lane%s %s (1-based), hidden from the "
            "build menu. Do not edit.\n"
            % (source, " and ".join(modes), "s" if len(want) > 1 else "",
               ", ".join(str(i + 1) for i in sorted(want))))
    return head + text


def name(stem, lanes, power):
    return "tram_%s_%s_%s.street_template.lua" % (stem, lanes, power)


def one_way(text):
    """All car lanes forward (the highways and their descents)."""
    return all(m.group(1) == "true"
               for m in LANE.finditer(laneblock(text)[0])
               if '"CAR"' in m.group(2))


def outputs(street_zip=STREET_ZIP, with_base=True):
    """{ file name: text } for every copy (the base ones only with_base)."""
    out = {}
    for stem, source in SOURCES:
        if source.startswith("base:") and not with_base:
            continue
        text = read_source(source, street_zip)
        for lanes in LANES:
            if lanes == "b" and one_way(text):
                continue
            for power, modes in POWERS:
                out[name(stem, lanes, power)] = make(text, lanes, modes, source)
    return out


def main(argv):
    if "-h" in argv or "--help" in argv:
        print(__doc__)
        return 0
    check = "--check" in argv
    args = [a for a in argv if a != "--check"]
    street_zip = args[0] if args else STREET_ZIP
    with_base = os.path.exists(street_zip)
    if not with_base:
        print("street.zip not found: only the mod's own templates")
    bad = 0
    for fname, text in sorted(outputs(street_zip, with_base).items()):
        path = os.path.join(STREETS, fname)
        old = None
        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                old = f.read()
        if old == text:
            continue
        if check:
            print("differs: " + fname)
            bad += 1
        else:
            with open(path, "w", encoding="utf-8") as f:
                f.write(text)
            print("wrote: " + fname)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
