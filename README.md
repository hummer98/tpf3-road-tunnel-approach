# Road Tunnel Approach (Transport Fever 3)

[日本語は下にあります](#日本語)

Builds a street ramp that descends from the surface into an underground road
tunnel, between concrete retaining walls with a portal cover, so a street
can go underground from flat ground in one placement.

A second construction, **Median Tunnel Approach**, takes only a two-lane
centre underground and keeps a one-way side street each side on the surface,
so the town still builds houses along the road (see
[Median Tunnel Approach](#median-tunnel-approach)).

Start a new game with this mod.

## Features

- One construction lays the whole approach: a flat street, the descent in an
  open trench between retaining walls with coping on top, the portal with a
  cover slab, and a 30 m tunnel stub at the bottom. The terrain is cut and
  levelled around it.
- The streets and the tunnel are the base game's own types (the tunnel is the
  vanilla car tunnel), so vehicles use them like any other street. The
  exceptions are this mod's own: the descent's street (next point), the
  streets with a tram track (copies of the others) and the street without
  sidewalks below.
- Only the flat approach keeps the chosen street's sidewalks. From the start
  of the descent into the tunnel the street has the same lanes with a 0.5 m
  shoulder each side and no sidewalks (a highway's wide shoulders become
  0.5 m too), drawn with the same lines as the street in front (a town
  street's lines without its curbs and sidewalk paving); nobody walks into
  a road tunnel. The width taken off goes to
  the retaining walls, which stand that much further in, so the ramp is no
  wider, and the step of the terrain from the trench floor up to the ground
  lies under the wall and its top (with the 1.5 m wall a narrow groove used
  to show along the top). The 30 m tunnel stub at the bottom is the chosen
  street again, so the tunnel you lay on from it can be the same type
  (with a tram track the stub is a tram copy of the descent's street, so your tunnel is
  another type there; whether cars and trams get through there is not yet
  checked in the game). The two lanes for motor vehicles only have no
  sidewalk to take off: with the 1.5 m wall a narrow groove may still show
  along their wall top.
- Seven street types, from the one-lane highway (9 m) to the large street
  (32 m). Wider streets widen the trench, walls and portal cover with them.
- An eighth, last in the list: two lanes for motor vehicles only (one
  3.5 m lane each way, 8 m), with a 0.5 m shoulder each side and no
  sidewalks. Pedestrians cannot use it. Not yet checked in the game: that
  traffic enters it from the street you snap it to.
- Up to three streets side by side. With the one-way highways this builds a
  divided road (Double) or a 2+1 layout (Triple), each direction on the
  correct side for the traffic side you pick.
- The steepest grade of the current settings is shown under the build cursor
  ("Max grade: 24.0%"), so a short, deep ramp's slope is visible before you
  build it.
- Builds on sloped ground: set the slope of the ground along and across the
  ramp, and the walls, coping, portal cover and the banks beside them follow
  it instead of floating on the downhill side. The slope of the ground under
  the cursor is measured and shown under the build cursor in the same units
  ("Ground slope: along +6.0%, across -4.0%").

## Placing it

- Build menu: **Roads > Road Constructions > Road Tunnel Approach**.
- Snap it to the **end of an existing street**. The snap point is the start
  of the flat approach street; the ramp then runs away from that road end.
- At the bottom, the 30 m tunnel stub ends in a snap node, so your own
  tunnel can be connected to it.
- With parallel streets only one of them snaps to the road (with one-way
  highways, the one chosen by Traffic direction). The others keep open ends
  that you connect by hand.
- The flat approach street becomes an ordinary street of yours once the
  ramp is built: it stays when the ramp is bulldozed, and towns may build
  along a town street there (not between the walls on a stated slope).
  The descent, tunnel and stub stay part of the construction. Join your
  roads at the approach's start, and leave the approach's street type as
  it is: where another type meets the descent, cars may not get in.

## Settings (in the build menu)

| Setting | Values | Default |
|---|---|---|
| Street type | One-Lane Highway (one-way, 9 m), Small Country Road (14 m), Small Street (16 m), Two-Lane Highway (one-way, 18 m), Medium Country Road (22 m), Medium Street (24 m), Large Street (32 m), Two lanes, motor vehicles only (no sidewalk, 8 m) | Small Street |
| Ramp length | 40–100 m in 2 m steps: the length of the descent, used as chosen | 100 m |
| Approach length | 2–50 m in 2 m steps: flat street before the descent, from the snap point | 20 m |
| Underground depth | 13–25 m in 0.5 m steps (13 m keeps earth above the tunnel roof) | 16 m |
| Parallel streets | Single, Double, Triple (2 m between carriageways) | Single |
| Retaining wall | 1.5m / 3.4m, each side from the street edge to the outer edge of the wall top. 1.5m: right against the street edge, a 1.0 m wall and a 0.5 m top band, with a parapet 1.1 m over the ground (the street's own sidewalk or shoulder is the margin beside its lanes). 3.4m: a wider wall, 0.4 m clear, a 1.2 m wall and a coping reaching 1.8 m past it. Along the descent the wall is thicker by the sidewalk taken off (for example 3.5 m instead of 1.0 m beside a Small Street), its outer edge where it was. The portal cover is as wide as the walls | 1.5m |
| Portal cover length | 12–24 m in 1 m steps: the whole length of the portal cover, which always starts 6 m in front of the portal; 18 m reaches 12 m past the portal; even the shortest covers the top of the game's tunnel portal | 18 m (see the mod setting below) |
| Traffic direction | Into tunnel / Out of tunnel: one-way highways only; picks which way traffic flows on the street that snaps | Into tunnel |
| Traffic side | Right-hand / Left-hand: set it to your game's driving side; only matters for parallel one-way highways | Right-hand |
| Tram track | None / Both / Right / Left: a tram track on the flat approach, the descent and the tunnel stub, on the same lane all the way. Both: the outer lane of each direction, as the base game's tram streets have it (on a one-way highway: its outer lane). Right / Left: only the lane on that side, facing the tunnel (on a one-way highway, facing the way its traffic runs); which lane that is follows Traffic side. On a street with sidewalks the game lays the flat approach's track in both directions' outer lanes, so right after the build the mod lays the approach again with the track on the chosen side only (it is an ordinary street once built). If the game refuses that, the approach keeps both, and the other side's track can be taken off with the street tool | None |
| Catenary | Yes / No: the overhead wire over the tram track; without it only trams that need no wire can run. No effect without a track | Yes |
| Slope curvature | Shallow, Gentle, Normal, Steep, Very steep: the shape of the descent | Normal |
| Ground slope along | −20% to +20% in 1% steps: rise of the ground toward the tunnel (negative = it falls toward the tunnel) | 0% |
| Ground slope across | −20% to +20% in 1% steps: rise of the ground to the right when facing the tunnel (negative = the left side is higher) | 0% |

The steepest grade with Normal is about 1.5 × depth / length (16 m over
100 m = 24%). Shallow and Gentle are closer to a straight slope with a small
step at both ends; Steep and Very steep keep the ends flat for longer and
steepen the middle.

On sloped ground, copy the two values of the "Ground slope" line under the
build cursor into the two ground slope settings. The walls, coping and portal
cover then lie on that slope, the ground beside and past the portal cover is
banked to it, and the portal moves to where the earth above the tunnel is
deep enough measured from the slope (at the lower edge of the portal cover).
The street itself stays level with the road it snaps to, so on a stated slope
the approach street gets walls and coping too, from the snap point on, and
the ground between them is cut or filled to the street. On downhill
ground steeper than the ramp can get under, the whole descent stays open and
the portal cover and the ground over the tunnel's first 30 m past the portal
are held above the tunnel stub (past a shorter cover, as an embankment
without a slab); the walls, coping and banks then rise from the trench
start to the cover as an embankment (with steep
slopes a big one, so a longer or deeper ramp fits such ground better).

The portal cover starts 6 m in front of the portal and runs on for the
Portal cover length, over the tunnel's first metres where the ground above
the tunnel roof is thinnest. The banks beside it and the ground held under
it end with it. The tunnel stub at the bottom stays 30 m whatever the cover
length. (1.0.0 always laid a 36 m cover, 30 m past the portal.)

Mod setting (in the game's mod settings when you start a new game):
**Initial portal cover length**, 12–24 m, initially 18 m. It is the value
the Portal cover length slider of both constructions starts on; ramps
already placed keep the length they were built with.

## Median Tunnel Approach

Build menu: **Roads > Road Constructions > Median Tunnel Approach**, right
after Road Tunnel Approach. Snap it to the end of a street, like the
full-width ramp, or place it on open ground; either way you join the side
streets yourself.

A tunnel approach laid across a whole town street leaves no street beside it
for houses to front. This construction takes only the centre underground:
a two-lane centre street goes down into a road tunnel with the full-width
ramp's own descent, retaining walls, coping, portal cover, banks and 30 m
tunnel stub, and a one-way side street each side stays on the surface.

Plan with the initial settings (entry 4, cars-only centre, 1.5 m wall,
approach 30 m, length 100 m), looking down, the tunnel to the right. It is
24 m across, as wide as the Medium Street it is placed on:

```
x (m):    -30       0             59  65   77        100      130
          snap      |             lid portal lid end          tunnel end
y +12.0             |====== side street <- =|
y  +8.75            |  (centre line; 3.5 m lane, 3 m sidewalk outside)
y  +5.5             |== side street's inner edge = coping's outer edge
y  +5.5        coping (0-59) / portal cover (59-77), outer edge
y  +4.0..5.0   wall (0-65)
y   0     p == approach ==|== descent ===|== tunnel ========|== stub ==|
y  -4.0..5.0   wall (0-65)
y  -5.5        coping / portal cover, outer edge
y  -5.5             |== side street's inner edge = coping's outer edge
y  -8.75            |  (centre line)
y -12.0             |====== side street -> =|
```

The centre street is 8 m (cars-only, ±4 m). Nothing joins the side streets
to the road: lay the fork in front of them and the merge past them
yourself, with ordinary streets (see below).

- Centre: one of the full-width ramp's two-lane streets: the Small Street,
  the Country Road (small), the One-Lane Highway (one-way, see Traffic
  direction), or two lanes for motor vehicles only (initial setting, 8 m,
  no sidewalks). Its flat approach becomes an ordinary street of yours, as on
  the full-width ramp, free at both ends; the descent, tunnel and stub stay
  in the construction, and nothing is built beside the walls. As on the
  full-width ramp, the descent of the Small Street, Country Road and
  highway centres has no sidewalks and the walls take that width; the side
  streets stay where they are (the whole stays 24 m on a four-lane street).
- Retaining wall: 1.5 m (initial setting) or 3.4 m, as on the full-width
  ramp. The side streets move out with the wall's top.
- Side streets: one each side, one-way, sidewalk on the outer side only,
  against the coping and the portal cover, the ground under them held
  level with them. They run straight beside the walls and the portal cover,
  as long as the two together: from the descent's start (x = 0) to the
  cover's far end (the portal − 6 m + the Portal cover length; 77 m with
  the initial settings, 38 m with a 40 m ramp), so the ramp length, the
  depth, the curvature, the slopes and the cover length set their length. Once built they are ordinary streets of yours,
  free at both ends, and the town builds houses on their outer side; the
  wall side carries an invisible decoration that keeps house plots off it.
  Street lights (post-top lamps, by the curb), fireplugs and bins stand on
  the sidewalk's side only. Traffic side sets which way each one runs.
- Entry street: the town street the approach stands for, by its lanes.
  **2** (Small Street, 16 m) and **4** (Medium Street, 24 m, initial
  setting): one lane in each side street (6.5 m: 3.5 m lane, 3 m sidewalk;
  with entry 4 the whole is the Medium Street's 24 m).
  **6** (Large Street, 32 m): two lanes in each side street (11.5 m: 2 x 4 m,
  3.5 m sidewalk). The centre carries one lane each way in all three (one
  way with the highway).
- Fork and merge: yours to lay. I wanted this to be one piece that joins a
  four-lane street cleanly at both ends. I tried every way I could find and
  the game would not have it. Sorry: this part is yours to draw. Snapped to
  a street's end, the approach starts there, and the side streets' near
  ends are 30–50 m on (the Approach length): room for an S-curve from that
  end out to each side street. Placed on open ground, every end (the
  approach's start and the side streets' ends) is free to go on from. The
  approach is an ordinary street, so it can also be bulldozed and the fork
  laid another way.
  On sloped ground (either ground slope not 0%) the approach has retaining
  walls and coping either side from the snap point, right where an S-curve
  from the snap point would run: lay the fork in front of the snap point,
  or bulldoze the approach first [not checked in the game]. With entry 6
  the side streets have two lanes; the menu's side street has one, so join
  them with an ordinary street.
  The one-lane side street is in the street menu as **Side street (one-way,
  one sidewalk)** (with the small streets, after the base one-way ones): laid in
  the direction its traffic runs, its sidewalk is on the right, which is the
  outside on both sides of the trench with right-hand traffic. Like the
  side streets, it gets no houses on its left (the side without a
  sidewalk).
- Sloped ground: the two ground slope settings of the full-width ramp. The
  walls, coping, portal cover and banks follow them as there, and so do the
  side streets: on the plane, and on downhill ground, where the banks beside
  the walls rise over it, at the banks' height in pieces of 5 m. The centre
  street stays level with the road it snaps to.
- The cursor shows the steepest grade and the measured ground slope, as on
  the full-width ramp.

Distance of the side streets' centre lines from the centre line (the
coping's outer edge + half the side street):

| Centre | Entry 2 / 4, wall 1.5 m | 3.4 m | Entry 6, wall 1.5 m | 3.4 m |
|---|---|---|---|---|
| Cars only (8 m) | 8.75 m | 10.65 m | 11.25 m | 13.15 m |
| Highway (one-way, 9 m) | 9.25 m | 11.15 m | 11.75 m | 13.65 m |
| Country Road (14 m) | 11.75 m | 13.65 m | 14.25 m | 16.15 m |
| Small Street (16 m) | 12.75 m | 14.65 m | 15.25 m | 17.15 m |

| Setting | Values | Initial setting |
|---|---|---|
| Entry street | 2 (Small Street, 16 m) / 4 (Medium Street, 24 m) / 6 (Large Street, 32 m) | 4 |
| Centre street | One-lane highway (one-way, 9 m), Country Road (small, 14 m), Small Street (16 m), two lanes for motor vehicles only (8 m) | Motor vehicles only |
| Retaining wall | 1.5m / 3.4m, as on the full-width ramp | 1.5m |
| Portal cover length | 12–24 m in 1 m steps, as on the full-width ramp (from 6 m in front of the portal); the side streets end with it | 18 m |
| Ramp length | 40–100 m in 2 m steps | 100 m |
| Approach length | 30–50 m in 2 m steps, from the snap point to the side streets' near ends | 30 m |
| Underground depth | 13–25 m in 0.5 m steps | 16 m |
| Traffic direction | Into tunnel / Out of tunnel; the highway centre only | Into tunnel |
| Traffic side | Right-hand / Left-hand: set it to your game's driving side; it sets which way each side street runs, so the sidewalk is on the outside | Right-hand |
| Tram track | None / Both / Right / Left: on the centre's flat approach, descent and tunnel stub, as on the full-width ramp; the side streets get none | None |
| Catenary | Yes / No, as on the full-width ramp | Yes |
| Slope curvature | Shallow, Gentle, Normal, Steep, Very steep | Normal |
| Ground slope along | −20% to +20% in 1% steps | 0% |
| Ground slope across | −20% to +20% in 1% steps | 0% |

Checked in the game with the test tool: placing the approach (every entry,
centre and wall), cars on the centre and on the side streets; the side
streets built as long as the walls and the portal cover together; the fork
and the merge drawn with the menu's Side street type; side streets laid as
S-curves from a street's end out to 12–16 m over 15–40 m, and a merge of
two one-lane side streets into a Medium Street. Not yet checked: placing it
and drawing the fork and the merge by hand with the game's own build menu
and road tool, left-hand traffic, sloped ground.

## Compatibility

- Start a new game with this mod.
- Removing it gives a warning (`severityRemove: Warning`): placed ramps are
  constructions of this mod (`ramp.con` and `median.con`, with their own
  wall, coping and cover models), so a save that has them depends on the mod.
  The median's side streets, the descents' streets, the streets with a tram
  track (copies of the others) and the full-width ramp's street without
  sidewalks are this mod's street types; the other
  streets and the tunnel are vanilla types.
- Not `cosmetic`: it adds a construction, so the game treats it as a gameplay
  mod.
- The build-cursor grade and ground slope lines wrap the game's construction
  action and keep the lines other mods add there (for example Construction
  Altitude Tooltip).
- No dependencies.

## Install

- mod.io: https://mod.io/g/transportfever3/m/road-tunnel-approach-full-width-median (or subscribe in the game's mod
  hub).
- Manually: the game loads a local mod only from a folder named exactly
  `road_tunnel_ramp_1` inside
  `<Steam>/userdata/<your id>/3493540/local/mods/`.
  - From the release zip: create that folder and extract the zip **into** it
    (the zip has no top folder of its own).
  - From GitHub: `git clone https://github.com/hummer98/tpf3-road-tunnel-approach road_tunnel_ramp_1`
    inside `local/mods/` (a different folder name will not load).
  - Then enable the mod in the game.

## Development

| File | Role |
|---|---|
| `content/road_tunnel_ramp/ramp.con.lua` | The construction: build-menu entry, parameters and the street templates with their widths |
| `content/road_tunnel_ramp/ramp.script.lua` | `updateFn`: the vertical profile, the portal position, edges (street / tunnel), walls, coping, portal cover, terrain alignment, cost and the snap point |
| `content/road_tunnel_ramp/ramp_geometry.lua` | The full-width ramp's body (profile, portal, edges, walls, coping, cover, terrain), shared with the median approach; no engine access |
| `content/road_tunnel_ramp/median.con.lua` | The Median Tunnel Approach construction: build-menu entry and parameters |
| `content/road_tunnel_ramp/median.script.lua` | Its `updateFn`: reads the menu and the tunnel resource, and builds with `median_geometry.lua` |
| `content/road_tunnel_ramp/median_geometry.lua` | The median's layout: the centre street choices, the entry table (side street types), where the side streets lie, and the result (the ramp body plus the side streets); no engine access |
| `content/road_tunnel_ramp/streets/` | The side streets (one and two lanes, sidewalk left / right; the one-lane right one also in the street menu), the invisible wall-side decoration that keeps house plots off the trench side, and the full-width ramp's cars-only street |
| `content/road_tunnel_ramp/grade.lua` | Pure helpers for the cursor lines (steepest grade of the settings, ground slope fit, formatting), no engine access |
| `content/mod.script.lua`, `content/road_tunnel_ramp/cover_setting.lua` | The mod setting Initial portal cover length (`mod.json` params): `runFn` adds a `loadConstruction` modifier that sets the Portal cover length slider's starting value (`defaultIndex`) in both constructions; no engine access in `cover_setting.lua` |
| `content/gui/rtr_grade.script.lua`, `rtr_grade.res.lua` | Adds the grade and ground slope lines under the build cursor by wrapping `construction_react_util.getActionParams`; the ground is read with `api.engine.terrain.getBaseHeightAt` |
| `content/road_tunnel_ramp/walls/aom_wall_box.msh`, `aom_slab_box.msh`, `aom_strip_box.msh` (each with its `.msh.blob`) | The meshes, made for this mod: each one box (x 0..1, y −0.225..0.225, z 0..1) stretched by the transforms, with texture coordinates set for its part's size: the wall box for a 4 m long, 6 m high wall piece (walls are stacked in boxes of about 6 m), the slab box for a 4 x 4 m cover piece 0.8 m thick (the cover is laid in pieces of about 4 m along and across, and the pattern runs on across the joints), the strip box for a 4 m coping 2.3 m wide |
| `content/road_tunnel_ramp/walls/wall.mdl`, `slab.mdl`, `strip.mdl` | The part models: the wall, the portal cover (slab), the coping and parapet (strip), each with its own mesh path and the base game's light concrete; written by `tools/wall_models.py`, which sets the mesh paths in one place. `concrete.mdl` is the wall model again under the file name an earlier development build used; the constructions do not place it |
| `tools/wall_models.py` | Writes the wall models (`--check` compares them with the files) |
| `tools/cover_range.py` | Writes the Portal cover length range (`LID_MIN`, `LID_MAX`, `LID_DEFAULT` in `content/road_tunnel_ramp/ramp_geometry.lua`) into `mod.json`'s mod setting and the ranges in this README, the mod.io texts and the changelog's Unreleased section; the sliders read it themselves. To change the lower end, change `LID_MIN` and run it (`--check` compares) |
| `strings.json` | Build-menu texts in the game's 13 languages; street names follow the base game's own |
| `tools/make_tram_templates.py` | Writes the tram copies of the streets (`content/road_tunnel_ramp/streets/tram_*`, 82 files: each street and descent with the track on both outer car lanes (two-way streets only), the last or the first, with or without catenary) from the base game's `street.zip` and the mod's own templates (`--check` compares) |
| `_metadata/modinfo.json` | Name, summary and description for the game's mod list and the in-game mod.io upload (one text for all languages, so "English / 日本語") |
| `_metadata/0.png` | Cover image (required by the in-game uploader) |
| `docs/modio_description.md` | Description for the mod.io web page |
| `CHANGELOG.md` | Changes by version |
| `VERSION` | The version (`MAJOR.MINOR.PATCH`); `mod.json`'s `revision` is MAJOR * 10000 + MINOR * 100 + PATCH |
| `tools/package.py`, `tools/stage.py`, `tools/release.py` | The release zip, the in-game upload's staging copy, and a release (see below and [docs/release.md](docs/release.md)) |

Tests run offline with LuaJIT (no game needed; a few checks compare against
the installed game's `street.zip` and `base.mo` and are skipped without it):

```sh
luajit tests/run.lua
TMPDIR=<scratch dir> python3 -m unittest discover -s tests
```

Set `TMPDIR` to a scratch directory for the Python tests and the tools
below (they create temporary folders), not `/tmp` or `local/mods`.

`python3 tools/package.py` runs both test suites and builds
`dist/road_tunnel_ramp_1.zip` with only `mod.json`, `strings.json`,
`content/` and `_metadata/`. LICENSE stays out: the game's mod validation
rejects files without an allowed extension (README, CHANGELOG, docs, tests
and tools stay out too). It refuses to build without `_metadata/0.png`, with
a name over 50 characters or with a summary over 250 bytes (UTF-8; Japanese
is 3 bytes a character) in `_metadata/modinfo.json` (mod.io's limits).

`python3 tools/stage.py` copies the mod into the game's staging area
(`local/staging_area/road_tunnel_ramp_1`) for the in-game upload. Run it from
the copy in `local/mods/` (it finds the staging area next to that folder),
while the game is stopped. It refuses uncommitted changes, a missing cover
and, after the first upload, an unraised `revision`, and keeps the
`_metadata/mod.io_fileid.txt` the game writes at the first upload, which is
what makes later uploads update the same mod.io page. Use `--first-upload`
for the first one.

`python3 tools/release.py patch|minor|major|X.Y.Z` (`--dry-run` first). It
writes `VERSION`, the revision and the changelog section, runs the tests,
commits `Release vX.Y.Z`, tags `vX.Y.Z`, builds
`dist/road_tunnel_ramp-vX.Y.Z.zip` and, with the `github` remote, pushes
the branch and that tag and creates the GitHub release with the section as
its notes. Then, with the game stopped, pull into the copy in
`local/mods/`, run `tools/stage.py` there and upload in game; the raised
revision is what lets `stage.py` accept the update. The tests fail when
`VERSION`, the revision and the changelog disagree.

## Credits

- The ramp's shape (eased vertical profile, portal position, walls, coping,
  portal cover and terrain cut) follows **Railway Tunnel Approach by Enivia**
  (mod.io 6497196), rescaled for roads. The code of this mod is written
  anew.
- The retaining-wall meshes (`content/road_tunnel_ramp/walls/aom_wall_box.msh`,
  `aom_slab_box.msh`, `aom_strip_box.msh`)
  are this mod's own, made for it; the walls use the base game's light
  concrete material. (Earlier development versions used the wall mesh and
  concrete material of Enivia's mod; they are no longer included.)

## License

[MIT](LICENSE) © 2026 hummer. The whole mod, the wall mesh included.

---

## 日本語

**道路地下進入路（Transport Fever 3）**

地上から地下の道路トンネルへ降りる道路のランプを、コンクリートの擁壁とポータル天蓋付きで建設します。平らな地面から道路を地下へ下ろす進入路が、1回の配置でできます。

2つ目の建設物 **道路中央の地下進入路** は、2車線の中央の道だけを地下へ下ろし、両側の一方通行の側道を地上に残します。道路の脇に町の建物が建つままです（[道路中央の地下進入路](#道路中央の地下進入路) を見てください）。

新しいゲームで始めてください。

### 機能

- 1つの建設物で、進入路をまとめて敷きます。平らな手前の道路、笠石付きの擁壁にはさまれた切り通しの下り坂、天蓋の付いたポータル、底の長さ 30 m のトンネルです。まわりの地形も掘り下げてならします。
- 道路とトンネルはバニラのもの（トンネルはバニラの自動車用トンネル）なので、車両はふつうの道路と同じように通ります。下り坂の道路（次の項）、トラムの線路付きの道路（ほかの道路の写し）、下の車専用の道路だけは、この MOD のものです。
- 選んだ道路の歩道が残るのは、手前の平らな道路だけです。下り坂の始まりからトンネルまでは、同じ車線に両側 0.5 m の路肩が付いた、歩道のない道路になります（高速道路の広い路肩も 0.5 m になります）。道路トンネルに歩いて入る人はいないためです。線は手前の道路と同じです（街道は、縁石と歩道の舗装を描かない街道の線）。外した幅は擁壁にあてて、擁壁がその分だけ内側まで来るので、ランプの幅は広がりません。掘割の底から地面までの地形の段差は、擁壁とその上の帯の下に隠れます（擁壁 1.5 m では、上の帯に沿って細い溝が見えていました）。底のトンネル（30 m）は選んだ道路に戻るので、そこから延ばすトンネルを同じ種類にできます（トラムの線路を付けたときは、底のトンネルは下り坂の道路のトラムの写しになるので、延ばすトンネルは別の種類になります。そこを車やトラムが通るかは、ゲームでまだ確認していません）。2車線の車専用の道路には外す歩道がないので、擁壁 1.5 m では、上の帯に沿う細い溝が残ることがあります。
- 道路の種類は7つ。1車線高速道路（9 m）から街道（大）（32 m）まで。幅の広い道路を選ぶと、溝・擁壁・ポータル天蓋も広がります。
- 一覧の最後に8つ目として、2車線の車専用の道路（各方向 3.5 m の1車線、8 m）があります。両側に 0.5 m の路肩があり、歩道はなく、歩行者は通れません。つないだ道路から車が入れるかは、ゲームでまだ確認していません。
- 3本まで並べて敷けます。一方通行の高速道路では、上下線のそろった道路（2本）や 2+1（3本）になり、選んだ通行区分に合わせて各方向を正しい側に置きます。
- いまの設定での最大勾配を、配置カーソルの下に出します（「最大勾配: 24.0%」）。短く深いランプの急さが、建てる前にわかります。
- 傾斜地にも置けます。ランプ方向と横方向の地面の勾配を設定すると、擁壁・笠石・ポータル天蓋と脇の土手がその勾配に沿い、下り側で浮き上がりません。カーソルの下の地面の勾配を測って、同じ単位で配置カーソルの下に出します（「地面の勾配: 縦断 +6.0%、横断 -4.0%」）。

### 置き方

- 建設メニュー：**道路 > 道路建設 > 道路地下進入路**。
- **既存の道路の端に接続（スナップ）** して置きます。接続点は手前の平らな道路の始まりで、ランプはその道路の端から先へ延びます。
- 底のトンネル（30 m）の先は接続点になっていて、自分で敷いたトンネルをつなげられます。
- 並べて敷いたときに既存の道路へ接続するのは1本だけです（一方通行の高速道路では「進行方向」で選んだ向きの車道）。残りは端が開いたままなので、手で接続します。

### 設定（建設メニュー）

| 設定 | 値 | 初期設定 |
|---|---|---|
| 道路種類 | 1車線高速道路（一方通行・9 m）、田舎道（小）（14 m）、街道（小）（16 m）、2車線高速道路（一方通行・18 m）、田舎道（中）（22 m）、街道（中）（24 m）、街道（大）（32 m）、2車線 車専用（歩道なし・8 m） | 街道（小） |
| ランプの長さ | 40〜100 m、2 m 刻み。下り坂の長さで、選んだ長さがそのまま使われます | 100 m |
| 手前の道路の長さ | 2〜50 m、2 m 刻み。下り始めるまでの平らな道路（接続点から） | 20 m |
| 地下深度 | 13〜25 m、0.5 m 刻み（13 m あればトンネルの天井の上に土が残ります） | 16 m |
| 並列車道数 | 1本・2本・3本（車道の間は 2 m） | 1本 |
| 擁壁の幅 | 1.5m／3.4m。片側の、道路の縁から擁壁の上の外の縁まで。1.5m：道路の縁にじかに接して厚さ 1.0 m の壁と幅 0.5 m の上の帯、壁の上に地面から 1.1 m の壁高欄（車線の脇の余白は、道路の型の歩道か路肩）。3.4m：幅の広い擁壁で、0.4 m あけて厚さ 1.2 m の壁と、その外へ 1.8 m 張り出す笠石。下り坂の区間では、外した歩道の分だけ壁が厚くなり（たとえば「街道（小）」の脇では 1.0 m でなく 3.5 m）、外の縁は変わりません。ポータル天蓋の幅も擁壁に合わせます | 1.5m |
| ポータル天蓋の長さ | 12〜24 m、1 m 刻み。ポータル天蓋の全体の長さで、天蓋はいつも坑口の 6 m 手前から始まります。18 m で坑口から 12 m 先まで。いちばん短くしても、ゲームのトンネルの坑口の上の面は天蓋で隠れます | 18 m（下の MOD の設定で変えられます） |
| 進行方向 | トンネルへ下る／トンネルから上る。一方通行の高速道路だけ。接続する車道の交通の向きを選びます | トンネルへ下る |
| 通行区分 | 右側通行／左側通行。ゲームの通行区分に合わせます。一方通行の高速道路を並べたときだけ効きます | 右側通行 |
| トラム線路 | なし／両方／右／左。手前の平らな道路・下り坂・底のトンネルに、同じ車線でトラムの線路を通します。両方：各方向の外側の車線（バニラのトラム線路付きの道路と同じ。一方通行の高速道路では外側の車線）。右・左：トンネルを向いて、その側の車線だけ（一方通行の高速道路では、車の進む向きに見て）。どの車線になるかは「通行区分」で決まります。歩道のある道路では、ゲームが手前の平らな道路の両方向の外側の車線に線路を付けるので、建設の直後に MOD が手前の道路を敷き直し、選んだ側の車線だけに線路を残します（手前の道路は建設後ふつうの道路です）。ゲームが敷き直しを断ったときは両方向に付いたままになり、要らない側の線路は道路のツールで外せます | なし |
| 架線 | あり／なし。トラムの線路の上の架線。なしでは、架線の要らないトラムだけが走れます。線路がないときは効きません | あり |
| 勾配カーブ | ゆるい・なだらか・標準・急・非常に急。下り坂の形 | 標準 |
| 地面の縦断勾配 | −20〜+20%、1% 刻み。トンネルへ向かって上る地面が＋（下る地面は−） | 0% |
| 地面の横断勾配 | −20〜+20%、1% 刻み。トンネルを向いて右側が高いと＋（左側が高いと−） | 0% |

標準での最大勾配は、およそ 1.5 × 深さ ÷ 長さ です（深さ 16 m・長さ 100 m で 24%）。ゆるい・なだらかは直線に近く、両端にわずかな勾配の段差があります。急・非常に急は両端を長く平らに保ち、中央を急にします。

傾斜地では、配置カーソルの下の「地面の勾配」の2つの値を、2つの地面の勾配の設定にそのまま入れます。擁壁・笠石・ポータル天蓋がその勾配に沿い、天蓋の脇と先の地面もその勾配に合わせて土手を作ります。ポータルの位置は、その勾配から（ポータル天蓋の低い側の端で）測ったトンネルの上の土の厚さで決まります。道路そのものは接続先の道路と同じ高さで水平のままなので、勾配を入れたときは手前の道路にも接続点から擁壁と笠石が付き、その間の地面を道路の高さまで削るか盛ります。ランプの深さで潜りきれないほど急な下り坂では、下り坂全体が切り通しのままになり、ポータル天蓋と、坑口から 30 m 先までのトンネルの上の地面は、底のトンネルより上に保たれます（天蓋が短いときは、その先を板のない盛土にします）。擁壁・笠石・土手は掘割の始まりから天蓋まで盛土として上がっていきます（急な坂ほど大きな盛土になるので、そういう地面には長いか深いランプが向いています）。

ポータル天蓋は坑口の 6 m 手前から始まり、「ポータル天蓋の長さ」だけ延びて、トンネルの天井の上の土がいちばん薄い入口近くを覆います。天蓋の脇の土手と、天蓋の下に保つ地面も、天蓋の端で終わります。底のトンネル（30 m）の長さは、天蓋の長さによらず変わりません（1.0.0 の天蓋は、いつも全体 36 m、坑口から 30 m 先まででした）。

MOD の設定（新しいゲームを始めるときの MOD の設定）：**ポータル天蓋の長さの初期値**。12〜24 m、初期設定は 18 m。2つの建設物の「ポータル天蓋の長さ」のスライダーが、新しく置くときにこの値から始まります。置いたものの長さは変わりません。

### 道路中央の地下進入路

建設メニュー：**道路 > 道路建設 > 道路中央の地下進入路**（道路地下進入路のすぐ後）。全幅のランプと同じく道路の端に接続して置くか、空き地に置きます。どちらでも、側道は自分でつなぎます。

町の道路の幅いっぱいに地下進入路を作ると、その脇は道路にならず、建物が建ちません。この建設物は、道路の中央だけを地下へ下ろします。2車線の中央の道が、全幅のランプと同じ下り坂・擁壁・笠石・ポータル天蓋・土手・底の 30 m のトンネルで地下の道路トンネルへ下り、両側には一方通行の側道が地上に残ります。

初期設定（入口 4、車専用の中央、擁壁 1.5 m、手前 30 m、長さ 100 m）の平面図は、英語の節の図を見てください（全体の幅はつなぐ「街道（中）」と同じ 24 m。側道の中心は中心線から ±8.75 m、外の縁は ±12 m、笠石と天蓋の外の縁と側道の内の縁は ±5.5 m、側道は下り坂の始まり（x = 0）から天蓋の終わり（x = 77）まで）。側道は道路につながっていません。手前の分かれ目と、遠い端の先の合流は、ふつうの道路で自分で引きます（下を見てください）。

- 中央の道：全幅のランプの2車線の道から選びます。「街道（小）」、「田舎道（小）」、1車線高速道路（一方通行。「進行方向」を見てください）、「2車線 車専用 歩道なし」（初期設定、8 m）。手前の平らな道路は、全幅のランプと同じく、ふつうの道路として手放します（両端とも、つなげる端です）。下り坂・トンネル・底のトンネルは建設物に残り、擁壁の脇には何も建ちません。全幅のランプと同じく、「街道（小）」「田舎道（小）」と高速道路の中央の下り坂は歩道のない道路になり、その幅は擁壁にあてます。側道の位置は変わりません（4車線の道に置いたときの全体の幅は 24 m のままです）。
- 擁壁：1.5 m（初期設定）か 3.4 m。全幅のランプと同じです。側道は擁壁の上の外の縁に合わせて外へずれます。
- 側道：両側に1本ずつ。一方通行で、歩道は外側だけです。笠石とポータル天蓋にぴったり付けて（その下の地面は側道と同じ高さに保ちます）、擁壁とポータル天蓋の脇を、その長さだけまっすぐに延びます。下り坂の始まり（x = 0）から天蓋の終わり（坑口の 6 m 手前 ＋ ポータル天蓋の長さ。初期設定で 77 m、長さ 40 m で 38 m）までで、ランプの長さ・深さ・勾配カーブ・地面の勾配・天蓋の長さに合わせて長さが変わります。建設が終わると、ふつうの道路として手放され（両端とも、つなげる端です）、町は側道の外側に建物を建てます。擁壁の側には、区画ができないようにする見えない飾りが付いています。街灯（柱の上に灯りの付いた型。縁石の近く）・消火栓・ごみ箱は歩道の側だけに立ちます。各側道の向きは「通行区分」で決まります。
- 入口の道：進入路が受け持つ町の道を、車線の数で選びます。**2**（「街道（小）」16 m）と **4**（「街道（中）」24 m、初期設定）は、側道が各1車線（6.5 m：車線 3.5 m、歩道 3 m。入口 4 では全体が「街道（中）」と同じ 24 m）。**6**（「街道（大）」32 m）は、側道が各2車線（11.5 m：4 m × 2、歩道 3.5 m）。中央はどれも各方向1車線です（高速道路では一方通行）。
- 分かれ目と合流：自分で引きます。本当は、4車線の道の前後にそのままきれいにつながる、ひとまとまりの形にしたかったのですが、どうやってもできませんでした。すみませんが、ここは自分で引いてください。道路の端に接続して置いたときは、手前の道路がそこから始まり、側道の手前の端はその 30〜50 m 先（「手前の道路の長さ」）なので、その端から各側道へ S 字の道路を引く余地があります。空き地に置いたときは、手前の道路の始まりと側道の両端が、どれもつなげる端です。手前の道路はふつうの道路なので、撤去して別の形の分かれ目を引くこともできます。
  - 1車線の側道は、道路のメニューにも **側道（片側歩道の一方通行）** としてあります（「街道（小）」の並び、バニラの一方通行の後）。交通の向きに引くと歩道は右になり、右側通行では掘割のどちら側でも外側になります。側道と同じく、左側（歩道の無い側）には建物が建ちません。
  - 傾斜地（地面の勾配のどちらかが 0% でない）では、手前の道路の両脇にも接続点から擁壁と笠石が立ち、接続点からの S 字の通り道をふさぎます。分かれ目は接続点より手前で引くか、手前の道路を撤去してから引いてください（ゲームでは未確認）。
  - 入口 6 の側道は 2 車線です。メニューの側道は 1 車線なので、ふつうの道路でつないでください。
- 傾斜地：全幅のランプと同じ2つの地面の勾配の設定を使います。擁壁・笠石・ポータル天蓋・土手が全幅のランプと同じく沿い、側道も沿います。下り坂の地面では、擁壁の脇の土手が勾配の面より高くなるので、側道はそこでは土手の高さに合わせて 5 m ごとに折れます。中央の道は接続先の道路と同じ高さのままです。
- 配置カーソルの下に、全幅のランプと同じく最大勾配と測った地面の勾配を出します。

側道の中心線の、中心線からの距離（笠石の外の縁＋側道の幅の半分）：

| 中央の道 | 入口 2・4、擁壁 1.5 m | 3.4 m | 入口 6、擁壁 1.5 m | 3.4 m |
|---|---|---|---|---|
| 車専用（8 m） | 8.75 m | 10.65 m | 11.25 m | 13.15 m |
| 高速道路（一方通行、9 m） | 9.25 m | 11.15 m | 11.75 m | 13.65 m |
| 田舎道（小）（14 m） | 11.75 m | 13.65 m | 14.25 m | 16.15 m |
| 街道（小）（16 m） | 12.75 m | 14.65 m | 15.25 m | 17.15 m |

| 設定 | 値 | 初期設定 |
|---|---|---|
| 入口の道 | 2（「街道（小）」16 m）／4（「街道（中）」24 m）／6（「街道（大）」32 m） | 4 |
| 中央の道 | 1車線高速道路（一方通行・9 m）、田舎道（小）（14 m）、街道（小）（16 m）、2車線 車専用（歩道なし・8 m） | 車専用 |
| 擁壁の幅 | 1.5m／3.4m（全幅のランプと同じ） | 1.5m |
| ポータル天蓋の長さ | 12〜24 m、1 m 刻み（全幅のランプと同じ。坑口の 6 m 手前から）。側道も天蓋の端で終わります | 18 m |
| ランプの長さ | 40〜100 m、2 m 刻み | 100 m |
| 手前の道路の長さ | 30〜50 m、2 m 刻み。接続点から側道の手前の端まで | 30 m |
| 地下深度 | 13〜25 m、0.5 m 刻み | 16 m |
| 進行方向 | トンネルへ下る／トンネルから上る。中央が高速道路のときだけ | トンネルへ下る |
| 通行区分 | 右側通行／左側通行。ゲームの通行区分に合わせます。各側道の向きが決まり、歩道が外側になります | 右側通行 |
| トラム線路 | なし／両方／右／左。中央の道の手前の平らな道路・下り坂・底のトンネルに、全幅のランプと同じく通します。側道には付きません | なし |
| 架線 | あり／なし（全幅のランプと同じ） | あり |
| 勾配カーブ | ゆるい・なだらか・標準・急・非常に急 | 標準 |
| 地面の縦断勾配 | −20〜+20%、1% 刻み | 0% |
| 地面の横断勾配 | −20〜+20%、1% 刻み | 0% |

ゲームで（試験用のツールで）確認したもの：進入路を置けること（入口・中央の道・擁壁の全部の組み合わせ）、中央と側道を車が通ること、道路の端から S 字の側道を 15〜40 m で 12〜16 m まで開けること、1車線の側道 2 本を「街道（中）」に合流できること、擁壁と天蓋を合わせた長さで側道が建つこと、メニューの側道の型で分かれ目と合流を引けること。まだ確認していないもの：ゲームの建設メニューと道路のツールを手で使って置き、分かれ目と合流を引くこと、左側通行、傾斜地。

### 互換性

- 新しいゲームで始めてください。
- 外すときは警告が出ます（`severityRemove: Warning`）。置いたランプはこの MOD の建設物（`ramp.con` と `median.con`、その擁壁・笠石・天蓋のモデル）なので、それがあるセーブはこの MOD に依存します。道路中央の地下進入路の側道と、下り坂の道路と、トラムの線路付きの道路（ほかの道路の写し）と、全幅のランプの車専用の道路は、この MOD の道路です。ほかの道路とトンネルはバニラのものです。
- `cosmetic` ではありません。建設物を加えるので、ゲームはゲームプレイに関わる MOD として扱います。
- 配置カーソルの最大勾配と地面の勾配の行は、バニラの建設アクションを包んで足しています。他の MOD（Construction Altitude Tooltip など）が同じ場所に足す行はそのまま残ります。
- 依存する MOD はありません。

### 導入

- mod.io：https://mod.io/g/transportfever3/m/road-tunnel-approach-full-width-median（ゲーム内の MODハブからも購読できます）。
- 手動：ゲームは `<Steam>/userdata/<ID>/3493540/local/mods/` の中の、名前がちょうど `road_tunnel_ramp_1` のフォルダからだけ読み込みます。
  - リリースの zip から：そのフォルダを作り、その**中に** zip を展開します（zip には外側のフォルダがありません）。
  - GitHub から：`local/mods/` の中で `git clone https://github.com/hummer98/tpf3-road-tunnel-approach road_tunnel_ramp_1` とします（別のフォルダ名では読み込まれません）。
  - そのあとゲーム内で有効にします。

### 開発

ファイルの役割とテスト・パッケージの手順は、英語の「Development」の節を見てください。テストは `luajit tests/run.lua` と `TMPDIR=<スクラッチ> python3 -m unittest discover -s tests`、zip は `python3 tools/package.py`、ステージングは `local/mods/` のコピーで、ゲームを止めて `python3 tools/stage.py`（最初は `--first-upload`）です。天蓋の長さの下限を変えるときは、`content/road_tunnel_ramp/ramp_geometry.lua` の `LID_MIN` を直して `python3 tools/cover_range.py` を走らせます（`mod.json` の MOD の設定と、文の中の範囲を書き直します）。版は `VERSION`、変更は `CHANGELOG.md` の `## [Unreleased]` に書き、release は開発用の clone で `python3 tools/release.py patch|minor|major|X.Y.Z` です（手順は [docs/release.md](docs/release.md)）。

### クレジット

- ランプの形（なめらかな縦断の形、ポータルの位置、擁壁、笠石、ポータル天蓋、地形の掘り下げ）は、**Enivia さんの Railway Tunnel Approach**（mod.io 6497196）にならい、道路向けに作り直しました。コードはこの MOD のために書いたものです。
- 擁壁のメッシュ（`content/road_tunnel_ramp/walls/aom_wall_box.msh`、`aom_slab_box.msh`、`aom_strip_box.msh`）は、この MOD のために作ったものです。素材はバニラのコンクリートを使います。（開発中の版では Enivia さんの MOD の擁壁のメッシュとコンクリートの素材を使っていましたが、今は入っていません。）

### ライセンス

[MIT](LICENSE) © 2026 hummer。擁壁のメッシュを含め、MOD の全体が対象です。
