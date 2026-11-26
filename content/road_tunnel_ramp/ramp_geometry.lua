-- The full-width tunnel ramp's shape (moved out of ramp.script.lua), so the
-- median approach can build the same descent, walls, coping, lid, terrain,
-- tunnel and underground runout as its centre and lay its own side streets
-- beside it. The user built that form by hand from the full-width ramp
-- and two side streets (one place at each end, 4 <-> (1)+2+(1)), and asked
-- for the median to be rebuilt that way: 「1. 作り直してください」.
--
-- No engine access here (the caller resolves the tunnel resource), so the
-- module holds no state and the tests can run it offline. Loaded with
-- require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua" [source:
-- the construction script tunnel_junction_template's tjt.script.lua requires
-- "tunnel_junction_template::/..." this way, and it was placed in game
-- without errors, 2026-11-23 e2e; vanilla's depot scripts require
-- "::/scripts/construction/constructionutil.lua"]. require keeps the module
-- loaded, so a changed copy may need a game restart to be picked up [guess].
--
-- M.spec(cap, p)  reads the full-width ramp's menu into a spec
-- M.layout(spec)  the dimensions (and the height functions) of the body
-- M.build(spec)   the construction result, and the layout it used
-- A spec: street = { ref, width, oneWay, descent }, count, L, D, curvature,
-- direction, side, approach, gx, gy, wall (one of M.WALLS), lidLength (the
-- portal cover's whole length; nil counts as M.LID_DEFAULT), tunnelRef,
-- tunnelHeight, tramLanes / tramPower (M.tramRef; nil lanes: no track),
-- handOver (nil counts as true), approachDepotStyle (read
-- only when handOver is false; nil counts as false). A construction building on
-- this module starts from M.spec(cap, p) and replaces street and count,
-- so the other fields keep the menu's defaults and clamps (the median
-- approach does so: median_geometry.lua);
-- M.layout refuses a spec with a number missing rather than lay the body
-- out from nil.

local M = {}

