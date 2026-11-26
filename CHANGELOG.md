# Changelog

All notable changes to Road Tunnel Approach are recorded here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
mod uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html). The
mod's `revision` in `mod.json` is MAJOR * 10000 + MINOR * 100 + PATCH.

The first public release is 1.0.0 (`revision` 10000).

## [Unreleased]

## [1.2.0] - 2026-11-26

### Added
- **Tram track** and **Catenary** (both constructions): a tram track on
  the flat approach, the descent and the tunnel stub, on the same lane all
  the way: None (initial setting), Both (the outer lane of each direction,
  as the base game's tram streets), or only the Right or Left lane, facing
  the tunnel (on a one-way highway, facing the way its traffic runs; which
  lane follows Traffic side). Catenary Yes (initial setting) or No, for
  trams that need no wire. On a one-way highway Both is its outer lane. On
  the Median Tunnel Approach the centre gets the track, the side streets
  none. With a track the tunnel stub is a tram copy of the descent's street, so a
  tunnel laid on from it is another type.
- **Right / Left on the flat approach of a street with sidewalks**: the
  game lays the approach's track in both directions' outer lanes (it needs
  the edges' tram track type there), so a game script lays the handed-over
  approach again right after the build, with the track taken off the lanes
  of the other direction. If the game refuses it, or the approach is not
  found, the approach keeps both tracks (logged). The descent, the tunnel
  and the Median Tunnel Approach's side streets are as before. Not yet
  checked in a game.

### Changed
- **Underground depth** (both constructions) is set in 0.5 m steps: 13,
  13.5, ... 25 m, 16 m initially as before.
- **The descent has no sidewalks** (both constructions). Only the flat
  approach keeps the chosen street's sidewalks; from the start of the
  descent into the tunnel the street has the same lanes with a 0.5 m
  shoulder each side (a highway's wide shoulders become 0.5 m too), drawn
  with the same lines as the street in front (a town street's lines without
  its curbs and sidewalk paving).
  Pedestrians cannot walk down the ramp. The width taken off goes to the
  retaining walls, which stand that much further in: the ramp, the portal
  cover and the Median Tunnel Approach's side streets are as wide as before.
  The 30 m tunnel stub is the chosen street, as before. The two lanes for
  motor vehicles only and the cars-only centre are unchanged (they have no
  sidewalk to take off).

### Fixed
- **Portal cover length** is now 12–24 m in 1 m steps (1.1.0 went down to
  6 m). With the shorter covers, the top of the game's tunnel portal
  piece showed beyond the cover's end (at 6 m the cover ended on the
  portal). The mod setting **Initial portal cover length** has the same
  range. 18 m initially and 24 m at most, as before.
- **No groove along the retaining wall.** With the 1.5 m wall a narrow
  groove showed in the ground just outside the wall top, deeper toward the
  portal: the terrain's slope from the trench floor up to the ground
  reached past the top. It now lies under the wall and its top (see
  Changed).
  Not on the two lanes for motor vehicles only (the Median Tunnel
  Approach's initial centre too): they have no sidewalk to give the wall.

## [1.1.0] - 2026-11-26

### Added
- **Portal cover length** (both constructions): the whole length of the
  portal cover, 6–24 m in 1 m steps, 18 m initially. The cover starts 6 m
  in front of the portal as before; 18 m reaches 12 m past the portal, 6 m
  ends at the portal. The banks beside the cover, the ground held under it
  and the Median Tunnel Approach's side streets end with it. The 30 m
  tunnel stub is unchanged. On downhill ground too steep for the ramp, the
  ground over the tunnel's first 30 m past the portal is still held above
  it, past a shorter cover as an embankment without a slab.
- Mod setting **Initial portal cover length** (6–24 m, 18 m initially): the
  value the Portal cover length slider starts on when you place a new ramp.
  Ramps already placed keep their own length.

### Changed
- The portal cover is shorter by default: 18 m (12 m past the portal)
  instead of 1.0.0's fixed 36 m (30 m past the portal), which looked like a
  huge concrete slab for a road. New ramps look different from 1.0.0's; the
  1.0.0 length is no longer offered. The Median Tunnel Approach's side
  streets are shorter with it (77 m instead of 95 m with the initial
  settings).

## [1.0.0] - 2026-11-25

First public release.

### Added
- **Road Tunnel Approach** (Roads > Road Constructions): one construction
  lays a street ramp from the surface into an underground road tunnel: a
  flat approach street, the descent in an open trench between concrete
  retaining walls with coping, the portal with a cover slab, and a 30 m
  vanilla car tunnel stub that your own tunnel can snap to. The terrain is
  cut and levelled around it. Snap it to the end of a street.
- Eight street types: seven of the base game's, from the One-Lane Highway
  (9 m) to the Large Street (32 m), and this mod's two lanes for motor
  vehicles only (8 m, a 0.5 m shoulder each side, no sidewalks). Wider
  streets widen the trench, walls and portal cover.
- Up to three streets side by side; with the one-way highways this builds a
  divided road or a 2+1 layout, each direction on the side chosen by
  Traffic side.
- Settings for ramp length (40–100 m), approach length (2–50 m),
  underground depth (13–25 m), slope curvature (five shapes), retaining
  wall (1.5 m with a parapet, or 3.4 m with a wide coping), traffic side
  and traffic direction (one-way highways).
- Ground slope along and across (−20 to +20%): the walls, coping, portal
  cover and the banks beside them follow sloped ground; the street stays
  level with the road it snaps to.
- The flat approach street becomes an ordinary street once the ramp is
  built, so other streets join it like any street and it stays when the
  ramp is bulldozed; the descent, tunnel and stub stay in the construction.
- The build cursor shows the steepest grade of the current settings and the
  measured slope of the ground, next to the lines other mods add there.
- **Median Tunnel Approach** (same menu): the two-lane centre of a town
  street goes down into a road tunnel with the full-width ramp's descent,
  walls, coping, portal cover and tunnel stub, while a one-way side street
  each side, sidewalk outside, stays on the surface against the coping.
  Entry street 2, 4 or 6 lanes (one lane in each side street with 2 and 4,
  two with 6); placed on a four-lane street it is that street's 24 m
  across. Centre street: two lanes for motor vehicles only (initial
  setting), Small Street, Country Road (small) or One-Lane Highway. The
  retaining wall, ramp length, approach length (30–50 m), depth, slope
  curvature, traffic side, traffic direction (highway centre) and ground
  slope settings work as on the full-width ramp.
- The median's side streets run straight beside the walls and the portal
  cover, as long as both together, so their length follows the ramp length,
  depth, curvature and slopes. Once built they are ordinary streets: the
  town builds houses on their outer side and none on the wall side. Nothing
  joins them to the road: draw the fork in front of them and the merge
  past them yourself.
- **Side street (one-way, one sidewalk)** in the street menu, with the
  small streets: the median's one-lane side street, to draw the fork and
  the merge with. Laid the way its traffic runs, its sidewalk is on the
  right.
- The walls, coping and portal cover are on this mod's own box meshes, in
  the base game's light concrete.
- Strings in the game's 13 languages.
- Credits: the ramp's shape follows Railway Tunnel Approach by Enivia
  (mod.io 6497196), rescaled for roads.
