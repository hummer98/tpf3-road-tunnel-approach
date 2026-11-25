-- Median tunnel approach, rebuilt as the set the user built by hand from the
-- full-width ramp and two side streets (user: 「1. 作り直してください」):
--
--   x = -approach        0 (trench start)        portalX        lidB
--   (snap point)         ==== side street (one-way, sidewalk outside) ====
--                        coping | walls ...    lid ...................
--   ======= approach (handed over) ====== descent === tunnel === runout
--                        coping | walls ...    lid ...................
--                        ==== side street (one-way, sidewalk outside) ====
--
-- The centre is ramp_geometry's body (descent, walls, coping, lid, terrain,
-- tunnel, underground runout) for one two-lane street; its flat approach is
-- handed over as on the full-width ramp. The side streets lie straight, at
-- +-Y from the centre line, beside the walls and the lid (x = 0 to lidB),
-- handed over too (both nodes free). The fork in front of them and the
-- merge past them are the player's to lay (the user, 2026-11-24: 「中央導入
-- 路パターンは、側道接続は離散/合流共にユーザーにやってもらうことにします。
-- プリセット設置が不可能ならスクリプト接続は無し。」), with ordinary streets
-- and the side street type in the build menu (median_side_r).
--
-- No engine access (median.script.lua resolves the tunnel), so the tests
-- can run it offline. Loaded as ramp_geometry is, by the mod's own path.

local geometry = require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua"

local M = {}

local STREETS = "road_tunnel_ramp::/road_tunnel_ramp/streets/"
local TOWN = "::/infrastructure/street/town/"

-- The centre's street: the full-width ramp's two-lane entries, by the same
-- rtr_street numbers (ramp.con.lua streets; the tests hold them equal).
-- The user: 「導入部は道路によって選べるのが理想です。同じ二車線にしても
-- 田舎道か街路か選べるのが理想です」「高速も、ですね」, and the cars-only one
-- first: 「車専用でいいです」.
M.CENTRES = {
	[1] = { ref = "::/infrastructure/street/highway/highway_new_small.street_template", width = 9, oneWay = true },
	[2] = { ref = "::/infrastructure/street/country/country_new_small.street_template", width = 14 },
	[3] = { ref = TOWN .. "town_new_small.street_template", width = 16 },
	[8] = { ref = STREETS .. "ramp_car_only.street_template", width = 8,
	        variants = {
		        STREETS .. "ramp_car_only_bare.street_template",
		        STREETS .. "ramp_car_only_town_style.street_template",
	        } },
}
M.CENTRE_ORDER = { 1, 2, 3, 8 }  -- the menu's order (width, cars-only last, as on the ramp)
M.CENTRE_DEFAULT = 8

-- The entry: the town street the approach is placed on, by its lanes. The
-- user: 「導入が2なら2、4なら4、6なら6にしましょう」「今ののバリエーション
-- なら 2->1+1->2 4->1+1->4 6->2+2->6 （中2+2は一方通行) ができればいい
-- んですよね」. The centre always carries one lane each way (the two-lane
-- street chosen above); the side streets the rest, one way each:
--   2: 1 + 1 (median_side_*, one 3.5m lane, sidewalk 3m outside, 6.5m; the user:
--      「1車線の歩道付きはバニラUIからは配線できないので高速で代用しました」,
--      so this mod's one-lane town street takes the highway's place)
--   4: 1 + 1, the same side street
--   6: 2 + 2 (median_c_side_*, two lanes of 4m, sidewalk 3.5m outside, 11.5m)
-- street: the town street the entry stands for (its width is the median's
-- across with the initial settings, tests).
-- Side templates are named by where the sidewalk is seen along the edge:
-- right with right-hand traffic, left with left-hand, so it lies outside.
local function side(stem, width, lanes)
	return { right = STREETS .. stem .. "_r.street_template", left = STREETS .. stem .. "_l.street_template",
	         width = width, lanes = lanes }
end
M.ENTRIES = {
	[2] = { side = side("median_side", 6.5, 1), street = { ref = TOWN .. "town_new_small.street_template", width = 16 } },
	[4] = { side = side("median_side", 6.5, 1), street = { ref = TOWN .. "town_new_medium.street_template", width = 24 } },
	[6] = { side = side("median_c_side", 11.5, 2), street = { ref = TOWN .. "town_new_large.street_template", width = 32 } },
}
M.ENTRY_DEFAULT = 4

