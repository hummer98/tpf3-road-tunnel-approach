#!/usr/bin/env python3
"""Writes the retaining wall's models: content/road_tunnel_ramp/walls/<part>.mdl.

One model per part: the wall (wall.mdl), the portal cover (slab.mdl) and
the coping and parapet (strip.mdl), and concrete.mdl, a copy of wall.mdl
kept under the name the wall had in earlier builds (OLD_NAMES). Each
part gets a mesh whose texture coordinates are baked for its own base
size, so a 19-107m wide cover is not drawn with the wall's texture
stretched across it (about 18 times in game, 2026-11-24). All parts have the same base-game material (MATERIAL). The
mesh paths are written here once (WALL_MESH, SLAB_MESH, STRIP_MESH): when a
mesh is replaced, change its constant and run this again rather than
editing the .mdl files by hand. All meshes span the same box
(BB_MIN..BB_MAX), which the transforms in ramp_geometry.lua scale.

The material is the base game's, referenced as "::/<path>" (other mods'
models reach the base game's rail.mtl as "::/infrastructure/track/shared/
mat/rail.mtl"); nothing is copied. The parts must match ramp_geometry.lua
M.WALL_MODELS (the Lua tests check that every model there exists and that
the files match this script's output).

Usage (from anywhere): python3 tools/wall_models.py [--check]
--check writes nothing and exits 1 when a file differs from the output.
"""
import argparse
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WALLS = os.path.join(ROOT, "content", "road_tunnel_ramp", "walls")

# The meshes, all a box x 0..1, y -0.225..0.225, z 0..1 (the transforms in
# ramp_geometry.lua scale it by these extents), made for this mod, each
# with texture coordinates set for its part's base size: the wall box for
# a 4 m long, 6 m high wall piece, the slab box for a 4 x 4 m cover piece
# 0.8 m thick (its top two repeats each way, whole numbers at the edges, so
# the pieces join without a break in the pattern), the strip box for a
# 4 m long coping 2.3 m wide and 0.4 m thick.
WALL_MESH = "/road_tunnel_ramp/walls/aom_wall_box.msh"
SLAB_MESH = "/road_tunnel_ramp/walls/aom_slab_box.msh"
STRIP_MESH = "/road_tunnel_ramp/walls/aom_strip_box.msh"
# (part, mesh): the file name (<part>.mdl) and the child node name. The
# names must match ramp_geometry.lua M.WALL_MODELS.
PARTS = [
    ("wall", WALL_MESH),
    ("slab", SLAB_MESH),
    ("strip", STRIP_MESH),
]
# (old name, part): models written again under a name an earlier build
# used, with the part's text. A save keeps the ids of the models it placed
# in its own model table, so a save from a build that placed
# walls/concrete.mdl for every wall, coping and cover piece (before the
# mod's own box, 2026-11-24) asks for that file when it loads; without it
# the game shows the "models are missing ... replaced by placeholders"
# window (measured 2026-11-25). The file keeps the old name only: the
# borrowed mesh, material and textures it used are gone (they are not in
# a save's model table) and it now shows the wall part. New builds never
# place it (ramp_geometry.lua M.WALL_MODELS has no entry for it).
OLD_NAMES = [
    ("concrete", "wall"),
]
BB_MIN = (0, -0.225, 0)
BB_MAX = (1, 0.225, 1)

# Plain light grey concrete with no dirt overlay (albedo mean about
# 138/134/131), tileable (wrap REPEAT) with a normal map (the meshes carry
# tangents); the nearest in look to the earlier wall (157/155/148).
# tf_walls_02 (169/165/158) is nearer by albedo but multiplies a dirt
# texture at 0.7 over it, so it would show darker. Dark concrete, red brick
# and dressed stone were tried as a Wall colour setting and dropped before
# release (the user, 2026-11-24: 「白以外は微妙ですね」「白だけ採用」).
MATERIAL = "::/warehouses/wh_goods/mat/warehouse_goods_concrete.mtl"

IDENTITY = "{1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}"


def num(x):
    return repr(x) if isinstance(x, float) else str(x)


def model_text(material, mesh, part):
    """The .mdl for one part and material, in the form the old concrete.mdl had."""
    bb_min = ",".join(num(v) for v in BB_MIN)
    bb_max = ",".join(num(v) for v in BB_MAX)
    return (
        "function data()\n"
        "return {[\"version\"]=2,"
        "[\"boundingInfo\"]={[\"bbMin\"]={%s},[\"bbMax\"]={%s}},"
        "[\"lods\"]={{[\"node\"]={[\"name\"]=\"Root\",[\"transf\"]=%s,"
        "[\"children\"]={{[\"name\"]=\"%s\",[\"mesh\"]=\"%s\","
        "[\"materials\"]={\"%s\"},[\"transf\"]=%s}}},"
        "[\"visibleFrom\"]=0,[\"visibleTo\"]=3000}},"
        "[\"metadata\"]={}}\n"
        "end\n"
    ) % (bb_min, bb_max, IDENTITY, part, mesh, material, IDENTITY)


def outputs():
    """{path: text} for every part and every old name (OLD_NAMES)."""
    out = {os.path.join(WALLS, "%s.mdl" % part): model_text(MATERIAL, mesh, part)
           for part, mesh in PARTS}
    for old, part in OLD_NAMES:
        out[os.path.join(WALLS, "%s.mdl" % old)] = out[os.path.join(WALLS, "%s.mdl" % part)]
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true",
                    help="write nothing; exit 1 if a file differs")
    args = ap.parse_args(argv)
    stale = []
    for path, text in outputs().items():
        try:
            with open(path, encoding="utf-8") as f:
                same = f.read() == text
        except FileNotFoundError:
            same = False
        if same:
            continue
        stale.append(os.path.relpath(path, ROOT))
        if not args.check:
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write(text)
    for rel in stale:
        print(("differs: " if args.check else "wrote: ") + rel)
    return 1 if (args.check and stale) else 0


if __name__ == "__main__":
    sys.exit(main())
