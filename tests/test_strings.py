"""Tests for strings.json: python3 -m unittest discover -s tests"""
import gettext
import json
import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME_STRINGS = os.path.expanduser(
    "~/.local/share/Steam/steamapps/common/Transport Fever 3/base/strings")
LANGS = ["en", "ja", "de", "es", "fr", "it", "ko", "nl", "pl", "pt_BR", "ru",
         "zh_CN", "zh_TW"]
# street picker entry -> the vanilla template's name key (the templates in
# ramp.con.lua use _("STREET_..._NAME") for their own build-menu names)
STREET_NAMES = {
    "rtr_street_highway_small": "STREET_HIGHWAY_NEW_SMALL_NAME",
    "rtr_street_country_small": "STREET_COUNTRY_NEW_SMALL_NAME",
    "rtr_street_town_small": "STREET_TOWN_NEW_SMALL_NAME",
    "rtr_street_highway_medium": "STREET_HIGHWAY_NEW_MEDIUM_NAME",
    "rtr_street_country_medium": "STREET_COUNTRY_NEW_MEDIUM_NAME",
    "rtr_street_town_medium": "STREET_TOWN_NEW_MEDIUM_NAME",
    "rtr_street_town_large": "STREET_TOWN_NEW_LARGE_NAME",
}
# the base game's own spelling mistakes, not copied
VANILLA_TYPOS = {("fr", "STREET_TOWN_NEW_MEDIUM_NAME"): "Rue moyenne"}


def load_strings():
    with open(os.path.join(ROOT, "strings.json"), encoding="utf-8") as f:
        return json.load(f)