-- Where the side streets lie. Their centre line is Y from the centre's:
-- the coping's (and lid's) outer edge, half the side street, and GAP, so the
-- side street's inner edge lies on the coping's and the lid's outer edge.
-- GAP was 0.5m: in game the strip between showed as a ditch beside one
-- side street and as green ground with the cut-bank texture along the
-- other (the user's manual check, 2026-11-24: 「側道と擁壁の間になにか溝の
-- ようになっている部分があります。片側の車線にしかないんですよね」「わずかに
-- コンクリートではなく緑の地面がみえているのと、盛土や掘割になったときに
-- みえる白い堀跡のようなものが道路沿いに見えています」); now 0, and the
-- ground under each side street is held at its height (build).
M.GAP = 0
-- The approach slider starts here: room between the snap point and the
-- side streets' near ends (the trench start) for a fork the player lays
-- from the snap point's node. S-curves from a four-lane street's end node
-- out to +-12..16m over 15 to 40m built on both sides [measured 2026-11-24
-- PA, tf3ctl road]; 30m is inside that range with room both ways.
M.APPROACH_MIN = 30

local value = geometry.value

local function entryOf(p)
	local e = value(p, "rtr_median_entry", M.ENTRY_DEFAULT, 2, 6)
	if e < 3 then return 2 end
	if e >= 5 then return 6 end
	return 4
end
M.entryOf = entryOf