-- The retaining wall's cross-section, per side, measured from the street
-- template's outer edge (rtr_wall). Every number is the distance out from
-- the wall centreline (outer = street edge + centre), written out so the
-- thick one gives bit-for-bit the body built before the option.
-- The wall and coping are the mod's part models (M.WALL_MODELS), each a
-- 1 x 0.45 x 1 box (boundingInfo y -0.225..0.225) stretched by each
-- model's transf, so both widths are the same models at another scale
-- [source: walls/*.mdl, tools/wall_models.py].
--   thin  (1.5m): the wall's inner face on the street edge, a 1.0m wall,
--         a 0.5m top band and no coping overhang; a 0.25m wall-type parapet
--         stands on the wall's inner edge, 1.1m over the ground (the Ken-O
--         Expressway's U-wall cut, Nishimatsu technical report vol. 37;
--         research notes: median_ramp_widths/retaining_wall_research.md).
--         It was 2.0m with 0.5m clear (the shoulder of a type-4 road, Road
--         Structure Ordinance art. 8); the street template's own margin
--         outside its lanes (the cars-only street's 0.5m shoulder, the
--         others' sidewalks or shoulders) now takes that place (the user,
--         2026-11-24: 「擁壁側の路肩はなくして」).
--   thick (3.4m): the earlier body, 0.4m clear, a 1.2m wall, the coping
--         1.8m past it.
-- half: half the wall's thickness, scale its model's y scale (2.667 for
-- the thick wall as before, not 1.2 / 0.45), copingIn / copingOut the
-- coping's edges, shoulderIn / shoulderOut the banks' terrain faces,
-- floor the trench floor faces' edge (under the wall).
M.WALLS = {
	{ key = "thin", centre = 0.5, half = 0.5, scale = 1.0 / 0.45,
	  copingIn = 0.55, copingOut = 1.0, shoulderIn = 0.55, shoulderOut = 5.6, floor = 0.4,
	  parapet = { thickness = 0.25, top = 1.1 } },
	{ key = "thick", centre = 1.0, half = 0.6, scale = 2.667,
	  copingIn = 0.65, copingOut = 2.4, shoulderIn = 0.65, shoulderOut = 7, floor = 0.4 },
}
M.WALL_THICK = 2

-- The game keeps the terrain's height on a grid of points 1m apart and
-- draws it as triangles between them; seen across a wall that runs at an
-- angle to the grid, one triangle spans up to sqrt(2) = 1.41m [measured
-- 2026-11-26 TC4: the 1m points; guess: the triangles' diagonal]. So where
-- the trench floor's faces end (F) and the ground's faces begin, the slope
-- between the two heights can reach up to GRID_REACH either way. With the
-- thin wall the floor ended 0.9m past the wall's inner face (I) and the top
-- 0.6m further out (C), and that slope showed outside the top as a narrow
-- groove, deeper toward the portal (TC4: 0.85m against the ground's 5.0m,
-- 9.5-10m from the centre line; the user: 「擁壁に沿って、だんだん深くなる
-- ような細い溝がみえます。」). Hidden, it needs I + GRID_REACH <= F and
-- F + GRID_REACH <= C: the slope then lies under the wall and its top.
M.GRID_REACH = 1.42

-- The wall beside the descent, where the street is laid without its
-- sidewalks (or the highways' wide shoulders): extra is the width taken off
-- each side (street.width - descent.width) / 2, and it goes to the wall
-- (the user: 「要望として全体の幅を増やすのはしたくない」, so the outer edge
-- of the top, C, stays where it was). The wall is extra thicker inward, its
-- inner face on the descent's edge (plus the thick wall's 0.4m clearance),
-- the top band reaches in over it as before (0.05m past its inner face),
-- and the banks end where they did. The floor and the banks then meet
-- halfway between I and C (floor = shoulderIn), so both slopes of
-- GRID_REACH stay inside the band when it is 2 * GRID_REACH or wider. Every
-- number stays relative to the wall's centreline (outer), as in M.WALLS.
-- extra 0 (the cars-only street, the flat approach) is w itself, so those
-- keep the body as it was to the bit.
function M.descentWall(w, extra)
	if not extra or extra <= 0 then return w end
	local d = {}
	for k, v in pairs(w) do d[k] = v end
	local h = extra * 0.5
	d.extra = extra
	d.centre = w.centre + h
	d.half = w.half + h
	-- the wall model is 0.45 across (M.WALLS scale)
	d.scale = (w.half + h) * 2 / 0.45
	d.copingIn = w.copingIn + h
	d.copingOut = w.copingOut + h
	d.shoulderOut = w.shoulderOut + h
	-- halfway between the inner face (-half) and the top's outer edge
	local mid = (d.copingOut - d.half) * 0.5
	d.floor = mid
	d.shoulderIn = mid
	return d
end

-- The part models: wall the retaining wall, slab the portal cover, strip
-- the coping and parapet. Each part has its own mesh with texture
-- coordinates baked for its own base size (one box mesh for all three
-- stretched the cover's top about 18 times across, 2026-11-24), and all
-- have the base game's light concrete. The .mdl files are written by
-- tools/wall_models.py (the mesh paths are set there once); the names
-- match its list. Dark concrete, brick and stone were tried as a colour
-- setting and dropped before release (the user, 2026-11-24: 「白以外は
-- 微妙ですね」「白だけ採用」).
local WALL_DIR = "road_tunnel_ramp::/road_tunnel_ramp/walls/"
M.WALL_MODELS = {
	wall = WALL_DIR .. "wall.mdl",
	slab = WALL_DIR .. "slab.mdl",
	strip = WALL_DIR .. "strip.mdl",
}

-- The wall box (walls/aom_wall_box.msh, the mod's own) has its texture
-- coordinates baked for a 4m piece of a 6m high wall: one repeat per 2m
-- along and up. A wall stretched to its full height stretched its texture
-- with it (5.3 times from a 3m to a 16m wall), so a wall piece of height H is a stack of stackCount(H) boxes of
-- H / n each, n = max(1, round(H / WALL_STACK)): a box of a wall 4.5m or
-- higher is 4.5..9m high, 0.75..1.5 times the 6m it was baked for (the
-- mesh's maker, 2026-11-24). The portal cover, LID_MIN-24m long (lidLength), is
-- laid in pieces of at most COVER_PIECE for the same reason (as one piece
-- its top was stretched about 9 times along x), and across its width
-- (19-59m, up to about 107m for three Large Streets) in coverAcross(W)
-- pieces of W / n, n = max(1, round(W / COVER_PIECE)), the way the wall
-- is stacked: as one piece its top was
-- stretched about 18 times across (in game, 2026-11-24). The coping and
-- parapet are drawn with the strip model and the cover with the slab
-- model (M.WALL_MODELS), each baked for its own base size.
M.WALL_STACK = 6
M.COVER_PIECE = 4

function M.stackCount(height)
	return math.max(1, math.floor(height / M.WALL_STACK + 0.5))
end

function M.coverAcross(width)
	return math.max(1, math.floor(width / M.COVER_PIECE + 0.5))
end

-- The ends of n equal pieces from x0 to x1, n = ceil((x1 - x0) / len) (at
-- least 1); the last end is x1 itself, so the pieces end where the whole did.
function M.pieces(x0, x1, len)
	local n = math.max(1, math.ceil((x1 - x0) / len - 1e-9))
	local xs = {}
	for i = 0, n - 1 do xs[i] = x0 + (x1 - x0) * i / n end
	xs[n] = x1
	return xs, n
end

-- The portal cover's whole length (rtr_cover_length). It starts
-- LID_BEHIND (6m) in front of the portal as before (lidA) and ends
-- lidLength after that (lidB), so a 6m lid would end on the portal. In 1.0.0 it
-- was 36m (30m past the portal), and a player asked on mod.io why a road
-- needs that huge slab. The user kept a lid, since the ground just past
-- the portal may be shallow enough to meet buildings, and found 36m too
-- long: 「地下に入った直後のエリアは道路の傾斜によりますが、地上の建物と干渉
-- する可能性があるので、ある程度の蓋、というかガード部が必要だと思われます。
-- しかし、現在は確かに長過ぎる気がします」, then 「30とかそもそもいらないので、
-- 6-18ぐらいをスライダーにするとかは？」 and 「全体の長さにしてください」.
-- So a 1m slider of the whole length, LID_MIN to 24, 18 initially. M.layout
-- takes any length from LID_BEHIND on (36 gives 1.0.0's body); only the
-- menu is held to the slider's range.
-- LID_MIN was 6 in 1.1.0: a 6m lid covers nothing past the portal, and the
-- top of the game's tunnel portal piece (tunnel_a_car) showed beyond the
-- slab's end [in game, picture, 2026-11-26]. The user: 「6mはなんかおかしい
-- ですよね」「下限を上げて隠す、ということですね」. 12, from e2e
-- [measured 2026-11-26, pictures]: at 6-10m the portal piece's top still
-- showed past the slab, at 11 and 12m it did not; 12 (6m past the portal)
-- leaves a margin over that edge. Everything else follows this one
-- value: both .con sliders (their values, numbers and defaultIndex), the
-- mod setting's positions (mod.script.lua's module), lidLengthOf below,
-- and, through
-- tools/cover_range.py (tests/test_cover_range.py fails until it is run),
-- mod.json's setting and the ranges in README, the mod.io texts and the
-- CHANGELOG's Unreleased section.
M.LID_MIN, M.LID_MAX, M.LID_DEFAULT = 12, 24, 18
M.LID_BEHIND = 6
-- The ground over the tunnel's first HOLD_AHEAD past the portal is held
-- over the tunnel roof whatever the lid's length: 1.0.0's lid reached that
-- far, and on downhill ground too steep for the ramp (the portal at the
-- descent's foot) it was all that kept the stub, from the portal on, under
-- ground. With a shorter lid the lift is found over the same run and the
-- ground past the lid is filled to the lifted plane (holdFace in M.build):
-- without it the stub came out of the ground by 0.55m (16m deep, 4% down)
-- to 24m (20% down) [review 2026-11-26, offline layout].
M.HOLD_AHEAD = 30

-- Tram track (rtr_tram, rtr_tram_wire; both constructions). The user:
-- 「今は設置時にトラム路線を指定できますか？」「高架線 あり・なし／トラム
-- 両方・右・左・なし／みたいな選択ですかね」, and earlier 「トラムの前提が
-- 間違ってます。デフォルトは外側ですが任意の車線につけれます」. The track is
-- laid on the flat approach, the descent and the tunnel stub alike, on one
-- lane: the outer car lane of a direction, as the base game's tram streets
-- have it. It comes with the street: each street is laid as its copy with
-- TRAM (and ELECTRIC_TRAM with the catenary) on those lanes
-- (streets/tram_*, written by tools/make_tram_templates.py), as the base
-- game's tram streets carry it; tramTrackType on the edges put it on both
-- directions' outer lanes and on no tunnel edge [measured 2026-11-23 PT
-- E1] and cannot pick a side [source: the edge's params, NO / YES /
-- ELECTRIC; busAndTramRight is one flag per template].
-- M.TRAM: rtr_tram 1 none, 2 both, 3 right, 4 left. lanes of a copy:
-- b both outer car lanes, f the last car lane, k the first (the copies'
-- lane sets, independent of the traffic side). Right and left are seen
-- facing the way the street's edges run (into the tunnel for a two-way
-- street, the way traffic runs on a one-way one): with right-hand traffic
-- the forward lanes lie on the right, so right is f; with left-hand
-- traffic the game lays them on the left [guess: as the layout of the
-- one-way carriageways below assumes; e2e], so right is k.
local TRAM_DIR = "road_tunnel_ramp::/road_tunnel_ramp/streets/tram_"
M.TRAM_POWER = { "etram", "tram" }  -- rtr_tram_wire 1 with catenary (initial), 2 without

-- The copy of a street resource with the track on lanes (b / f / k) and
-- power (tram / etram): the base streets' and this mod's by their file
-- stem. nil lanes is the street itself.
function M.tramRef(ref, lanes, power)
	if not lanes then return ref end
	local stem = ref:match("([%w_]+)%.street_template$")
	assert(stem, "ramp_geometry: no street template stem in " .. tostring(ref))
	return TRAM_DIR .. stem .. "_" .. lanes .. "_" .. (power or "etram") .. ".street_template"
end

-- The copies' lanes for rtr_tram (1-4) and the traffic side (1 right-hand, 2 left).
function M.tramLanes(tram, side)
	if tram == 2 then return "b" end
	if tram == 3 then return side == 2 and "k" or "f" end
	if tram == 4 then return side == 2 and "f" or "k" end
	return nil
end

function M.value(p, key, default, lo, hi)
	local n = tonumber(p[key])
	if not n or n ~= n then n = default end
	return math.max(lo, math.min(hi, n))
end
local value = M.value

-- rtr_cover_length, read for the spec: a whole metre in the slider's range.
-- Below it, LID_MIN: a ramp placed with 1.1.0's 6-11m keeps that value in
-- its params, and is rebuilt with it when its settings window changes it
-- (or the game rebuilds it); the window's slider shows the nearest of its
-- numbers for a value it lacks [source: gui script_param_util.tl
-- findNumberIndex1; construction.tl clampParamValue keeps a value when the
-- param has numbers], so that rebuild matches what it shows, and the
-- portal piece is hidden there too. Missing, junk or above the range (a
-- value no menu gave) is the initial 18m, not the nearest end, so nothing
-- quietly keeps 1.0.0's 36m.
function M.lidLengthOf(p)
	local n = tonumber(p and p.rtr_cover_length)
	if not n or n ~= n or n > M.LID_MAX then
		return M.LID_DEFAULT
	end
	if n < M.LID_MIN then return M.LID_MIN end
	return math.floor(n + 0.5)
end

function M.spec(cap, p)
	-- rtr_street picks one of the street templates captured by
	-- con.lua; each entry carries both the resource reference and
	-- the measured width so wall / coping / terrain spacing stays
	-- in step with the template without probing the engine.
	local streetIdx = math.floor(value(p, "rtr_street", 3, 1, #cap.streets) + 0.5)
	local street = cap.streets[streetIdx] or cap.streets[3]
	-- An entry with variants (the cars-only one) swaps its template for one
	-- of them under rtr_car_only_variant 2.. (not in the menu: the e2e's
	-- stand-ins). The other fields stay, so only the edges' type changes.
	if street.variants then
		local k = math.floor(value(p, "rtr_car_only_variant", 1, 1, #street.variants + 1) + 0.5)
		if k > 1 then
			street = { ref = street.variants[k - 1], width = street.width, oneWay = street.oneWay, variant = true }
		end
	end
	local side = math.floor(value(p, "rtr_side", 1, 1, 2) + 0.5)
	-- (the e2e's stand-ins have no tram copies: no track on them)
	local tramLanes = not street.variant and M.tramLanes(math.floor(value(p, "rtr_tram", 1, 1, 4) + 0.5), side) or nil
	local tramPower = M.TRAM_POWER[math.floor(value(p, "rtr_tram_wire", 1, 1, 2) + 0.5)]
	-- 0.5 and up rounds to 1, the threshold the 0 / 1 switch had.
	local approachMode = math.floor(value(p, "rtr_approach_hand_over", 1, 0, 2) + 0.5)
	return {
		street = street,
		-- The UI stops at 100m, but ramps placed before that kept up to
		-- 400m; clamping them would shorten them on rebuild.
		L = value(p, "rtr_length", 100, 40, 400),
		D = value(p, "rtr_depth", 16, 10, 25),
		curvature = math.floor(value(p, "rtr_curvature", 3, 1, 5) + 0.5),
		count = math.floor(value(p, "rtr_count", 1, 1, 3) + 0.5),
		-- 1 = traffic descends into the tunnel, 2 = climbs out of it.
		direction = math.floor(value(p, "rtr_direction", 1, 1, 2) + 0.5),
		-- 1 = right-hand traffic (game default), 2 = left-hand.
		side = side,
		-- tram track: the copies' lanes (nil: none) and power (M.tramRef)
		tramLanes = tramLanes,
		tramPower = tramPower,
		approach = value(p, "rtr_approach", 20, 2, 50),
		-- The menu starts on thin (rtr_wall defaultIndex); a spec read
		-- without the key (the tests written before it) keeps the thick
		-- wall the body was built with. A script placing the ramp must
		-- pass rtr_wall = 1 to get the thin one (median_geometry.spec
		-- does, when its own menu's value is missing).
		wall = M.WALLS[math.floor(value(p, "rtr_wall", M.WALL_THICK, 1, #M.WALLS) + 0.5)],
		lidLength = M.lidLengthOf(p),
		-- Ground plane (see ground in M.layout): along = % rise toward
		-- the tunnel, across = % rise to the right when facing it, so
		-- gy (rise toward local +Y, the left) takes the opposite sign.
		gx = value(p, "rtr_ground_along", 0, -20, 20) / 100,
		gy = -value(p, "rtr_ground_across", 0, -20, 20) / 100,
		tunnelRef = cap.tunnelRef,
		tunnelHeight = cap.tunnelHeight or 10.55,
		-- The flat approach handed over as an ordinary street (see the
		-- approach edge in M.build). rtr_approach_hand_over (not in the
		-- menu) picks the others for the e2e to compare at one sitting:
		-- 0 keeps it in the construction as before, 2 keeps it but
		-- frees its outer end, as the base game's depots do.
		handOver = approachMode == 1,
		approachDepotStyle = approachMode == 2,
	}
end

-- Everything the edges, models and terrain are laid out from. Side streets
-- beside the body need: outer (wall centreline), copingOut (outer edge of
-- the coping and of the lid), portalX (the portal), lidA / lidB (the lid's
-- run along x, lidB = lidA + lidLength), coverA / coverB (the lid's
-- terrain faces' run, 0.25m past each end), runoutEnd (x of the
-- underground runout's end, at z = -D),
-- and the height functions (ground, roadZ, lidZ, surface).
function M.layout(s)
	for _, k in ipairs({ "L", "D", "count", "approach", "gx", "gy", "curvature", "direction", "side", "tunnelHeight" }) do
		assert(type(s[k]) == "number", "ramp_geometry: spec." .. k .. " must be a number")
	end
	assert(type(s.street) == "table" and type(s.street.width) == "number", "ramp_geometry: spec.street.width must be a number")
	assert(type(s.wall) == "table", "ramp_geometry: spec.wall must be one of M.WALLS")
	for _, k in ipairs({ "centre", "half", "scale", "copingIn", "copingOut", "shoulderIn", "shoulderOut", "floor" }) do
		assert(type(s.wall[k]) == "number", "ramp_geometry: spec.wall." .. k .. " must be a number")
	end
	local street = s.street
	-- The descent's street and wall (M.descentWall); the flat approach keeps
	-- the chosen street and s.wall (approachWall below).
	local descent = street.descent
	if descent then
		assert(type(descent.width) == "number" and descent.width <= street.width and type(descent.ref) == "string",
			"ramp_geometry: spec.street.descent must be { ref, width } no wider than the street")
	end
	local extra = descent and (street.width - descent.width) * 0.5 or 0
	local w = M.descentWall(s.wall, extra)
	local g = {}
	local L, D, count, approach = s.L, s.D, s.count, s.approach
	local gx, gy = s.gx, s.gy
	local tunnelHeight = s.tunnelHeight
	local lidLength = s.lidLength
	if lidLength == nil then lidLength = M.LID_DEFAULT end
	-- (from LID_BEHIND on: a shorter lid would end before the portal, and
	-- the lid support from the portal on would turn inside out)
	assert(type(lidLength) == "number" and lidLength >= M.LID_BEHIND,
		"ramp_geometry: spec.lidLength must be a number of at least " .. M.LID_BEHIND)
	-- The tunnel stub past the descent's foot (x = L .. L + 30), not the
	-- lid: it stays 30m whatever lidLength is.
	local runout = 30
	local halfWidth = street.width * 0.5
	-- Parallel streets: centre-to-centre pitch is the template
	-- width plus a 2m gap; ys holds each street's lateral offset,
	-- centred on y = 0 (so count=1 stays at y=0 like before).
	local gap = 2
	local pitch = street.width + gap
	local ys = {}
	for i = 1, count do ys[i] = (i - (count + 1) * 0.5) * pitch end
	local halfSpread = math.abs(ys[count])  -- 0 when count == 1
	-- Wall geometry: outer = wall centreline offset from the group
	-- centre. halfSpread is the offset of the farthest street (0
	-- for a single street); halfWidth + w.centre keeps the wall
	-- (half thick w.half) just outside the outermost sidewalk edge.
	-- The descent's street is narrower by extra each side, the wall's
	-- centreline in by extra / 2, so its outer face and everything past it
	-- (the coping's outer edge, the cover, the banks) stay where they were.
	local outer = halfSpread + (halfWidth - extra) + w.centre
	-- The flat approach's walls (on a stated slope only) stand beside the
	-- chosen street, sidewalks and all: s.wall as before.
	local outerA = halfSpread + halfWidth + s.wall.centre
	-- Outer edge of the coping, and of the portal cover with it.
	-- The cover used to reach outer + 4, 1.6m past the coping, and
	-- the ground showed in the notch between the two bands in front
	-- of the cover (seen in game, 2026-11-23). Both now end on one
	-- line, the narrower one, so the models' footprint is 1.6m
	-- narrower each side [guess: roads laid beside the ramp can
	-- then come closer; the shoulders' terrain faces still reach
	-- outer + 7]. The cover still reaches past the base portal's
	-- side pieces, out to 2.4m past their origin [source:
	-- tunnel_a_car.tunnel.lua bounding boxes; guess: that the origin
	-- is the street's edge, so the street edge + 2.4: outer + 1.4
	-- with the thick wall], but not past the
	-- terrain the tunnel's padding (2m, source: the same file) may
	-- open beyond them [guess: the dark patches the median's e2e
	-- picture showed beside its lid; here the strip in front of the
	-- cover, uncovered before as well, showed ground in game, not a
	-- void. The median's aprons are not copied: they would lie in
	-- the strip freed for roads beside the ramp; the e2e pictures
	-- decide].
	-- (The thin wall's coping, and so the cover, ends at outer + 1.0,
	-- the street edge + 1.5 since its clearance went (2026-11-24), short
	-- of the street edge + 2.4 where those side pieces may end, by 0.9m
	-- (0.4m before) [guess, as above]: whether they then show beside the
	-- cover, under the median's side streets too, is for the e2e
	-- pictures.)
	local copingOut = outer + w.copingOut

	-- The pit must cover the full tunnel clearance plus a thin layer.
	D = math.max(D, tunnelHeight + 2)

	-- Travel direction (+1 = toward +X) of each street. One-way
	-- carriageways are laid out by traffic side: facing +X, the +X
	-- group sits on the driving side (right-hand: -Y = ys[1..],
	-- left-hand: +Y), the -X group opposite, so Double is always a
	-- proper divided road and Triple is 2+1. The direction option
	-- then only picks which carriageway snaps to the external road.
	-- A single one-way street simply follows the direction.
	local want = (s.direction == 1) and 1 or -1
	local flows, snapIdx = {}, 1
	if street.oneWay and count > 1 then
		local plus = math.ceil(count / 2)
		for k = 1, count do
			-- (not `side == 1 and x or y`: a false x would fall through)
			local onPlus
			if s.side == 1 then onPlus = k <= plus else onPlus = k > count - plus end
			flows[k] = onPlus and 1 or -1
		end
		for k = 1, count do
			if flows[k] == want then snapIdx = k; break end
		end
	else
		for k = 1, count do flows[k] = street.oneWay and want or 1 end
	end

	-- Ground plane. The body is placed at the height of the road end
	-- it snaps to (Z), and everything used to be level with it, so on
	-- sloped ground the walls, coping and lid floated on the downhill
	-- side. The player states the slope instead (the build cursor
	-- shows the measured one): along = % rise toward the tunnel,
	-- across = % rise to the right when facing the tunnel (local +X
	-- is the ramp direction, local +Y its left side). The plane
	-- passes through the snap point, the one place where the ground
	-- is known to be at Z. 0/0 reproduces the old level layout.
	local ySnap = ys[snapIdx]
	local function ground(x, y)
		return gx * (x + approach) + gy * (y - ySnap)
	end
	local sloped = gx ~= 0 or gy ~= 0

	-- Vertical profile f(t) ∈ [0,1], with f(0)=0 and f(1)=1. Five
	-- shapes blend the straight line, cubic smoothstep, and quintic
	-- smootherstep in pairs so idx 3 reproduces the legacy cubic
	-- easing exactly (end slope 0, mid slope 1.5*D/L).
	--   idx 1 Shallow:    0.5 * t + 0.5 * cubic   (end 0.5, mid 1.25)
	--   idx 2 Gentle:     0.25 * t + 0.75 * cubic (end 0.25, mid 1.375)
	--   idx 3 Normal:     cubic                   (end 0, mid 1.5)
	--   idx 4 Steep:      0.5 * cubic + 0.5 * quintic (end 0, mid 1.6875)
	--   idx 5 Very steep: quintic                 (end 0, mid 1.875)
	local blend = { { 0.5, 0.5, 0 }, { 0.25, 0.75, 0 }, { 0, 1, 0 }, { 0, 0.5, 0.5 }, { 0, 0, 1 } }
	local b = blend[s.curvature] or blend[3]
	local function profile(t)
		local cubic = 3 * t * t - 2 * t * t * t
		local dcubic = 6 * t - 6 * t * t
		local quintic = t * t * t * (10 + t * (-15 + 6 * t))
		local dquintic = 30 * t * t * (1 + t * (-2 + t))
		local f  = b[1] * t    + b[2] * cubic  + b[3] * quintic
		local df = b[1] * 1    + b[2] * dcubic + b[3] * dquintic
		return -D * f, -D * df / L
	end

	-- Portal t: the first point where the earth cover above the roof
	-- exceeds one tunnel height (same heuristic the rail mod uses).
	-- The cover is measured from the ground plane on the lower edge
	-- of the portal cover slab (copingOut + 0.25 out), so a downhill or
	-- cross slope pushes the portal on until the whole slab has it.
	local roof = math.max(7, tunnelHeight + 1)
	local cover = math.min(D * 0.85, roof)
	local lidEdge = copingOut + 0.25  -- = roofHalf + 0.25 below
	local function coverAt(t)
		local z = profile(t)
		local x = L * t
		return math.min(ground(x, -lidEdge), ground(x, lidEdge)) - z
	end
	local lo, hi = 0, 1
	if gx < 0 then
		-- Downhill the cover can peak and shrink again, so bisection
		-- alone could land on a later crossing: bracket the first one.
		-- If it never gets deep enough the portal sits at the foot.
		local steps, found = 200, false
		for k = 1, steps do
			if coverAt(k / steps) >= cover then
				lo, hi, found = (k - 1) / steps, k / steps, true
				break
			end
		end
		if not found then lo, hi = 1, 1 end
	end
	for _ = 1, 40 do
		local m = (lo + hi) * 0.5
		if coverAt(m) < cover then lo = m else hi = m end
	end
	-- Steep uphill ground can give the cover at once; keep 8m of open
	-- trench so the walls and the lid (from portalX - 6) stay on the
	-- ramp side of x = 0.
	local portal = math.max((lo + hi) * 0.5, 8 / L)
	local portalX = L * portal

	-- Height the walls, coping and shoulders follow: the ground plane,
	-- but never below the road. Near the mouth on a downhill slope
	-- the road is still above the ground, and walls cut to the plane
	-- there would sit below the trench floor fill.
	local function roadZ(x)
		return (profile(math.max(0, math.min(1, x / L))))
	end
	-- The portal cover lies on the ground plane, but must never sink
	-- into the tunnel: on downhill ground steeper than the ramp can
	-- get under, the plane runs through it. Then the plane is lifted
	-- as a whole (lift) until the ground under the cover is 0.6m over
	-- the tunnel roof (just under the cover at the portal, so level
	-- ground, where the cover is met exactly, never trips it),
	-- checked from the portal to the cover's end or HOLD_AHEAD past the
	-- portal, whichever is further (with the faces' 0.25m margin), so a
	-- shorter cover is lifted as 1.0.0's 36m one was. The walls, coping and banks
	-- ramp up to it from the trench start, an embankment instead of
	-- a lid floating over the walls.
	local roofHalf = copingOut
	-- lidB = lidA + lidLength, written from the portal as 1.0.0's
	-- portalX + 30 and portalX + 30.25 were, so 36 gives them to the bit
	local ahead = lidLength - M.LID_BEHIND
	local lidA, lidB = portalX - M.LID_BEHIND, portalX + ahead
	local coverA, coverB = portalX - 6.25, portalX + (ahead + 0.25)
	local lidClear = math.min(cover, tunnelHeight + 0.6) - 0.01
	local lift = 0
	-- (holdB is lidB for 1.0.0's 36m lid, so its lift stays to the bit)
	local holdB = math.max(lidB, portalX + M.HOLD_AHEAD)
	for k = 0, 10 do
		local x = portalX + (holdB + 0.25 - portalX) * k / 10
		for _, y in ipairs({ -roofHalf - 0.25, roofHalf + 0.25 }) do
			lift = math.max(lift, roadZ(x) + lidClear - ground(x, y))
		end
	end
	-- Lifted as a whole: the lid and the faces under it stay one flat
	-- slab parallel to the ground.
	local function lidZ(x, y)
		return ground(x, y) + lift
	end
	-- 0 at the trench start (no step to the approach), full from
	-- the front of the cover's margin on.
	local function lifted(x, y)
		return ground(x, y) + lift * math.max(0, math.min(1, x / (portalX - 6.25)))
	end
	local function surface(x, y)
		return math.max(lifted(x, y), roadZ(x))
	end
	-- The trench floor's faces reach floorOuter, the shoulders' banks
	-- shoulderOut: side streets laid beside the walls meet that terrain.
	local floorOuter = outer + w.floor
	local shoulderOut = outer + w.shoulderOut

	g.L, g.D, g.count, g.approach, g.runout = L, D, count, approach, runout
	g.runoutEnd = L + runout
	g.gx, g.gy, g.sloped = gx, gy, sloped
	g.tunnelHeight = tunnelHeight
	g.halfWidth, g.pitch, g.ys, g.halfSpread = halfWidth, pitch, ys, halfSpread
	g.flows, g.snapIdx = flows, snapIdx
	g.outer, g.copingOut, g.roofHalf, g.lidEdge = outer, copingOut, roofHalf, lidEdge
	g.cover, g.portal, g.portalX = cover, portal, portalX
	g.lidA, g.lidB, g.lift = lidA, lidB, lift
	g.lidLength, g.coverA, g.coverB = lidLength, coverA, coverB
	g.holdB = holdB
	g.floorOuter, g.shoulderOut = floorOuter, shoulderOut
	g.wall, g.shoulderIn = w, outer + w.shoulderIn
	g.extra = extra
	g.descentRef = descent and descent.ref or street.ref
	-- the wall's inner face (I) beside the descent
	g.wallInner = outer - w.half
	g.approachWall = {
		wall = s.wall, outer = outerA, floorOuter = outerA + s.wall.floor,
		shoulderIn = outerA + s.wall.shoulderIn, copingOut = outerA + s.wall.copingOut,
	}
	g.ground, g.profile, g.roadZ = ground, profile, roadZ
	g.lidZ, g.lifted, g.surface = lidZ, lifted, surface
	return g
end

local function newResult()
	-- One subconstruction holds every piece that isn't an edge: walls,
	-- coping slabs, portal cover, and the terrain alignment faces that
	-- carve the open trench. A non-empty models list is what lets the
	-- engine accept this subcon (Phase 1 crashed on "Empty Subconstruction"
	-- here; see commit aa749c6).
	return {
		cost = 0,
		bulldozeCost = 0,
		maintenanceCost = 0,
		edgeLists = {},
		edgeObjects = {},
		subconstructions = {
			{ tag = 1, models = {}, groundFaces = {}, terrainAlignmentLists = {}, colliders = {} },
		},
	}
end

function M.build(s)
	local g = M.layout(s)
	local r = newResult()
	local sub = r.subconstructions[1]
	-- The flat approach and the underground runout are the chosen street;
	-- the descent between them (x = 0 to L) its sidewalk-less descent
	-- (g.descentRef, the same street when it has none). The runout stays the
	-- chosen street so a tunnel of that type, laid on from its end, meets
	-- its own type there, as before: at a construction's kept node a street
	-- of another type let no car through [measured 2026-11-23 PC, PD].
	local streetRef = M.tramRef(s.street.ref, s.tramLanes, s.tramPower)
	local descentRef = M.tramRef(g.descentRef, s.tramLanes, s.tramPower)
	local edgeRef = streetRef
	local tunnelRef = s.tunnelRef
	local L, D, count, approach, runout = g.L, g.D, g.count, g.approach, g.runout
	local gy, sloped = g.gy, g.sloped
	local ys, flows, snapIdx = g.ys, g.flows, g.snapIdx
	local outer, copingOut, roofHalf, lidEdge = g.outer, g.copingOut, g.roofHalf, g.lidEdge
	local wall = g.wall
	local portal, portalX, lidA, lidB = g.portal, g.portalX, g.lidA, g.lidB
	local profile, roadZ, lidZ, surface = g.profile, g.roadZ, g.lidZ, g.surface
	local Z = 0

	local function node(x, y, z, dx, dy, dz)
		return { { x, y, Z + z }, { dx, dy, dz } }
	end

	-- One-way templates carry traffic in edge direction, so a
	-- reversed street is emitted b→a with negated tangents (and
	-- its snap/free node indices swapped to stay on the same end).
	local reverse = false
	local function edge(a, b, isTunnel, snapA, snapB, freeA, freeB)
		if reverse then
			a, b = { b[1], { -b[2][1], -b[2][2], -b[2][3] } },
			       { a[1], { -a[2][1], -a[2][2], -a[2][3] } }
			snapA, snapB = snapB, snapA
			freeA, freeB = freeB, freeA
		end
		local snaps, frees = {}, {}
		if snapA then snaps[#snaps + 1] = 0 end
		if snapB then snaps[#snaps + 1] = 1 end
		-- Mark a node 'free' when it is not snapped and would
		-- otherwise be a bare dangling endpoint: the engine then
		-- treats it as an explicitly open end of construction
		-- rather than a floating node.
		if freeA then frees[#frees + 1] = 0 end
		if freeB then frees[#frees + 1] = 1 end
		-- Terrain is shaped centrally via terrainAlignmentLists on
		-- the subconstruction, so no per-edge alignment is wanted
		-- either side of the portal.
		local e = {
			type = "STREET",
			params = { type = edgeRef },
			edges = { a, b },
			snapNodes = snaps,
			freeNodes = frees,
			alignTerrain = false,
		}
		if isTunnel then
			e.edgeType = "TUNNEL"
			e.edgeTypeName = tunnelRef
		end
		r.edgeLists[#r.edgeLists + 1] = e
	end

	-- Ramp proper: a mix of surface and tunnel segments, split at the
	-- portal so that curvature stays smooth at the transition.
	local segments = math.max(8, math.ceil(L / 40))
	local ts = { 0, portal, 1 }
	-- Skip regular splits that land within 2m of the portal: they
	-- would leave a sliver edge (down to ~0.07m on 40m ramps), which
	-- TF placement handles poorly.
	for i = 1, segments - 1 do
		if math.abs(i / segments - portal) * L >= 2 then ts[#ts + 1] = i / segments end
	end
	table.sort(ts)
	local uniq = {}
	for _, t in ipairs(ts) do
		if #uniq == 0 or t - uniq[#uniq] > 1e-7 then
			uniq[#uniq + 1] = t
		end
	end

	-- Build each parallel street. Only ys[snapIdx] exposes a
	-- snap node at its approach start so the external edge-end snap
	-- binds to exactly one lane; the others stay free so the player
	-- can hand-connect them after placement.
	local segN = math.max(1, math.ceil(runout / 40))
	local handOver = s.handOver ~= false
	local depotStyle = not handOver and s.approachDepotStyle == true
	for idx, yOffset in ipairs(ys) do
		reverse = flows[idx] == -1
		local snapApproach = (idx == snapIdx)
		edgeRef = streetRef
		-- Flat approach segment (external connection at x = -approach).
		-- ys[snapIdx] snaps to the external road.
		-- Handed over (both nodes free, as the base game's interchanges
		-- hand over all their streets, street_constructions.script.lua
		-- freeAllNodes), so the road joined at its start meets an
		-- ordinary street's node, and the kept descent starts at a free
		-- node, as the median's kept ramp does after its handed-over
		-- first piece (median.script.lua rampHandOver, layout 11).
		-- Why: with the approach kept, a road of another type joined at
		-- its start let pedestrians in but no car, whatever the ramp's
		-- type (country_new_small too), while the same type passed
		-- [measured 2026-11-23 PS, PW, PC, tf3ctl road + reach]; the
		-- median's handed-over joints pass cars between types [measured
		-- C5, C6]. tf3ctl road leaves a construction's node set-up as it
		-- is and writes no lane connections for the new piece there
		-- [source: remote_build.lua planJoin, NOTE_KEEP], so at a kept
		-- node the cars' connections were left to the engine [guess:
		-- which joins only the same type's lanes there; e2e pending].
		-- Kept (rtr_approach_hand_over 0): the others expose their
		-- approach start as a free node so the engine treats the
		-- dangling endpoint as an open end rather than a floating
		-- node (unsnapped + non-free can trigger placement refusal).
		-- Depot style (rtr_approach_hand_over 2): kept, but every
		-- street's outer end is free, the snapping one's too, as the
		-- base game's road_depot and tram_depot leave their entrance
		-- edge (snapNodes {0}, freeNodes {0}) [source: depots/road.zip
		-- road_depot.script.lua, tram_depot.script.lua]; on a reversed
		-- one-way street the same end is index 1. The approach
		-- then goes with the ramp when bulldozed and nothing builds
		-- beside it, while the road joined there meets a free node
		-- [guess: that this lets cars of another street type through
		-- as the handed-over approach does; e2e pending]. x = 0 and
		-- the descent stay kept.
		edge(
			node(-approach, yOffset, 0, approach, 0, 0),
			node(0, yOffset, 0, approach, 0, 0),
			false, snapApproach, false,
			handOver or depotStyle or not snapApproach, handOver
		)
		edgeRef = descentRef
		for i = 1, #uniq - 1 do
			local ta, tb = uniq[i], uniq[i + 1]
			local za, ga = profile(ta)
			local zb, gb = profile(tb)
			local dx = L * (tb - ta)
			local isTunnel = (ta + tb) * 0.5 >= portal
			edge(
				node(L * ta, yOffset, za, dx, 0, ga * dx),
				node(L * tb, yOffset, zb, dx, 0, gb * dx),
				isTunnel, false, false,
				handOver and i == 1, false
			)
		end
		-- Underground runout, so the player's own tunnel can snap to the end.
		edgeRef = streetRef
		for i = 0, segN - 1 do
			local a, b = L + runout * i / segN, L + runout * (i + 1) / segN
			edge(
				node(a, yOffset, -D, b - a, 0, 0),
				node(b, yOffset, -D, b - a, 0, 0),
				true, false, i == segN - 1
			)
		end
	end

	local wallSegLen = 4
	local wallSegments = math.max(1, math.ceil(portalX / wallSegLen))
	-- the part models: the wall pieces are the wall model, the coping and
	-- parapet the strip, the cover the slab
	local wallModel, slabModel, stripModel = M.WALL_MODELS.wall, M.WALL_MODELS.slab, M.WALL_MODELS.strip

	-- Walls along both sides of the surface trench.
	-- transf columns: local x along the segment (its z component
	-- shears the segment so the top follows the surface), local y
	-- perpendicular (scaled wall.scale: 2.667 for the thick ~1.2m
	-- wall, 2.222 for the thin 1.0m one), local z
	-- up (scaled by height, so the top sits 30cm above the surface).
	-- On a stated slope the approach street gets walls too: the
	-- plane meets the road at the snap point but not at x = 0, so
	-- without them the trench walls would start with a bare end face
	-- over a cut (uphill) or a fill (downhill).
	-- side: { outer, wall }, the descent's (g) or the flat approach's
	-- (g.approachWall), whose wall is the thinner one beside the sidewalk.
	local function walls(x0, x1, segments, prefix, side)
		local outer, wall = side.outer, side.wall
		for _, wallSide in ipairs({ -1, 1 }) do
			for i = 0, segments - 1 do
				local xa = x0 + (x1 - x0) * i / segments
				local xb = x0 + (x1 - x0) * (i + 1) / segments
				local a = node(xa, wallSide * outer, 0, 1, 0, 0)[1]
				local b = node(xb, wallSide * outer, 0, 1, 0, 0)[1]
				local dx, dy = b[1] - a[1], b[2] - a[2]
				local len = math.sqrt(dx * dx + dy * dy)
				local za = roadZ(xa)
				local zb = roadZ(xb)
				local topA = surface(xa, wallSide * outer) + 0.3
				local rise = surface(xb, wallSide * outer) + 0.3 - topA
				-- The shear also tilts the base; start it lower when the
				-- top rises so both ends stay 1.5m under the road.
				local bottom = math.min(za, zb) - 1.5 - math.max(0, rise)
				local height = topA - bottom
				-- stacked in n boxes of one height (M.stackCount); all take
				-- the same shear, so each box's top runs along the next one's
				-- base over the whole piece
				local n = M.stackCount(height)
				local h = height / n
				for k = 1, n do
					sub.models[#sub.models + 1] = {
						id = wallModel,
						transf = {
							dx, dy, rise, 0,
							-wall.scale * dy / len, wall.scale * dx / len, 0, 0,
							0, 0, h, 0,
							a[1], a[2], Z + bottom + h * (k - 1), 1,
						},
						tag = string.format("%s%d_%d_%d", prefix, wallSide, i, k),
					}
				end
			end
		end
	end
	local approachSegments = math.max(1, math.ceil(approach / wallSegLen))
	local approachSide = g.approachWall
	walls(0, portalX, wallSegments, "wall_", g)
	if sloped then walls(-approach, 0, approachSegments, "approach_wall_", approachSide) end

	-- Concrete coping on top of the wall, hiding the seam where the
	-- descending terrain meets the wall face. rise (z over the
	-- segment) and tilt (z per metre toward the segment's left)
	-- shear the slab onto a sloped surface.
	local function slab(a, b, width, bottom, thickness, tag, rise, tilt, model)
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dy * dy)
		sub.models[#sub.models + 1] = {
			id = model,
			transf = {
				dx, dy, rise or 0, 0,
				-dy / len * width / 0.45, dx / len * width / 0.45, (tilt or 0) * width / 0.45, 0,
				0, 0, thickness, 0,
				a[1], a[2], Z + bottom, 1,
			},
			tag = tag,
		}
	end
	local function copings(x0, x1, segments, prefix, side)
		local outer, wall = side.outer, side.wall
		for _, sign in ipairs({ -1, 1 }) do
			local inside = outer - wall.copingIn
			local outside = copingOut
			local mid = sign * (inside + outside) * 0.5
			local width = outside - inside
			for i = 0, segments - 1 do
				local xa = x0 + (x1 - x0) * i / segments
				local xb = x0 + (x1 - x0) * (i + 1) / segments
				local sa = surface(xa, mid)
				local xm = (xa + xb) * 0.5
				slab(
					node(xa, mid, 0, 1, 0, 0)[1],
					node(xb, mid, 0, 1, 0, 0)[1],
					width, sa + 0.28, 0.25,
					string.format("%s%d_%d", prefix, sign, i),
					surface(xb, mid) - sa,
					(surface(xm, mid + width * 0.5) - surface(xm, mid - width * 0.5)) / width,
					stripModel
				)
			end
		end
	end
	-- The trench coping stops where the cover starts: past it the two
	-- would share their outer side faces (z-fighting), and the
	-- coping's top, 3cm over the cover's, would show as a strip on it.
	copings(0, lidA, math.max(1, math.ceil(lidA / wallSegLen)), "coping_", g)
	if sloped then copings(-approach, 0, approachSegments, "approach_coping_", approachSide) end

	-- The thin wall's parapet: a wall-type barrier on the coping, its
	-- inner face over the wall's, its top wall.parapet.top over the
	-- ground, along the same run as the coping (the cover takes over
	-- from lidA on).
	local function parapets(x0, x1, segments, prefix, side)
		local outer, wall = side.outer, side.wall
		local pp = wall.parapet
		local copingTop = 0.28 + 0.25
		for _, sign in ipairs({ -1, 1 }) do
			local mid = sign * (outer - wall.half + pp.thickness * 0.5)
			for i = 0, segments - 1 do
				local xa = x0 + (x1 - x0) * i / segments
				local xb = x0 + (x1 - x0) * (i + 1) / segments
				local sa = surface(xa, mid)
				local xm = (xa + xb) * 0.5
				slab(
					node(xa, mid, 0, 1, 0, 0)[1],
					node(xb, mid, 0, 1, 0, 0)[1],
					pp.thickness, sa + copingTop, pp.top - copingTop,
					string.format("%s%d_%d", prefix, sign, i),
					surface(xb, mid) - sa,
					(surface(xm, mid + pp.thickness * 0.5) - surface(xm, mid - pp.thickness * 0.5)) / pp.thickness,
					stripModel
				)
			end
		end
	end
	if wall.parapet then
		parapets(0, lidA, math.max(1, math.ceil(lidA / wallSegLen)), "parapet_", g)
		if sloped then parapets(-approach, 0, approachSegments, "approach_parapet_", approachSide) end
	end

	-- Portal top cover: a rigid slab across the portal tangent so
	-- the heightmap below the cover can be driven down (LESS face
	-- below) and the surface seam at the portal is hidden. It lies
	-- on the (lifted, see lift in M.layout) ground plane like the coping.
	-- Laid in pieces of at most M.COVER_PIECE along and coverAcross(W)
	-- across (portal_top_cover_<i>_<j>, i along from lidA, j across from
	-- -roofHalf): lidZ is a plane, so the pieces lie in the one slab's
	-- plane and meet edge to edge. The end edges are the slab's own (lidA,
	-- lidB, -roofHalf, roofHalf), and one piece across is the slab as it
	-- was (centred on y 0, width roofHalf * 2).
	local coverXs, coverN = M.pieces(lidA, lidB, M.COVER_PIECE)
	local coverW = roofHalf * 2
	local acrossN = M.coverAcross(coverW)
	local coverYs = {}
	-- (2j - n) / n: the edges are symmetric about y 0 to the last bit
	for j = 0, acrossN do coverYs[j] = roofHalf * (2 * j - acrossN) / acrossN end
	for i = 1, coverN do
		local xa, xb = coverXs[i - 1], coverXs[i]
		for j = 1, acrossN do
			local ya, yb = coverYs[j - 1], coverYs[j]
			local yc = (ya + yb) * 0.5
			slab(
				node(xa, yc, -D, 1, 0, 0)[1],
				node(xb, yc, -D, 1, 0, 0)[1],
				yb - ya, lidZ(xa, yc) - 0.3, 0.8,
				string.format("portal_top_cover_%d_%d", i, j),
				lidZ(xb, yc) - lidZ(xa, yc), gy, slabModel
			)
		end
	end

	-- Terrain alignment: floor (EQUAL) carves the trench bottom
	-- below the ramp; shoulders (EQUAL on the surface) keep the
	-- ground at the coping outside the walls and beside / past the
	-- lid; portal cover (LESS) lowers the heightmap under the big
	-- top slab so dirt doesn't poke through, and lid support
	-- (GREATER, same height) fills it up where the ground is lower
	-- so the slab never floats.
	local floorOuter = g.floorOuter
	local floorFaces = {}
	for i = 0, wallSegments - 1 do
		local xa = portalX * i / wallSegments
		local xb = portalX * (i + 1) / wallSegments
		local za = profile(xa / L)
		local zb = profile(xb / L)
		floorFaces[#floorFaces + 1] = {
			{ xa, -floorOuter, Z + za - 0.25 },
			{ xb, -floorOuter, Z + zb - 0.25 },
			{ xb,  floorOuter, Z + zb - 0.25 },
			{ xa,  floorOuter, Z + za - 0.25 },
		}
	end
	-- Faces are counter-clockwise seen from above. A face on the
	-- surface is level in old saves' 0/0 case and tilted otherwise.
	local function face(height, x0, x1, y0, y1, dz)
		return {
			{ x0, y0, Z + height(x0, y0) + dz },
			{ x1, y0, Z + height(x1, y0) + dz },
			{ x1, y1, Z + height(x1, y1) + dz },
			{ x0, y1, Z + height(x0, y1) + dz },
		}
	end
	-- Beside and past the lid the shoulders rise with it.
	local function lidSurface(x, y)
		return math.max(surface(x, y), lidZ(x, y))
	end
	-- Shoulders run from the coping to well past it (the old 2.35m
	-- strip gave a 1:1 bank right at the wall), along the trench and
	-- on beside and beyond the lid, which used to have nothing
	-- holding the ground up to it.
	local inner = g.shoulderIn
	local outside = g.shoulderOut
	-- (from M.layout, written out there, not lidA - 0.25: keeps the 0/0
	-- faces bit-identical)
	local coverA, coverB = g.coverA, g.coverB
	local shoulders = {}
	local trenchSegments = math.max(1, math.ceil(coverA / wallSegLen))
	for _, sign in ipairs({ -1, 1 }) do
		local function strip(height, x0, x1, y0, y1)
			if sign == 1 then
				shoulders[#shoulders + 1] = face(height, x0, x1, y0, y1, 0)
			else
				shoulders[#shoulders + 1] = face(height, x0, x1, -y1, -y0, 0)
			end
		end
		-- Along the approach walls (stated slope only), so the
		-- banks run on to the snap point.
		if sloped then
			for i = 0, approachSegments - 1 do
				strip(surface, -approach + approach * i / approachSegments,
					-approach + approach * (i + 1) / approachSegments, approachSide.shoulderIn, outside)
			end
		end
		for i = 0, trenchSegments - 1 do
			strip(surface, coverA * i / trenchSegments, coverA * (i + 1) / trenchSegments, inner, outside)
		end
		strip(lidSurface, coverA, coverB, lidEdge, outside)
	end
	shoulders[#shoulders + 1] = face(lidSurface, coverB, coverB + (outside - lidEdge), -outside, outside, 0)
	local coverFace = face(lidZ, coverA, coverB, -lidEdge, lidEdge, -0.55)
	-- Lid support leaves out the open trench mouth under the lid's
	-- front 6m, which the floor faces cut down.
	local lidSupport = {
		face(lidZ, portalX, coverB, -lidEdge, lidEdge, -0.55),
		face(lidZ, coverA, portalX, inner, lidEdge, -0.55),
		face(lidZ, coverA, portalX, -lidEdge, -inner, -0.55),
	}
	-- Gentle banks: slopeLow is the fill side (embankment from below),
	-- slopeHigh the cut side, as for the street types' embankments.
	sub.terrainAlignmentLists = {
		{ type = "EQUAL",   faces = floorFaces,   slopeLow = 100,  slopeHigh = 100, optional = true },
		{ type = "EQUAL",   faces = shoulders,    slopeLow = 0.45, slopeHigh = 1,   optional = true },
		{ type = "LESS",    faces = { coverFace }, slopeLow = 100, slopeHigh = 100, optional = true },
		{ type = "GREATER", faces = lidSupport,   slopeLow = 100,  slopeHigh = 100, optional = true },
	}
	-- Past a lid shorter than HOLD_AHEAD, the ground over the tunnel up to
	-- holdB is filled to the lifted plane itself (lidZ: there is no slab to
	-- make room for, unlike the lid support's - 0.55), so it meets the end
	-- bank's height and keeps lidClear (about 0.6m) over the roof, with
	-- gentle banks as an embankment (review, 2026-11-26). Only when lifted: unlifted, the plane is over
	-- the roof by lidClear on that run already. Last of the body's lists
	-- (after the sloped approach's face), so their numbers stay; the 36m
	-- lid has none.
	local holdB = g.holdB + 0.25
	-- The approach street stays level at Z (it has to meet the road
	-- it snaps to), so on a stated slope its ground between the
	-- approach walls is cut or filled to the trench floor level.
	if sloped then
		table.insert(sub.terrainAlignmentLists, {
			type = "EQUAL",
			faces = { { { -approach, -approachSide.floorOuter, Z - 0.25 }, { 0, -approachSide.floorOuter, Z - 0.25 },
			            { 0, approachSide.floorOuter, Z - 0.25 }, { -approach, approachSide.floorOuter, Z - 0.25 } } },
			slopeLow = 0.45, slopeHigh = 1, optional = true,
		})
	end

	if g.lift > 0 and holdB > coverB + 1e-9 then
		sub.terrainAlignmentLists[#sub.terrainAlignmentLists + 1] = {
			type = "GREATER", faces = { face(lidZ, coverB, holdB, -lidEdge, lidEdge, 0) },
			slopeLow = 0.45, slopeHigh = 1, optional = true,
		}
	end

	r.cost = math.floor((L + approach + runout) * 300 * count + D * 2000)
	r.bulldozeCost = math.floor(r.cost * 0.1)
	r.maintenanceCost = math.floor(r.cost * 0.001)

	-- External connection point at the snapping street's approach
	-- start. With count > 1, only ys[snapIdx] exposes a snap node, so
	-- the snap point is placed on that lane.
	--
	-- TPF3 interprets a snap point's local +Y axis (not +X as the
	-- landmark examples might suggest) as the direction of the edge
	-- it should snap to. Our approach edge runs along world +X, so
	-- we rotate the frame CW 90° about Z to point local +Y along
	-- +X. Writing a unit matrix here places the ramp sideways
	-- (90° right-rotated) against the target road.
	r.snapPoint = {
		transf = {
			0, -1, 0, 0,
			1,  0, 0, 0,
			0,  0, 1, 0,
			-approach, ys[snapIdx], Z, 1,
		},
		transportModes = { "CAR", "BUS", "TRUCK" },
		snapToBaseEdgeTypes = { "STREET" },
		allowSnapToBaseEdgeEnds = true,
		placeAtTerrainHeight = true,
		allowSnapToMesh = false,
	}

	return r, g
end

return M