class StringsTest(unittest.TestCase):
    def test_all_game_languages_have_the_same_keys(self):
        s = load_strings()
        self.assertEqual(sorted(s), sorted(LANGS))
        for lang in LANGS:
            self.assertEqual(sorted(s[lang]), sorted(s["en"]), lang)
            for key, value in s[lang].items():
                self.assertTrue(value.strip(), "%s: %s empty" % (lang, key))

    def test_median_side_streets_are_joined_by_the_player(self):
        # 2026-11-24: 「中央導入路パターンは、側道接続は離散/合流共にユーザーに
        # やってもらうことにします。プリセット設置が不可能ならスクリプト接続は
        # 無し。」 The Exit and Fork settings and the fork's streets are gone,
        # and the description no longer promises a join the mod does not lay
        s = load_strings()
        promised = ("Right after placing", "置くとすぐ", "Gleich nach dem Platzieren",
                    "Justo al colocarlo", "Dès la pose", "Appena posato", "놓자마자",
                    "Direct na het plaatsen", "Zaraz po postawieniu",
                    "Logo ao colocar", "Сразу после установки", "立即接上")
        for lang in LANGS:
            for key in s[lang]:
                self.assertFalse(key.startswith(("rtr_median_exit", "rtr_median_fork")),
                                 "%s: %s" % (lang, key))
            desc = s[lang]["rtr_median_description"]
            for old in promised:
                self.assertNotIn(old, desc, lang)
            self.assertNotIn("=", desc, lang)
        self.assertIn("lay the fork at the near end and the merge past the far end yourself",
                      s["en"]["rtr_median_description"])
        self.assertIn("自分で道路を引いてつないでください", s["ja"]["rtr_median_description"])
        self.assertIn("擁壁とポータル天蓋の脇", s["ja"]["rtr_median_description"])

    def test_median_side_street_menu_name(self):
        # 2026-11-24: the side street is in the street menu, one type only,
        # so its name says what it is (one-way, one sidewalk), not a side
        # (「名前も「左右」を入れず「側道（片側歩道の一方通行）」の意味の短い
        # ものに」); the median's description points to it by that name
        s = load_strings()
        self.assertEqual(s["ja"]["rtr_median_side_name"], "側道（片側歩道の一方通行）")
        self.assertEqual(s["en"]["rtr_median_side_name"], "Side street (one-way, one sidewalk)")
        for lang in LANGS:
            name = s[lang]["rtr_median_side_name"]
            for word in ("左", "右", "Left", "Right", "left", "right", "Median", "median"):
                self.assertNotIn(word, name, lang)
            self.assertLessEqual(len(name), 50, lang)
            self.assertIn(name, s[lang]["rtr_median_description"], lang)
        self.assertIn("建物が建ちません", s["ja"]["rtr_median_side_desc"])

    def test_median_rebuilt_options_are_described_and_the_old_ones_gone(self):
        # 2026-11-24, the median rebuilt on the full-width ramp's body: a
        # centre street picked from the ramp's two-lane streets (cars-only
        # initially), the side streets' lanes by entry; the old options
        # (centre lanes, split / separate, link, tram) are gone everywhere
        s = load_strings()
        gone = ("rtr_median_lanes_", "rtr_median_join", "rtr_median_link",
                "rtr_median_tram", "rtr_median_side_stub",
                "rtr_median_split_piece", "rtr_median_ramp_")
        for lang in LANGS:
            for key in s[lang]:
                self.assertFalse(key.startswith(gone), "%s: %s" % (lang, key))
            for key in ("rtr_median_street_name", "rtr_median_street_tooltip",
                        "rtr_median_direction_tooltip"):
                self.assertTrue(s[lang][key].strip(), "%s: %s" % (lang, key))
            # the centre street's label is not the Medium Street's name
            self.assertNotIn(s[lang]["rtr_median_street_name"],
                             s[lang]["rtr_street_town_medium"], lang)
        self.assertIn("初期設定", s["ja"]["rtr_median_street_tooltip"])
        self.assertIn("(initial setting)", s["en"]["rtr_median_street_tooltip"])
        for key in ("rtr_median_entry_tooltip", "rtr_median_description",
                    "rtr_median_ground_along_tooltip"):
            # no green median, split or centre-lanes option any more
            for word in ("Split", "Centre lanes", "green", "Medium Street piece"):
                self.assertNotIn(word, s["en"][key], key)
            for word in ("分岐", "中央の車線", "緑"):
                self.assertNotIn(word, s["ja"][key], key)
            self.assertNotIn("既定", s["ja"][key], key)
        # the base game's Russian spells it туннель
        for key in ("rtr_median_entry_tooltip",
                    "rtr_median_description", "rtr_median_direction_tooltip",
                    "rtr_median_street_tooltip"):
            self.assertNotIn("тоннел", s["ru"][key], key)
        self.assertNotIn("路面電車", "".join(s["ja"].values()))

    def test_car_only_street_label_and_tooltip(self):
        # entry 8: its label gives the width (8m since 2026-11-24: its own
        # template with two 3.5m car lanes and 0.5m shoulders that carry
        # nothing; 14m with town_new_small's lanes and 2m pedestrian
        # shoulders before, briefly 11m), and the street tooltip says
        # pedestrians cannot use it, in every language; 11m and 14m are gone
        # from both (the small country road's own 14m label is another key)
        s = load_strings()
        width = r"(?<![\d.])8\s?(m|м|米|公尺)"
        olds = (r"(?<![\d.])11\s?(m|м|米|公尺)", r"(?<![\d.])14\s?(m|м|米|公尺)")
        for lang in LANGS:
            for key in ("rtr_street_car_only", "rtr_street_tooltip"):
                self.assertRegex(s[lang][key], width, lang + " " + key)
                for old in olds:
                    self.assertNotRegex(s[lang][key], old, lang + " " + key)
        self.assertEqual(s["ja"]["rtr_street_car_only"], "2車線 車専用 歩道なし 幅8m")
        self.assertIn("歩行者は通れません", s["ja"]["rtr_street_tooltip"])
        # buses and trucks use it too, so no word that reads as "cars"
        self.assertNotIn("cars", s["en"]["rtr_street_car_only"])
        self.assertIn("pedestrians cannot use the ramp",
                      s["en"]["rtr_street_tooltip"])

    def test_wall_width_labels_and_tooltip(self):
        # rtr_wall (2026-11-23): short ASCII labels, the same everywhere;
        # the tooltip names both and the initial setting in every language.
        # The thin wall is 1.5m since 2026-11-24 (no clearance to the
        # street: 「擁壁側の路肩はなくして」); 2.0m is gone
        s = load_strings()
        for lang in LANGS:
            self.assertEqual(s[lang]["rtr_wall_thin"], "1.5m", lang)
            self.assertNotIn("2.0m", s[lang]["rtr_wall_tooltip"], lang)
            self.assertNotRegex(s[lang]["rtr_wall_tooltip"], r"0[.,]5\s?(m|м|米|公尺)\s?(clear|Abstand|de separación|d'écart|di distanza|vrij|odstępu|de folga|от дороги|あけて|띄우고)", lang)
            self.assertNotRegex(s[lang]["rtr_wall_tooltip"], r"(离|離)道路 0\.5", lang)
            self.assertEqual(s[lang]["rtr_wall_thick"], "3.4m", lang)
            self.assertTrue(s[lang]["rtr_wall_name"], lang)
            tip = s[lang]["rtr_wall_tooltip"]
            self.assertLess(tip.index("1.5m"), tip.index("3.4m"), lang)
            self.assertRegex(tip, r"1[.,]1\s?(m|м|米|公尺)", lang + ": parapet height")
        self.assertIn("1.5m（初期設定）", s["ja"]["rtr_wall_tooltip"])
        self.assertNotIn("既定", s["ja"]["rtr_wall_tooltip"])
        self.assertIn("1.5m (initial setting)", s["en"]["rtr_wall_tooltip"])

    def test_car_only_template_name_and_description(self):
        # the street's own name and description (its info window), in every
        # language; the description says pedestrians cannot use it
        s = load_strings()
        for lang in LANGS:
            self.assertTrue(s[lang]["rtr_ramp_car_only_name"], lang)
            self.assertTrue(s[lang]["rtr_ramp_car_only_desc"], lang)
        self.assertIn("歩行者は通れません", s["ja"]["rtr_ramp_car_only_desc"])
        self.assertIn("Pedestrians cannot use it", s["en"]["rtr_ramp_car_only_desc"])

    def test_street_labels_start_with_the_vanilla_street_names(self):
        # players pick the street by the name the build menu shows them
        if not os.path.isdir(GAME_STRINGS):
            self.skipTest("game strings not found")
        s = load_strings()
        for lang in LANGS:
            mo = os.path.join(GAME_STRINGS, lang, "LC_MESSAGES", "base.mo")
            with open(mo, "rb") as f:
                catalog = gettext.GNUTranslations(f)
            for key, vanilla_key in STREET_NAMES.items():
                want = VANILLA_TYPOS.get((lang, vanilla_key),
                                         catalog.gettext(vanilla_key))
                self.assertNotEqual(want, vanilla_key, "%s: %s not in base.mo"
                                    % (lang, vanilla_key))
                self.assertTrue(s[lang][key].startswith(want),
                                "%s %s: %r does not start with %r"
                                % (lang, key, s[lang][key], want))

    def test_no_test_street_strings_are_left(self):
        # the test streets tried in the game on 2026-11-24 were removed
        # before 1.0.0, so their names and descriptions go too
        s = load_strings()
        for lang in LANGS:
            left = [k for k in s[lang] if k.startswith("rtr_test_")]
            self.assertEqual(left, [], lang)


if __name__ == "__main__":
    unittest.main()