-- The centre's rtr_street number: one of CENTRES, the cars-only one when
-- missing or any other (the ramp's wider entries are not offered here).
local function centreOf(p)
	local n = tonumber(p.rtr_street)
	if n and n == n then n = math.floor(n + 0.5) end
	if not (n and M.CENTRES[n]) then n = M.CENTRE_DEFAULT end
	return n
end
M.centreOf = centreOf

-- The spec ramp_geometry builds the centre from: the menu read as the
-- full-width ramp reads it (same keys, defaults and clamps), with the
-- centre street, one street, the approach handed over, and the thin wall
-- when rtr_wall is missing (this menu starts on it, as the ramp's does).
-- cap: { tunnelRef, tunnelHeight }.
function M.spec(cap, p)
	p = p or {}
	local q = {}
	for k, v in pairs(p) do q[k] = v end
	q.rtr_street = 1
	q.rtr_count = 1
	q.rtr_approach_hand_over = 1
	-- thin unless the thick wall is asked for (junk too reads as the
	-- menu's initial setting)
	local wall = tonumber(q.rtr_wall)
	if not wall or wall ~= wall then q.rtr_wall = 1 end
	local s = geometry.spec({ streets = { M.CENTRES[centreOf(p)] }, tunnelRef = cap.tunnelRef,
		tunnelHeight = cap.tunnelHeight }, q)
	-- At least APPROACH_MIN, so a fork laid from the snap point has room
	-- in front of the walls and the coping (review, 2026-11-24: from 20m a
	-- curve to x = 10 crossed the wall's first 5m).
	s.approach = math.max(s.approach, M.APPROACH_MIN)
	return s
end

-- Everything the side streets are laid out from: g (ramp_geometry.layout),
-- the entry, its side template, Y, the side streets' run (x0 .. x1) and
-- whether each runs toward the tunnel.
-- The run is the walls' and the lid's together, from the trench start
-- (x = 0, where the walls start) to the lid's far end (lidB = portalX +
-- 30), so it follows the length, the depth, the curvature, the slopes and
-- the centre and wall (they move the portal) by itself (the user,
-- 2026-11-24: 「側道の長さは、擁壁部＋蓋と同じ長さに自動的に調整される
-- ようにしてください」). Not from the snap point: the approach in front is
-- where the player lays the fork. Not on along the runout: it is
-- underground, and the merge is laid past the lid.
function M.layout(spec, p)
	p = p or {}
	local g = geometry.layout(spec)
	local entry = entryOf(p)
	local E = M.ENTRIES[entry]
	local sideSide = spec.side == 2 and "left" or "right"
	local y = g.copingOut + E.side.width * 0.5 + M.GAP
	return {
		g = g,
		entry = entry,
		street = E.street,
		side = { ref = E.side[sideSide], width = E.side.width, lanes = E.side.lanes },
		y = y,
		x0 = 0,
		x1 = g.lidB,
		-- Facing the tunnel (+x) with right-hand traffic, the right side
		-- (-y) carries traffic toward it; with left-hand the left side.
		toward = { [-1] = spec.side ~= 2, [1] = spec.side == 2 },
	}
end

-- Height of the body's banks at (x, y) beside the trench, where the side
-- street's inner edge lies: the shoulders' faces (ramp_geometry.build), on
-- the ground plane but never below the road near the mouth, lifted with the
-- lid on downhill ground too steep for the ramp, out to the faces' end past
-- the lid; the plane beyond.
local function bankZ(g, x, y)
	local coverA, coverB = g.portalX - 6.25, g.portalX + 30.25
	local coverEnd = coverB + (g.shoulderOut - g.lidEdge)
	if x > coverEnd then return g.ground(x, y) end
	local z = g.surface(x, y)
	if x >= coverA then z = math.max(z, g.lidZ(x, y)) end
	return z
end
M.bankZ = bankZ

-- Longest piece of a side street where it has to follow the banks: 5m
-- keeps the curve within 0.35m of them between nodes (tests).
M.PIECE = 5

local function sideEdge(r, lay, a, b, toward)
	-- One-way: traffic in edge direction, so the side away from the
	-- tunnel is laid from its far end.
	if not toward then
		a, b = { b[1], { -b[2][1], -b[2][2], -b[2][3] } }, { a[1], { -a[2][1], -a[2][2], -a[2][3] } }
	end
	r.edgeLists[#r.edgeLists + 1] = {
		type = "STREET",
		params = { type = lay.side.ref },
		edges = { a, b },
		snapNodes = {},
		-- Handed over: an ordinary street of the player's once built,
		-- so towns build along its outer side (its trench side carries
		-- median_inner's preventParcels), and the player joins its ends.
		freeNodes = { 0, 1 },
		-- (the ground under it is held by the faces in build, as the
		-- body's is by its own: every edge of the body leaves it off)
		alignTerrain = false,
	}
end

-- How far past the side street's outer edge the ground is held level with
-- it (sideGround): the street's own border, so the bank starts beyond it
-- [guess: 0.5m clears the border texture; e2e pictures].
M.GROUND_PAD = 0.5

-- Terrain faces holding the ground at a side street's height under its
-- whole width, from the coping's outer edge (its inner edge, GAP 0; beside
-- the portal cover from the cover's terrain edge, see below) to
-- GROUND_PAD past its outer edge, flat across as the street is, between
-- the x's of its nodes (xs[0..n]) at their heights (zs). Why: the
-- body's shoulders hold the ground only out to shoulderOut (5.6m past the
-- wall's centre with the thin wall), short of a 6.5m side street's outer
-- edge, and the side streets align no terrain of their own (alignTerrain
-- false), so their outer part lay on whatever ground was there and the
-- bank down from the shoulders ran under them [source: ramp_geometry
-- shoulders, sideEdge]. Counter-clockwise from above, as the body's.
local function sideGround(lay, g, ySign, xs, zs, n)
	local b = lay.y + lay.side.width * 0.5 + M.GROUND_PAD
	-- Beside the portal cover the body's LESS face (the cover's) reaches
	-- 0.25m past the coping's line (out to lidEdge), and its shoulders
	-- start there: these faces start there too, so no two lists hold the
	-- same ground at two heights (with GAP 0 an EQUAL face from copingOut
	-- met the cover's LESS one 0.55m lower; review, 2026-11-24). The street's
	-- inner 0.25m then lies over the cover's cut there [guess: unseen from
	-- above; e2e pictures].
	local coverA, coverB = g.portalX - 6.25, g.portalX + 30.25
	local cuts = {}
	for i = 0, n do cuts[#cuts + 1] = { x = xs[i], z = zs[i] } end
	for _, xc in ipairs({ coverA, coverB }) do
		for i = 0, n - 1 do
			if xc > xs[i] + 1e-9 and xc < xs[i + 1] - 1e-9 then
				local t = (xc - xs[i]) / (xs[i + 1] - xs[i])
				cuts[#cuts + 1] = { x = xc, z = zs[i] + (zs[i + 1] - zs[i]) * t }
			end
		end
	end
	table.sort(cuts, function(p, q) return p.x < q.x end)
	local faces = {}
	for k = 1, #cuts - 1 do
		local xa, xb, za, zb = cuts[k].x, cuts[k + 1].x, cuts[k].z, cuts[k + 1].z
		local xm = (xa + xb) * 0.5
		local a = (xm > coverA and xm < coverB) and g.lidEdge or g.copingOut
		if ySign > 0 then
			faces[#faces + 1] = { { xa, a, za }, { xb, a, zb }, { xb, b, zb }, { xa, b, za } }
		else
			faces[#faces + 1] = { { xa, -b, za }, { xb, -b, zb }, { xb, -a, zb }, { xa, -a, za } }
		end
	end
	return faces
end
M.sideGround = sideGround

-- The construction result: the centre's body, and the two side streets.
function M.build(spec, p)
	local r, g = geometry.build(spec)
	local lay = M.layout(spec, p)
	local x0, x1 = lay.x0, lay.x1
	local ground = {}
	for _, ySign in ipairs({ -1, 1 }) do
		local y = ySign * lay.y
		local yIn = ySign * (lay.y - lay.side.width * 0.5)
		-- On the ground plane, which the walls and lid follow: a side
		-- street level with the snap point would float or sink by metres
		-- at its far end on a stated slope. Where the banks beside the
		-- trench rise over the plane (downhill: kept at the road near the
		-- mouth, lifted with the lid when the ramp cannot get under), the
		-- plane would bury the street's inner edge in them by metres
		-- (review, 2026-11-24): there the street follows the banks' height
		-- at its inner edge, in pieces of at most PIECE.
		local n = math.max(1, math.ceil((x1 - x0) / M.PIECE))
		local xs, zs, follow = {}, {}, false
		for i = 0, n do
			local x = x0 + (x1 - x0) * i / n
			xs[i], zs[i] = x, math.max(g.ground(x, y), bankZ(g, x, yIn))
			if zs[i] - g.ground(x, y) > 1e-9 then follow = true end
		end
		if not follow then
			-- one straight edge on the plane (along x only)
			local za, zb = g.ground(x0, y), g.ground(x1, y)
			local dx, dz = x1 - x0, zb - za
			sideEdge(r, lay, { { x0, y, za }, { dx, 0, dz } }, { { x1, y, zb }, { dx, 0, dz } }, lay.toward[ySign])
			-- (the ground in PIECE-long faces along the same straight line:
			-- za..zb is linear in x, so their heights are the edge's)
			for _, f in ipairs(sideGround(lay, g, ySign, xs, (function()
				local t = {}
				for i = 0, n do t[i] = za + dz * (xs[i] - x0) / dx end
				return t
			end)(), n)) do ground[#ground + 1] = f end
		else
			for _, f in ipairs(sideGround(lay, g, ySign, xs, zs, n)) do ground[#ground + 1] = f end
			-- each node's tangent from the banks' own slope there, so the
			-- pieces meet with one tangent and bend with the descent's
			-- banks between nodes (a slope from the chords left the curve
			-- half a metre under them, tests); at a kink (the trench start,
			-- the lid's edges) the gentler side's, 0 where they slope
			-- opposite ways
			local function h(x) return math.max(g.ground(x, y), bankZ(g, x, yIn)) end
			local e = 0.01
			local slope = {}
			for i = 0, n do
				local x = xs[i]
				local dl, dr = (h(x) - h(x - e)) / e, (h(x + e) - h(x)) / e
				if math.abs(dl - dr) < 1e-3 then slope[i] = (dl + dr) * 0.5
				elseif dl * dr <= 0 then slope[i] = 0
				elseif math.abs(dl) < math.abs(dr) then slope[i] = dl
				else slope[i] = dr end
			end
			for i = 0, n - 1 do
				local dx = xs[i + 1] - xs[i]
				sideEdge(r, lay,
					{ { xs[i], y, zs[i] }, { dx, 0, slope[i] * dx } },
					{ { xs[i + 1], y, zs[i + 1] }, { dx, 0, slope[i + 1] * dx } },
					lay.toward[ySign])
			end
		end
	end
	-- After the body's lists, so the side streets' ground is the last word
	-- where it meets the shoulders' faces [guess: a later list wins where
	-- faces overlap; on level ground both are at the same height].
	local lists = r.subconstructions[1].terrainAlignmentLists
	lists[#lists + 1] = { type = "EQUAL", faces = ground, slopeLow = 0.45, slopeHigh = 1, optional = true }
	return r, lay
end

return M
