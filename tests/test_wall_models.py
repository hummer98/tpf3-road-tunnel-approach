"""Tests for tools/wall_models.py: python3 -m unittest discover -s tests"""
import os
import re
import shutil
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tools"))
import package  # noqa: E402
import wall_models  # noqa: E402


class WallModelsTest(unittest.TestCase):
    def test_files_are_the_scripts_output(self):
        # the .mdl files are written by the script, so a mesh change is one
        # edit of WALL_MESH / SLAB_MESH / STRIP_MESH and a rerun; a hand
        # edit shows up here
        self.assertEqual(wall_models.main(["--check"]), 0)

    def test_check_finds_a_stale_or_missing_file_and_writes_nothing(self):
        # on a copy of the walls folder, so the mod's files are never touched
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("wall.mdl", "slab.mdl", "strip.mdl", "concrete.mdl"):
                shutil.copy(os.path.join(wall_models.WALLS, name), tmp)
            saved = wall_models.WALLS
            wall_models.WALLS = tmp
            try:
                self.assertEqual(wall_models.main(["--check"]), 0)
                path = os.path.join(tmp, "strip.mdl")
                with open(path, encoding="utf-8") as f:
                    good = f.read()
                with open(path, "w", encoding="utf-8") as f:
                    f.write(good.replace(".msh\"", "_x.msh\""))
                self.assertEqual(wall_models.main(["--check"]), 1)
                with open(path, encoding="utf-8") as f:
                    self.assertIn("_x.msh", f.read())  # --check wrote nothing
                os.remove(path)
                self.assertEqual(wall_models.main(["--check"]), 1)
                self.assertFalse(os.path.exists(path))
                self.assertEqual(wall_models.main([]), 0)  # writes it back
                with open(path, encoding="utf-8") as f:
                    self.assertEqual(f.read(), good)
                self.assertEqual(wall_models.main(["--check"]), 0)
            finally:
                wall_models.WALLS = saved

    def test_one_model_per_part_with_its_own_mesh_constant(self):
        # wall, slab (the portal cover) and strip (the coping and parapet),
        # one file each, each naming its own constant's mesh
        out = wall_models.outputs()
        meshes = {"wall": wall_models.WALL_MESH, "slab": wall_models.SLAB_MESH,
                  "strip": wall_models.STRIP_MESH}
        self.assertEqual([p for p, _ in wall_models.PARTS], ["wall", "slab", "strip"])
        self.assertEqual(sorted(os.path.basename(p) for p in out),
                         ["concrete.mdl", "slab.mdl", "strip.mdl", "wall.mdl"])
        for part, mesh in meshes.items():
            text = out[os.path.join(wall_models.WALLS, part + ".mdl")]
            self.assertEqual(re.findall(r'"mesh"\]="([^"]+)"', text), [mesh], part)
            self.assertIn('"name"]="%s"' % part, text)
            mats = re.findall(r'"materials"\]=\{"([^"]+)"\}', text)
            self.assertEqual(mats, [wall_models.MATERIAL], part)
        self.assertEqual(wall_models.MATERIAL,
                         "::/warehouses/wh_goods/mat/warehouse_goods_concrete.mtl")

    def test_a_changed_mesh_constant_changes_only_its_part(self):
        # what a mesh swap does: the slab constant moves the slab file only
        saved = wall_models.PARTS
        try:
            wall_models.PARTS = [(p, "/road_tunnel_ramp/walls/other_box.msh" if p == "slab" else m)
                                 for p, m in saved]
            new = wall_models.outputs()
        finally:
            wall_models.PARTS = saved
        old = wall_models.outputs()
        for path in old:
            if path.endswith("slab.mdl"):
                self.assertNotEqual(new[path], old[path])
                self.assertIn('"/road_tunnel_ramp/walls/other_box.msh"', new[path])
            else:
                self.assertEqual(new[path], old[path], path)

    def test_wall_model_is_unchanged_by_the_split(self):
        # wall.mdl is the earlier wall_concrete_light.mdl under a new name
        text = wall_models.outputs()[os.path.join(wall_models.WALLS, "wall.mdl")]
        self.assertEqual(text, (
            'function data()\n'
            'return {["version"]=2,["boundingInfo"]={["bbMin"]={0,-0.225,0},'
            '["bbMax"]={1,0.225,1}},["lods"]={{["node"]={["name"]="Root",'
            '["transf"]={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1},["children"]={{'
            '["name"]="wall",["mesh"]="/road_tunnel_ramp/walls/aom_wall_box.msh",'
            '["materials"]={"::/warehouses/wh_goods/mat/warehouse_goods_concrete.mtl"},'
            '["transf"]={1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}}}},["visibleFrom"]=0,'
            '["visibleTo"]=3000}},["metadata"]={}}\n'
            'end\n'))

    def test_box_is_the_one_the_transforms_scale(self):
        # ramp_geometry.lua scales a 1 x 0.45 x 1 box from x 0, y centred,
        # z 0 (the box the walls were built on before the mod's own mesh)
        self.assertEqual(wall_models.BB_MIN, (0, -0.225, 0))
        self.assertEqual(wall_models.BB_MAX, (1, 0.225, 1))
        for text in wall_models.outputs().values():
            self.assertIn('["bbMin"]={0,-0.225,0},["bbMax"]={1,0.225,1}', text)

    def test_mesh_exists_and_models_are_packed(self):
        content = os.path.join(wall_models.ROOT, "content")
        names = [name for _, name in package.files_to_pack()]
        for _, mesh in wall_models.PARTS:
            rel = mesh.lstrip("/")
            self.assertTrue(os.path.isfile(os.path.join(content, rel)))
            self.assertTrue(os.path.isfile(os.path.join(content, rel + ".blob")))
            self.assertIn("content" + mesh, names)
            self.assertIn("content" + mesh + ".blob", names)
        for part, _ in wall_models.PARTS:
            self.assertIn("content/road_tunnel_ramp/walls/%s.mdl" % part, names)
        # the colour models are gone (white only, 2026-11-24)
        for name in names:
            self.assertNotRegex(name, r"walls/(wall|slab|strip)_\w+\.mdl$")

    @staticmethod
    def read_mesh(mesh):
        """(corners, counts): every triangle corner as (position, uv), and
        the vertex and index counts, read from the .msh and its blob."""
        path = os.path.join(wall_models.ROOT, "content", mesh.lstrip("/"))
        with open(path, encoding="utf-8") as f:
            msh = f.read()
        with open(path + ".blob", "rb") as f:
            blob = f.read()

        def attr(section, name):
            body = msh[msh.index(section):]
            body = body[body.index(name + " = {"):]
            body = body[:body.index("}")]
            return {k: int(v) for k, v in re.findall(r"(\w+) = (\d+)", body)}

        def arr(fmt, a):
            return struct.unpack_from("<%d%s" % (a["count"] // 4, fmt), blob,
                                      a["offset"])

        pos_a, uv_a = attr("vertexAttr", "position"), attr("vertexAttr", "uv0")
        assert pos_a["numComp"] == 3 and uv_a["numComp"] == 2
        pos, uv = arr("f", pos_a), arr("f", uv_a)
        ip, iu = arr("I", attr("indices", "position")), arr("I", attr("indices", "uv0"))
        corners = [(pos[3 * a:3 * a + 3], uv[2 * b:2 * b + 2]) for a, b in zip(ip, iu)]
        return corners, (len(pos) // 3, len(ip))

    def test_meshes_are_the_mods_own_boxes(self):
        # aom_wall_box (2026-11-24) replaced the wall mesh borrowed from
        # Enivia's mod; aom_slab_box and aom_strip_box (the same day) give
        # the cover and the coping / parapet their own texture scale. Each
        # spans the box the .mdl's boundingInfo states, 24 vertices (4 per
        # face) and 12 triangles
        self.assertEqual(
            [m for _, m in wall_models.PARTS],
            ["/road_tunnel_ramp/walls/aom_wall_box.msh",
             "/road_tunnel_ramp/walls/aom_slab_box.msh",
             "/road_tunnel_ramp/walls/aom_strip_box.msh"])
        blobs = set()
        for part, mesh in wall_models.PARTS:
            corners, (nv, ni) = self.read_mesh(mesh)
            self.assertEqual((nv, ni), (24, 36), part)
            for axis in range(3):
                vals = [p[axis] for p, _ in corners]
                self.assertAlmostEqual(min(vals), wall_models.BB_MIN[axis], 6)
                self.assertAlmostEqual(max(vals), wall_models.BB_MAX[axis], 6)
            with open(os.path.join(wall_models.ROOT, "content",
                                   mesh.lstrip("/") + ".blob"), "rb") as f:
                blobs.add(f.read())
        self.assertEqual(len(blobs), 3, "three different meshes")
        # no borrowed file left beside them
        walls = wall_models.WALLS
        for gone in ("wall.msh", "wall.msh.blob", "concrete_albedo.dds",
                     "concrete_mga.dds", "concrete.mtl"):
            self.assertFalse(os.path.exists(os.path.join(walls, gone)), gone)

    def test_old_concrete_name_is_kept_as_the_wall_model(self):
        # saves made before the mod's own box list walls/concrete.mdl in
        # their model table; when the file is missing the game shows the
        # "models are missing ... placeholders" window on load (2026-11-25).
        # The name stays, on the wall's own mesh and the base-game material
        # only (nothing of the borrowed files it used to point at)
        self.assertEqual(wall_models.OLD_NAMES, [("concrete", "wall")])
        path = os.path.join(wall_models.WALLS, "concrete.mdl")
        self.assertTrue(os.path.isfile(path))
        out = wall_models.outputs()
        with open(path, encoding="utf-8") as f:
            text = f.read()
        self.assertEqual(text, out[path])
        self.assertEqual(text, out[os.path.join(wall_models.WALLS, "wall.mdl")])
        self.assertEqual(re.findall(r'"mesh"\]="([^"]+)"', text), [wall_models.WALL_MESH])
        self.assertEqual(wall_models.WALL_MESH, "/road_tunnel_ramp/walls/aom_wall_box.msh")
        self.assertEqual(re.findall(r'"materials"\]=\{([^}]*)\}', text),
                         ['"::/warehouses/wh_goods/mat/warehouse_goods_concrete.mtl"'])
        self.assertNotIn("/road_tunnel_ramp/walls/concrete.mtl", text)
        self.assertNotIn("/road_tunnel_ramp/walls/wall.msh", text)
        names = [name for _, name in package.files_to_pack()]
        self.assertIn("content/road_tunnel_ramp/walls/concrete.mdl", names)

    def test_check_finds_a_missing_old_name(self):
        # the old name is part of --check: deleting concrete.mdl fails it
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("wall.mdl", "slab.mdl", "strip.mdl"):
                shutil.copy(os.path.join(wall_models.WALLS, name), tmp)
            saved = wall_models.WALLS
            wall_models.WALLS = tmp
            try:
                self.assertEqual(wall_models.main(["--check"]), 1)
                self.assertEqual(wall_models.main([]), 0)
                self.assertTrue(os.path.isfile(os.path.join(tmp, "concrete.mdl")))
                self.assertEqual(wall_models.main(["--check"]), 0)
            finally:
                wall_models.WALLS = saved

    def top_uv(self, mesh):
        corners, _ = self.read_mesh(mesh)
        tris = [corners[i:i + 3] for i in range(0, len(corners), 3)]
        top = [c for t in tris if all(abs(p[2] - 1) < 1e-6 for p, _ in t) for c in t]
        self.assertEqual(len(top), 6, mesh)  # two triangles
        return top

    def test_slab_top_is_two_repeats_each_way_on_whole_numbers(self):
        # a cover piece is about 4 x 4 m (ramp_geometry COVER_PIECE along,
        # W / round(W / 4) across): its top two repeats along x and across
        # y, edges on whole numbers, so the pieces join without a break
        for p, (u, v) in self.top_uv(wall_models.SLAB_MESH):
            self.assertAlmostEqual(u, 2 * p[0], 6)
            self.assertAlmostEqual(v, 2 * p[1] / 0.225 * 0.5, 6)
            self.assertAlmostEqual(u, round(u), 6)
            self.assertAlmostEqual(v, round(v), 6)

    def test_strip_top_is_set_for_a_2_3m_wide_strip(self):
        # one repeat per 2 m: 4 m along is 2, 2.3 m across is 1.15
        for p, (u, v) in self.top_uv(wall_models.STRIP_MESH):
            self.assertAlmostEqual(u, 2 * p[0], 6)
            self.assertAlmostEqual(v, p[1] / 0.225 * 0.575, 5)

    def test_every_mesh_exists(self):
        # each part's mesh (and its blob) is in the mod, so a constant
        # pointing at a mesh not yet copied in fails here, not in game
        content = os.path.join(wall_models.ROOT, "content")
        for part, mesh in wall_models.PARTS:
            rel = mesh.lstrip("/")
            self.assertTrue(os.path.isfile(os.path.join(content, rel)), part)
            self.assertTrue(os.path.isfile(os.path.join(content, rel + ".blob")), part)

    def test_lua_list_matches(self):
        # ramp_geometry.lua M.WALL_MODELS: one entry per part, <part>.mdl
        with open(os.path.join(wall_models.ROOT, "content", "road_tunnel_ramp",
                               "ramp_geometry.lua"), encoding="utf-8") as f:
            src = f.read()
        block = src[src.index("M.WALL_MODELS = {"):]
        block = block[:block.index("\n}")]
        lua = re.findall(r'(\w+) = WALL_DIR \.\. "(\w+)\.mdl"', block)
        self.assertEqual(sorted(lua), sorted((p, p) for p, _ in wall_models.PARTS))
        self.assertNotIn("WALL_COLORS", src)

if __name__ == "__main__":
    unittest.main()
