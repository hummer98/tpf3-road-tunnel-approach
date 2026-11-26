-- Offline tests for road_tunnel_ramp. Run:
--   luajit tests/run.lua
-- No game needed: data() is the engine's entry, so we execute the chunk
-- and then call it to get the updateFn.

local root = (arg and arg[0] or "tests/run.lua"):match("^(.*)/tests/[^/]*$") or "."

local failures, passes = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passes = passes + 1
		print("PASS " .. name)
	else
		failures = failures + 1
		print("FAIL " .. name .. "\n     " .. tostring(err))
	end
end
local function eq(a, b, msg)
	if a ~= b then error((msg or "values differ") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end
end
local function near(a, b, tol, msg)
	tol = tol or 1e-6
	if math.abs(a - b) > tol then
		error((msg or "not within tol") .. ": " .. tostring(a) .. " vs " .. tostring(b) .. " (tol " .. tol .. ")", 2)
	end
end

------------------------------------------------------------------------
-- Load the script chunk. The engine ignores the chunk return value and
-- calls the global data(); we do the same.
------------------------------------------------------------------------
_ = function(s) return s end
api = nil  -- the script must cope with api not being populated offline

-- The game's require takes "<modId>::/<path under content/>" (vanilla
-- depot construction scripts: require "::/scripts/construction/constructionutil.lua").
-- Offline, this mod's own names are read from content/ and kept like
-- package.loaded; any other name goes to luajit's require.
local luaRequire = require
local modLoaded = {}
require = function(name)
	local rel = type(name) == "string" and name:match("^road_tunnel_ramp::/(.+)$")
	if not rel then return luaRequire(name) end
	if modLoaded[rel] == nil then
		modLoaded[rel] = assert(loadfile(root .. "/content/" .. rel))()
	end
	return modLoaded[rel]
end

data = false
local scriptChunkResult = assert(loadfile(root .. "/content/road_tunnel_ramp/ramp.script.lua"))()
test("script: data() is a global function; the chunk returns nothing", function()
	assert(type(data) == "function", "data() must be a global function")
	assert(scriptChunkResult == nil, "chunk should not also return a table")
end)
if type(data) ~= "function" then
	print("\n" .. passes .. " passed, " .. failures .. " failed (aborted: data() missing)")
	os.exit(1)
end

local script = data()
test("script: exports updateFn", function()
	assert(type(script.updateFn) == "function", "updateFn missing")
end)

-- 1.0.0's portal cover, 36m long, which the menu no longer offers
-- (rtr_cover_length is LID_MIN-24m, above it reads as 18m): fn runs with every
-- spec read by ramp_geometry.spec (the ramp's, the median's, the tests'
-- own calls) given lidLength 36, so the frozen builds before the option can
-- still be compared bit for bit through the real scripts.
local rampGeo = require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua"
local function lid36(fn)
	return function(...)
		local spec = rampGeo.spec
		rampGeo.spec = function(...)
			local s = spec(...)
			s.lidLength = 36
			return s
		end
		local ok, err = pcall(fn, ...)
		rampGeo.spec = spec
		if not ok then error(err, 0) end
	end
end

-- Take the captured params straight from con.lua so the tests can't
-- drift from the street list the game actually passes in.
local function defaultCap()
	local saved = data
	data = false
	assert(loadfile(root .. "/content/road_tunnel_ramp/ramp.con.lua"))()
	local cap = data().updateScript.params
	data = saved
	return cap
end
local function defaultParams(overrides)
	local p = { rtr_length = 100, rtr_depth = 16 }
	for k, v in pairs(overrides or {}) do p[k] = v end
	return p
end
-- The same params with the flat approach kept in the construction
-- (rtr_approach_hand_over 0), the layout every frozen "before" script
-- builds: the comparisons with them hold everything else to one bit.
local function kept(p)
	local q = {}
	for k, v in pairs(p or {}) do q[k] = v end
	q.rtr_approach_hand_over = 0
	return q
end

-- Since 2026-11-24 a wall piece is a stack of boxes (wall_<side>_<i>_<k>,
-- k = 1..n bottom up, ramp_geometry.stackCount) and the portal cover a grid
-- of pieces (portal_top_cover_<i>_<j>, i along, j across), so the mod's own
-- boxes keep their texture scale. oneBox(r) is a copy of a result with each
-- stack and the grid written back as the one box they replace (tag without
-- the piece numbers, the first piece's transf, the heights added up; for
-- the cover the x extents of the first row across and the y extents of the
-- first column along added up, and the centre of that column as the
-- position), the form every test written before then reads. The pieces
-- themselves are checked in "stack:" and "cover pieces:".
local function copyTable(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = copyTable(v) end
	return out
end
local function oneBoxModels(models)
	local out, merged = {}, {}
	local cover
	for _, m in ipairs(models) do
		local tag = type(m.tag) == "string" and m.tag or ""
		local base = tag:match("^(.*wall_%-?%d+_%d+)_%d+$")
		local last = out[#out]
		if base and last and last.tag == base and merged[last] then
			last.transf[11] = last.transf[11] + m.transf[11]
		elseif base then
			local c = copyTable(m)
			c.tag = base
			out[#out + 1] = c
			merged[c] = true
		elseif tag:match("^portal_top_cover_%d+_%d+$") then
			local i, j = tag:match("_(%d+)_(%d+)$")
			i, j = tonumber(i), tonumber(j)
			if not cover then
				cover = copyTable(m)
				cover.tag = "portal_top_cover"
				cover.across = {}
				out[#out + 1] = cover
				merged[cover] = true
			end
			if j == 1 and i > 1 then
				for k = 1, 3 do cover.transf[k] = cover.transf[k] + m.transf[k] end
			end
			if i == 1 then cover.across[#cover.across + 1] = m.transf end
		else
			out[#out + 1] = copyTable(m)
		end
	end
	if cover then
		-- the y column is the widths added up; the position the middle of
		-- the column's two end pieces (their centres are symmetric about the
		-- slab's); one piece: that piece's own numbers, untouched
		local a = cover.across
		if #a > 1 then
			for k = 5, 7 do
				local sum = a[1][k]
				for n = 2, #a do sum = sum + a[n][k] end
				cover.transf[k] = sum
			end
			for k = 13, 15 do cover.transf[k] = (a[1][k] + a[#a][k]) * 0.5 end
		end
		cover.across = nil
	end
	return out, merged
end
-- old: a result built before the pieces; a summed number within 1e-9 of its
-- value there is taken as that value (pieces add up to the box only to the
-- last bits), so the comparisons with frozen builds stay exact elsewhere.
local function oneBox(r, old)
	if type(r) ~= "table" or type(r.subconstructions) ~= "table" then return r end
	local out = copyTable(r)
	for si, sub in ipairs(out.subconstructions) do
		if type(sub.models) == "table" then
			local models, merged = oneBoxModels(sub.models)
			local om = old and old.subconstructions and old.subconstructions[si]
				and old.subconstructions[si].models
			if om then
				for i, m in ipairs(models) do
					local o = om[i]
					if merged[m] and o and o.tag == m.tag then
						for k = 1, 16 do
							local a, b = m.transf[k], o.transf[k]
							if type(a) == "number" and type(b) == "number" and a ~= b
								and math.abs(a - b) <= 1e-9 * math.max(1, math.abs(b)) then
								m.transf[k] = b
							end
						end
					end
				end
			end
			sub.models = models
		end
	end
	return out
end

-- The builds frozen before the mod's own box (tests/fixtures/) place the old
-- walls/concrete.mdl (since 2026-11-24 no longer placed: the borrowed
-- mesh and material were replaced by the mod's own box; the file stays by
-- name only, for old saves' model tables) for every piece;
-- the part models (walls/wall.mdl, slab.mdl for the cover, strip.mdl for
-- the coping and parapet) now stand where it stood. asBefore(r, old) is
-- oneBox(r, old) with those ids written back, so the "builds what it did
-- before" tests keep comparing every other bit of the shape. Any other
-- model is left as it is (and then differs).
local OLD_WALL_MODEL = "road_tunnel_ramp::/road_tunnel_ramp/walls/concrete.mdl"
local DEFAULT_WALL_MODEL = "road_tunnel_ramp::/road_tunnel_ramp/walls/wall.mdl"
local DEFAULT_PART_MODELS = {
	[DEFAULT_WALL_MODEL] = true,
	["road_tunnel_ramp::/road_tunnel_ramp/walls/slab.mdl"] = true,
	["road_tunnel_ramp::/road_tunnel_ramp/walls/strip.mdl"] = true,
}
local function oldId(r)
	if type(r) ~= "table" then return r end
	local out = {}
	for k, v in pairs(r) do
		if k == "id" and DEFAULT_PART_MODELS[v] then out[k] = OLD_WALL_MODEL
		else out[k] = oldId(v) end
	end
	return out
end
local function asBefore(r, old)
	return oldId(oneBox(r, old))
end

------------------------------------------------------------------------
-- Shape of the result
------------------------------------------------------------------------
test("updateFn: returns a construction result with edges, cost, snap and a non-empty subconstruction", function()
	local r = script.updateFn(defaultCap(), defaultParams())
	assert(type(r) == "table", "result must be a table")
	assert(#r.edgeLists > 0, "must emit at least one edge list")
	assert(r.cost and r.cost > 0, "cost must be positive")
	assert(r.bulldozeCost and r.bulldozeCost > 0, "bulldoze cost must be positive")
	assert(r.maintenanceCost and r.maintenanceCost >= 0, "maintenance must be non-negative")
	assert(r.snapPoint, "a snap point is required so the player can connect existing roads")
	-- The engine refuses "Empty Subconstruction" when the subcon has no
	-- fat/thin instance, runway, lot or edge of its own; walls populate
	-- thinInstances via sub.models, so one subconstruction is enough.
	eq(#r.subconstructions, 1, "one subconstruction carries the walls, coping, cover and terrain")
	assert(#r.subconstructions[1].models > 0, "subconstruction must carry at least one model so it is not 'empty'")
end)

------------------------------------------------------------------------
-- Every edge list is a STREET and references the captured template
------------------------------------------------------------------------
test("edges: all edges are type STREET and use the selected template; none align terrain (subcon does)", function()
	local cap = defaultCap()
	local r = script.updateFn(cap, defaultParams())
	-- defaultParams omits rtr_street, so the script falls back to idx 3
	-- (town_new_small) — the same template as before Step B.
	local expectedRef = cap.streets[3].ref
	for i, e in ipairs(r.edgeLists) do
		eq(e.type, "STREET", "edge " .. i .. " type")
		eq(e.params.type, expectedRef, "edge " .. i .. " template")
		eq(e.alignTerrain, false, "edge " .. i .. " must not align terrain in Phase 2 (subcon owns it)")
	end
end)

test("edges: selecting a different street index swaps every edge's template", function()
	local cap = defaultCap()
	-- Pick the widest option (town_new_large = 32m) so the template
	-- change is unambiguous and simultaneously forces a wider geometry.
	local r = script.updateFn(cap, defaultParams({ rtr_street = 7 }))
	local expectedRef = cap.streets[7].ref
	for i, e in ipairs(r.edgeLists) do
		eq(e.params.type, expectedRef, "edge " .. i .. " template must follow rtr_street")
	end
end)

------------------------------------------------------------------------
-- Parallel streets (Step C)
------------------------------------------------------------------------

test("count: single street (default) matches the legacy single-lane layout exactly", function()
	-- When rtr_count is omitted, the script falls back to 1 and keeps
	-- ys = {0}; every edge must sit on y = 0, exactly the layout tests
	-- in this file predate Step C.
	local r = script.updateFn(defaultCap(), defaultParams())
	for i, e in ipairs(r.edgeLists) do
		eq(e.edges[1][1][2], 0, "edge " .. i .. " start y must be 0 for count=1")
		eq(e.edges[2][1][2], 0, "edge " .. i .. " end y must be 0 for count=1")
	end
end)

test("count: raising to 2 doubles the edge count and lays streets at ±(width+gap)/2", function()
	-- town_new_small (16m) + 2m gap = 18m pitch → ys = {-9, +9}.
	local single = script.updateFn(defaultCap(), defaultParams({ rtr_count = 1 }))
	local double = script.updateFn(defaultCap(), defaultParams({ rtr_count = 2 }))
	eq(#double.edgeLists, 2 * #single.edgeLists, "count=2 must produce twice as many edges")
	local ySeen = {}
	for _, e in ipairs(double.edgeLists) do
		ySeen[e.edges[1][1][2]] = (ySeen[e.edges[1][1][2]] or 0) + 1
	end
	assert(ySeen[-9] and ySeen[9], "count=2 must place streets at y=-9 and y=+9")
	eq(ySeen[-9], #single.edgeLists, "the -y street must carry half of the edges")
	eq(ySeen[9], #single.edgeLists, "the +y street must carry the other half")
end)

test("count: triple lays streets at {-pitch, 0, +pitch}", function()
	-- Three parallel town_new_small streets: pitch = 18m → ys = {-18, 0, +18}.
	local r = script.updateFn(defaultCap(), defaultParams({ rtr_count = 3 }))
	local ySeen = {}
	for _, e in ipairs(r.edgeLists) do
		ySeen[e.edges[1][1][2]] = true
	end
	assert(ySeen[-18] and ySeen[0] and ySeen[18], "count=3 must place streets at y=-18, 0, +18")
end)

test("count: only the first street exposes the external snap node", function()
	-- The external connection point (approach start at x=-approach)
	-- should snap on exactly one lane, otherwise the cursor jumps
	-- between lanes while placing.
	local r = script.updateFn(defaultCap(), defaultParams({ rtr_count = 2 }))
	local approachesWithSnap = 0
	for _, e in ipairs(r.edgeLists) do
		if e.edges[1][1][1] == -20 and e.edges[2][1][1] == 0 then
			if #e.snapNodes > 0 then approachesWithSnap = approachesWithSnap + 1 end
		end
	end
	eq(approachesWithSnap, 1, "exactly one approach edge must carry the external snap")
	-- The snap point itself must sit at ys[1] = -9 (the first street).
	local t = r.snapPoint.transf
	eq(t[13], -20, "snap transf tx = -approach")
	eq(t[14], -9, "snap transf ty = ys[1] = -(pitch/2)")
end)

test("count: kept approach (hand-over 0): ys[2..] expose their approach start as a free node, ys[1] does not", function()
	-- Dangling node preventive measure: an unsnapped approach start
	-- must be marked as a free node so the engine accepts the open
	-- endpoint instead of treating it as a floating node.
	local r = script.updateFn(defaultCap(), kept(defaultParams({ rtr_count = 3 })))
	local approachesSeen = {}
	for _, e in ipairs(r.edgeLists) do
		if e.edges[1][1][1] == -20 and e.edges[2][1][1] == 0 then
			local y = e.edges[1][1][2]
			approachesSeen[y] = { snaps = e.snapNodes, frees = e.freeNodes }
		end
	end
	eq(approachesSeen[-18].snaps[1], 0, "ys[1] approach must snap at node 0 (external connection)")
	eq(#approachesSeen[-18].frees, 0, "ys[1] approach must NOT mark node 0 as free (it is snapped)")
	eq(approachesSeen[0].frees[1], 0, "ys[2] approach must mark node 0 as free")
	eq(#approachesSeen[0].snaps, 0, "ys[2] approach must NOT snap")
	eq(approachesSeen[18].frees[1], 0, "ys[3] approach must mark node 0 as free")
	eq(#approachesSeen[18].snaps, 0, "ys[3] approach must NOT snap")
end)

test("count: cost scales linearly with the parallel count (ramp part only, depth stays fixed)", function()
	-- The formula is (L + approach + runout) * 300 * count + D * 2000,
	-- so cost(count=N) - cost(count=1) == (L+approach+runout) * 300 * (N-1).
	-- Nail this invariant in so flipping the formula to e.g. cost * count
	-- (double-charging the depth) triggers an immediate failure.
	local c1 = script.updateFn(defaultCap(), defaultParams({ rtr_count = 1 })).cost
	local c2 = script.updateFn(defaultCap(), defaultParams({ rtr_count = 2 })).cost
	local c3 = script.updateFn(defaultCap(), defaultParams({ rtr_count = 3 })).cost
	local step = (100 + 20 + 30) * 300  -- L + approach + runout, × 300/lane
	eq(c2 - c1, step, "count 1→2 must add exactly one lane's worth of ramp cost")
	eq(c3 - c1, 2 * step, "count 1→3 must add two lanes' worth of ramp cost")
end)

test("count: portal top cover width tracks halfSpread + halfWidth + 1 + 2.4", function()
	-- The cover slab's y-width is 2 * roofHalf where roofHalf = outer + 2.4
	-- (the coping's outer edge, 2026-11-23; outer + 4 before)
	-- = halfSpread + halfWidth + 3.4. The width is baked into transf[6]
	-- as (2 * roofHalf) / 0.45. Pin that so a future refactor that
	-- forgets to widen the cover for count>1 trips immediately.
	local cap = defaultCap()
	local function coverWidth(cnt)
		local r = oneBox(script.updateFn(cap, defaultParams({ rtr_count = cnt })))
		for _, m in ipairs(r.subconstructions[1].models) do
			if m.tag == "portal_top_cover" then return m.transf[6] * 0.45 end
		end
		error("portal_top_cover missing for count=" .. cnt)
	end
	-- town_new_small: halfWidth=8, pitch=18.
	-- count=1 → halfSpread=0 → roofHalf=11.4 → width=22.8
	-- count=2 → halfSpread=9 → roofHalf=20.4 → width=40.8
	-- count=3 → halfSpread=18 → roofHalf=29.4 → width=58.8
	near(coverWidth(1), 22.8, 1e-6, "count=1 portal cover width must be 22.8m")
	near(coverWidth(2), 40.8, 1e-6, "count=2 portal cover width must widen to 40.8m")
	near(coverWidth(3), 58.8, 1e-6, "count=3 portal cover width must widen to 58.8m")
end)

test("count: walls stretch out to halfSpread + halfWidth + 1 on both sides", function()
	-- With town_new_small (halfWidth=8) and pitch=18, count=2 gives
	-- halfSpread=9, so outer = 18 and walls sit at y = ±18.
	local cap = defaultCap()
	for _, case in ipairs({ { 1, 9 }, { 2, 18 }, { 3, 27 } }) do
		local cnt, expectedY = case[1], case[2]
		local r = script.updateFn(cap, defaultParams({ rtr_count = cnt }))
		local sub = r.subconstructions[1]
		local wallSeen = {}
		for _, m in ipairs(sub.models) do
			if m.tag:match("^wall_") then wallSeen[m.transf[14]] = true end
		end
		assert(wallSeen[expectedY], string.format("count=%d must place walls at y=%d", cnt, expectedY))
		assert(wallSeen[-expectedY], string.format("count=%d must place walls at y=-%d", cnt, expectedY))
	end
end)

test("walls: outer offset follows the selected street's half-width for every entry", function()
	local cap = defaultCap()
	-- Cover all six captured streets so a wrong width in any single
	-- entry is caught immediately (half-width + 1.0 clearance).
	local cases = {}
	for i, s in ipairs(cap.streets) do
		cases[#cases + 1] = { i, s.width * 0.5 + 1.0 }
	end
	for _, case in ipairs(cases) do
		local idx, expectedY = case[1], case[2]
		local r = script.updateFn(cap, defaultParams({ rtr_street = idx }))
		local sub = r.subconstructions[1]
		local wallSeen = {}
		for _, m in ipairs(sub.models) do
			if m.tag:match("^wall_") then
				local y = m.transf[14]  -- ty
				wallSeen[y] = true
			end
		end
		assert(wallSeen[expectedY], string.format("idx %d (width %.1fm) must place walls at y=%.1f",
			idx, cap.streets[idx].width, expectedY))
		assert(wallSeen[-expectedY], string.format("idx %d must also place walls at y=-%.1f", idx, expectedY))
	end
end)

------------------------------------------------------------------------
-- The approach segment is flat; the tunnel segments reference the tunnel
-- resource; the endpoints are at the expected elevations.
------------------------------------------------------------------------
test("edges: the approach is flat at z=0 and snaps at its start", function()
	local r = script.updateFn(defaultCap(), defaultParams())
	local approach = r.edgeLists[1]
	eq(approach.edgeType, nil, "approach is a surface edge, not a tunnel")
	eq(approach.edges[1][1][3], 0, "approach start z")
	eq(approach.edges[2][1][3], 0, "approach end z")
	-- snap at index 0: the engine accepts this as the external connection
	local hasZero = false
	for _, s in ipairs(approach.snapNodes) do if s == 0 then hasZero = true end end
	assert(hasZero, "approach must expose snap at index 0")
end)

test("edges: ramp descends from z=0 to z=-D and transitions to a tunnel", function()
	local cap = defaultCap()
	local p = defaultParams()
	local r = script.updateFn(cap, p)
	-- Find all tunnel edges and ensure they all use edgeTypeName == tunnelRef
	local sawSurfaceDescent, sawTunnelDescent, lastZ = false, false, 0
	for _, e in ipairs(r.edgeLists) do
		if e.edgeType == "TUNNEL" then
			eq(e.edgeTypeName, cap.tunnelRef, "tunnel edges must reference the car tunnel resource")
		end
		local za = e.edges[1][1][3]
		local zb = e.edges[2][1][3]
		if zb < za then
			if e.edgeType == "TUNNEL" then sawTunnelDescent = true
			else sawSurfaceDescent = true end
		end
		lastZ = zb
	end
	assert(sawSurfaceDescent, "there must be at least one descending surface edge (the open ramp)")
	assert(sawTunnelDescent, "there must be at least one descending tunnel edge (under the portal)")
	-- The very last edge is the deepest point of the runout.
	near(lastZ, -math.max(p.rtr_depth, cap.tunnelHeight + 2), 1e-6, "runout terminates at full depth")
end)

test("edges: runout extends exactly `runout` metres past L and snaps at its far end", function()
	local r = script.updateFn(defaultCap(), defaultParams())
	-- Scan for the final edge at the deepest level and verify its end x
	local last = r.edgeLists[#r.edgeLists]
	-- The last edge should be the runout terminator with snap at index 1.
	local hasOne = false
	for _, s in ipairs(last.snapNodes) do if s == 1 then hasOne = true end end
	assert(hasOne, "last edge must expose snap at index 1 (underground connection point)")
	near(last.edges[2][1][1], 100 + 30, 1e-6, "runout ends at L + runout")
end)

------------------------------------------------------------------------
-- Coincident nodes between edges, so the engine merges them: each edge's
-- end must coincide with the next edge's start (same x, y, z).
------------------------------------------------------------------------
test("edges: successive edges share endpoints exactly (engine merges by coord)", function()
	local r = script.updateFn(defaultCap(), defaultParams())
	for i = 1, #r.edgeLists - 1 do
		local cur = r.edgeLists[i].edges[2][1]
		local nxt = r.edgeLists[i + 1].edges[1][1]
		near(cur[1], nxt[1], 1e-6, "x mismatch between edge " .. i .. " and " .. (i + 1))
		near(cur[2], nxt[2], 1e-6, "y mismatch between edge " .. i .. " and " .. (i + 1))
		near(cur[3], nxt[3], 1e-6, "z mismatch between edge " .. i .. " and " .. (i + 1))
	end
end)

------------------------------------------------------------------------
-- Length and depth params actually feed through
------------------------------------------------------------------------
test("params: length controls where the runout starts", function()
	for _, L in ipairs({ 40, 42, 60, 98, 100 }) do
		local r = script.updateFn(defaultCap(), defaultParams({ rtr_length = L }))
		-- The last edge ends at L + runout (runout = 30 hardcoded).
		near(r.edgeLists[#r.edgeLists].edges[2][1][1], L + 30, 1e-6, "runout end for L=" .. L)
	end
end)

test("params: depth controls the floor elevation of the tunnel", function()
	-- The requested depth must be at least tunnelHeight + 2 = 12.55m, so
	-- a tiny depth is clamped upward silently; deeper requests pass through.
	local shallow = script.updateFn(defaultCap(), defaultParams({ rtr_depth = 10 }))
	near(shallow.edgeLists[#shallow.edgeLists].edges[2][1][3], -12.55, 1e-6, "shallow depth is clamped to tunnelHeight+2")
	local deep = script.updateFn(defaultCap(), defaultParams({ rtr_depth = 25 }))
	near(deep.edgeLists[#deep.edgeLists].edges[2][1][3], -25, 1e-6, "deep depth passes through")
end)

test("params: short ramps (40-80m) stay continuous for every curvature and depth", function()
	-- The UI now offers 40m; nothing in the geometry may assume L >= 100.
	for _, L in ipairs({ 40, 60, 80 }) do
		for c = 1, 5 do
			for _, D in ipairs({ 12, 25 }) do
				local r = oneBox(script.updateFn(defaultCap(), defaultParams({ rtr_length = L, rtr_depth = D, rtr_curvature = c })))
				local tag = string.format("L=%d c=%d D=%d", L, c, D)
				local es = r.edgeLists
				local wantD = math.max(D, 12.55)
				near(es[#es].edges[2][1][1], L + 30, 1e-6, tag .. " runout end x")
				near(es[#es].edges[2][1][3], -wantD, 1e-6, tag .. " runout end z")
				for i = 2, #es do
					local prev, cur = es[i - 1].edges[2][1], es[i].edges[1][1]
					near(cur[1], prev[1], 1e-6, tag .. " edge " .. i .. " x continuity")
					near(cur[3], prev[3], 1e-6, tag .. " edge " .. i .. " z continuity")
					assert(es[i].edges[2][1][1] > cur[1], tag .. " edge " .. i .. " runs forward")
				end
				-- Walls cover 0..portal only; their far end must lie inside the ramp.
				local maxWallX = 0
				for _, m in ipairs(r.subconstructions[1].models) do
					if m.tag and m.tag:match("^wall_") then
						maxWallX = math.max(maxWallX, m.transf[13] + m.transf[1])
					end
				end
				assert(maxWallX > 0 and maxWallX <= L + 1e-6, tag .. " walls end inside the ramp (" .. maxWallX .. ")")
				-- The portal cover reaches past L on short ramps but must
				-- stay over the construction's own runout.
				local coverEnd
				for _, m in ipairs(r.subconstructions[1].models) do
					if m.tag == "portal_top_cover" then coverEnd = m.transf[13] + m.transf[1] end
				end
				assert(coverEnd and coverEnd <= L + 30 + 1e-6, tag .. " portal cover ends within the runout")
			end
		end
	end
end)

test("edges: no sliver edges where the portal lands near a regular split", function()
	-- Regression: splits were deduplicated only within 1e-7 in t, leaving
	-- edges down to 0.07m (L=40, c=5, D=16) and 0.35m at the old 200m default.
	local worst, where = math.huge, ""
	for L = 40, 100, 2 do
		for c = 1, 5 do
			for D = 13, 25 do
				local r = script.updateFn(defaultCap(), defaultParams({ rtr_length = L, rtr_depth = D, rtr_curvature = c }))
				for _, e in ipairs(r.edgeLists) do
					local len = math.abs(e.edges[2][1][1] - e.edges[1][1][1])
					if len < worst then worst, where = len, string.format("L=%d c=%d D=%d", L, c, D) end
				end
			end
		end
	end
	assert(worst >= 2 - 1e-6, string.format("shortest edge %.3fm at %s", worst, where))
end)

test("params: approach length moves the snap point and the approach start", function()
	for _, A in ipairs({ 2, 20, 36, 50 }) do
		local r = script.updateFn(defaultCap(), defaultParams({ rtr_approach = A }))
		local first = r.edgeLists[1]
		near(first.edges[1][1][1], -A, 1e-6, "approach starts at -A for A=" .. A)
		near(first.edges[2][1][1], 0, 1e-6, "approach ends at the ramp start for A=" .. A)
		near(first.edges[1][2][1], A, 1e-6, "approach tangent length = A for A=" .. A)
		near(r.snapPoint.transf[13], -A, 1e-6, "snap point at -A for A=" .. A)
	end
	local lo = script.updateFn(defaultCap(), defaultParams({ rtr_approach = 0 }))
	near(lo.edgeLists[1].edges[1][1][1], -2, 1e-6, "approach clamped to min 2m (no zero-length edge)")
	local hi = script.updateFn(defaultCap(), defaultParams({ rtr_approach = 999 }))
	near(hi.edgeLists[1].edges[1][1][1], -50, 1e-6, "approach clamped to max 50m")
	local none = script.updateFn(defaultCap(), { rtr_depth = 16 })
	near(none.edgeLists[1].edges[1][1][1], -20, 1e-6, "missing approach uses the 20m default")
end)

test("params: out-of-range values are clamped, nil falls back to the default", function()
	local huge = script.updateFn(defaultCap(), defaultParams({ rtr_length = 10000 }))
	near(huge.edgeLists[#huge.edgeLists].edges[2][1][1], 400 + 30, 1e-6, "length clamped to max 400m")
	-- Regression: ramps placed with the old 150-400m options must keep
	-- their length on rebuild even though the UI now stops at 100m.
	local old = script.updateFn(defaultCap(), defaultParams({ rtr_length = 200 }))
	near(old.edgeLists[#old.edgeLists].edges[2][1][1], 200 + 30, 1e-6, "saved 200m ramp keeps its length")
	local tiny = script.updateFn(defaultCap(), defaultParams({ rtr_length = 10 }))
	near(tiny.edgeLists[#tiny.edgeLists].edges[2][1][1], 40 + 30, 1e-6, "length clamped to min 40m")
	local default = script.updateFn(defaultCap(), { rtr_depth = 16 })  -- length missing
	near(default.edgeLists[#default.edgeLists].edges[2][1][1], 100 + 30, 1e-6, "missing length uses the 100m default")
end)

------------------------------------------------------------------------
-- Vertical profile curvature (Step A)
------------------------------------------------------------------------

-- Scan every ramp edge for a node whose x matches the sample within the
-- tolerance; return its z. We cannot directly call the internal profile
-- function, so we drive it indirectly through the generated edge list.
local function zAtX(r, x, tol)
	tol = tol or 0.5
	for _, e in ipairs(r.edgeLists) do
		for _, side in ipairs(e.edges) do
			if math.abs(side[1][1] - x) < tol then
				return side[1][3]
			end
		end
	end
	return nil
end

test("curvature: omitted parameter falls back to cubic easing (the legacy profile)", function()
	-- Without rtr_curvature, defaultParams gives idx 3 (cubic), and z at
	-- x = L/4 must equal -D * (3*(1/4)^2 - 2*(1/4)^3) = -D * 5/32.
	local r = script.updateFn(defaultCap(), defaultParams())
	local expected = -16 * (3 * 0.25 * 0.25 - 2 * 0.25 * 0.25 * 0.25)  -- = -2.5
	near(zAtX(r, 25), expected, 1e-6, "default curvature must match the legacy cubic easing exactly")
end)

test("curvature: lower indices flatten the slope, higher indices concentrate the descent", function()
	-- At t = 0.25 the five profiles give monotonically shallower |z|:
	-- idx1 ≈ -3.25 (closest to linear), idx3 = -2.5 (cubic), idx5 ≈ -1.67
	-- (quintic). The engine samples t = 0.25 exactly because segments
	-- defaults to 8 for L = 100.
	local function zq(i)
		return zAtX(script.updateFn(defaultCap(), defaultParams({ rtr_curvature = i })), 25)
	end
	local z1, z2, z3, z4, z5 = zq(1), zq(2), zq(3), zq(4), zq(5)
	assert(z1 and z2 and z3 and z4 and z5, "all curvatures must sample x = 25")
	assert(z1 < z2, string.format("idx1 (%.3f) must sit deeper than idx2 (%.3f) at x=L/4", z1, z2))
	assert(z2 < z3, string.format("idx2 (%.3f) must sit deeper than idx3 (%.3f) at x=L/4", z2, z3))
	assert(z3 < z4, string.format("idx3 (%.3f) must sit deeper than idx4 (%.3f) at x=L/4", z3, z4))
	assert(z4 < z5, string.format("idx4 (%.3f) must sit deeper than idx5 (%.3f) at x=L/4", z4, z5))
end)

test("curvature: all indices still hit z = 0 at the portal start and z = -D at the runout", function()
	-- No matter how we bend the middle, the entry (x=0) must stay flush
	-- with the ground, the ramp itself must reach full depth at x=L (so
	-- the runout joins the tunnel floor without a step), and the runout
	-- terminator must still land at -D. Checking all three locks down
	-- f(0)=0 and f(1)=1 against any future blend-table mistake.
	for i = 1, 5 do
		local r = script.updateFn(defaultCap(), defaultParams({ rtr_curvature = i }))
		near(zAtX(r, 0), 0, 1e-6, "idx " .. i .. ": ramp must start at z=0")
		near(zAtX(r, 100), -16, 1e-6, "idx " .. i .. ": ramp itself must reach -D at x=L")
		local last = r.edgeLists[#r.edgeLists]
		near(last.edges[2][1][3], -16, 1e-6, "idx " .. i .. ": runout terminates at -D")
	end
end)

test("curvature: idx 1/2 introduce an end-slope step on BOTH ends (linear mix), idx 3/4/5 stay flat", function()
	-- For blends that include the linear term, the ramp starts (x=0)
	-- AND ends (x=L) with a non-zero z tangent — the gradient steps the
	-- tooltip warns about. Checking both ends catches any asymmetry a
	-- future blend-table edit might introduce. Idx 3-5 are pure
	-- smoothstep blends and keep dz = 0 at both ends.
	for _, case in ipairs({ { 1, true }, { 2, true }, { 3, false }, { 4, false }, { 5, false } }) do
		local idx, expectStep = case[1], case[2]
		local r = script.updateFn(defaultCap(), defaultParams({ rtr_curvature = idx }))
		local firstRamp, lastRamp
		for _, e in ipairs(r.edgeLists) do
			if e.edges[1][1][1] == 0 and e.edges[2][1][1] > 0 then
				firstRamp = e
			end
			if math.abs(e.edges[2][1][1] - 100) < 0.5 and e.edges[1][1][1] < 100 - 0.5 then
				lastRamp = e
			end
		end
		assert(firstRamp, "idx " .. idx .. ": must have a ramp edge starting at x=0")
		assert(lastRamp, "idx " .. idx .. ": must have a ramp edge ending at x=L")
		local dzStart = firstRamp.edges[1][2][3]
		local dzEnd = lastRamp.edges[2][2][3]
		if expectStep then
			assert(math.abs(dzStart) > 1e-6, string.format("idx %d: dz at ramp start must be non-zero (got %.6f)", idx, dzStart))
			assert(math.abs(dzEnd) > 1e-6, string.format("idx %d: dz at ramp end must be non-zero (got %.6f)", idx, dzEnd))
		else
			near(dzStart, 0, 1e-6, "idx " .. idx .. ": dz at ramp start must be 0 (end-flat smoothstep)")
			near(dzEnd, 0, 1e-6, "idx " .. idx .. ": dz at ramp end must be 0 (end-flat smoothstep)")
		end
	end
end)

------------------------------------------------------------------------
-- Snap point
------------------------------------------------------------------------
test("snap point: places at the approach start, lists road transport modes, snaps to STREET", function()
	local r = script.updateFn(defaultCap(), defaultParams())
	local sp = r.snapPoint
	eq(sp.transf[13], -20, "transf tx = -approach")
	eq(sp.transf[14], 0, "transf ty = 0 (single central road)")
	eq(sp.transf[15], 0, "transf tz = 0")
	local modes = {}
	for _, m in ipairs(sp.transportModes) do modes[m] = true end
	assert(modes.CAR, "CAR must be a transport mode")
	assert(modes.BUS, "BUS must be a transport mode")
	assert(modes.TRUCK, "TRUCK must be a transport mode")
	eq(sp.snapToBaseEdgeTypes[1], "STREET", "must snap to STREET edges, not TRACK")
	eq(sp.allowSnapToBaseEdgeEnds, true)
end)

test("snap point: local +Y axis points along the approach tangent (regression against 90-degree snap rotation)", function()
	-- TPF3 engine uses the snap point's local +Y axis as the direction of
	-- the edge it snaps to. The approach runs along world +X, so local +Y
	-- must land on world +X; otherwise the construction places 90° rotated
	-- against the target road (see commit message for the bug report).
	local r = script.updateFn(defaultCap(), defaultParams())
	local t = r.snapPoint.transf
	eq(t[5], 1, "transf[5] = local +Y x-component must be 1 (= approach tangent direction)")
	eq(t[6], 0, "transf[6] = local +Y y-component must be 0")
	eq(t[7], 0, "transf[7] = local +Y z-component must be 0 (snap stays in the ground plane)")
	-- The frame must stay orthonormal and right-handed, so the local +X
	-- axis is the lateral (snap-side) direction and +Z keeps pointing up.
	eq(t[1], 0, "transf[1] = local +X x-component must be 0")
	eq(t[2], -1, "transf[2] = local +X y-component must be -1 (lateral, right-hand to +Y)")
	eq(t[11], 1, "transf[11] = local +Z z-component must be 1 (up)")
end)

------------------------------------------------------------------------
-- The portal lies between the surface descent and the deepest segments
------------------------------------------------------------------------
test("portal: surface ends at the portal depth, tunnel starts there", function()
	local cap = defaultCap()
	local r = script.updateFn(cap, defaultParams())
	-- The surface's lowest point and the tunnel's highest point must meet
	-- at the portal; otherwise the two sections would overlap or leave a gap.
	local minSurfaceZ = 0            -- bottom of the open ramp (most negative)
	local maxTunnelZ = -math.huge    -- top of the tunnel section (least negative)
	for _, e in ipairs(r.edgeLists) do
		local za, zb = e.edges[1][1][3], e.edges[2][1][3]
		local lo, hi = math.min(za, zb), math.max(za, zb)
		if e.edgeType == "TUNNEL" then
			if hi > maxTunnelZ then maxTunnelZ = hi end
		else
			if lo < minSurfaceZ then minSurfaceZ = lo end
		end
	end
	near(minSurfaceZ, maxTunnelZ, 1e-6,
		"surface bottom and tunnel top must meet exactly at the portal")
	-- Given D=16, roof=max(7, 10.55+1)=11.55 and D*0.85=13.6, so cover=11.55
	-- and the portal lies at a depth of ~11.55m.
	near(-maxTunnelZ, 11.55, 0.5, "portal depth close to the roof-cover heuristic")
end)

------------------------------------------------------------------------
-- Phase 2: walls, coping, portal cover, terrain alignment
------------------------------------------------------------------------
local function modelsByTagPrefix(r, prefix)
	local out = {}
	for _, m in ipairs(r.subconstructions[1].models) do
		if type(m.tag) == "string" and m.tag:sub(1, #prefix) == prefix then
			out[#out + 1] = m
		end
	end
	return out
end

test("walls: both sides covered along the whole surface trench", function()
	local r = oneBox(script.updateFn(defaultCap(), defaultParams()))
	local left = modelsByTagPrefix(r, "wall_-1_")
	local right = modelsByTagPrefix(r, "wall_1_")
	assert(#left > 0, "left wall must have at least one segment")
	eq(#left, #right, "left and right walls must have the same number of segments")
	-- 4m segments across the surface portion (portalX ~65m) → tens of segments.
	assert(#left >= 10, "expected many wall segments along a 100m ramp, got " .. #left)
	for _, m in ipairs(left) do
		eq(m.id, DEFAULT_WALL_MODEL, "wall model id")
		-- transf[14] = world y of wall base; left side must be at -outer.
		assert(m.transf[14] < 0, "left wall must sit at y<0 (got " .. m.transf[14] .. ")")
	end
	for _, m in ipairs(right) do
		assert(m.transf[14] > 0, "right wall must sit at y>0 (got " .. m.transf[14] .. ")")
	end
end)

test("walls: wall offset keeps clear of the sidewalk edge", function()
	-- With halfWidth=8m and outer=halfWidth+1=9m, the wall centreline is
	-- at |y|=9m. Wall mesh half-depth is 0.225 scaled by 2.667 → 0.6m,
	-- so the inner face sits at |y|=8.4m -- 0.4m outside the sidewalk edge.
	local r = oneBox(script.updateFn(defaultCap(), defaultParams()))
	local right = modelsByTagPrefix(r, "wall_1_")
	assert(#right > 0, "need wall segments to check")
	near(right[1].transf[14], 9, 1e-6, "wall centreline must be 9m from road centre")
end)

test("walls: transf stays in sync with the rail-mod scale formulas", function()
	-- Catches scale-formula regressions the position-only tests miss:
	-- for a straight ramp, each segment's transf must match the Enivia
	-- rail recipe exactly (2.667 thickness scale; height = 0.3 - bottom;
	-- bottom = min(za,zb) - 1.5).
	local r = oneBox(script.updateFn(defaultCap(), defaultParams()))
	local right = modelsByTagPrefix(r, "wall_1_")
	assert(#right >= 2, "need at least two right-wall segments")
	local shallow = right[1]           -- near x=0, z profile ~ 0
	local deep = right[#right]         -- near x=portalX, z profile deepest
	-- Straight segment → local x axis is pure +x; thickness is on local y.
	for _, m in ipairs({ shallow, deep }) do
		assert(m.transf[1] > 0, "transf[1] (dx) must be positive for a forward segment")
		eq(m.transf[2], 0, "transf[2] (dy) must be zero on a straight ramp")
		eq(m.transf[5], 0, "transf[5] must be zero when dy=0")
		near(m.transf[6], 2.667, 1e-6, "transf[6] must equal the 2.667 thickness scale")
		eq(m.transf[9], 0, "transf[9] (local z x-component) must be zero")
		eq(m.transf[10], 0, "transf[10] (local z y-component) must be zero")
	end
	-- Height grows with depth (deeper bottom → larger height).
	assert(deep.transf[11] > shallow.transf[11],
		"wall height must grow with depth: " .. deep.transf[11] .. " vs " .. shallow.transf[11])
	-- Base of the wall sits 1.5m below the ramp profile at that x.
	local approx = shallow.transf[15]  -- = Z + bottom = min(za,zb) - 1.5
	assert(approx <= -1.5 + 1e-6, "shallow wall base must sit at or below -1.5m")
	assert(deep.transf[15] < approx,  "deep wall base must sit below the shallow one")
end)

test("portal cover: one slab over the portal tangent at depth D, laid in 4m pieces", function()
	local cap = defaultCap()
	local r = script.updateFn(cap, defaultParams())
	local covers = modelsByTagPrefix(r, "portal_top_cover")
	-- 18m (rtr_cover_length's initial setting) in pieces of at most 4m
	-- (ramp_geometry.COVER_PIECE) along, five of 3.6m, and the 22.8m width
	-- (the thick wall a spec without rtr_wall gets) in six pieces across
	-- (ramp_geometry.coverAcross)
	eq(#covers, 5 * 6, "the cover in five 3.6m pieces along, six across")
	local one = modelsByTagPrefix(oneBox(r), "portal_top_cover")
	eq(#one, 1, "one slab when added up")
	near(one[1].transf[6] * 0.45, 22.8, 1e-9, "22.8m wide")
	-- transf[15] = Z + bottom = 0 + (-0.3) = -0.3 below ground.
	for k, m in ipairs(covers) do
		eq(m.tag, string.format("portal_top_cover_%d_%d", math.floor((k - 1) / 6) + 1, (k - 1) % 6 + 1), "piece tag")
		near(m.transf[15], -0.3, 1e-6, "cover slab base 30cm below ground")
		near(m.transf[1], 3.6, 1e-9, "piece length")
	end
	near(one[1].transf[1], 18, 1e-9, "18m long")
end)

test("coping: slabs on top of the walls on both sides", function()
	local r = script.updateFn(defaultCap(), defaultParams())
	local left = modelsByTagPrefix(r, "coping_-1_")
	local right = modelsByTagPrefix(r, "coping_1_")
	assert(#left > 0 and #left == #right, "coping segments on both sides, same count")
	-- Coping lies just outside the wall centreline (inner=outer-0.65,
	-- outside=outer+2.4 → centre at outer+0.875).
	for _, m in ipairs(right) do
		assert(m.transf[14] > 9, "right coping must be outboard of the wall centreline (got " .. m.transf[14] .. ")")
	end
	-- Width and thickness scale regressions: slab() scales local y by
	-- width/0.45 (mesh is 0.45m thick) and local z by thickness. For a
	-- straight ramp the width is (outer+2.4) - (outer-0.65) = 3.05m.
	local sample = right[1]
	eq(sample.transf[5], 0, "straight segment: transf[5] must be zero")
	near(sample.transf[6], 3.05 / 0.45, 1e-6, "coping width scale must be 3.05/0.45 for a 3.05m slab")
	near(sample.transf[11], 0.25, 1e-6, "coping thickness must be 0.25m")
end)

test("terrain: subconstruction carries floor (EQUAL), shoulders (EQUAL), cover (LESS) and lid support (GREATER)", function()
	local r = script.updateFn(defaultCap(), defaultParams())
	local lists = r.subconstructions[1].terrainAlignmentLists
	eq(#lists, 4, "four terrain alignment lists on level ground (no approach face)")
	eq(lists[1].type, "EQUAL", "first list is the trench floor")
	eq(lists[2].type, "EQUAL", "second list keeps the shoulders at ground level")
	eq(lists[3].type, "LESS",  "third list lowers the heightmap under the portal cover")
	eq(lists[4].type, "GREATER", "fourth list holds the ground up to the portal cover")
	for i, al in ipairs(lists) do
		assert(al.optional == true, "list " .. i .. " must be optional so dense builds still succeed")
		assert(#al.faces >= 1, "list " .. i .. " must have at least one face")
	end
	-- The floor should descend: the first face sits near z=0, the last near z=-cover.
	local floor = lists[1].faces
	near(floor[1][1][3], -0.25, 1e-6, "floor face 1 near ground")
	assert(floor[#floor][2][3] < -5, "floor far-end descends well below ground")
end)

------------------------------------------------------------------------
-- Contract between ramp.con.lua and ramp.script.lua
-- The UI default (numbers[defaultIndex]) must line up with the fallback
-- the script uses when a param is missing; otherwise the geometry a
-- first-time placer sees differs from the one the tests exercise.
------------------------------------------------------------------------
test("contract: con.lua agrees with script on defaults and clamp ranges", function()
	data = false
	assert(loadfile(root .. "/content/road_tunnel_ramp/ramp.con.lua"))()
	assert(type(data) == "function", "ramp.con.lua must define data()")
	local spec = data()
	assert(spec.type == "ASSET_DEFAULT", "construction type must be ASSET_DEFAULT")
	assert(spec.snapping and spec.snapping.road == true, "snapping.road must be enabled")
	assert(spec.snapping.rail == false, "snapping.rail must be disabled for a road construction")
	eq(spec.menuCategory.categories[1].category, "street_constructions", "menu category")
	assert(spec.updateScript.fileName:find("@updateFn"), "updateScript must point at @updateFn")
	local streets = spec.updateScript.params.streets
	assert(type(streets) == "table" and #streets >= 1, "streets table must be captured")
	for i, s in ipairs(streets) do
		assert(type(s.ref) == "string" and s.ref:find("street_template", 1, true),
			"streets[" .. i .. "] ref missing or not a street_template")
		assert(type(s.width) == "number" and s.width > 0,
			"streets[" .. i .. "] width must be a positive number")
	end
	assert(spec.updateScript.params.tunnelRef, "tunnelRef must be captured")
	-- Pack params by key for lookup.
	local byKey = {}
	for _, param in ipairs(spec.params) do byKey[param.key] = param end
	-- Street: UI picker must have exactly one entry per captured street,
	-- each number must resolve to a valid streets index, and the UI
	-- default must resolve to the script fallback (2 = town_new_small),
	-- the same pattern length/depth/curvature use.
	local st = byKey.rtr_street
	assert(st, "rtr_street param missing")
	eq(#st.numbers, #streets, "rtr_street numbers must match captured streets count")
	eq(#st.values, #st.numbers, "every street value needs a matching number")
	for i, n in ipairs(st.numbers) do
		assert(streets[n], "rtr_street option " .. i .. " (value " .. tostring(n) .. ") has no matching streets[] entry")
	end
	eq(st.numbers[st.defaultIndex], 3, "rtr_street defaultIndex must resolve to the script fallback 3 (town_new_small)")
	-- Length: UI default matches script fallback and every option is in
	-- the script's clamp range (40..400 from value(); the UI stops at 100).
	local len = byKey.rtr_length
	assert(len, "rtr_length param missing")
	eq(len.numbers[len.defaultIndex], 100, "rtr_length defaultIndex must resolve to the script fallback 100")
	for i, n in ipairs(len.numbers) do
		assert(n >= 40 and n <= 100, "length option " .. i .. " (" .. tostring(n) .. ") outside the UI range [40,100]")
	end
	eq(len.numbers[1], 40, "shortest length option is 40m (matches road_bridge_ramp)")
	eq(#len.values, #len.numbers, "every length value needs a matching number")
	-- Depth: UI default matches script fallback. Options below tunnelHeight+2
	-- are allowed in the UI (they clamp up with a tooltip note) but must
	-- still be in the script's broad clamp range.
	local dep = byKey.rtr_depth
	assert(dep, "rtr_depth param missing")
	eq(dep.numbers[dep.defaultIndex], 16, "rtr_depth defaultIndex must resolve to the script fallback 16")
	for i, n in ipairs(dep.numbers) do
		assert(n >= 10 and n <= 25, "depth option " .. i .. " (" .. tostring(n) .. ") outside script clamp [10,25]")
	end
	eq(#dep.values, #dep.numbers, "every depth value needs a matching number")
	-- 1m steps from 13m: no option sits below the 12.55m roof-cover minimum.
	for i, n in ipairs(dep.numbers) do eq(n, 12 + i, "depth option " .. i) end
	-- Length: 2m steps 40..100.
	for i, n in ipairs(len.numbers) do eq(n, 38 + 2 * i, "length option " .. i) end
	eq(#len.numbers, 31, "length options 40..100 step 2")
	-- Approach: default matches the script fallback, options inside its clamp.
	local app = byKey.rtr_approach
	assert(app, "rtr_approach param missing")
	eq(app.numbers[app.defaultIndex], 20, "rtr_approach defaultIndex must resolve to the script fallback 20")
	for i, n in ipairs(app.numbers) do
		assert(n >= 2 and n <= 50, "approach option " .. i .. " outside script clamp [2,50]")
	end
	eq(#app.values, #app.numbers, "every approach value needs a matching number")
	-- Count: UI default maps to the script fallback (1 = single), every
	-- option is a valid integer in [1, 3].
	local cnt = byKey.rtr_count
	assert(cnt, "rtr_count param missing")
	eq(cnt.numbers[cnt.defaultIndex], 1, "rtr_count defaultIndex must resolve to the script fallback 1 (single)")
	for i, n in ipairs(cnt.numbers) do
		assert(n >= 1 and n <= 3 and n == math.floor(n),
			"count option " .. i .. " (" .. tostring(n) .. ") must be an integer in [1,3]")
	end
	eq(#cnt.values, #cnt.numbers, "every count value needs a matching number")
	-- Curvature: UI default maps to the script fallback (3 = cubic), and
	-- every number is within the script's clamp range [1, 5].
	local cur = byKey.rtr_curvature
	assert(cur, "rtr_curvature param missing")
	eq(cur.numbers[cur.defaultIndex], 3, "rtr_curvature defaultIndex must resolve to the script fallback 3 (cubic)")
	for i, n in ipairs(cur.numbers) do
		assert(n >= 1 and n <= 5, "curvature option " .. i .. " (" .. tostring(n) .. ") outside script clamp [1,5]")
	end
	eq(#cur.values, #cur.numbers, "every curvature value needs a matching number")
end)

------------------------------------------------------------------------
-- Asset path hygiene: the walls were first copied out of the Enivia mod
-- with the paths renamed; no file we distribute may reference that
-- mod's namespace. Catches an accidental re-copy or an incomplete rewrite.
------------------------------------------------------------------------
test("assets: no wall file references the /enivia/ namespace", function()
	local files = {
		"content/road_tunnel_ramp/walls/aom_wall_box.msh",
		"content/road_tunnel_ramp/walls/aom_slab_box.msh",
		"content/road_tunnel_ramp/walls/aom_strip_box.msh",
		"content/road_tunnel_ramp/walls/wall.mdl",
		"content/road_tunnel_ramp/walls/slab.mdl",
		"content/road_tunnel_ramp/walls/strip.mdl",
		"content/road_tunnel_ramp/walls/concrete.mdl",
		"content/road_tunnel_ramp/ramp.script.lua",
		"content/road_tunnel_ramp/ramp_geometry.lua",
	}
	for _, rel in ipairs(files) do
		local f = assert(io.open(root .. "/" .. rel, "r"), "cannot open " .. rel)
		local body = f:read("*a")
		f:close()
		assert(not body:find("/enivia/", 1, true),
			"'/enivia/' string leaked into " .. rel .. " -- rename aborted or regressed")
	end
end)

------------------------------------------------------------------------
-- Street list order and one-way direction handling
------------------------------------------------------------------------
test("streets: picker is ordered by width, highway small (9m) first, only highways are one-way", function()
	local cap = defaultCap()
	eq(cap.streets[1].ref, "::/infrastructure/street/highway/highway_new_small.street_template", "first entry")
	eq(cap.streets[1].width, 9, "highway small = 2+5+2 from laneConfigs")
	-- the seven vanilla entries; the car-only one (8) is appended after them
	eq(#cap.streets, 8, "street entries")
	for i = 2, 7 do
		assert(cap.streets[i].width > cap.streets[i - 1].width, "not width-ordered at " .. i)
	end
	for _, st in ipairs(cap.streets) do
		eq(not not st.oneWay, st.ref:find("/highway/", 1, true) ~= nil, "oneWay flag on " .. st.ref)
	end
end)

local function dirOf(e) return e.edges[2][1][1] > e.edges[1][1][1] and 1 or -1 end
local function edgesAtY(r, y)
	local out = {}
	for _, e in ipairs(r.edgeLists) do if e.edges[1][1][2] == y then out[#out + 1] = e end end
	return out
end

test("one-way: carriageways sit on the driving side, direction picks the snapping one", function()
	local cap = defaultCap()
	-- Independent expectation tables: flows per street (ys order, -Y first)
	-- for right-hand (1) and left-hand (2) traffic.
	local layouts = {
		[1] = { [2] = { 1, -1 }, [3] = { 1, 1, -1 } },
		[2] = { [2] = { -1, 1 }, [3] = { -1, 1, 1 } },
	}
	for _, idx in ipairs({ 1, 4 }) do
		local pitch = cap.streets[idx].width + 2
		for _, side in ipairs({ 1, 2 }) do
			for _, dir in ipairs({ 1, 2 }) do
				local want = dir == 1 and 1 or -1
				for count = 1, 3 do
					local r = (function(o) return script.updateFn(cap, defaultParams(o)) end)({ rtr_street = idx, rtr_count = count, rtr_direction = dir, rtr_side = side })
					local flows = count == 1 and { want } or layouts[side][count]
					local snapK
					for k = 1, count do if flows[k] == want then snapK = k; break end end
					local tag = string.format("idx %d side %d dir %d count %d", idx, side, dir, count)
					for k = 1, count do
						local y = (k - (count + 1) * 0.5) * pitch
						local es = edgesAtY(r, y)
						assert(#es > 0, tag .. ": no edges for street " .. k)
						for _, e in ipairs(es) do
							eq(dirOf(e), flows[k], tag .. " street " .. k .. " direction")
							assert(e.edges[1][2][1] * flows[k] > 0 and e.edges[2][2][1] * flows[k] > 0, "tangent sign")
						end
						-- Driving side: facing its own travel direction, a
						-- carriageway off the centre line is on the right
						-- (RHT) or left (LHT). Right of +X travel is -Y.
						if count > 1 and y ~= 0 then
							local onRight = (y * flows[k]) < 0
							eq(onRight, side == 1, tag .. " street " .. k .. " driving side")
						end
						-- Only the snapping street snaps at the approach start.
						local snapsHere = 0
						for _, e in ipairs(es) do
							for _, n in ipairs(e.snapNodes) do
								if e.edges[n + 1][1][1] < 0 then snapsHere = snapsHere + 1 end
							end
						end
						eq(snapsHere, k == snapK and 1 or 0, tag .. " street " .. k .. " approach snap")
						-- Every other street keeps its approach start as a free
						-- node, also when it is reversed (free index swapped).
						local freesHere = 0
						for _, e in ipairs(es) do
							for _, n in ipairs(e.freeNodes) do
								if e.edges[n + 1][1][1] < 0 then freesHere = freesHere + 1 end
							end
						end
						-- (handed over by default, so the snapping one's too)
						eq(freesHere, 1, tag .. " street " .. k .. " approach free node")
					end
					eq(r.snapPoint.transf[14], (snapK - (count + 1) * 0.5) * pitch, tag .. " snap point y")
				end
			end
		end
	end
end)

test("one-way: reversing keeps snap/free ends, tunnel flags and world slope", function()
	local cap = defaultCap()
	local function summary(r)
		local snaps, frees, tunnels = {}, {}, 0
		for _, e in ipairs(r.edgeLists) do
			for _, n in ipairs(e.snapNodes) do local p = e.edges[n + 1][1]; snaps[#snaps + 1] = p[1] .. "," .. p[2] end
			for _, n in ipairs(e.freeNodes) do local p = e.edges[n + 1][1]; frees[#frees + 1] = p[1] .. "," .. p[2] end
			if e.edgeType == "TUNNEL" then tunnels = tunnels + 1 end
		end
		table.sort(snaps); table.sort(frees)
		return table.concat(snaps, ";"), table.concat(frees, ";"), tunnels
	end
	local fwd = script.updateFn(cap, defaultParams({ rtr_street = 4, rtr_count = 1, rtr_direction = 1 }))
	local rev = script.updateFn(cap, defaultParams({ rtr_street = 4, rtr_count = 1, rtr_direction = 2 }))
	local s1, f1, t1 = summary(fwd)
	local s2, f2, t2 = summary(rev)
	eq(s2, s1, "snap node positions"); eq(f2, f1, "free node positions"); eq(t2, t1, "tunnel edge count")
	for _, e in ipairs(rev.edgeLists) do
		for k = 1, 2 do
			local t = e.edges[k][2]
			if t[1] ~= 0 then assert(t[3] / t[1] <= 1e-12, "world slope toward +X must stay non-positive (descending)") end
		end
	end
end)

test("two-way streets ignore the direction parameter", function()
	local cap = defaultCap()
	for _, idx in ipairs({ 2, 3, 5, 6, 7 }) do
		local a = script.updateFn(cap, defaultParams({ rtr_street = idx, rtr_count = 2 }))
		local b = script.updateFn(cap, defaultParams({ rtr_street = idx, rtr_count = 2, rtr_direction = 2, rtr_side = 2 }))
		eq(#b.edgeLists, #a.edgeLists, "edge count")
		for i, e in ipairs(b.edgeLists) do
			eq(dirOf(e), 1, "street " .. idx .. " edge " .. i .. " must run +X")
			eq(e.edges[1][1][2], a.edgeLists[i].edges[1][1][2], "identical layout")
		end
		eq(b.snapPoint.transf[14], a.snapPoint.transf[14], "snap stays on ys[1]")
	end
end)

test("contract: rtr_direction / rtr_side defaults equal the script fallback (1), options in [1,2]", function()
	data = false
	assert(loadfile(root .. "/content/road_tunnel_ramp/ramp.con.lua"))()
	local byKey = {}
	for _, p in ipairs(data().params) do byKey[p.key] = p end
	for _, key in ipairs({ "rtr_direction", "rtr_side" }) do
		local d = assert(byKey[key], key .. " missing")
		eq(d.numbers[d.defaultIndex], 1, key .. " default")
		eq(#d.values, #d.numbers, key .. " values/numbers")
		for _, n in ipairs(d.numbers) do assert(n == 1 or n == 2, key .. " option " .. n) end
	end
	-- The fallback really is 1: omitting both params must equal passing 1.
	local cap = defaultCap()
	local a = script.updateFn(cap, defaultParams({ rtr_street = 4, rtr_count = 2 }))
	local b = script.updateFn(cap, defaultParams({ rtr_street = 4, rtr_count = 2, rtr_direction = 1, rtr_side = 1 }))
	for i, e in ipairs(a.edgeLists) do eq(dirOf(e), dirOf(b.edgeLists[i]), "edge " .. i) end
	eq(a.snapPoint.transf[14], b.snapPoint.transf[14], "snap y")
end)

test("streets: widths and oneWay flags match vanilla street.zip laneConfigs", function()
	local zip = os.getenv("HOME") .. "/.local/share/Steam/steamapps/common/Transport Fever 3/base/content/infrastructure/street.zip"
	local fh = io.open(zip, "rb")
	if not fh then print("     (skipped: street.zip not found)") return end
	fh:close()
	for _, st in ipairs(defaultCap().streets) do
		local sub = st.ref:match("^::/infrastructure/street(.*)$")
		-- (this mod's own template is checked against its file below)
		if not sub then goto continue end
		local member = "street" .. sub .. ".lua"
		local p = assert(io.popen(string.format("unzip -p %q %q 2>/dev/null", zip, member)))
		local src = p:read("*a"); p:close()
		local lanes = src:match("laneConfigs%s*=%s*(%b{})")
		assert(lanes, "laneConfigs not found for " .. member)
		local total, backwardCar = 0, false
		for lane in lanes:sub(2, -2):gmatch("%b{}") do
			total = total + tonumber(lane:match("width%s*=%s*([%d%.]+)"))
			if lane:find("forward%s*=%s*false") and lane:find('"CAR"') then backwardCar = true end
		end
		eq(st.width, total, member .. " width")
		eq(not not st.oneWay, not backwardCar, member .. " oneWay")
		::continue::
	end
end)

-- The game's 13 UI languages (base/strings/<lang>); a missing language
-- falls back to the raw key, so every key must be in every block.
local LANGS = { "en", "ja", "de", "es", "fr", "it", "ko", "nl", "pl", "pt_BR", "ru", "zh_CN", "zh_TW" }

test("strings: every _() key used by con.lua, its cars-only street and the grade line exists in all 13 languages", function()
	local f = assert(io.open(root .. "/strings.json")); local s = f:read("*a"); f:close()
	local cf = assert(io.open(root .. "/content/road_tunnel_ramp/ramp.con.lua")); local c = cf:read("*a"); cf:close()
	local tf = assert(io.open(root .. "/content/road_tunnel_ramp/streets/ramp_car_only.street_template.lua"))
	c = c .. tf:read("*a"); tf:close()
	local keys = { "rtr_grade_label", "rtr_ground_line" }
	for key in c:gmatch('_%("([%w_]+)"%)') do keys[#keys + 1] = key end
	assert(#keys > 10, "string scan found too few keys")
	local blocks = 0
	for _ in s:gmatch('\n\t"[%w_]+": (%b{})') do blocks = blocks + 1 end
	eq(blocks, #LANGS, "language blocks in strings.json")
	for _, lang in ipairs(LANGS) do
		local block = s:match('\n\t"' .. lang .. '": (%b{})')
		assert(block, "language block missing: " .. lang)
		for _, key in ipairs(keys) do
			local value = block:match('"' .. key .. '"%s*:%s*"([^"]*)"')
			assert(value and value ~= "", lang .. ": " .. key .. " missing or empty")
		end
	end
end)

------------------------------------------------------------------------
-- Build-cursor grade line
------------------------------------------------------------------------
local grade = assert(loadfile(root .. "/content/road_tunnel_ramp/grade.lua"))()

test("grade: maxGrade matches the steepest point of the emitted ramp edges", function()
	-- Pins the tooltip number to the real geometry for every slider value.
	for L = 40, 100, 6 do
		for c = 1, 5 do
			for _, D in ipairs({ 13, 16, 20, 25 }) do
				local p = defaultParams({ rtr_length = L, rtr_depth = D, rtr_curvature = c })
				local r = script.updateFn(defaultCap(), p)
				local maxG = 0
				for _, e in ipairs(r.edgeLists) do
					local p0, t0 = e.edges[1][1], e.edges[1][2]
					local p1, t1 = e.edges[2][1], e.edges[2][2]
					local dxl = p1[1] - p0[1]
					for k = 0, 40 do
						local u = k / 40
						local dz = (6 * u * u - 6 * u) * p0[3] + (3 * u * u - 4 * u + 1) * t0[3]
							+ (-6 * u * u + 6 * u) * p1[3] + (3 * u * u - 2 * u) * t1[3]
						maxG = math.max(maxG, math.abs(dz / dxl))
					end
				end
				local want = grade.maxGrade(p)
				assert(math.abs(maxG - want) <= 0.02 * want,
					string.format("L=%d c=%d D=%d sampled %.4f vs maxGrade %.4f", L, c, D, maxG, want))
			end
		end
	end
end)

test("grade: defaults, clamps and the 12.55m depth floor follow the script", function()
	near(grade.maxGrade({}), 1.5 * 16 / 100, 1e-9, "defaults 100m / 16m / Normal")
	near(grade.maxGrade({ rtr_length = 10, rtr_depth = 10, rtr_curvature = 9 }), 1.875 * 12.55 / 40, 1e-9, "clamped")
	near(grade.maxGrade({ rtr_length = 40, rtr_depth = 25, rtr_curvature = 5 }), 1.875 * 25 / 40, 1e-9, "worst case")
	near(grade.maxGrade({ rtr_length = 200 }), 1.5 * 16 / 200, 1e-9, "old 200m ramps are not clamped to 100")
	eq(grade.formatLine("Max grade", 0.24), "Max grade: 24.0%", "format")
	eq(grade.isRamp({ "road_tunnel_ramp/ramp.con" }), true, "own construction")
	eq(grade.isRamp({ "road_bridge_ramp/ramp.con" }), false, "other construction")
	eq(grade.isRamp(nil), false, "nil list")
end)

-- Minimal stand-in for the GUI state: ug_require returns a fake
-- construction_react_util whose getActionParams yields one action.
-- Fake engine terrain: heightAt(x, y) in world coordinates.
local function fakeApi(heightAt)
	return {
		engine = { terrain = { getBaseHeightAt = function(v) return heightAt(v.x, v.y) end } },
		type = { Vec2f = { new = function(x, y) return { x = x, y = y } end } },
	}
end
-- A proposal whose first construction sits at origin (ox, oy) with its
-- local +x along world angle `angle` (radians); transf is a plain
-- column-major array like Mat4f's 1-based __index.
local function fakeProposal(ox, oy, angle)
	local c, s = math.cos(angle), math.sin(angle)
	local transf = { c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, ox, oy, 50, 1 }
	return { toAdd_native = {
		size = function() return 1 end,
		at = function(_, i) assert(i == 1); return { transf = transf } end,
	} }
end

local function loadGradeHook(constructions, params, apiTable)
	local logs = {}
	local cru = {}
	cru.getActionParams = function()
		return { constructionActionParams = {
			constructionBuilder = { constructions = constructions, params = params },
			getProposalStringsFn = function() return { "base line" } end,
		} }
	end
	local env = setmetatable({
		ug_require = function() return cru end,
		require = function(name)
			assert(name == "road_tunnel_ramp::/road_tunnel_ramp/grade.lua", "unexpected require " .. name)
			return grade
		end,
		debugPrint = function(m) logs[#logs + 1] = m end,
		_ = function(k)
			if k == "rtr_grade_label" then return "最大勾配" end
			if k == "rtr_ground_line" then return "地面の勾配: 縦断 {along}、横断 {across}" end
			return k
		end,
		api = apiTable or fakeApi(function() return 100 end),
	}, { __index = _G })
	local chunk = assert(loadfile(root .. "/content/gui/rtr_grade.script.lua"))
	setfenv(chunk, env)
	chunk()
	env.data().prepare({})
	return cru, logs
end

test("grade hook: appends the grade line for the ramp and keeps earlier lines", function()
	local params = { rtr_length = 40, rtr_depth = 16, rtr_curvature = 3 }
	local cru, logs = loadGradeHook({ "road_tunnel_ramp/ramp.con" }, params)
	local action = cru.getActionParams().constructionActionParams
	local proposal = fakeProposal(0, 0, 0)
	local lines = action.getProposalStringsFn(proposal, {})
	eq(lines[1], "base line", "chained base line kept")
	eq(lines[2], "最大勾配: 60.0%", "grade line uses the live params")
	eq(lines[3], "地面の勾配: 縦断 0.0%、横断 0.0%", "level ground line")
	-- The same action follows later param changes.
	params.rtr_length = 80
	eq(action.getProposalStringsFn(proposal, {})[2], "最大勾配: 30.0%", "line follows param changes")
	eq(cru.__rtrGradeInstalled, true, "install flag set")
	-- Only failures may reach stdout.txt; a working install stays silent.
	eq(#logs, 0, "nothing logged on success: " .. tostring(logs[1]))
end)

test("grade hook: the median approach gets both lines too (grade.isRamp)", function()
	eq(grade.isRamp({ "road_tunnel_ramp/median.con" }), true, "median.con is one of them")
	eq(grade.isRamp({ "road_tunnel_ramp/other.con" }), false, "others are not")
	local params = { rtr_length = 40, rtr_depth = 16, rtr_curvature = 3, rtr_approach = 30 }
	local cru, logs = loadGradeHook({ "road_tunnel_ramp/median.con" }, params)
	local lines = cru.getActionParams().constructionActionParams.getProposalStringsFn(fakeProposal(0, 0, 0), {})
	eq(lines[2], "最大勾配: 60.0%", "grade line")
	eq(lines[3], "地面の勾配: 縦断 0.0%、横断 0.0%", "ground line")
	eq(#logs, 0, "nothing logged")
end)

test("grade hook: no line (and one log) when builder params are unreadable", function()
	local cru, logs = loadGradeHook({ "road_tunnel_ramp/ramp.con" }, {})
	local action = cru.getActionParams().constructionActionParams
	local lines = action.getProposalStringsFn(fakeProposal(0, 0, 0), {})
	eq(#lines, 1, "no default-based grade line")
	action.getProposalStringsFn(fakeProposal(0, 0, 0), {})
	local n = 0
	for _, m in ipairs(logs) do if m:find("not readable") then n = n + 1 end end
	eq(n, 1, "reported once")
end)

test("grade hook: other constructions are left untouched", function()
	local cru = loadGradeHook({ "station/rail/modular.con" }, {})
	local lines = cru.getActionParams().constructionActionParams.getProposalStringsFn({}, {})
	eq(#lines, 1, "no line added")
	eq(lines[1], "base line", "base line intact")
end)

------------------------------------------------------------------------
-- Ground slope (rtr_ground_along / rtr_ground_across). Bug: on sloped
-- ground the level walls, coping and lid floated on the downhill side.
------------------------------------------------------------------------

-- The script as it was before the ground slope options, frozen, so 0/0
-- can be compared with what older saves were built with.
local legacy
do
	local saved = data
	data = false
	assert(loadfile(root .. "/tests/fixtures/ramp_before_ground_grade.script.lua"))()
	legacy = data()
	data = saved
end

-- The models without the portal cover and the trench coping (tags
-- portal_top_cover, coping_*; approach_coping_* stay).
local function withoutBand(r)
	local out = {}
	for _, m in ipairs(r.subconstructions[1].models) do
		if m.tag ~= "portal_top_cover" and not m.tag:find("^coping_") then out[#out + 1] = m end
	end
	return out
end

local function deepEq(a, b, path)
	if type(a) ~= type(b) then error(path .. ": type " .. type(a) .. " ~= " .. type(b), 0) end
	if type(a) ~= "table" then
		if a ~= b then error(path .. ": " .. tostring(a) .. " ~= " .. tostring(b), 0) end
		return
	end
	for k, v in pairs(a) do deepEq(v, b[k], path .. "." .. tostring(k)) end
	for k in pairs(b) do
		if a[k] == nil then error(path .. "." .. tostring(k) .. ": missing", 0) end
	end
end

-- The plane and road profile the tests expect, written out independently
-- of the script (cubic profile = the default curvature).
local function expectGround(along, across, approach, ySnap)
	return function(x, y) return along / 100 * (x + approach) - across / 100 * (y - ySnap) end
end
local function roadZ(x, L, D)
	local t = math.max(0, math.min(1, x / L))
	return -D * (3 * t * t - 2 * t * t * t)
end
local function portalXOf(r)
	for _, e in ipairs(r.edgeLists) do
		if e.edgeType == "TUNNEL" then return math.min(e.edges[1][1][1], e.edges[2][1][1]) end
	end
end
local function allFinite(t, path)
	for k, v in pairs(t) do
		if type(v) == "number" then
			assert(v == v and v > -math.huge and v < math.huge, path .. "." .. tostring(k) .. " is " .. tostring(v))
		elseif type(v) == "table" then
			allFinite(v, path .. "." .. tostring(k))
		end
	end
end

test("ground 0/0: edges, models, floor, cover, snap and cost match the build before the option", function()
	local cap = defaultCap()
	local cases = {}
	for _, st in ipairs({ 1, 3, 7 }) do
		for _, count in ipairs({ 1, 2, 3 }) do
			for _, L in ipairs({ 40, 72, 100, 200 }) do
				cases[#cases + 1] = { rtr_street = st, rtr_count = count, rtr_length = L, rtr_depth = 16 }
			end
		end
	end
	for c = 1, 5 do cases[#cases + 1] = { rtr_curvature = c, rtr_depth = 25, rtr_length = 46, rtr_approach = 2 } end
	cases[#cases + 1] = { rtr_street = 4, rtr_count = 3, rtr_direction = 2, rtr_side = 2, rtr_approach = 50, rtr_depth = 13 }
	for i, p in ipairs(cases) do
		local old = legacy.updateFn(cap, p)
		for _, extra in ipairs({ {}, { rtr_ground_along = 0, rtr_ground_across = 0 } }) do
			local q = {}
			for k, v in pairs(p) do q[k] = v end
			for k, v in pairs(extra) do q[k] = v end
			local new = asBefore(script.updateFn(cap, kept(q)), old)
			local tag = "case " .. i
			deepEq(new.edgeLists, old.edgeLists, tag .. " edges")
			-- (the cover and the trench coping were narrowed to one band on
			-- 2026-11-23: "lidwidth" checks them against the build before)
			deepEq(withoutBand(new), withoutBand(old), tag .. " models")
			deepEq(new.snapPoint, old.snapPoint, tag .. " snap")
			eq(new.cost, old.cost, tag .. " cost")
			local nl, ol = new.subconstructions[1].terrainAlignmentLists, old.subconstructions[1].terrainAlignmentLists
			deepEq(nl[1], ol[1], tag .. " floor")
			eq(#nl, 4, tag .. ": no approach face on level ground")
			-- Shoulders on level ground stay at z = 0 (only wider / longer).
			for _, f in ipairs(nl[2].faces) do
				for _, v in ipairs(f) do eq(v[3], 0, tag .. " shoulder z") end
			end
		end
	end
end)

-- along/across cases: uphill + right side high, downhill + left side high.
local slopeCases = {
	{ along = 8, across = 5 },
	{ along = -2, across = -4 },  -- downhill the ramp still gets under
	{ along = -3, across = -7 },  -- just too steep: plane lifted ~0.15m at the lid
	{ along = -8, across = 3 },   -- much too steep: embankment up to the lid
	{ along = 0, across = 12 },
	{ along = 15, across = 0 },
}

-- The lift the script applied (lid bottom over the plane), and the
-- surface the walls, coping and shoulders follow: the plane ramped up by
-- the lift from the trench start to the front of the cover margin, never
-- below the road.
local function liftOf(r, g)
	local lid = modelsByTagPrefix(oneBox(r), "portal_top_cover")[1].transf
	return lid[15] - (g(lid[13], 0) - 0.3)
end
local function expectSurface(r, g, D)
	local lift, px = liftOf(r, g), portalXOf(r)
	return function(x, y)
		return math.max(g(x, y) + lift * math.max(0, math.min(1, x / (px - 6.25))), roadZ(x, 100, D or 16))
	end
end

test("ground: wall tops follow the plane on both sides and at both ends of every segment", function()
	for _, sc in ipairs(slopeCases) do
		local r = oneBox(script.updateFn(defaultCap(), defaultParams({ rtr_ground_along = sc.along, rtr_ground_across = sc.across })))
		local g = expectGround(sc.along, sc.across, 20, 0)
		local sf = expectSurface(r, g)
		if sc.along >= -2 then near(liftOf(r, g), 0, 1e-9, "no lift while the ramp gets under the ground") end
		for _, side in ipairs({ -1, 1 }) do
			local walls = modelsByTagPrefix(r, "wall_" .. side .. "_")
			assert(#walls >= 2, "wall segments on side " .. side)
			for j, m in ipairs(walls) do
				local t = m.transf
				local xa, xb, y = t[13], t[13] + t[1], t[14]
				near(y, side * 9, 1e-9, "wall line")
				local topA = t[15] + t[11]
				local topB = topA + t[3]
				local tag = string.format("along %d across %d side %d seg %d", sc.along, sc.across, side, j)
				near(topA, sf(xa, y) + 0.3, 1e-9, tag .. " top at start")
				near(topB, sf(xb, y) + 0.3, 1e-9, tag .. " top at end")
				-- Both base corners stay 1.5m under the road.
				local lowRoad = math.min(roadZ(xa, 100, 16), roadZ(xb, 100, 16))
				assert(t[15] <= lowRoad - 1.5 + 1e-9, tag .. " base at start above road - 1.5")
				assert(t[15] + t[3] <= lowRoad - 1.5 + 1e-9, tag .. " base at end above road - 1.5")
				assert(t[11] > 0, tag .. " positive height")
			end
			-- Where the ground is above the road the top is exactly ground + 0.3
			-- (the far end of the trench, near the portal).
			local last = walls[#walls].transf
			near(last[15] + last[11] + last[3], g(last[13] + last[1], last[14]) + liftOf(r, g) + 0.3, 1e-9, "last segment on the (lifted) plane")
		end
	end
end)

test("ground: walls and shoulders run on along the approach to the snap point without a step", function()
	for _, sc in ipairs(slopeCases) do
		local r = oneBox(script.updateFn(defaultCap(), defaultParams({ rtr_ground_along = sc.along, rtr_ground_across = sc.across })))
		local g = expectGround(sc.along, sc.across, 20, 0)
		local tag = string.format("along %d across %d", sc.along, sc.across)
		for _, side in ipairs({ -1, 1 }) do
			local aw = modelsByTagPrefix(r, "approach_wall_" .. side .. "_")
			eq(#aw, 5, tag .. ": 20m approach in 4m wall segments")
			near(aw[1].transf[13], -20, 1e-9, tag .. " approach wall starts at the snap point")
			near(aw[1].transf[15] + aw[1].transf[11], math.max(g(-20, side * 9), 0) + 0.3, 1e-9, tag .. " top at the snap end")
			local last, first = aw[#aw].transf, modelsByTagPrefix(r, "wall_" .. side .. "_")[1].transf
			near(last[13] + last[1], first[13], 1e-9, tag .. " approach wall meets the trench wall")
			near(last[15] + last[11] + last[3], first[15] + first[11], 1e-9, tag .. " no step in the wall top at x = 0")
			for k = 1, #aw - 1 do
				local a, b = aw[k].transf, aw[k + 1].transf
				near(a[15] + a[11] + a[3], b[15] + b[11], 1e-9, tag .. " approach wall tops continuous")
				assert(a[15] <= -1.5 + 1e-9 and a[15] + a[3] <= -1.5 + 1e-9, tag .. " approach wall base under the road")
			end
			eq(#modelsByTagPrefix(r, "approach_coping_" .. side .. "_"), 5, tag .. " approach coping")
		end
		-- Shoulder heights where the approach strips meet the trench strips.
		local atZero = {}
		for _, f in ipairs(r.subconstructions[1].terrainAlignmentLists[2].faces) do
			for _, v in ipairs(f) do
				if math.abs(v[1]) < 1e-9 then
					local key = string.format("%.6f", v[2])
					if atZero[key] then near(atZero[key], v[3], 1e-9, tag .. " shoulder step at x = 0, y = " .. key) end
					atZero[key] = v[3]
				end
			end
		end
		assert(atZero[string.format("%.6f", 9.65)], tag .. ": shoulders meet at x = 0")
	end
	local flat = script.updateFn(defaultCap(), defaultParams())
	eq(#modelsByTagPrefix(flat, "approach_"), 0, "level ground: no approach walls (the old layout)")
end)

-- Every cover length's ends (rtr_cover_length): the slider's shortest
-- (LID_MIN), the initial 18m and the longest.
test("ground: steep downhill keeps the lid and the ground under it out of the tunnel", function()
	for _, C in ipairs({ rampGeo.LID_MIN, 18, 24 }) do
	for _, D in ipairs({ 13, 16, 25 }) do
		for _, along in ipairs({ -4, -6, -10, -20 }) do
			for _, across in ipairs({ -10, 0, 10 }) do
				local r = oneBox(script.updateFn(defaultCap(), defaultParams({ rtr_depth = D, rtr_ground_along = along, rtr_ground_across = across, rtr_cover_length = C })))
				local px = portalXOf(r)
				local function roofAt(x) return roadZ(x, 100, D) + 10.55 end
				local tag = string.format("cover %d D %d along %d across %d", C, D, along, across)
				local lid = modelsByTagPrefix(oneBox(r), "portal_top_cover")[1].transf
				near(lid[1], C, 1e-9, tag .. " lid length")
				local tilt = lid[7] / lid[6]
				for _, u in ipairs({ 6 / C, 1 }) do      -- the portal and the far end
					for _, y in ipairs({ -11.4, 11.4 }) do
						local bottom = lid[15] + lid[3] * u + tilt * y
						local roof = roofAt(px - 6 + C * u)
						assert(bottom >= roof + 0.15 - 1e-9, tag .. string.format(" lid bottom %.2f under roof %.2f", bottom, roof))
					end
				end
				-- The walls rise with the lid: at the portal the wall top is
				-- 0.6m over the lid bottom, as on level ground (no gap).
				local g = expectGround(along, across, 20, 0)
				local sf = expectSurface(r, g, D)
				for _, side in ipairs({ -1, 1 }) do
					local ws = modelsByTagPrefix(r, "wall_" .. side .. "_")
					local w = ws[#ws].transf
					near(w[13] + w[1], px, 1e-9, tag .. " last wall ends at the portal")
					local wallTop = w[15] + w[11] + w[3]
					local lidBottom = lid[15] + lid[3] * 6 / C + tilt * side * 9
					near(wallTop - lidBottom, 0.6, 1e-9, tag .. " wall top vs lid bottom at the portal")
				end
				-- Shoulders meet without a step at the front of the lid area.
				local lists = r.subconstructions[1].terrainAlignmentLists
				local front = {}
				for _, f in ipairs(lists[2].faces) do
					for _, v in ipairs(f) do
						if math.abs(v[1] - (px - 6.25)) < 1e-9 and math.abs(math.abs(v[2]) - 16) < 1e-9 then
							front[#front + 1] = v
						end
					end
				end
				assert(#front >= 4, tag .. " shoulder vertices at the front of the lid area")
				for _, v in ipairs(front) do near(v[3], sf(v[1], v[2]), 1e-9, tag .. " no shoulder step at the lid front") end
				for _, li in ipairs({ 3, 4 }) do
					for _, f in ipairs(lists[li].faces) do
						for _, v in ipairs(f) do
							if v[1] >= px - 1e-9 then
								-- (level ground at 13m depth already sits 0.05m in)
								local roofHere = roadZ(v[1], 100, D) + 10.55
								assert(v[3] >= roofHere - 0.1, tag .. " list " .. li .. " face cuts into the tunnel")
							end
						end
					end
				end
			end
		end
	end
	end
end)

test("ground: walls start at the road with no step (downhill keeps them at road + 0.3)", function()
	for _, sc in ipairs(slopeCases) do
		local r = oneBox(script.updateFn(defaultCap(), defaultParams({ rtr_ground_along = sc.along, rtr_ground_across = sc.across })))
		local g = expectGround(sc.along, sc.across, 20, 0)
		for _, side in ipairs({ -1, 1 }) do
			local first = modelsByTagPrefix(r, "wall_" .. side .. "_")[1].transf
			eq(first[13], 0, "wall starts at the trench start x = 0")
			local top = first[15] + first[11]
			near(top, math.max(g(0, side * 9), 0) + 0.3, 1e-9, "start top")
			assert(top >= 0.3 - 1e-9, "wall top never below road + 0.3 at the start")
		end
	end
end)

test("ground: coping follows the plane along and across", function()
	local r = script.updateFn(defaultCap(), defaultParams({ rtr_ground_along = 8, rtr_ground_across = 5 }))
	local g = expectGround(8, 5, 20, 0)
	for _, side in ipairs({ -1, 1 }) do
		local copings = modelsByTagPrefix(r, "coping_" .. side .. "_")
		for _, m in ipairs({ copings[1], copings[#copings] }) do
			local t = m.transf
			local xa, xb, y = t[13], t[13] + t[1], t[14]
			-- Uphill: the ground is above the road everywhere along the trench.
			near(t[15], g(xa, y) + 0.28, 1e-9, "coping bottom at start")
			near(t[15] + t[3], g(xb, y) + 0.28, 1e-9, "coping bottom at end")
			-- tilt = transf[7] / transf[6] (both scaled by width / 0.45);
			-- across +5% = right side (-y) higher = falls toward +y.
			near(t[7] / t[6], -0.05, 1e-9, "coping cross tilt")
		end
	end
end)

test("ground: the portal lid lies on the plane", function()
	for _, C in ipairs({ rampGeo.LID_MIN, 13, 18, 24 }) do
	for _, sc in ipairs(slopeCases) do
		local r = oneBox(script.updateFn(defaultCap(), defaultParams({ rtr_ground_along = sc.along, rtr_ground_across = sc.across, rtr_cover_length = C })))
		local g = expectGround(sc.along, sc.across, 20, 0)
		local lid = modelsByTagPrefix(oneBox(r), "portal_top_cover")[1].transf
		local px = portalXOf(r)
		near(lid[13], px - 6, 1e-9, "lid starts 6m before the portal")
		near(lid[1], C, 1e-9, "lid length")
		-- Parallel to the plane; lifted only where downhill ground would
		-- take it into the tunnel (see the steep downhill test), never on
		-- uphill or level ground.
		local lift = lid[15] - (g(px - 6, 0) - 0.3)
		assert(lift >= -1e-9, "lid never below the plane")
		if sc.along >= 0 then near(lift, 0, 1e-9, "uphill / cross only: lid on the plane") end
		near(lid[3], g(px - 6 + C, 0) - g(px - 6, 0), 1e-9, "lid rise follows the plane")
		near(lid[7] / lid[6], -sc.across / 100, 1e-9, "lid cross tilt")
	end
	end
end)

test("ground: shoulder, cover and lid-support faces follow the plane", function()
	for _, sc in ipairs(slopeCases) do
		local r = script.updateFn(defaultCap(), defaultParams({ rtr_ground_along = sc.along, rtr_ground_across = sc.across }))
		local g = expectGround(sc.along, sc.across, 20, 0)
		local lists = r.subconstructions[1].terrainAlignmentLists
		local px = portalXOf(r)
		local lift = liftOf(r, g)
		local sf = expectSurface(r, g)
		for _, f in ipairs(lists[2].faces) do
			local x0 = math.min(f[1][1], f[2][1], f[3][1], f[4][1])
			for _, v in ipairs(f) do
				local want = sf(v[1], v[2])
				-- beside and past the lid the shoulders sit at least at the lid
				if x0 >= px - 6.25 - 1e-9 then want = math.max(want, g(v[1], v[2]) + lift) end
				near(v[3], want, 1e-9, "shoulder vertex on the surface")
			end
		end
		for _, li in ipairs({ 3, 4 }) do
			for _, f in ipairs(lists[li].faces) do
				for _, v in ipairs(f) do near(v[3], g(v[1], v[2]) + lift - 0.55, 1e-9, "list " .. li .. " vertex under the lid") end
			end
		end
		eq(lists[5].type, "EQUAL", "sloped: approach face")
		for _, v in ipairs(lists[5].faces[1]) do
			eq(v[3], -0.25, "approach face at the trench floor level under the level street")
			assert(v[1] >= -20 and v[1] <= 0, "approach face spans the approach")
		end
	end
end)

test("ground: shoulders widen, run past the lid and keep out of the lid area; lid support skips the trench mouth", function()
	for _, C in ipairs({ rampGeo.LID_MIN, 18, 24 }) do
	local r = script.updateFn(defaultCap(), defaultParams({ rtr_ground_along = 5, rtr_cover_length = C }))
	local lists = r.subconstructions[1].terrainAlignmentLists
	local sh = lists[2]
	eq(sh.slopeLow, 0.45, "gentle fill banks")
	eq(sh.slopeHigh, 1, "1:1 cut banks")
	local px = portalXOf(r)
	local coverA, coverB, lidEdge, floorOuter = px - 6.25, px - 6 + C + 0.25, 9 + 2.4 + 0.25, 9 + 0.4
	local maxX, maxY = -math.huge, 0
	local function bbox(f)
		local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
		for _, v in ipairs(f) do
			x0, x1 = math.min(x0, v[1]), math.max(x1, v[1])
			y0, y1 = math.min(y0, v[2]), math.max(y1, v[2])
		end
		return x0, x1, y0, y1
	end
	local function overlaps(f, ax0, ax1, ay0, ay1)
		local x0, x1, y0, y1 = bbox(f)
		return x0 < ax1 - 1e-9 and x1 > ax0 + 1e-9 and y0 < ay1 - 1e-9 and y1 > ay0 + 1e-9
	end
	for _, f in ipairs(sh.faces) do
		local x0, x1, y0, y1 = bbox(f)
		maxX, maxY = math.max(maxX, x1), math.max(maxY, math.abs(y0), math.abs(y1))
		assert(not overlaps(f, coverA, coverB, -lidEdge, lidEdge), "shoulder overlaps the lid area")
		-- counter-clockwise seen from above
		local area = 0
		for k = 1, #f do
			local a, b = f[k], f[k % #f + 1]
			area = area + a[1] * b[2] - b[1] * a[2]
		end
		assert(area > 0, "shoulder face must be counter-clockwise")
	end
	assert(maxX > coverB, "shoulders run on past the lid end")
	near(maxY, 9 + 7, 1e-9, "shoulders reach outer + 7")
	for _, f in ipairs(lists[4].faces) do
		assert(not overlaps(f, coverA, px, -floorOuter, floorOuter), "lid support would fill the trench mouth")
	end
	end
end)

test("ground: the portal search measures the cover from the plane (lower edge of the lid)", function()
	local flat = portalXOf(script.updateFn(defaultCap(), defaultParams()))
	local function check(along, across)
		local r = script.updateFn(defaultCap(), defaultParams({ rtr_ground_along = along, rtr_ground_across = across }))
		local px = portalXOf(r)
		local g = expectGround(along, across, 20, 0)
		local cover = math.min(g(px, -11.65), g(px, 11.65)) - roadZ(px, 100, 16)
		near(cover, 11.55, 1e-6, string.format("cover at the portal (along %d, across %d)", along, across))
		return px
	end
	assert(check(5, 0) < flat - 1, "uphill reaches the cover sooner")
	assert(check(-3, 0) > flat + 1, "downhill pushes the portal on")
	assert(check(0, 10) > flat + 0.5, "a cross slope measures the low side")
	near(check(0, 10), check(0, -10), 1e-9, "cross slope is symmetric for a centred street")
end)

test("ground: the street stays level with the snapped road on a slope", function()
	local flat = script.updateFn(defaultCap(), defaultParams())
	local r = script.updateFn(defaultCap(), defaultParams({ rtr_ground_along = 10, rtr_ground_across = -8 }))
	deepEq(r.snapPoint, flat.snapPoint, "snap point")
	deepEq(r.edgeLists[1], flat.edgeLists[1], "approach edge")
	for _, e in ipairs(r.edgeLists) do
		for _, n in ipairs(e.edges) do
			local x = n[1][1]
			if x <= 100 then near(n[1][3], roadZ(x, 100, 16), 1e-9, "road profile unchanged at x=" .. x) end
		end
	end
end)

test("ground: the plane is anchored at the snap point (parallel one-way lanes)", function()
	-- Two-lane highway x3, right-hand, into tunnel: ys = {-20, 0, 20}, the
	-- snapping carriageway is ys[1] = -20 (see the one-way tests).
	local p = defaultParams({ rtr_street = 4, rtr_count = 3, rtr_ground_across = 10, rtr_ground_along = 4 })
	local r = script.updateFn(defaultCap(), p)
	local ySnap = r.snapPoint.transf[14]
	eq(ySnap, -20, "snapping carriageway")
	local g = expectGround(4, 10, 20, ySnap)
	local outer = 20 + 9 + 1
	local px = portalXOf(r)
	near(math.min(g(px, -outer - 2.65), g(px, outer + 2.65)) - roadZ(px, 100, 16), 11.55, 1e-6, "cover from the snap-anchored plane")
	local lid = modelsByTagPrefix(oneBox(r), "portal_top_cover")[1].transf
	near(lid[15], g(px - 6, 0) - 0.3, 1e-9, "lid on the snap-anchored plane")
end)

test("ground: extreme, out-of-range and odd values stay finite and clamp", function()
	local cap = defaultCap()
	for _, along in ipairs({ -20, -12, 20 }) do
		for _, across in ipairs({ -20, 20 }) do
			for _, approach in ipairs({ 2, 50 }) do
				for _, L in ipairs({ 40, 100 }) do
					local r = script.updateFn(cap, defaultParams({ rtr_ground_along = along, rtr_ground_across = across,
						rtr_approach = approach, rtr_length = L, rtr_street = 7, rtr_count = 3 }))
					allFinite(r, string.format("a%d c%d ap%d L%d", along, across, approach, L))
					assert(#modelsByTagPrefix(r, "wall_1_") >= 1, "walls present")
					local lid = modelsByTagPrefix(oneBox(r), "portal_top_cover")[1].transf
					assert(lid[13] >= 2 - 1e-9, "lid stays on the ramp side of x = 0 (portal >= 8m)")
				end
			end
		end
	end
	-- Steep uphill gives the cover at once: the portal holds at 8m.
	-- (20% over the 50m approach = 10m, plus 25m deep over 40m: cover
	-- 11.55m is reached ~5m in.)
	local up = script.updateFn(cap, defaultParams({ rtr_ground_along = 20, rtr_approach = 50, rtr_length = 40, rtr_depth = 25 }))
	near(modelsByTagPrefix(oneBox(up), "portal_top_cover")[1].transf[13], 2, 1e-9, "minimum open trench")
	-- Steep downhill never gets deep enough: the portal sits at the foot,
	-- so the whole descent is open and only the runout is tunnel.
	local down = script.updateFn(cap, defaultParams({ rtr_ground_along = -20 }))
	eq(portalXOf(down), 100, "portal at the ramp foot")
	-- Clamp and fallbacks.
	local function same(a, b, what)
		deepEq(script.updateFn(cap, defaultParams(a)), script.updateFn(cap, defaultParams(b)), what)
	end
	same({ rtr_ground_along = 300, rtr_ground_across = -300 }, { rtr_ground_along = 20, rtr_ground_across = -20 }, "clamped to +-20")
	same({ rtr_ground_along = "x", rtr_ground_across = 0 / 0 }, {}, "non-numbers fall back to 0")
end)

test("contract: ground slope sliders run -20..+20% in 1% steps, default 0", function()
	data = false
	assert(loadfile(root .. "/content/road_tunnel_ramp/ramp.con.lua"))()
	local byKey = {}
	for _, param in ipairs(data().params) do byKey[param.key] = param end
	for _, key in ipairs({ "rtr_ground_along", "rtr_ground_across" }) do
		local prm = assert(byKey[key], key .. " missing")
		eq(prm.uiType, "Slider", key .. " ui")
		eq(#prm.numbers, 41, key .. " options")
		eq(#prm.values, #prm.numbers, key .. " labels")
		for i, n in ipairs(prm.numbers) do eq(n, i - 21, key .. " option " .. i) end
		eq(prm.numbers[prm.defaultIndex], 0, key .. " default = script fallback 0")
		eq(prm.values[prm.defaultIndex], "0%", key .. " default label")
		eq(prm.values[1], "-20%", key .. " first label")
		eq(prm.values[41], "+20%", key .. " last label")
	end
end)

test("grade: fitGround recovers a plane in the build-menu sign convention", function()
	local p = { rtr_length = 60, rtr_approach = 10 }
	local pts = grade.groundSamples(p)
	eq(#pts, 27, "9 x 3 samples")
	near(pts[1][1], -10, 1e-9, "samples start at the snap end")
	near(pts[#pts][1], 60, 1e-9, "samples end at the ramp foot")
	local zs = {}
	for i, pt in ipairs(pts) do zs[i] = 37 + 0.04 * pt[1] - 0.03 * pt[2] end
	local along, across = grade.fitGround(pts, zs)
	near(along, 4, 1e-9, "along")
	near(across, 3, 1e-9, "across: -y higher = right side higher = positive")
	eq(grade.fitGround({ { 0, 0 }, { 1, 0 }, { 2, 0 } }, { 0, 1, 2 }), nil, "collinear points")
	zs[5] = 0 / 0
	eq(grade.fitGround(pts, zs), nil, "NaN height")
	eq(grade.formatGroundLine("A {along} / C {across}", 3.04, -12.36), "A +3.0% / C -12.4%", "format")
	eq(grade.formatGroundLine("A {along} / C {across}", -0.01, 0.02), "A 0.0% / C 0.0%", "no -0.0%")
end)

test("grade hook: ground line reads the terrain through the placement transf and matches the script's plane", function()
	-- Build the world terrain from the script's own plane (anchored at
	-- the snap point), placed rotated, and check the line reads back the
	-- slope values that make the script fit that terrain.
	local along, across, approach = 6, -4, 20
	local ox, oy, ang = 1000, -500, math.rad(130)
	local c, s = math.cos(ang), math.sin(ang)
	local g = expectGround(along, across, approach, 0)
	local function worldHeight(wx, wy)
		local dx, dy = wx - ox, wy - oy
		local x, y = dx * c + dy * s, -dx * s + dy * c  -- back to local
		return 200 + g(x, y)
	end
	local params = { rtr_length = 100, rtr_depth = 16, rtr_curvature = 3, rtr_approach = approach }
	local cru, logs = loadGradeHook({ "road_tunnel_ramp/ramp.con" }, params, fakeApi(worldHeight))
	local lines = cru.getActionParams().constructionActionParams.getProposalStringsFn(fakeProposal(ox, oy, ang), {})
	eq(lines[3], "地面の勾配: 縦断 +6.0%、横断 -4.0%", "measured line")
	eq(#logs, 0, "silent on success")
end)

test("grade hook: unreadable placement skips only the ground line and logs once", function()
	local params = { rtr_length = 40, rtr_depth = 16, rtr_curvature = 3 }
	local cru, logs = loadGradeHook({ "road_tunnel_ramp/ramp.con" }, params)
	local action = cru.getActionParams().constructionActionParams
	for _ = 1, 3 do
		local lines = action.getProposalStringsFn({}, {})
		eq(#lines, 2, "base + max grade only")
		eq(lines[2], "最大勾配: 60.0%", "max grade still shown")
	end
	eq(#logs, 1, "one log line")
	assert(logs[1]:find("transf not readable", 1, true), logs[1])
	-- An empty proposal (nothing under the cursor yet) is not a failure.
	local cru3, logs3 = loadGradeHook({ "road_tunnel_ramp/ramp.con" }, params)
	local empty = { toAdd_native = { size = function() return 0 end, at = function() error("empty") end } }
	eq(#cru3.getActionParams().constructionActionParams.getProposalStringsFn(empty, {}), 2, "no ground line")
	eq(#logs3, 0, "empty proposal stays silent")
	-- A throwing terrain read is caught the same way.
	local cru2, logs2 = loadGradeHook({ "road_tunnel_ramp/ramp.con" }, params, fakeApi(function() error("boom") end))
	local a2 = cru2.getActionParams().constructionActionParams
	eq(#a2.getProposalStringsFn(fakeProposal(0, 0, 0), {}), 2, "no ground line when the read throws")
	a2.getProposalStringsFn(fakeProposal(0, 0, 0), {})
	eq(#logs2, 1, "logged once")
	assert(logs2[1]:find("ground line failed", 1, true), logs2[1])
end)

------------------------------------------------------------------------
-- The data() of another content file (a con file's or a script's).
------------------------------------------------------------------------
local function loadData(path)
	local saved = data
	data = false
	assert(loadfile(root .. path))()
	local d = data()
	data = saved
	return d
end

------------------------------------------------------------------------
-- Median tunnel approach, rebuilt as a set (2026-11-24; user: 「1. 作り
-- 直してください」): the full-width ramp's body for a two-lane centre
-- (ramp_geometry.lua), a one-way side street either side, handed over
-- (median_geometry.lua). No script joins them: the player lays the fork and
-- the merge (2026-11-24).
------------------------------------------------------------------------
-- Lane list of a template of this mod from its resource name.
local function templateOf(ref)
	local path = ref:match("^road_tunnel_ramp::(/.*)$")
	assert(path, "not a road_tunnel_ramp resource: " .. tostring(ref))
	return loadData("/content" .. path .. ".lua")
end
local function laneWidth(t)
	local w = 0
	for _, lane in ipairs(t.laneConfigs) do w = w + lane.width end
	return w
end
local function hasMode(lane, mode)
	for _, m in ipairs(lane.transportModes) do if m == mode then return true end end
	return false
end

local medianSpec = loadData("/content/road_tunnel_ramp/median.con.lua")
local medianCap = medianSpec.updateScript.params
local median = loadData("/content/road_tunnel_ramp/median.script.lua")
local medianGeo = require "road_tunnel_ramp::/road_tunnel_ramp/median_geometry.lua"
local medianParam = {}
for _, prm in ipairs(medianSpec.params) do medianParam[prm.key] = prm end

-- Exact comparison of two values made of tables, strings, numbers and
-- booleans; the path of the first difference.
local function sameValue(a, b, path)
	path = path or "r"
	if type(a) ~= type(b) then return false, path .. ": " .. type(a) .. " vs " .. type(b) end
	if type(a) ~= "table" then
		if a ~= b then return false, path .. ": " .. tostring(a) .. " vs " .. tostring(b) end
		return true
	end
	for k, v in pairs(a) do
		local ok, why = sameValue(v, b[k], path .. "." .. tostring(k))
		if not ok then return false, why end
	end
	for k in pairs(b) do
		if a[k] == nil then return false, path .. "." .. tostring(k) .. ": missing on the left" end
	end
	return true
end
local function copy(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in pairs(t) do o[k] = copy(v) end
	return o
end
local function with(p, extra)
	local q = copy(p or {})
	for k, v in pairs(extra or {}) do q[k] = v end
	return q
end
-- The median's result split into the side streets (their template is a
-- side one) and the rest.
local SIDE_REFS = {}
for _, e in pairs(medianGeo.ENTRIES) do
	SIDE_REFS[e.side.right] = true
	SIDE_REFS[e.side.left] = true
end
-- The median's result split into the body, its side streets and the
-- ground held under them (the last terrain list, median_geometry.build
-- appends it after the body's).
local function splitSides(r)
	local body, sides = copy(r), {}
	body.edgeLists = {}
	for _, e in ipairs(r.edgeLists) do
		if SIDE_REFS[e.params.type] then sides[#sides + 1] = e else body.edgeLists[#body.edgeLists + 1] = copy(e) end
	end
	local lists = body.subconstructions[1].terrainAlignmentLists
	local ground = table.remove(lists)
	return body, sides, ground
end
local function sideAt(sides, ySign)
	for _, e in ipairs(sides) do
		if (e.edges[1][1][2] > 0) == (ySign > 0) then return e end
	end
end

-- Settings the body comparison sweeps (each also with the thick wall).
local bodyCases = {
	{},
	{ rtr_length = 40, rtr_depth = 25, rtr_curvature = 5 },
	{ rtr_length = 70, rtr_depth = 13, rtr_curvature = 1, rtr_approach = 2 },
	{ rtr_approach = 50, rtr_curvature = 4 },
	{ rtr_ground_along = 6, rtr_ground_across = -4 },
	{ rtr_ground_along = -12, rtr_ground_across = 5, rtr_length = 60 },
	{ rtr_ground_along = 20, rtr_ground_across = 20 },
	{ rtr_direction = 2, rtr_side = 2 },
	{ rtr_car_only_variant = 2 },
	{ rtr_car_only_variant = 3, rtr_ground_along = 3 },
}

test("median: con offers entry, centre, wall, length, approach, depth, direction, side, curvature and the slopes, nothing else", function()
	local keys = {}
	for _, prm in ipairs(medianSpec.params) do keys[#keys + 1] = prm.key end
	eq(table.concat(keys, " "), "rtr_median_entry rtr_street rtr_wall rtr_cover_length rtr_length rtr_approach rtr_depth "
		.. "rtr_direction rtr_side rtr_curvature rtr_ground_along rtr_ground_across", "menu keys")
	local function pick(prm) return prm.numbers[prm.defaultIndex] end
	eq(table.concat(medianParam.rtr_median_entry.numbers, ","), "2,4,6", "entries")
	eq(pick(medianParam.rtr_median_entry), 4, "entry 4 initially")
	eq(table.concat(medianParam.rtr_street.numbers, ","), "1,2,3,8", "centres: the ramp's two-lane entries")
	eq(pick(medianParam.rtr_street), 8, "cars-only initially")
	eq(table.concat(medianParam.rtr_wall.numbers, ","), "1,2", "walls")
	eq(pick(medianParam.rtr_wall), 1, "1.5m initially")
	-- labels and the street behind each number are the full-width ramp's
	local rampSpec = loadData("/content/road_tunnel_ramp/ramp.con.lua")
	local rampStreet
	for _, prm in ipairs(rampSpec.params) do if prm.key == "rtr_street" then rampStreet = prm end end
	local rampCap = rampSpec.updateScript.params
	for i, n in ipairs(medianParam.rtr_street.numbers) do
		eq(medianParam.rtr_street.values[i], rampStreet.values[n], "label of " .. n)
		local ok, why = sameValue(medianGeo.CENTRES[n], rampCap.streets[n], "centre " .. n)
		assert(ok, why)
		eq(medianGeo.CENTRE_ORDER[i], n, "module order")
	end
	-- the same sliders as the full-width ramp
	for _, prm in ipairs(rampSpec.params) do
		local m = medianParam[prm.key]
		if m and prm.key ~= "rtr_street" and prm.key ~= "rtr_approach" then
			local ok, why = sameValue(m.numbers, prm.numbers, prm.key .. ".numbers")
			assert(ok, why)
			eq(m.defaultIndex, prm.defaultIndex, prm.key .. " initial")
			eq(m.uiType, prm.uiType, prm.key .. " uiType")
		end
	end
	-- the approach from 30m (APPROACH_MIN: room for a fork laid from the
	-- snap point), in the ramp's 2m steps
	eq(medianParam.rtr_approach.numbers[1], 30, "approach from 30m")
	eq(medianParam.rtr_approach.numbers[#medianParam.rtr_approach.numbers], 50, "to 50m")
	eq(pick(medianParam.rtr_approach), 30, "30m initially")
	eq(medianGeo.APPROACH_MIN, 30, "approach min")
	eq(medianCap.tunnelRef, rampCap.tunnelRef, "tunnel")
	eq(medianCap.tunnelHeight, rampCap.tunnelHeight, "tunnel height")
end)

test("median: the centre is exactly the full-width ramp's body for that street (every centre, wall and swept setting)", function()
	local n = 0
	for _, c in ipairs(medianGeo.CENTRE_ORDER) do
		for _, wall in ipairs({ 1, 2 }) do
			for i, base in ipairs(bodyCases) do
				local p = with(base, { rtr_street = c, rtr_wall = wall })
				local body, sides = splitSides(median.updateFn(medianCap, p))
				assert(#sides >= 2, "side streets")
				-- the ramp at the approach the median raises it to
				local ramp = script.updateFn(defaultCap(), with(p, { rtr_count = 1,
					rtr_approach = math.max(p.rtr_approach or 20, 30) }))
				local ok, why = sameValue(body, ramp, string.format("centre %d wall %d case %d", c, wall, i))
				assert(ok, why)
				n = n + 1
			end
		end
	end
	eq(n, 4 * 2 * #bodyCases, "cases")
end)

test("median: the body ignores the ramp-only params (count, hand-over), the median's own (entry) and the removed fork and exit", function()
	local ref = splitSides(median.updateFn(medianCap, {}))
	for _, extra in ipairs({ { rtr_count = 3 }, { rtr_approach_hand_over = 0 }, { rtr_approach_hand_over = 2 },
		{ rtr_median_entry = 2 }, { rtr_median_entry = 6 } }) do
		local body = splitSides(median.updateFn(medianCap, extra))
		local ok, why = sameValue(body, ref, "body")
		assert(ok, why)
	end
	-- the removed settings (and the 2+2 plan) change nothing at all
	for _, extra in ipairs({ { rtr_median_exit = 1 }, { rtr_median_exit = 4 }, { rtr_median_fork = 1 }, { rtr_median_fork = 2 },
		{ rtr_median_fork = 2, rtr_median_fork22_plan = 5 } }) do
		local ok, why = sameValue(median.updateFn(medianCap, extra), median.updateFn(medianCap, {}), "removed setting")
		assert(ok, why)
	end
end)

test("median: defaults and junk read as the menu's initial settings (entry 4, cars-only, 1.5m wall)", function()
	local ref = median.updateFn(medianCap, {
		rtr_median_entry = 4, rtr_street = 8, rtr_wall = 1,
		rtr_length = 100, rtr_approach = 30, rtr_depth = 16, rtr_curvature = 3,
		rtr_direction = 1, rtr_side = 1, rtr_ground_along = 0, rtr_ground_across = 0 })
	for _, p in ipairs({ {}, { rtr_street = 4 }, { rtr_street = 7 }, { rtr_street = 0 }, { rtr_street = "x" },
		{ rtr_street = 0 / 0 }, { rtr_street = 8.2 }, { rtr_median_entry = 3.5 }, { rtr_median_entry = "x" },
		{ rtr_wall = "x" }, { rtr_wall = 0 / 0 }, { rtr_approach = 2 }, { rtr_approach = 29 } }) do
		local ok, why = sameValue(median.updateFn(medianCap, p), ref, "params")
		assert(ok, why)
	end
	local s = medianGeo.spec(medianCap, {})
	eq(s.wall.key, "thin", "thin wall without rtr_wall")
	eq(s.street.ref, medianGeo.CENTRES[8].ref, "cars-only centre")
	eq(s.count, 1, "one street")
	eq(s.handOver, true, "approach handed over")
	eq(medianGeo.entryOf({ rtr_median_entry = 1 }), 2, "entry 1 -> 2")
	eq(medianGeo.entryOf({ rtr_median_entry = 3 }), 4, "entry 3 -> 4")
	eq(medianGeo.entryOf({ rtr_median_entry = 5 }), 6, "entry 5 -> 6")
	eq(medianGeo.entryOf({ rtr_median_entry = 9 }), 6, "entry 9 -> 6")
	eq(medianGeo.centreOf({ rtr_street = 2.4 }), 2, "2.4 -> 2")
end)

-- Y with each centre, entry and wall: coping's outer edge + half the side
-- street (GAP 0 since 2026-11-24: 0.5m before; the thin wall 1.5m since
-- then, 2.0m before). Written out so a change to any of them shows.
local Y = {
	-- [centre] = { [entry] = { thin, thick } }
	[1] = { [2] = { 9.25, 11.15 }, [4] = { 9.25, 11.15 }, [6] = { 11.75, 13.65 } },
	[2] = { [2] = { 11.75, 13.65 }, [4] = { 11.75, 13.65 }, [6] = { 14.25, 16.15 } },
	[3] = { [2] = { 12.75, 14.65 }, [4] = { 12.75, 14.65 }, [6] = { 15.25, 17.15 } },
	[8] = { [2] = { 8.75, 10.65 }, [4] = { 8.75, 10.65 }, [6] = { 11.25, 13.15 } },
}

test("median: with the initial settings, entry 4 is the four-lane street's 24m across: 6.5 + 1.5 + 8 + 1.5 + 6.5", function()
	-- (the user, 2026-11-24: 「24mを目指したいですね。そうすると、4車線の幅に
	-- おさまるのでアップグレードツールが可能になるのでは」)
	local p = { rtr_median_entry = 4 }
	local lay = medianGeo.layout(medianGeo.spec(medianCap, p), p)
	local g = lay.g
	eq(g.halfWidth * 2, 8, "centre 8m")
	near(g.copingOut - g.halfWidth, 1.5, 1e-12, "wall 1.5m each side")
	eq(lay.side.width, 6.5, "side street 6.5m")
	near(lay.y + lay.side.width * 0.5, 12, 1e-12, "side streets' outer edges at +-12m")
	near(lay.y - lay.side.width * 0.5, g.copingOut, 1e-12, "side street against the coping")
	eq(medianGeo.ENTRIES[4].street.width, 24, "the four-lane street")
	-- as built: the side streets' outer edges
	local _, sides = splitSides(median.updateFn(medianCap, p))
	for _, ySign in ipairs({ -1, 1 }) do
		near(math.abs(sideAt(sides, ySign).edges[1][1][2]) + 3.25, 12, 1e-12, "built at +-12m, side " .. ySign)
	end
end)

test("median: entry table: 2 and 4 get the one-lane side street (6.5m), 6 the two-lane one (11.5m), sidewalk outside only", function()
	local want = { [2] = { "median_side", 6.5, 1, "town_new_small", 16 }, [4] = { "median_side", 6.5, 1, "town_new_medium", 24 },
		[6] = { "median_c_side", 11.5, 2, "town_new_large", 32 } }
	for entry, w in pairs(want) do
		local E = medianGeo.ENTRIES[entry]
		eq(E.side.right, "road_tunnel_ramp::/road_tunnel_ramp/streets/" .. w[1] .. "_r.street_template", entry .. " right")
		eq(E.side.left, "road_tunnel_ramp::/road_tunnel_ramp/streets/" .. w[1] .. "_l.street_template", entry .. " left")
		eq(E.side.width, w[2], entry .. " width")
		eq(E.side.lanes, w[3], entry .. " lanes")
		eq(E.street.ref, "::/infrastructure/street/town/" .. w[4] .. ".street_template", entry .. " entry street")
		eq(E.street.width, w[5], entry .. " entry street width")
		for _, which in ipairs({ "right", "left" }) do
			local t = templateOf(E.side[which])
			eq(laneWidth(t), w[2], entry .. " " .. which .. ": laneConfigs add up")
			local cars, people = 0, {}
			for i, lane in ipairs(t.laneConfigs) do
				if hasMode(lane, "CAR") then
					cars = cars + 1
					assert(lane.forward, entry .. " " .. which .. ": every car lane forward (one-way)")
				end
				if hasMode(lane, "PERSON") then people[#people + 1] = i end
			end
			eq(cars, w[3], entry .. " " .. which .. ": car lanes")
			eq(#people, 1, entry .. " " .. which .. ": one sidewalk")
			-- laneConfigs run left to right in the build direction
			eq(people[1], which == "right" and #t.laneConfigs or 1, entry .. " " .. which .. ": sidewalk on that side")
			-- the trench side keeps house plots off
			local deco = t.defaultEdgeDecorations[1]
			eq(deco[1], "road_tunnel_ramp::/road_tunnel_ramp/streets/median_inner.edge", "preventParcels decoration")
			eq(deco[2], which == "right", entry .. " " .. which .. ": decoration on the trench side (true = left)")
		end
	end
end)

-- The walls' and the lid's run along x as built: from the first wall
-- model's start to the portal cover slab's far end (its origin + its x
-- column), read off the models, not off the layout, so the side streets
-- are held to what is drawn.
local function wallsAndLid(r)
	r = oneBox(r)
	local x0 = math.huge
	for _, m in ipairs(modelsByTagPrefix(r, "wall_")) do x0 = math.min(x0, m.transf[13]) end
	local lid = modelsByTagPrefix(oneBox(r), "portal_top_cover")[1]
	assert(lid, "the portal cover")
	return x0, lid.transf[13] + lid.transf[1]
end
-- Each side's run along x over all its pieces, and its two end nodes.
local function sideRun(sides, ySign)
	local lo, hi, ends = math.huge, -math.huge, {}
	for _, e in ipairs(sides) do
		if (e.edges[1][1][2] > 0) == (ySign > 0) then
			for k, n in ipairs(e.edges) do
				local x = n[1][1]
				local free = false
				for _, f in ipairs(e.freeNodes) do if f == k - 1 then free = true end end
				local snap = false
				for _, f in ipairs(e.snapNodes) do if f == k - 1 then snap = true end end
				if x < lo - 1e-9 then lo = x; ends.lo = { free = free, snap = snap } end
				if x > hi + 1e-9 then hi = x; ends.hi = { free = free, snap = snap } end
			end
		end
	end
	return lo, hi, ends
end

test("median: the side streets lie straight at +-Y (coping's edge + half the side street), beside the walls and the lid (trench start to the lid's end)", function()
	for _, c in ipairs(medianGeo.CENTRE_ORDER) do
		for _, entry in ipairs({ 2, 4, 6 }) do
			for wall = 1, 2 do
				for _, base in ipairs({ {}, { rtr_length = 60, rtr_approach = 2 }, { rtr_approach = 50, rtr_length = 40 } }) do
					local p = with(base, { rtr_street = c, rtr_median_entry = entry, rtr_wall = wall })
					local tag = string.format("centre %d entry %d wall %d", c, entry, wall)
					local _, sides = splitSides(median.updateFn(medianCap, p))
					local g = medianGeo.layout(medianGeo.spec(medianCap, p), p).g
					local y = Y[c][entry][wall]
					local E = medianGeo.ENTRIES[entry]
					near(y, g.copingOut + E.side.width * 0.5, 1e-9, tag .. ": Y formula")
					near(y - E.side.width * 0.5 - g.copingOut, 0, 1e-9, tag .. ": inner edge on the coping's and lid's outer edge")
					local L = p.rtr_length or 100
					for _, ySign in ipairs({ -1, 1 }) do
						local e = assert(sideAt(sides, ySign), tag .. ": side " .. ySign)
						eq(e.params.type, E.side.right, tag .. ": right-hand template")
						eq(e.type, "STREET", tag .. ": street")
						eq(e.edgeType, nil, tag .. ": on the surface")
						eq(e.alignTerrain, false, tag .. ": no own terrain")
						local a, b = e.edges[1], e.edges[2]
						near(a[1][2], ySign * y, 1e-9, tag .. ": start at Y")
						near(b[1][2], ySign * y, 1e-9, tag .. ": end at Y")
						eq(a[2][2], 0, tag .. ": straight")
						eq(b[2][2], 0, tag .. ": straight")
						local x0, x1 = math.min(a[1][1], b[1][1]), math.max(a[1][1], b[1][1])
						near(x0, 0, 1e-9, tag .. ": starts at the trench start")
						near(x1, g.lidB, 1e-9, tag .. ": ends with the lid")
						near(x1, g.portalX + 12, 1e-9, tag .. ": the lid's end, 12m past the portal (18m in all, initially)")
						assert(x1 < L + 30 - 1e-9, tag .. ": short of the runout's end")
						near(math.abs(a[2][1]), x1 - x0, 1e-9, tag .. ": tangent as long as the edge")
						eq(a[1][3], 0, tag .. ": level ground, z 0")
						eq(b[1][3], 0, tag .. ": level ground, z 0")
					end
				end
			end
		end
	end
end)

-- The user, 2026-11-24: 「側道の長さは、擁壁部＋蓋と同じ長さに自動的に調整
-- されるようにしてください」. Every length and entry, the slider ends among
-- them, with the depth, curvature, centre, wall and slopes that move the
-- portal; downhill the side streets come in pieces, so the run is taken
-- over all of them.
test("median: each side street runs exactly the walls' and the lid's length, whatever the length, entry, depth and slopes; both ends free", function()
	local cases, lengths = 0, {}
	for _, L in ipairs({ 40, 42, 70, 98, 100, 400 }) do
		for _, entry in ipairs({ 2, 4, 6 }) do
			for _, extra in ipairs({ {}, { rtr_depth = 13, rtr_curvature = 1 }, { rtr_depth = 25, rtr_curvature = 5 },
				{ rtr_street = 3, rtr_wall = 2 }, { rtr_ground_along = 8, rtr_ground_across = -3 },
				{ rtr_ground_along = -12, rtr_ground_across = 5 }, { rtr_ground_along = -20, rtr_ground_across = -20 },
				{ rtr_approach = 50, rtr_side = 2 } }) do
				local p = with(extra, { rtr_length = L, rtr_median_entry = entry })
				local tag = string.format("L %d entry %d case %s", L, entry, table.concat((function()
					local t = {}
					for k, v in pairs(extra) do t[#t + 1] = k .. "=" .. tostring(v) end
					table.sort(t)
					return t
				end)(), ","))
				local r = median.updateFn(medianCap, p)
				local wx0, wx1 = wallsAndLid(r)
				local _, sides = splitSides(r)
				for _, ySign in ipairs({ -1, 1 }) do
					local lo, hi, ends = sideRun(sides, ySign)
					near(lo, wx0, 1e-9, tag .. ": starts with the walls, side " .. ySign)
					near(hi, wx1, 1e-9, tag .. ": ends with the lid, side " .. ySign)
					near(hi - lo, wx1 - wx0, 1e-9, tag .. ": as long as walls + lid, side " .. ySign)
					assert(ends.lo.free and ends.hi.free, tag .. ": both ends free nodes, side " .. ySign)
					assert(not ends.lo.snap and not ends.hi.snap, tag .. ": neither end a snap node, side " .. ySign)
					-- pieces in a row, no gap, no overlap
					local span = 0
					for _, e in ipairs(sides) do
						if (e.edges[1][1][2] > 0) == (ySign > 0) then span = span + math.abs(e.edges[2][1][1] - e.edges[1][1][1]) end
					end
					near(span, hi - lo, 1e-9, tag .. ": the pieces cover the run once, side " .. ySign)
				end
				if next(extra) == nil and entry == 4 then lengths[L] = wx1 - wx0 end
				cases = cases + 1
			end
		end
	end
	eq(cases, 6 * 3 * 8, "cases")
	-- it follows the length (the portal moves with it), not a fixed run
	assert(lengths[40] < lengths[70] and lengths[70] < lengths[100] and lengths[100] < lengths[400], "longer with the length")
	-- the slider's ends, written out (initial settings otherwise): the
	-- portal by the cover search, + 12m of lid (18m from 6m in front)
	for L, len in pairs(lengths) do
		local g = medianGeo.layout(medianGeo.spec(medianCap, { rtr_length = L }), {}).g
		near(len, g.portalX + 12, 1e-9, "L " .. L)
	end
end)

test("median: right-hand traffic runs the -Y side toward the tunnel and +Y away, sidewalk outside; left-hand mirrors it with the _l templates", function()
	for _, entry in ipairs({ 2, 4, 6 }) do
		for _, sideOpt in ipairs({ 1, 2 }) do
			local _, sides = splitSides(median.updateFn(medianCap, { rtr_median_entry = entry, rtr_side = sideOpt }))
			local E = medianGeo.ENTRIES[entry]
			for _, ySign in ipairs({ -1, 1 }) do
				local e = sideAt(sides, ySign)
				local towardTunnel = e.edges[2][1][1] > e.edges[1][1][1]
				eq(towardTunnel, (ySign == -1) == (sideOpt == 1), string.format("entry %d side %d y %d direction", entry, sideOpt, ySign))
				eq(e.params.type, sideOpt == 1 and E.side.right or E.side.left, "template")
				-- the tangent points the way the edge runs
				eq(e.edges[1][2][1] > 0, towardTunnel, "tangent a")
				eq(e.edges[2][2][1] > 0, towardTunnel, "tangent b")
				-- seen along travel, the sidewalk side (right / left) is
				-- the outside: right of +x is -y
				local rightOfTravel = towardTunnel and -1 or 1
				eq(sideOpt == 1, rightOfTravel == ySign, "sidewalk outside")
			end
		end
	end
end)

test("median: hand-over: the approach and both side streets free at both ends, the descent's start free, the rest kept; one snap point", function()
	for _, c in ipairs(medianGeo.CENTRE_ORDER) do
		for _, p in ipairs({ { rtr_street = c }, { rtr_street = c, rtr_direction = 2 }, { rtr_street = c, rtr_ground_along = 5 } }) do
			local r = median.updateFn(medianCap, p)
			local body, sides = splitSides(r)
			for _, e in ipairs(sides) do
				eq(table.concat(e.freeNodes, ","), "0,1", "side street free at both ends")
				eq(#e.snapNodes, 0, "side street snaps nowhere")
			end
			local approach = 30
			local frees, snaps = {}, 0
			for _, e in ipairs(body.edgeLists) do
				for _, k in ipairs(e.freeNodes) do
					local n = e.edges[k + 1][1]
					frees[#frees + 1] = string.format("%g", n[1])
				end
				snaps = snaps + #e.snapNodes
			end
			table.sort(frees, function(a, b) return tonumber(a) < tonumber(b) end)
			-- the approach (both ends) and the descent's start, which share x = 0
			eq(table.concat(frees, ","), string.format("%g,0,0", -approach), "centre " .. c .. ": free nodes")
			eq(snaps, 2, "centre " .. c .. ": the approach's start and the runout's end snap")
			near(r.snapPoint.transf[13], -approach, 1e-9, "snap point at the approach start")
			near(r.snapPoint.transf[14], 0, 1e-9, "on the centre line")
		end
	end
end)

test("median: level and uphill ground: each side street one straight edge on the plane", function()
	for _, sl in ipairs({ { 0, 0 }, { 6, 0 }, { 20, 0 }, { 3, 0 } }) do
		local p = { rtr_ground_along = sl[1], rtr_ground_across = sl[2], rtr_approach = 30, rtr_length = 80 }
		local _, sides = splitSides(median.updateFn(medianCap, p))
		eq(#sides, 2, "one edge each side")
		local gx, gy = sl[1] / 100, -sl[2] / 100
		for _, e in ipairs(sides) do
			for _, n in ipairs(e.edges) do
				local x, y = n[1][1], n[1][2]
				near(n[1][3], gx * (x + 30) + gy * y, 1e-9, "node on the plane")
				near(n[2][3], gx * n[2][1], 1e-9, "tangent along the plane")
			end
		end
	end
end)

-- Review 2026-11-24: on downhill ground the body's banks beside the trench
-- stay at the road near the mouth and rise with a lifted lid, over the
-- plane by metres (-12% along: 8.9m and more), and a side street on the
-- plane had its inner edge buried in them.
test("median: downhill and cross slopes: the side streets follow the banks at their inner edge, never under the plane, in pieces of 5m at most", function()
	local function hermite(a, b, u)
		local h00, h10 = 2 * u ^ 3 - 3 * u ^ 2 + 1, u ^ 3 - 2 * u ^ 2 + u
		local h01, h11 = -2 * u ^ 3 + 3 * u ^ 2, u ^ 3 - u ^ 2
		return h00 * a[1][3] + h10 * a[2][3] + h01 * b[1][3] + h11 * b[2][3],
			h00 * a[1][1] + h10 * a[2][1] + h01 * b[1][1] + h11 * b[2][1]
	end
	local followed = 0
	for _, sl in ipairs({ { -5, 0 }, { -12, 5 }, { -20, -20 }, { 0, 7 }, { -3, -4 } }) do
		for _, depth in ipairs({ 13, 25 }) do
			for _, entry in ipairs({ 4, 6 }) do
				local p = { rtr_ground_along = sl[1], rtr_ground_across = sl[2], rtr_depth = depth, rtr_median_entry = entry, rtr_length = 60 }
				local tag = string.format("along %d across %d depth %d entry %d", sl[1], sl[2], depth, entry)
				local spec = medianGeo.spec(medianCap, p)
				local lay = medianGeo.layout(spec, p)
				local g = lay.g
				local _, sides = splitSides(median.updateFn(medianCap, p))
				local nodesAt, perSide = {}, { [-1] = 0, [1] = 0 }
				for _, e in ipairs(sides) do
					local k = e.edges[1][1][2] > 0 and 1 or -1
					perSide[k] = perSide[k] + 1
				end
				for _, e in ipairs(sides) do
					local a, b = e.edges[1], e.edges[2]
					local y = a[1][2]
					local ySign = y > 0 and 1 or -1
					local yIn = ySign * (lay.y - lay.side.width * 0.5)
					if perSide[ySign] > 1 then
						assert(math.abs(b[1][1] - a[1][1]) <= medianGeo.PIECE + 1e-9, tag .. ": piece length")
					end
					for k = 0, 10 do
						local z, x = hermite(a, b, k / 10)
						local want = math.max(g.ground(x, y), medianGeo.bankZ(g, x, yIn))
						-- within a piece the curve may cut a corner where
						-- the banks kink between nodes (the road meeting the
						-- lifted plane: 0.32m at most in 5m pieces here),
						-- never by metres
						assert(z >= want - 0.35, string.format("%s: x %.1f z %.2f under the bank %.2f", tag, x, z, want))
						assert(z >= g.ground(x, y) - 0.35, tag .. ": under the plane")
					end
					for _, n in ipairs({ a, b }) do
						local x = n[1][1]
						near(n[1][3], math.max(g.ground(x, y), medianGeo.bankZ(g, x, yIn)), 1e-9, tag .. ": node on the bank")
						local key = string.format("%d:%.6f", ySign, x)
						if nodesAt[key] then
							near(nodesAt[key][1], n[2][3] / n[2][1], 1e-9, tag .. ": one slope where pieces meet")
						else
							nodesAt[key] = { n[2][3] / n[2][1] }
						end
					end
				end
				if #sides > 2 then followed = followed + 1 end
			end
		end
	end
	assert(followed >= 10, "downhill cases cut into pieces: " .. followed)
end)

test("median: the ground under each side street is held at its height, coping edge to 0.5m past its outer edge, both sides alike", function()
	-- (the 0.5m strip between the coping and the side street showed as a
	-- ditch on one side and as green ground with cut banks on the other,
	-- the user's manual check 2026-11-24; the body's shoulders end at
	-- shoulderOut, short of the side street's outer edge)
	local cases = { {}, { rtr_median_entry = 6, rtr_wall = 2 }, { rtr_street = 1 }, { rtr_side = 2 },
		{ rtr_ground_along = 6, rtr_ground_across = -4 }, { rtr_ground_along = -12, rtr_ground_across = 5, rtr_length = 60 } }
	for k, p in ipairs(cases) do
		local tag = "case " .. k
		local _, sides, ground = splitSides(median.updateFn(medianCap, p))
		local lay = medianGeo.layout(medianGeo.spec(medianCap, p), p)
		local g = lay.g
		eq(ground.type, "EQUAL", tag .. ": EQUAL")
		eq(ground.optional, true, tag .. ": optional, as the body's")
		local yIn, yOut = g.copingOut, lay.y + lay.side.width * 0.5 + medianGeo.GROUND_PAD
		assert(yOut > g.shoulderOut, tag .. ": reaches past the body's shoulders")
		-- the side street's height at x on side ySign, from its pieces
		local function streetZ(ySign, x)
			for _, e in ipairs(sides) do
				local a, b = e.edges[1], e.edges[2]
				if (a[1][2] > 0) == (ySign > 0) then
					local xa, xb = math.min(a[1][1], b[1][1]), math.max(a[1][1], b[1][1])
					if x >= xa - 1e-9 and x <= xb + 1e-9 then
						local za = a[1][1] < b[1][1] and a[1][3] or b[1][3]
						local zb = a[1][1] < b[1][1] and b[1][3] or a[1][3]
						if xb - xa < 1e-9 then return za end
						return za + (zb - za) * (x - xa) / (xb - xa)
					end
				end
			end
		end
		local cover = { [-1] = 0, [1] = 0 }
		for _, f in ipairs(ground.faces) do
			eq(#f, 4, tag .. ": quads")
			local area = 0
			for i = 1, 4 do
				local a, b = f[i], f[i % 4 + 1]
				area = area + a[1] * b[2] - b[1] * a[2]
			end
			assert(area > 0, tag .. ": counter-clockwise")
			local ySign = f[1][2] > 0 and 1 or -1
			local ys = {}
			for _, v in ipairs(f) do
				ys[#ys + 1] = math.abs(v[2])
				local z = streetZ(ySign, v[1])
				-- the straight edge's chord, the pieces' end heights: on level
				-- and uphill ground exact; in pieces the chord is the face's
				assert(z, tag .. ": a vertex where no side street is (x " .. v[1] .. ")")
				near(v[3], z, 1e-6, tag .. ": at the street's height")
			end
			table.sort(ys)
			-- beside the cover from its LESS face's edge, elsewhere from the
			-- coping's: never on the cover's ground (review, 2026-11-24)
			local xm = (f[1][1] + f[2][1]) * 0.5
			local coverA, coverB = g.portalX - 6.25, g.portalX + 30.25
			local besideCover = xm > coverA and xm < coverB
			near(ys[1], besideCover and g.lidEdge or yIn, 1e-9, tag .. ": from the coping's (or the cover's) outer edge")
			if not besideCover then
				assert(math.max(f[1][1], f[2][1]) <= coverA + 1e-9 or math.min(f[1][1], f[2][1]) >= coverB - 1e-9,
					tag .. ": a face from the coping's edge runs into the cover's x range")
			end
			near(ys[4], yOut, 1e-9, tag .. ": to 0.5m past the street's outer edge")
			cover[ySign] = cover[ySign] + math.abs(f[2][1] - f[1][1])
		end
		for _, ySign in ipairs({ -1, 1 }) do
			near(cover[ySign], lay.x1 - lay.x0, 1e-6, tag .. ": the whole run on side " .. ySign)
		end
	end
end)

test("median: the side streets' styles are town_new.street with their street assets on the sidewalk's side only, the light town_old's post-top lamp", function()
	-- (the user, 2026-11-24: the lights both sides met over the 7.5m side
	-- street as an arch; with oneSideOnly the offset runs from the left edge)
	local zip = os.getenv("HOME") .. "/.local/share/Steam/steamapps/common/Transport Fever 3/base/content/infrastructure/street.zip"
	local base
	local fh = io.open(zip, "rb")
	if fh then
		fh:close()
		local pp = assert(io.popen(string.format("unzip -p %q %q 2>/dev/null", zip, "street/town/town_new.street.lua")))
		local src = pp:read("*a"); pp:close()
		local saved = data; data = false; assert(load(src))(); base = data(); data = saved
	end
	local function abs(name)
		if name:match("^mat/") then return "::/infrastructure/street/town/" .. name end
		if name:match("^/") then return "::" .. name end
		return name
	end
	for _, entry in ipairs({ 2, 6 }) do
		for _, which in ipairs({ "right", "left" }) do
			local E = medianGeo.ENTRIES[entry]
			local t = templateOf(E.side[which])
			local tag = entry .. " " .. which
			local stem = t.streetStyle:match("^road_tunnel_ramp::/road_tunnel_ramp/streets/(median_c?_?side_[rl])%.street$")
			assert(stem, tag .. ": its own style: " .. tostring(t.streetStyle))
			eq(stem .. ".street_template", E.side[which]:match("([%w_]+%.street_template)$"), tag .. ": the style named after the template")
			local st = loadData("/content/road_tunnel_ramp/streets/" .. stem .. ".street.lua")
			-- the sidewalk's width and where it is
			local W, sw = laneWidth(t), nil
			for _, lane in ipairs(t.laneConfigs) do if hasMode(lane, "PERSON") then sw = lane.width end end
			local function fromLeft(fromOuter) return which == "right" and W - fromOuter or fromOuter end
			-- (PN6, 2026-11-24: town_new's eu_c at the curb on the right-hand
			-- sidewalk stood by the wall, its arm over the lane, an arch over
			-- the coping: its pole is 2.8m behind its origin. The post-top
			-- eu_a stands at its origin, on the sidewalk 0.6m in from the
			-- curb on either side, as town_old puts it 2.4m in on 3m)
			eq(st.assets.street_light.name, "::/assets/streets/street_light_eu_a.mdl", tag .. ": the post-top lamp")
			near(st.assets.street_light.offsetOrth, fromLeft(sw - 0.6), 1e-9, tag .. ": the light on the sidewalk by the curb")
			local o = st.assets.street_light.offsetOrth
			if which == "right" then
				assert(o > W - sw and o < W, tag .. ": the light inside the right-hand sidewalk")
			else
				assert(o > 0 and o < sw, tag .. ": the light inside the left-hand sidewalk")
			end
			eq(st.assets.street_light.offset, 6.0, tag .. ": town_old's spacing (offset)")
			eq(st.assets.street_light.distance, 12.0, tag .. ": town_old's spacing (distance)")
			near(st.assets.fireplug.offsetOrth, fromLeft(0.35), 1e-9, tag .. ": the fireplug at the outer edge")
			near(st.assets.trash.offsetOrth, fromLeft(0.4), 1e-9, tag .. ": the bin at the outer edge")
			for k, a in pairs(st.assets) do eq(a.oneSideOnly, true, tag .. ": " .. k .. " one side only") end
			if base then
				-- everything else as town_new's, with its paths written out
				for k, m in pairs(base.materials) do
					eq(st.materials[k].name, m.name and abs(m.name) or nil, tag .. ": material " .. k)
				end
				for k, a in pairs(base.assets) do
					local b = st.assets[k]
					-- (the light: its own lamp and spacing, checked above)
					local light = k == "street_light"
					if not light then eq(b.name, abs(a.name), tag .. ": asset " .. k) end
					for _, f in ipairs({ "offset", "distance", "prob", "randRot", "alignToElevation", "avoidFaceEdges", "placeOnBridge" }) do
						if not (light and (f == "offset" or f == "distance")) then
							eq(b[f], a[f], tag .. ": asset " .. k .. " " .. f)
						end
					end
				end
				eq(st.priority, base.priority, tag .. ": priority")
				eq(table.concat(st.categoryList.categories, ","), table.concat(base.categoryList.categories, ","), tag .. ": categories")
			end
		end
	end
end)

test("median: the 1.5m / 3.4m wall moves the side streets with the coping (1.9m each side) and changes the walls as on the ramp", function()
	for _, entry in ipairs({ 2, 4, 6 }) do
		local thin = median.updateFn(medianCap, { rtr_median_entry = entry, rtr_wall = 1 })
		local thick = median.updateFn(medianCap, { rtr_median_entry = entry, rtr_wall = 2 })
		local _, ts = splitSides(thin)
		local _, ks = splitSides(thick)
		for _, ySign in ipairs({ -1, 1 }) do
			near(math.abs(sideAt(ks, ySign).edges[1][1][2]) - math.abs(sideAt(ts, ySign).edges[1][1][2]), 1.9, 1e-9, "1.9m further out")
		end
		local function halfWall(r)
			local m = modelsByTagPrefix(r, "wall_1_")[1]
			return math.abs(m.transf[6]) * 0.225
		end
		near(halfWall(thin), 0.5, 1e-9, "thin wall 1.0m")
		near(halfWall(thick), 0.6, 1e-3, "thick wall 1.2m (scale 2.667, as before the option)")
		eq(#modelsByTagPrefix(thin, "parapet_"), 2 * #modelsByTagPrefix(thin, "coping_1_"), "thin: a parapet on each coping")
		eq(#modelsByTagPrefix(thick, "parapet_"), 0, "thick: none")
	end
end)

test("median: the module keeps no state, leaves the params alone and avoids functions TF3 lacks", function()
	local p = { rtr_median_entry = 6, rtr_street = 3, rtr_ground_along = 4 }
	local before = copy(p)
	local a = median.updateFn(medianCap, p)
	local b = median.updateFn(medianCap, p)
	local ok, why = sameValue(a, b, "twice")
	assert(ok, why)
	ok, why = sameValue(p, before, "params")
	assert(ok, why)
	for _, file in ipairs({ "median_geometry.lua", "median.script.lua", "median.con.lua" }) do
		local f = assert(io.open(root .. "/content/road_tunnel_ramp/" .. file)); local src = f:read("*a"); f:close()
		for _, bad in ipairs({ "rawget", "rawequal", "collectgarbage", "dofile", "loadfile", "debug%.", "os%.clock" }) do
			assert(not src:find(bad), file .. " uses " .. bad)
		end
	end
	local f = assert(io.open(root .. "/content/road_tunnel_ramp/median.script.lua")); local src = f:read("*a"); f:close()
	assert(src:find('require "road_tunnel_ramp::/road_tunnel_ramp/median_geometry.lua"', 1, true), "required by the mod's path")
end)

test("median: the tunnel fallback through api, as on the ramp", function()
	local savedApi = api
	local seen = {}
	api = { res = { tunnelTypeRep = { find = function(ref)
		seen[#seen + 1] = ref
		return ref:find("/tunnel/tunnel/tunnel_", 1, true) and 3 or -1
	end } } }
	local ok, r = pcall(median.updateFn, medianCap, {})
	api = savedApi
	assert(ok, tostring(r))
	local tunnels = 0
	for _, e in ipairs(r.edgeLists) do
		if e.edgeType == "TUNNEL" then
			eq(e.edgeTypeName, "::/infrastructure/tunnel/tunnel/tunnel_a_car.tunnel", "fallback path")
			tunnels = tunnels + 1
		end
	end
	assert(tunnels > 0, "tunnel edges")
end)

test("median: every _() key of the median's con and its side streets exists in all 13 languages; the removed options' keys are gone", function()
	local f = assert(io.open(root .. "/strings.json")); local s = f:read("*a"); f:close()
	local c = ""
	for _, path in ipairs({ "median.con.lua", "streets/median_side_r.street_template.lua", "streets/median_side_l.street_template.lua",
		"streets/median_c_side_r.street_template.lua", "streets/median_c_side_l.street_template.lua", "streets/median_inner.edge.lua" }) do
		local cf = assert(io.open(root .. "/content/road_tunnel_ramp/" .. path)); c = c .. cf:read("*a"); cf:close()
	end
	local keys = {}
	for key in c:gmatch('_%("([%w_]+)"%)') do keys[#keys + 1] = key end
	assert(#keys > 20, "string scan found too few keys")
	for _, lang in ipairs(LANGS) do
		local block = assert(s:match('\n\t"' .. lang .. '": (%b{})'), lang)
		for _, key in ipairs(keys) do
			local value = block:match('"' .. key .. '"%s*:%s*"([^"]*)"')
			assert(value and value ~= "", lang .. ": " .. key .. " missing or empty")
		end
		for _, gone in ipairs({ "rtr_median_lanes_", "rtr_median_join", "rtr_median_link", "rtr_median_tram",
			"rtr_median_side_stub", "rtr_median_split_piece", "rtr_median_ramp_", "rtr_median_exit", "rtr_median_fork" }) do
			assert(not block:find('"' .. gone, 1, true), lang .. ": " .. gone .. " left")
		end
	end
end)

-- The side street in the build menu (the user, 2026-11-24: 「側道用の道路を
-- MODで提供します。片側にしか歩道がない一方通行です。ツールシルエットは流用で
-- OK。」), the right-hand one only (「左右二種類いります？一方通行を正しく引いたら
-- いつも右が歩道側になりませんか？」): the others stay hidden.
test("median: median_side_r is in the street menu with the base one-way small streets; _l and the two-lane ones stay hidden", function()
	local STREETS = "road_tunnel_ramp::/road_tunnel_ramp/streets/"
	local t = templateOf(STREETS .. "median_side_r.street_template")
	local cats = t.menuCategory and t.menuCategory.categories
	assert(cats and #cats == 1, "one menu category")
	eq(cats[1].category, "roads_small", "with the small town streets")
	eq(cats[1].order, 145, "after the base one-way small ones (100-140), before the extra-small ones (150)")
	eq(t.availability.yearFrom, 0, "yearFrom"); eq(t.availability.yearTo, 0, "yearTo")
	assert(not t.initiallyLocked, "not locked")
	eq(t.roadType, "STREET", "a street")
	eq(t.description.name, "rtr_median_side_name", "name key")
	eq(t.description.description, "rtr_median_side_desc", "description key")
	eq(t.description.icon, "::/infrastructure/street/town/town_new_one_way_small.tga", "the base one-way icon")
	eq(t.description.previewIcon, "::/infrastructure/street/town/town_new_one_way_small_preview.tga", "the base one-way preview")
	-- the trench side's parcel stop stays, so built from the menu it takes no
	-- houses on its left either
	eq(t.defaultEdgeDecorations[1][1], STREETS .. "median_inner.edge", "decoration kept")
	eq(t.defaultEdgeDecorations[1][2], true, "on the left")
	for _, stem in ipairs({ "median_side_l", "median_c_side_r", "median_c_side_l" }) do
		eq(templateOf(STREETS .. stem .. ".street_template").menuCategory, nil, stem .. " hidden")
	end
	-- the order is not a base small street's
	local zip = os.getenv("HOME") .. "/.local/share/Steam/steamapps/common/Transport Fever 3/base/content/infrastructure/street.zip"
	local fh = io.open(zip, "rb")
	if not fh then print("     (base part skipped: street.zip not found)") return end
	fh:close()
	local lp = assert(io.popen(string.format("unzip -Z1 %q 2>/dev/null", zip)))
	local n, icons = 0, {}
	for member in lp:lines() do
		icons[member] = true
		if member:match("%.street_template%.lua$") then
			local p = assert(io.popen(string.format("unzip -p %q %q 2>/dev/null", zip, member)))
			local src = p:read("*a"); p:close()
			local env = setmetatable({ _ = function(x) return x end }, { __index = _G })
			local chunk = assert(loadstring(src, member)); setfenv(chunk, env); chunk()
			local b = env.data()
			for _, c in ipairs(b.menuCategory and b.menuCategory.categories or {}) do
				if c.category == "roads_small" then
					n = n + 1
					assert(c.order ~= cats[1].order, member .. " has order " .. c.order .. " too")
				end
			end
		end
	end
	lp:close()
	assert(n >= 15, "base small streets seen: " .. n)
	for _, ic in ipairs({ t.description.icon, t.description.previewIcon }) do
		local m = ic:gsub("^::/infrastructure/", ""):gsub("%.tga$", "@2x.tga")
		assert(icons[m], "base icon " .. m)
	end
end)

-- 2026-11-24: 「プリセット設置が不可能ならスクリプト接続は無し。」 The game
-- script that laid the fork and the merge, its layout module, its settings
-- and its streets are gone; nothing in the mod names them any more.
test("median: no game script joins the side streets: no game script file, no fork / merge module, settings or streets", function()
	local p = assert(io.popen(string.format("cd %q && find content tools -type f | sort", root)))
	local n = 0
	for path in p:lines() do
		n = n + 1
		assert(not path:match("%.gs%.lua$"), path .. ": a game script")
		for _, gone in ipairs({ "rtr_median_close", "median_close", "median_fork_", "fork22" }) do
			assert(not path:find(gone, 1, true), path .. ": " .. gone)
		end
		if path:match("%.lua$") then
			local f = assert(io.open(root .. "/" .. path)); local src = f:read("*a"); f:close()
			for _, gone in ipairs({ "rtr_median_close", "median_close", "median_fork_", "rtr_median_fork", "rtr_median_exit",
				"FORK22", "FORK_22", "fork22" }) do
				assert(not src:find(gone, 1, true), path .. " names " .. gone)
			end
		end
	end
	p:close()
	assert(n > 20, "files seen: " .. n)
	for _, k in ipairs({ "FORK_S", "FORK_22", "FORK22", "OPEN", "EXIT_SAME", "EXIT_SPLIT", "forkOf", "fork22PlanOf" }) do
		eq(medianGeo[k], nil, "median_geometry." .. k)
	end
	local lay = medianGeo.layout(medianGeo.spec(medianCap, {}), {})
	eq(lay.exit, nil, "no exit in the layout"); eq(lay.fork, nil, "no fork in the layout")
	-- the 2+2 plan's fixed 110m approach is gone with it: the slider is read
	eq(medianGeo.spec(medianCap, { rtr_median_fork = 2, rtr_approach = 40 }).approach, 40, "approach from the slider")
end)

test("median: no content file names a street template, mesh or script that is not there", function()
	local p = io.popen('find "' .. root .. '/content" -name "*.lua"')
	local n = 0
	for path in p:lines() do
		local f = assert(io.open(path)); local src = f:read("*a"); f:close()
		do
			for ref in src:gmatch('road_tunnel_ramp::(/[%w_/]+%.[%w_]+)') do
				local file = root .. "/content" .. ref
				local ok = io.open(file) or io.open(file .. ".lua")
				assert(ok, path:match("content/.*$") .. " names " .. ref)
				ok:close()
				n = n + 1
			end
			for stem in src:gmatch('streets/([%w_]+)%.street_template') do
				local ok = io.open(root .. "/content/road_tunnel_ramp/streets/" .. stem .. ".street_template.lua")
				assert(ok, path:match("content/.*$") .. " names " .. stem)
				ok:close()
				n = n + 1
			end
		end
	end
	p:close()
	assert(n > 10, "references checked: " .. n)
end)


------------------------------------------------------------------------
-- lidwidth (2026-11-23): the retaining-wall band and the portal cover
-- band end on one line. Asked: 「擁壁エリアと蓋のエリアの幅が違うと間に地面
-- が見えるので、この2つのエリアの幅は合わせてしまったほうがいいかもしれ
-- ません」. On the full-width ramp the cover reached outer + 4 and the coping
-- outer + 2.4, so ground showed in a 1.6m notch in front of the cover; the
-- cover now ends at the coping's edge (the narrower one), and the trench
-- coping stops where the cover starts.
------------------------------------------------------------------------
do
	local rampBefore = loadData("/tests/fixtures/ramp_before_lidwidth.script.lua")
	-- y range of a concrete.mdl piece (y -0.225..0.225) and its x range.
	local function concreteY(m)
		local t = m.transf
		local hw = math.abs(t[6]) * 0.225
		return t[14] - hw, t[14] + hw, t[13], t[13] + t[1]
	end
	local cases = {}
	for st = 1, 7 do
		for _, count in ipairs({ 1, 2, 3 }) do
			cases[#cases + 1] = { rtr_street = st, rtr_count = count, rtr_length = 100, rtr_depth = 16 }
		end
	end
	for _, L in ipairs({ 40, 72, 400 }) do cases[#cases + 1] = { rtr_street = 3, rtr_length = L, rtr_depth = 25, rtr_curvature = 5 } end
	cases[#cases + 1] = { rtr_street = 4, rtr_count = 3, rtr_direction = 2, rtr_side = 2, rtr_approach = 50, rtr_depth = 13 }
	cases[#cases + 1] = { rtr_street = 1, rtr_count = 2, rtr_approach = 2, rtr_curvature = 1 }
	local slopes = { { 0, 0 }, { 8, 5 }, { -8, 3 }, { 0, 12 }, { -20, -20 }, { 15, 0 } }

	test("lidwidth: the coping's and the cover's outer edges are one line, and the cover starts where the coping ends", function()
		for i, p in ipairs(cases) do
			for _, sl in ipairs(slopes) do
				local q = {}
				for k, v in pairs(p) do q[k] = v end
				q.rtr_ground_along, q.rtr_ground_across = sl[1], sl[2]
				local r = oneBox(script.updateFn(defaultCap(), q))
				local tag = string.format("case %d along %d across %d", i, sl[1], sl[2])
				local cover = modelsByTagPrefix(r, "portal_top_cover")
				eq(#cover, 1, tag .. ": one cover")
				local ly0, ly1, lx0 = concreteY(cover[1])
				near(ly0, -ly1, 1e-9, tag .. ": cover centred")
				for _, side in ipairs({ -1, 1 }) do
					local walls = modelsByTagPrefix(r, "wall_" .. side .. "_")
					local copings = modelsByTagPrefix(r, "coping_" .. side .. "_")
					assert(#walls > 0 and #copings > 0, tag .. ": walls and coping on side " .. side)
					-- the wall line, and its faces (the wall is 1.2m thick)
					local wallY = walls[1].transf[14]
					local wIn, wOut = math.abs(wallY) - 0.6, math.abs(wallY) + 0.6
					local endX = 0
					for _, m in ipairs(copings) do
						local y0, y1, x0, x1 = concreteY(m)
						local cin, cout = math.min(math.abs(y0), math.abs(y1)), math.max(math.abs(y0), math.abs(y1))
						near(cout, ly1, 1e-9, tag .. " side " .. side .. ": coping edge on the cover edge")
						assert(cin < wIn and cout > wOut, tag .. ": the coping covers the wall top")
						endX = math.max(endX, x1)
					end
					near(endX, lx0, 1e-9, tag .. " side " .. side .. ": coping ends where the cover starts")
				end
				-- the terrain under the cover and the shoulders beside it
				-- keep the 0.25m margin past the new edge
				local lists = r.subconstructions[1].terrainAlignmentLists
				for _, v in ipairs(lists[3].faces[1]) do near(math.abs(v[2]), ly1 + 0.25, 1e-9, tag .. ": cover face edge") end
				for _, f in ipairs(lists[4].faces) do
					for _, v in ipairs(f) do assert(math.abs(v[2]) <= ly1 + 0.25 + 1e-9, tag .. ": lid support inside the margin") end
				end
			end
		end
	end)

	test("lidwidth: on level ground and along-only slopes the edges, snap, cost, walls and floor are those of the build before (1.0.0's 36m cover)", lid36(function()
		for i, p in ipairs(cases) do
			for _, sl in ipairs({ { nil, nil }, { 0, 0 }, { 8, 0 }, { -8, 0 } }) do
				local q = {}
				for k, v in pairs(p) do q[k] = v end
				q.rtr_ground_along, q.rtr_ground_across = sl[1], sl[2]
				local old = rampBefore.updateFn(defaultCap(), q)
				local new = asBefore(script.updateFn(defaultCap(), kept(q)), old)
				local tag = string.format("case %d along %s", i, tostring(sl[1]))
				deepEq(new.edgeLists, old.edgeLists, tag .. " edges")
				deepEq(new.snapPoint, old.snapPoint, tag .. " snap")
				eq(new.cost, old.cost, tag .. " cost")
				eq(new.bulldozeCost, old.bulldozeCost, tag .. " bulldoze cost")
				eq(new.maintenanceCost, old.maintenanceCost, tag .. " maintenance")
				deepEq(withoutBand(new), withoutBand(old), tag .. " models other than the cover and the trench coping")
				local nl, ol = new.subconstructions[1].terrainAlignmentLists, old.subconstructions[1].terrainAlignmentLists
				eq(#nl, #ol, tag .. " terrain lists")
				deepEq(nl[1], ol[1], tag .. " floor")
				if #nl > 4 then deepEq(nl[5], ol[5], tag .. " approach face") end
				-- the cover: same place along and in height, 1.6m narrower each side
				local nc = modelsByTagPrefix(new, "portal_top_cover")[1].transf
				local oc = modelsByTagPrefix(old, "portal_top_cover")[1].transf
				for k = 1, 16 do
					if k ~= 6 and k ~= 7 then eq(nc[k], oc[k], tag .. " cover transf[" .. k .. "]") end
				end
				near((oc[6] - nc[6]) * 0.225, 1.6, 1e-9, tag .. ": cover 1.6m narrower each side")
				-- the coping keeps its cross-section; only its run is shorter
				local ncp, ocp = modelsByTagPrefix(new, "coping_1_"), modelsByTagPrefix(old, "coping_1_")
				eq(ncp[1].transf[6], ocp[1].transf[6], tag .. " coping width")
				eq(ncp[1].transf[14], ocp[1].transf[14], tag .. " coping line")
				eq(ncp[1].transf[11], ocp[1].transf[11], tag .. " coping thickness")
			end
		end
	end))

	test("lidwidth: the model footprint gets narrower, never wider", function()
		local function maxY(r)
			local m = 0
			for _, mdl in ipairs(r.subconstructions[1].models) do
				local y0, y1 = concreteY(mdl)
				m = math.max(m, math.abs(y0), math.abs(y1))
			end
			return m
		end
		for i, p in ipairs(cases) do
			local old = rampBefore.updateFn(defaultCap(), p)
			local new = script.updateFn(defaultCap(), p)
			near(maxY(old) - maxY(new), 1.6, 1e-9, "case " .. i .. ": 1.6m narrower each side")
		end
	end)

end

------------------------------------------------------------------------
-- geometry (2026-11-23): the full-width ramp's shape moved to
-- ramp_geometry.lua, the first stage of rebuilding the median approach on
-- it (user: 「1. 作り直してください」). The move must not change one value
-- the script returns; the script before it is frozen in the fixture.
------------------------------------------------------------------------
do
	local rampBefore = loadData("/tests/fixtures/ramp_before_geometry.script.lua")
	local geometry = require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua"
	-- slope, length, depth, curvature, approach and the one-way options,
	-- with the corners of each range and values the clamps must catch
	local variants = {
		{},
		{ rtr_length = 100, rtr_depth = 16 },
		{ rtr_length = 40, rtr_depth = 25, rtr_curvature = 5, rtr_approach = 2 },
		{ rtr_length = 72, rtr_depth = 13, rtr_curvature = 1, rtr_ground_along = 8, rtr_ground_across = 5 },
		{ rtr_length = 400, rtr_curvature = 2, rtr_ground_along = -8, rtr_ground_across = 3, rtr_direction = 2, rtr_side = 2 },
		{ rtr_length = 46, rtr_depth = 25, rtr_curvature = 4, rtr_ground_along = -20, rtr_ground_across = -20, rtr_approach = 50 },
		{ rtr_length = 88, rtr_ground_along = 15, rtr_ground_across = 0, rtr_direction = 2 },
		{ rtr_length = 60, rtr_ground_along = -3, rtr_ground_across = -7, rtr_curvature = 4, rtr_side = 2 },
		{ rtr_ground_along = 0, rtr_ground_across = 12, rtr_depth = 20 },
		{ rtr_ground_along = 20, rtr_ground_across = 20, rtr_length = 40, rtr_depth = 10 },
		{ rtr_length = "abc", rtr_depth = 0 / 0, rtr_curvature = 9, rtr_approach = -5, rtr_ground_along = 99 },
		{ rtr_length = "74", rtr_depth = "14.5", rtr_curvature = 2.4, rtr_direction = 1.6 },
		-- steep uphill with a long approach: the portal is held at 8 / L
		{ rtr_length = 40, rtr_ground_along = 20, rtr_approach = 50 },
	}
	-- deepEq, but -0 and +0 differ too: the move must not change one bit
	local function sameBits(a, b, path)
		if type(a) ~= type(b) then error(path .. ": type " .. type(a) .. " ~= " .. type(b), 0) end
		if type(a) ~= "table" then
			if a ~= b or (a == 0 and 1 / a ~= 1 / b) then error(path .. ": " .. tostring(a) .. " ~= " .. tostring(b), 0) end
			return
		end
		for k, v in pairs(a) do sameBits(v, b[k], path .. "." .. tostring(k)) end
		for k in pairs(b) do
			if a[k] == nil then error(path .. "." .. tostring(k) .. ": missing", 0) end
		end
	end

	test("geometry: ramp.script returns exactly what it did before the move (7 streets x 1-3 x slope, length, depth, curvature) (1.0.0's 36m cover)", lid36(function()
		local cap = defaultCap()
		local n = 0
		for st = 1, 7 do
			for count = 1, 3 do
				for i, v in ipairs(variants) do
					local p = { rtr_street = st, rtr_count = count }
					for k, x in pairs(v) do p[k] = x end
					local old = rampBefore.updateFn(cap, p)
					sameBits(asBefore(script.updateFn(cap, kept(p)), old), old,
						string.format("street %d count %d variant %d", st, count, i))
					n = n + 1
				end
			end
		end
		-- an empty menu (every value defaulted) too
		local old = rampBefore.updateFn(cap, {})
		sameBits(asBefore(script.updateFn(cap, kept({})), old), old, "empty params")
		assert(n == 7 * 3 * #variants, "cases run: " .. n)
	end))

	test("geometry: the tunnel fallback through api gives the same result as before (1.0.0's 36m cover)", lid36(function()
		local cap = defaultCap()
		local savedApi = api
		local found = {}
		-- only the alternate path exists: both scripts must switch to it
		api = { res = { tunnelTypeRep = { find = function(ref)
			found[#found + 1] = ref
			return ref:find("/tunnel/tunnel/tunnel_", 1, true) and 7 or -1
		end } } }
		local ok, err = pcall(function()
			local p = { rtr_street = 4, rtr_count = 2, rtr_ground_along = 5 }
			local new, old = script.updateFn(cap, kept(p)), rampBefore.updateFn(cap, p)
			sameBits(asBefore(new, old), old, "alternate tunnel")
			local tunnels = 0
			for _, e in ipairs(new.edgeLists) do
				if e.edgeType == "TUNNEL" then
					eq(e.edgeTypeName, "::/infrastructure/tunnel/tunnel/tunnel_a_car.tunnel", "alternate name")
					tunnels = tunnels + 1
				end
			end
			assert(tunnels > 0, "tunnel edges")
			-- neither path: both refuse with the same message
			api.res.tunnelTypeRep.find = function() return -1 end
			local okNew, errNew = pcall(script.updateFn, cap, p)
			local okOld, errOld = pcall(rampBefore.updateFn, cap, p)
			assert(not okNew and not okOld, "a missing tunnel resource must stop both")
			eq(tostring(errNew):match("road_tunnel_ramp: .*$"), tostring(errOld):match("road_tunnel_ramp: .*$"), "same message")
		end)
		api = savedApi
		assert(ok, err)
	end))

	-- half the y extent of a concrete.mdl piece (the mesh is 0.45m wide)
	local function halfY(m) return math.abs(m.transf[6]) * 0.225 end
	-- (own helpers: the median's tests above shadow portalXOf)
	local function tagged(r, prefix)
		local out = {}
		for _, m in ipairs(r.subconstructions[1].models) do
			if m.tag:sub(1, #prefix) == prefix then out[#out + 1] = m end
		end
		return out
	end
	local function firstTunnelX(r)
		local px
		for _, e in ipairs(r.edgeLists) do
			if e.edgeType == "TUNNEL" then
				local x = math.min(e.edges[1][1][1], e.edges[2][1][1])
				px = px and math.min(px, x) or x
			end
		end
		return px
	end

	test("geometry: layout's dimensions are the ones the built body uses", function()
		local cap = defaultCap()
		for st = 1, 7 do
			for count = 1, 3 do
				for i, v in ipairs(variants) do
					local p = { rtr_street = st, rtr_count = count }
					for k, x in pairs(v) do p[k] = x end
					local tag = string.format("street %d count %d variant %d", st, count, i)
					local spec = geometry.spec(cap, p)
					local r, g = geometry.build(spec)
					deepEq(r, script.updateFn(cap, p), tag .. ": build = ramp.script")
					-- the layout alone gives the same numbers
					local g2 = geometry.layout(spec)
					for _, k in ipairs({ "outer", "copingOut", "portalX", "lidA", "lidB", "runoutEnd", "D", "lift", "floorOuter", "shoulderOut" }) do
						eq(g2[k], g[k], tag .. ": layout." .. k)
					end
					-- wall centreline
					local walls = tagged(r, "wall_1_")
					eq(walls[1].transf[14], g.outer, tag .. ": wall on outer")
					eq(tagged(r, "wall_-1_")[1].transf[14], -g.outer, tag .. ": wall on -outer")
					-- coping's and lid's outer edge, lid's run
					local lids = tagged(r, "portal_top_cover_")
					local lid, lidEnd = tagged(oneBox(r), "portal_top_cover")[1], lids[#lids]
					near(halfY(lid), g.copingOut, 1e-9, tag .. ": lid edge on copingOut")
					local cp = tagged(r, "coping_1_")[1]
					near(cp.transf[14] + halfY(cp), g.copingOut, 1e-9, tag .. ": coping edge on copingOut")
					eq(lid.transf[13], g.lidA, tag .. ": lidA")
					eq(lidEnd.transf[13] + lidEnd.transf[1], g.lidB, tag .. ": lidB")
					-- portal and the runout's end
					-- (a portal within 1e-7 of the foot merges with t = 1, so
					-- the tunnel then starts at L: the script's own dedup)
					near(firstTunnelX(r), g.portalX, 1e-7 * g.L + 1e-9, tag .. ": portalX")
					local far = -math.huge
					for _, e in ipairs(r.edgeLists) do
						for _, nd in ipairs(e.edges) do
							if nd[1][1] > far then far = nd[1][1] end
							if nd[1][1] == g.runoutEnd then eq(nd[1][3], -g.D, tag .. ": runout end at -D") end
						end
					end
					eq(far, g.runoutEnd, tag .. ": runoutEnd")
					-- the floor's and the shoulders' outer edges
					local lists = r.subconstructions[1].terrainAlignmentLists
					near(math.abs(lists[1].faces[1][1][2]), g.floorOuter, 1e-12, tag .. ": floorOuter")
					local far2 = 0
					for _, f in ipairs(lists[2].faces) do
						for _, v in ipairs(f) do far2 = math.max(far2, math.abs(v[2])) end
					end
					near(far2, g.shoulderOut, 1e-12, tag .. ": shoulderOut")
					if i == #variants then near(g.portalX, 8, 1e-12, tag .. ": portal held at 8m") end
					-- the lid's height function is the one the lid is laid on
					near(lid.transf[15], g.lidZ(g.lidA, 0) - 0.3, 1e-12, tag .. ": lidZ")
				end
			end
		end
	end)

	test("geometry: a spec with another street type, count and width builds a body of that width", function()
		-- (what the median will pass: its own centre street, not a menu entry)
		local spec = geometry.spec(defaultCap(), {})
		spec.street = { ref = "road_tunnel_ramp::/test/centre.street_template", width = 20 }
		spec.count = 2
		local r, g = geometry.build(spec)
		for i, e in ipairs(r.edgeLists) do eq(e.params.type, spec.street.ref, "edge " .. i .. " template") end
		-- pitch 22 -> ys -11, 11; outer = 11 + 10 + 1; copingOut = outer + 2.4
		eq(g.ys[1], -11, "ys[1]")
		eq(g.ys[2], 11, "ys[2]")
		eq(g.outer, 22, "outer")
		near(g.copingOut, 24.4, 1e-12, "copingOut")
		eq(g.runoutEnd, spec.L + 30, "runoutEnd")
		-- two-way: both streets run toward the tunnel; one-way: divided
		eq(g.flows[1], 1, "two-way flow 1")
		eq(g.flows[2], 1, "two-way flow 2")
		spec.street = { ref = "x", width = 9, oneWay = true }
		local _, g1 = geometry.build(spec)
		eq(g1.flows[1], 1, "right-hand: -Y carriageway toward +X")
		eq(g1.flows[2], -1, "right-hand: +Y carriageway toward -X")
	end)

	test("geometry: a spec with a number missing is refused, not laid out from nil", function()
		for _, k in ipairs({ "L", "D", "count", "approach", "gx", "gy", "curvature", "direction", "side", "tunnelHeight" }) do
			local spec = geometry.spec(defaultCap(), {})
			spec[k] = nil
			local ok, err = pcall(geometry.layout, spec)
			assert(not ok and tostring(err):find("spec." .. k, 1, true), k .. ": " .. tostring(err))
		end
		local spec = geometry.spec(defaultCap(), {})
		spec.street = { ref = "x" }
		assert(not pcall(geometry.build, spec), "a street without a width")
	end)

	test("geometry: the module keeps no state, touches no engine global and leaves the spec alone", function()
		local spec = geometry.spec(defaultCap(), { rtr_street = 5, rtr_count = 3, rtr_ground_along = -6, rtr_ground_across = 4 })
		local before = {}
		for k, x in pairs(spec) do before[k] = x end
		local savedApi = api
		api = setmetatable({}, { __index = function(_, k) error("engine accessed: api." .. tostring(k)) end })
		local ok, err = pcall(function()
			local a = geometry.build(spec)
			local b = geometry.build(spec)
			deepEq(a, b, "same spec, same result")
			assert(a ~= b and a.edgeLists ~= b.edgeLists, "a fresh result each call")
		end)
		api = savedApi
		assert(ok, err)
		for k, x in pairs(before) do eq(spec[k], x, "spec." .. k) end
		eq(spec.D, 16, "spec keeps the menu depth; the clamp is the layout's")
		assert(require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua" == geometry, "one module table")
	end)

	test("geometry: ramp.script requires the module by the mod's own path and the module avoids functions TF3 lacks", function()
		local function read(rel)
			local f = assert(io.open(root .. "/" .. rel, "r"))
			local body = f:read("*a")
			f:close()
			return body
		end
		local scriptSrc = read("content/road_tunnel_ramp/ramp.script.lua")
		assert(scriptSrc:find('require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua"', 1, true), "require line")
		local modSrc = read("content/road_tunnel_ramp/ramp_geometry.lua")
		for _, src in ipairs({ scriptSrc, modSrc }) do
			for _, bad in ipairs({ "dofile", "loadfile", "rawget", "rawequal", "collectgarbage", "debug%." , "os%.clock" }) do
				assert(not src:find(bad), "uses " .. bad)
			end
		end
		assert(not modSrc:find("api%."), "the module must not call the engine")
		assert(modSrc:find("\nreturn M\n?$"), "the module returns its table")
	end)
end

------------------------------------------------------------------------
-- car only (2026-11-23): rtr_street 8, two lanes with no sidewalk,
-- appended after the seven vanilla entries. User: 「一旦歩道ありはそのまま
-- 置いておいて、「歩道無し」版のパーツを作る感じですかね」「車専用でいいです」.
-- First it was the median's 8m centre (median_ramp_two_way, car lanes at
-- -2/+2); with town_new_small, country_new_small, town_new_medium or
-- highway_new_small snapped to its near end no car got through either way
-- [measured 2026-11-23 PS, reach drive]. Then its own 14m template
-- (streets/ramp_car_only) whose car lanes are town_new_small's, with 2m
-- shoulders for PERSON and CARGO, since with bare ones no car got in from a
-- snapped town_new_small while the approach was kept [measured PW]. With the
-- approach handed over cars pass [measured PC, PJ], so since 2026-11-24 the
-- shoulders are 0.5m and carry nothing and the lanes 3.5m: 0.5m, 3.5m,
-- 3.5m, 0.5m, 8m (the user: 「中央の道の幅がずいぶん太いイメージです」, then
-- 24m across from a four-lane street). These tests pin the layout.
------------------------------------------------------------------------
do
	local CAR_ONLY = "road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_car_only.street_template"
	local STREET_ZIP = os.getenv("HOME") .. "/.local/share/Steam/steamapps/common/Transport Fever 3/base/content/infrastructure/street.zip"
	local function zipText(member)
		local fh = io.open(STREET_ZIP, "rb")
		if not fh then return nil end
		fh:close()
		local p = assert(io.popen(string.format("unzip -p %q %q 2>/dev/null", STREET_ZIP, member)))
		local src = p:read("*a"); p:close()
		assert(src ~= "", "not in street.zip: " .. member)
		return src
	end
	-- Lane centres across the street, left to right: the widths laid side
	-- by side from -total/2, then the lane's offset added. This reproduces
	-- the measured lanes where a street meets the ramp (around --lanes,
	-- 2026-11-23): town_new_small sidewalk -6.35, cars -3/+3, sidewalk +6.35.
	local function lanesAcross(t)
		local total = 0
		for _, l in ipairs(t.laneConfigs) do total = total + l.width end
		local out, from = {}, -total / 2
		for _, l in ipairs(t.laneConfigs) do
			out[#out + 1] = { centre = from + l.width / 2 + l.offset, lane = l }
			from = from + l.width
		end
		return out
	end
	local function carLaneList(t)
		local out = {}
		for _, x in ipairs(lanesAcross(t)) do
			if hasMode(x.lane, "CAR") then out[#out + 1] = x end
		end
		return out
	end

	test("car only: the lane-centre rule gives the measured lanes of town_new_small", function()
		local src = zipText("street/town/town_new_small.street_template.lua")
		if not src then print("     (vanilla part skipped: street.zip not found)") return end
		local saved = data; data = false; assert(load(src))(); local t = data(); data = saved
		local got = {}
		for _, x in ipairs(lanesAcross(t)) do got[#got + 1] = string.format("%.2f", x.centre) end
		eq(table.concat(got, " "), "-6.35 -3.00 3.00 6.35", "town_new_small lanes as measured")
	end)

	test("car only: entry 8 is the 8m cars-only template, hidden, no raised sidewalk, 0.5m shoulders that carry nothing", function()
		local cap = defaultCap()
		local st = cap.streets[8]
		eq(st.ref, CAR_ONLY, "ref")
		eq(st.oneWay, nil, "two-way")
		local t = templateOf(CAR_ONLY)
		eq(st.width, laneWidth(t), "width = the template's lanes")
		eq(st.width, 8, "8m")
		eq(t.menuCategory, nil, "not in the build menu")
		eq(#t.laneConfigs, 4, "shoulder, two car lanes, shoulder")
		for i, lane in ipairs(t.laneConfigs) do
			eq(lane.height, 0, "lane " .. i .. ": no raised sidewalk")
		end
		-- the shoulders: 0.5m, nothing on them (2026-11-24; pedestrian
		-- shoulders were needed only while the approach was kept, PW / PC / PJ)
		for _, i in ipairs({ 1, 4 }) do
			eq(#t.laneConfigs[i].transportModes, 0, "shoulder " .. i .. " carries nothing")
			eq(t.laneConfigs[i].width, 0.5, "shoulder " .. i .. " 0.5m")
		end
		eq(t.pedestrianWalkPenalty, nil, "no walk penalty: no pedestrian lane")
		for _, i in ipairs({ 2, 3 }) do
			eq(table.concat(t.laneConfigs[i].transportModes, ","), "CAR,BUS,TRUCK", "lane " .. i .. " modes")
		end
		-- the menu: an eighth label and number, the default still 3
		local spec
		for _, prm in ipairs(loadData("/content/road_tunnel_ramp/ramp.con.lua").params) do
			if prm.key == "rtr_street" then spec = prm end
		end
		eq(#spec.values, 8, "labels")
		eq(spec.values[8], "rtr_street_car_only", "label key")
		eq(spec.numbers[8], 8, "number")
		eq(spec.numbers[spec.defaultIndex], 3, "default")
	end)

	test("car only: two 3.5m car lanes, one each way, at -1.75 / +1.75, with town_new_small's modes and speed", function()
		-- (3.5m since 2026-11-24, so the median from a four-lane street is 24m
		-- across; town_new_small's 5m lanes at -3 / +3 before. Off its
		-- centres, cars from a Small Street are for the e2e's reach [guess:
		-- the handed-over approach's start is an ordinary node])
		local own = carLaneList(templateOf(CAR_ONLY))
		eq(#own, 2, "two car lanes")
		near(own[1].centre, -1.75, 1e-9, "left car lane centre")
		near(own[2].centre, 1.75, 1e-9, "right car lane centre")
		for k = 1, 2 do
			eq(own[k].lane.width, 3.5, "car lane " .. k .. " 3.5m")
			eq(own[k].lane.offset, 0, "car lane " .. k .. " no offset")
		end
		eq(own[1].lane.forward, false, "left lane backward")
		eq(own[2].lane.forward, true, "right lane forward")
		local src = zipText("street/town/town_new_small.street_template.lua")
		if not src then print("     (vanilla part skipped: street.zip not found)") return end
		local saved = data; data = false; assert(load(src))(); local t = data(); data = saved
		local v = carLaneList(t)
		for k = 1, 2 do
			eq(table.concat(own[k].lane.transportModes, ","), table.concat(v[k].lane.transportModes, ","), "car lane " .. k .. " modes")
			eq(own[k].lane.speed, v[k].lane.speed, "car lane " .. k .. " speed")
		end
	end)

	test("car only: the shoulders are narrower than country_new_small's and the town sidewalk; the style draws no sidewalk", function()
		local t = templateOf(CAR_ONLY)
		local country = zipText("street/country/country_new_small.street_template.lua")
		if not country then print("     (vanilla part skipped: street.zip not found)") return end
		local town = zipText("street/town/town_new_small.street_template.lua")
		local saved = data; data = false
		assert(load(country))(); local c = data()
		assert(load(town))(); local w = data()
		data = saved
		assert(t.laneConfigs[1].width < c.laneConfigs[1].width, "left shoulder narrower than the country road's")
		assert(t.laneConfigs[4].width < c.laneConfigs[4].width, "right shoulder narrower than the country road's")
		assert(c.laneConfigs[1].width < w.laneConfigs[1].width, "the country road's narrower than the town sidewalk")
		-- a style without sidewalk materials, paved with town_new's
		local style = assert(t.streetStyle:match("^::/infrastructure/(street/.+)$"), t.streetStyle)
		local s = assert(zipText(style .. ".lua"))
		local paving = assert(s:match("sidewalkPaving%s*=%s*(%b{})"), "sidewalkPaving block")
		assert(not paving:find("name"), "the style draws no sidewalk paving")
		local curb = assert(s:match("sidewalkCurb%s*=%s*(%b{})"), "sidewalkCurb block")
		assert(not curb:find("name"), "the style draws no curb")
		assert(s:find("town_new_street_paving.mtl", 1, true), "town_new's paving")
		assert(t.borderGroundTex:find("town_street_border", 1, true), "town border ground")
		assert(t.fillGroundTex:find("town_street_fill", 1, true), "town fill ground")
		eq(t.country, nil, "not a country road")
	end)

	-- The e2e's stand-ins for entry 8 (rtr_car_only_variant, not in the menu).
	local BARE = "road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_car_only_bare.street_template"
	local TOWN_STYLE = "road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_car_only_town_style.street_template"
	local function streetZipMembers()
		local zip = STREET_ZIP
		local fh = io.open(zip, "rb")
		if not fh then return nil end
		fh:close()
		local p = assert(io.popen(string.format("unzip -Z1 %q 2>/dev/null", zip)))
		local out = {}
		for line in p:lines() do
			if line:match("%.street_template%.lua$") then out[#out + 1] = line end
		end
		p:close()
		return out
	end
	local function loadSrc(src)
		local saved = data; data = false; assert(load(src))(); local t = data(); data = saved
		return t
	end
	local function twoWayCars(t)
		local back, fwd = false, false
		for _, l in ipairs(t.laneConfigs) do
			if hasMode(l, "CAR") then
				if l.forward then fwd = true else back = true end
			end
		end
		return back and fwd
	end

	test("car only: every two-way street of the base game has pedestrian lanes first and last; entry 8 and its stand-ins have none (motor vehicles only)", function()
		local members = streetZipMembers()
		if not members then print("     (vanilla part skipped: street.zip not found)") else
			local n = 0
			for _, member in ipairs(members) do
				local t = loadSrc(zipText(member))
				if twoWayCars(t) then
					local lanes = t.laneConfigs
					assert(hasMode(lanes[1], "PERSON"), member .. ": first lane for pedestrians")
					assert(hasMode(lanes[#lanes], "PERSON"), member .. ": last lane for pedestrians")
					for i, l in ipairs(lanes) do
						assert(#l.transportModes > 0, member .. ": lane " .. i .. " carries something")
					end
					n = n + 1
				end
			end
			assert(n >= 20, "two-way base streets found: " .. n)
			-- the base game's road without a sidewalk: flat pedestrian lanes
			local c = loadSrc(zipText("street/country/country_new_small.street_template.lua"))
			eq(table.concat(c.laneConfigs[1].transportModes, ","), "PERSON,CARGO", "country_new_small shoulder")
			eq(c.laneConfigs[1].height, 0, "country_new_small shoulder flat")
		end
		for _, ref in ipairs({ CAR_ONLY, BARE, TOWN_STYLE }) do
			for i, l in ipairs(templateOf(ref).laneConfigs) do
				assert(not hasMode(l, "PERSON") and not hasMode(l, "CARGO"), ref .. ": lane " .. i .. " for no pedestrian or cargo")
			end
			eq(laneWidth(templateOf(ref)), 8, ref .. ": 8m, the width the body is laid for")
		end
	end)

	test("car only: the stand-ins are entry 8's template (bare, the same street since 2026-11-24) and it under the town style", function()
		local function strip(t, keepStyle)
			local q = {}
			for k, v in pairs(t) do q[k] = v end
			q.pedestrianWalkPenalty = nil
			if not keepStyle then q.streetStyle = nil end
			local lanes = {}
			for i, l in ipairs(t.laneConfigs) do
				local m = {}
				for k, v in pairs(l) do m[k] = v end
				if i == 1 or i == #t.laneConfigs then m.transportModes = {} end
				lanes[i] = m
			end
			q.laneConfigs = lanes
			return q
		end
		local fixed, bare, town = templateOf(CAR_ONLY), templateOf(BARE), templateOf(TOWN_STYLE)
		deepEq(strip(bare, true), strip(fixed, true), "bare")
		eq(bare.pedestrianWalkPenalty, nil, "bare: no walk penalty (as at 6549c59)")
		eq(bare.streetStyle, fixed.streetStyle, "bare: the same style")
		deepEq(strip(town, false), strip(fixed, false), "town style")
		eq(town.streetStyle, "::/infrastructure/street/town/town_new.street", "town style: the base town style")
		eq(#town.laneConfigs[1].transportModes, 0, "town style: bare shoulders")
		-- not menu entries: no category, the same name and description keys
		for _, t in ipairs({ bare, town }) do
			eq(t.menuCategory, nil, "hidden")
			eq(t.description.name, fixed.description.name, "name key")
			eq(t.description.description, fixed.description.description, "description key")
		end
	end)

	test("car only: rtr_car_only_variant (not in the menu) swaps entry 8's edges for a stand-in and nothing else; entries 1-7 ignore it", function()
		local cap = defaultCap()
		eq(cap.streets[8].variants[1], BARE, "variant 2")
		eq(cap.streets[8].variants[2], TOWN_STYLE, "variant 3")
		for i = 1, 7 do eq(cap.streets[i].variants, nil, "entry " .. i .. " has no variants") end
		for _, prm in ipairs(loadData("/content/road_tunnel_ramp/ramp.con.lua").params) do
			assert(prm.key ~= "rtr_car_only_variant", "not a menu option")
		end
		local function types(r)
			local seen = {}
			for _, e in ipairs(r.edgeLists) do seen[e.params.type] = true end
			local out = {}
			for k in pairs(seen) do out[#out + 1] = k end
			table.sort(out)
			return table.concat(out, " ")
		end
		local function retyped(r, ref)
			for _, e in ipairs(r.edgeLists) do e.params.type = ref end
			return r
		end
		for _, extra in ipairs({ {}, { rtr_count = 3, rtr_length = 40, rtr_depth = 25, rtr_curvature = 5, rtr_approach = 2 },
		                         { rtr_count = 2, rtr_ground_along = 8, rtr_ground_across = 5, rtr_wall = 1 } }) do
			local function run(v)
				local p = { rtr_street = 8 }
				for k, x in pairs(extra) do p[k] = x end
				p.rtr_car_only_variant = v
				return script.updateFn(cap, p)
			end
			local base = run(nil)
			eq(types(base), CAR_ONLY, "no variant: entry 8's template")
			for _, v in ipairs({ 1, 0, -4, 1.4, "x" }) do
				deepEq(run(v), base, "variant " .. tostring(v) .. " = none")
			end
			eq(types(run(2)), BARE, "2: bare")
			eq(types(run(3)), TOWN_STYLE, "3: town style")
			eq(types(run(9)), TOWN_STYLE, "clamped to the last")
			eq(types(run(2.4)), BARE, "rounded")
			-- only the type changes: walls, lid, terrain, snap, cost the same
			deepEq(retyped(run(2), CAR_ONLY), base, "2: the same body")
			deepEq(retyped(run(3), CAR_ONLY), base, "3: the same body")
		end
		for i = 1, 7 do
			deepEq(script.updateFn(cap, { rtr_street = i, rtr_car_only_variant = 2 }), script.updateFn(cap, { rtr_street = i }), "entry " .. i)
		end
	end)

	test("car only: entries 1-7 keep their vanilla templates and widths", function()
		local want = {
			{ "::/infrastructure/street/highway/highway_new_small.street_template", 9 },
			{ "::/infrastructure/street/country/country_new_small.street_template", 14 },
			{ "::/infrastructure/street/town/town_new_small.street_template", 16 },
			{ "::/infrastructure/street/highway/highway_new_medium.street_template", 18 },
			{ "::/infrastructure/street/country/country_new_medium.street_template", 22 },
			{ "::/infrastructure/street/town/town_new_medium.street_template", 24 },
			{ "::/infrastructure/street/town/town_new_large.street_template", 32 },
		}
		local cap = defaultCap()
		for i, w in ipairs(want) do
			eq(cap.streets[i].ref, w[1], "entry " .. i)
			eq(cap.streets[i].width, w[2], "entry " .. i .. " width")
			local r = script.updateFn(cap, { rtr_street = i })
			for _, e in ipairs(r.edgeLists) do eq(e.params.type, w[1], "entry " .. i .. " edges") end
		end
	end)

	-- A digest of the whole updateFn result: keys sorted, numbers to 10
	-- significant digits, so a change anywhere in edges, models, terrain or
	-- cost shows.
	local function serialize(v, out)
		local t = type(v)
		if t == "number" then out[#out + 1] = string.format("%.10g", v)
		elseif t == "string" then out[#out + 1] = string.format("%q", v)
		elseif t == "table" then
			local keys = {}
			for k in pairs(v) do keys[#keys + 1] = k end
			table.sort(keys, function(a, b)
				if type(a) == type(b) then return a < b end
				return type(a) < type(b)
			end)
			out[#out + 1] = "{"
			for _, k in ipairs(keys) do
				serialize(k, out); out[#out + 1] = "="; serialize(v[k], out); out[#out + 1] = ","
			end
			out[#out + 1] = "}"
		else out[#out + 1] = t .. ":" .. (t == "function" and "" or tostring(v)) end
	end
	local function digest(r)
		local out = {}
		serialize(r, out)
		local s = table.concat(out)
		local h = 5381
		for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
		return string.format("%d:%d", #s, h)
	end
	local DIGEST_VARIANTS = {
		{},
		{ rtr_count = 3, rtr_length = 40, rtr_depth = 25, rtr_curvature = 5, rtr_approach = 2 },
		{ rtr_count = 2, rtr_ground_along = 8, rtr_ground_across = 5, rtr_direction = 2, rtr_side = 2 },
	}
	-- Written by the same digest from 14daf1a (the commit before the
	-- cars-only template), entries 1-7 x the variants above.
	local BEFORE = {
		["1/1"] = "25744:729079730",
		["1/2"] = "17797:580990373",
		["1/3"] = "31370:215820704",
		["2/1"] = "25556:17799052",
		["2/2"] = "17710:95107883",
		["2/3"] = "31218:1558933238",
		["3/1"] = "25490:1390720038",
		["3/2"] = "17530:67046264",
		["3/3"] = "30990:1484340066",
		["4/1"] = "25763:1578554175",
		["4/2"] = "17760:1517251827",
		["4/3"] = "31166:214699055",
		["5/1"] = "25754:1710882019",
		["5/2"] = "17740:271263509",
		["5/3"] = "31170:1191063830",
		["6/1"] = "25697:1305470959",
		["6/2"] = "17552:284200333",
		["6/3"] = "31483:343614729",
		["7/1"] = "25686:729588324",
		["7/2"] = "17530:392816914",
		["7/3"] = "31817:1977434074",
	}

	test("car only: entries 1-7 build exactly what they built before the cars-only template (whole result digest) (1.0.0's 36m cover)", lid36(function()
		local cap = defaultCap()
		local got = {}
		for i = 1, 7 do
			for v, extra in ipairs(DIGEST_VARIANTS) do
				local p = { rtr_street = i }
				for k, x in pairs(extra) do p[k] = x end
				got[#got + 1] = string.format('["%d/%d"] = "%s",', i, v, digest(asBefore(script.updateFn(cap, kept(p)))))
			end
		end
		if os.getenv("RTR_PRINT_DIGESTS") then print(table.concat(got, "\n")) end
		local n = 0
		for _, line in ipairs(got) do
			local key, d = line:match('^%["([%d/]+)"%] = "([^"]+)",$')
			eq(d, BEFORE[key], "entry/variant " .. key)
			n = n + 1
		end
		eq(n, 21, "cases")
	end))

	test("car only: every edge is the 8m template, each street one unbroken chain from the snapped near end to the runout", function()
		local cap = defaultCap()
		local n = 0
		for count = 1, 3 do
			for _, v in ipairs({ {}, { rtr_length = 40, rtr_depth = 25, rtr_curvature = 5, rtr_approach = 2 },
			                      { rtr_ground_along = 8, rtr_ground_across = 5, rtr_direction = 2, rtr_side = 2 } }) do
				local p = { rtr_street = 8, rtr_count = count }
				for k, x in pairs(v) do p[k] = x end
				local r = script.updateFn(cap, p)
				local tag = "count " .. count .. " case " .. n
				-- (pitch 10: the 8m street plus the 2m gap)
				local ys = {}
				for i = 1, count do ys[i] = (i - (count + 1) * 0.5) * 10 end
				for _, e in ipairs(r.edgeLists) do eq(e.params.type, CAR_ONLY, tag .. ": template") end
				for si, y in ipairs(ys) do
					local chain = edgesAtY(r, y)
					table.sort(chain, function(a, b) return a.edges[1][1][1] < b.edges[1][1][1] end)
					assert(#chain > 2, tag .. ": edges on y " .. y)
					for k, e in ipairs(chain) do
						local a, b = e.edges[1], e.edges[2]
						-- two-way: never reversed, so every edge runs toward the tunnel
						assert(b[1][1] > a[1][1], tag .. ": edge " .. k .. " runs toward +X")
						assert(a[2][1] > 0 and b[2][1] > 0, tag .. ": tangents toward +X")
						if k > 1 then
							local prev = chain[k - 1].edges[2]
							for c = 1, 3 do eq(prev[1][c], a[1][c], tag .. ": joint " .. k .. " coordinate " .. c) end
						end
					end
					-- the near end: the snapped street's node 0 at the snap point
					local first = chain[1]
					eq(first.edges[1][1][1], -(p.rtr_approach or 20), tag .. ": near end x")
					if si == 1 then
						eq(first.snapNodes[1], 0, tag .. ": near end snaps")
						eq(r.snapPoint.transf[13], first.edges[1][1][1], tag .. ": snap point x")
						eq(r.snapPoint.transf[14], y, tag .. ": snap point y")
						eq(r.snapPoint.transportModes[1], "CAR", tag .. ": snap for cars")
					else
						eq(#first.snapNodes, 0, tag .. ": other near ends stay free")
						eq(first.freeNodes[1], 0, tag .. ": free near end")
					end
					-- the far end: tunnel, snappable for the player's tunnel
					local last = chain[#chain]
					eq(last.edgeType, "TUNNEL", tag .. ": runout in tunnel")
					eq(last.snapNodes[1], 1, tag .. ": far end snaps")
				end
				-- the body: walls 1m outside the outer carriageway edge
				local outer = (count - 1) * 5 + 4 + 1
				local wall
				for _, m in ipairs(r.subconstructions[1].models) do
					if m.tag == "wall_1_0_1" then wall = m end
				end
				eq(wall.transf[14], outer, tag .. ": wall line")
				n = n + 1
			end
		end
		eq(n, 9, "cases run")
	end)
end

------------------------------------------------------------------------
-- wall width (2026-11-23): rtr_wall picks the retaining wall per side,
-- street edge to the outer edge of its top. User: 「擁壁幅を選べるように
-- するのは面倒？」, then yes to two buttons, thin (2.0m: 0.5m clear, 1.0m
-- wall, 0.5m top band, a 0.25m parapet 1.1m over the ground; research
-- notes median_ramp_widths/retaining_wall_research.md) and thick (3.4m,
-- the earlier body), short labels, thin first.
------------------------------------------------------------------------
do
	local geometry = require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua"
	-- the script frozen before the option (and before the module)
	local wallBefore = loadData("/tests/fixtures/ramp_before_geometry.script.lua")
	local function halfY(m) return math.abs(m.transf[6]) * 0.225 end
	local function tagged(r, prefix)
		local out = {}
		for _, m in ipairs(r.subconstructions[1].models) do
			if m.tag:sub(1, #prefix) == prefix then out[#out + 1] = m end
		end
		return out
	end
	local VARIANTS = {
		{},
		{ rtr_count = 3, rtr_length = 40, rtr_depth = 25, rtr_curvature = 5, rtr_approach = 2 },
		{ rtr_count = 2, rtr_ground_along = 8, rtr_ground_across = 5, rtr_direction = 2, rtr_side = 2 },
		{ rtr_ground_along = -8, rtr_ground_across = -6, rtr_length = 60 },
	}
	local function with(p, extra)
		local q = {}
		for k, x in pairs(p) do q[k] = x end
		for k, x in pairs(extra) do q[k] = x end
		return q
	end

	test("wall: the menu offers 1.5m and 3.4m as buttons, thin first and the initial setting", function()
		local spec
		for _, prm in ipairs(loadData("/content/road_tunnel_ramp/ramp.con.lua").params) do
			if prm.key == "rtr_wall" then spec = prm end
		end
		assert(spec, "rtr_wall param")
		eq(spec.uiType, "Button", "buttons")
		eq(table.concat(spec.values, ","), "rtr_wall_thin,rtr_wall_thick", "labels")
		eq(table.concat(spec.numbers, ","), "1,2", "numbers")
		eq(spec.numbers[spec.defaultIndex], 1, "thin by default")
		eq(geometry.WALLS[1].key, "thin", "1 = thin")
		eq(geometry.WALLS[2].key, "thick", "2 = thick")
		-- the wall model is 0.45 wide, so its y scale and half thickness agree
		for _, w in ipairs(geometry.WALLS) do near(w.scale * 0.225, w.half, 1e-3, w.key .. ": scale and half") end
		local f = assert(io.open(root .. "/strings.json")); local s = f:read("*a"); f:close()
		for _, lang in ipairs(LANGS) do
			local block = s:match('\n\t"' .. lang .. '": (%b{})')
			eq(block:match('"rtr_wall_thin"%s*:%s*"([^"]*)"'), "1.5m", lang .. " thin label")
			eq(block:match('"rtr_wall_thick"%s*:%s*"([^"]*)"'), "3.4m", lang .. " thick label")
		end
	end)

	test("wall: spec reads rtr_wall (1 thin, 2 thick, clamped); without it the thick wall, as before the option", function()
		local cap = defaultCap()
		eq(geometry.spec(cap, { rtr_wall = 1 }).wall, geometry.WALLS[1], "1")
		eq(geometry.spec(cap, { rtr_wall = 2 }).wall, geometry.WALLS[2], "2")
		eq(geometry.spec(cap, {}).wall, geometry.WALLS[2], "missing")
		eq(geometry.spec(cap, { rtr_wall = 9 }).wall, geometry.WALLS[2], "clamped high")
		eq(geometry.spec(cap, { rtr_wall = -3 }).wall, geometry.WALLS[1], "clamped low")
		eq(geometry.spec(cap, { rtr_wall = "x" }).wall, geometry.WALLS[2], "not a number")
		local spec = geometry.spec(cap, {})
		spec.wall = nil
		local ok, err = pcall(geometry.layout, spec)
		assert(not ok and tostring(err):find("spec.wall", 1, true), "no wall: " .. tostring(err))
		spec.wall = { centre = 1 }
		ok, err = pcall(geometry.layout, spec)
		assert(not ok and tostring(err):find("spec.wall.half", 1, true), "incomplete wall: " .. tostring(err))
	end)

	test("wall: thick (3.4m) builds exactly what the ramp built before the option (every entry, whole result) (1.0.0's 36m cover)", lid36(function()
		local cap = defaultCap()
		local n = 0
		for st = 1, #cap.streets do
			for _, v in ipairs(VARIANTS) do
				local p = with(v, { rtr_street = st })
				-- against the frozen script, so it holds whatever a missing key means
				local old = wallBefore.updateFn(cap, p)
				deepEq(asBefore(script.updateFn(cap, with(p, { rtr_wall = 2, rtr_approach_hand_over = 0 })), old), old, "street " .. st)
				n = n + 1
			end
		end
		eq(n, 8 * #VARIANTS, "cases")
		-- written out: 0.4m clear, the 1.2m wall, the coping 1.8m past it
		local g = geometry.layout(geometry.spec(cap, { rtr_wall = 2 }))
		near(g.copingOut - (g.outer - 1.0), 3.4, 1e-12, "3.4m from the street edge")
		eq(#tagged(geometry.build(geometry.spec(cap, { rtr_wall = 2 })), "parapet_"), 0, "no parapet")
	end))

	test("wall: thin (1.5m) is the wall on the street edge, a 1.0m wall and a 0.5m top band; the lid, floor and banks follow", function()
		local cap = defaultCap()
		local n = 0
		for st = 1, #cap.streets do
			for vi, v in ipairs(VARIANTS) do
				local p = with(v, { rtr_street = st, rtr_wall = 1 })
				local tag = string.format("street %d variant %d", st, vi)
				local spec = geometry.spec(cap, p)
				local r, g = geometry.build(spec)
				deepEq(r, script.updateFn(cap, p), tag .. ": build = ramp.script")
				local g2 = geometry.layout(spec)
				for _, k in ipairs({ "outer", "copingOut", "portalX", "lidA", "lidB", "floorOuter", "shoulderOut", "shoulderIn" }) do
					eq(g2[k], g[k], tag .. ": layout." .. k)
				end
				local edge = g.halfSpread + g.halfWidth  -- the outermost street's outer edge
				near(g.outer - edge, 0.5, 1e-12, tag .. ": wall centre 0.5m out (half the wall, no clearance)")
				near(g.copingOut - edge, 1.5, 1e-12, tag .. ": 1.5m from the street edge")
				for _, side in ipairs({ -1, 1 }) do
					local walls = tagged(r, "wall_" .. side .. "_")
					assert(#walls > 0, tag .. ": walls")
					for _, w in ipairs(walls) do
						eq(w.transf[14], side * g.outer, tag .. ": wall line")
						near(halfY(w) * 2, 1.0, 1e-12, tag .. ": wall 1.0m thick")
						near(math.abs(w.transf[14]) - halfY(w) - edge, 0, 1e-12, tag .. ": the wall's inner face on the street edge")
					end
					local copings = tagged(r, "coping_" .. side .. "_")
					assert(#copings > 0, tag .. ": copings")
					for _, c in ipairs(copings) do
						local cin = math.abs(c.transf[14]) - halfY(c)
						local cout = math.abs(c.transf[14]) + halfY(c)
						near(cout, g.copingOut, 1e-9, tag .. ": coping edge on copingOut")
						near(cout - (g.outer + 0.5), 0.5, 1e-9, tag .. ": the top band 0.5m past the wall")
						assert(cin < g.outer - 0.5, tag .. ": coping covers the wall's inner edge")
					end
					-- the parapet: 0.25m, its inner face over the wall's, its
					-- top 1.1m over the ground, along the coping's run
					local pp = tagged(r, "parapet_" .. side .. "_")
					eq(#pp, #copings, tag .. ": a parapet piece per coping piece")
					for i, m in ipairs(pp) do
						near(halfY(m) * 2, 0.25, 1e-12, tag .. ": parapet 0.25m")
						near(math.abs(m.transf[14]) - halfY(m), g.outer - 0.5, 1e-12, tag .. ": parapet on the wall's inner edge")
						eq(m.transf[13], copings[i].transf[13], tag .. ": parapet starts with the coping")
						near(m.transf[15] + m.transf[11], g.surface(m.transf[13], m.transf[14]) + 1.1, 1e-9, tag .. ": parapet top 1.1m over the ground")
					end
				end
				local lid = tagged(oneBox(r), "portal_top_cover")[1]
				near(halfY(lid), g.copingOut, 1e-9, tag .. ": lid as wide as the walls")
				local lists = r.subconstructions[1].terrainAlignmentLists
				near(math.abs(lists[1].faces[1][1][2]), g.outer + 0.4, 1e-12, tag .. ": floor under the wall")
				local far, near2 = 0, math.huge
				for _, f in ipairs(lists[2].faces) do
					for _, v in ipairs(f) do
						far = math.max(far, math.abs(v[2]))
						near2 = math.min(near2, math.abs(v[2]))
					end
				end
				near(far, g.outer + 5.6, 1e-12, tag .. ": banks out to outer + 5.6 (the band 4.6m past the top, as on the thick wall)")
				near(g.shoulderIn, g.outer + 0.55, 1e-12, tag .. ": banks from just outside the wall")
				assert(near2 <= g.shoulderIn + 1e-12, tag .. ": banks reach in to the wall")
				for _, v in ipairs(lists[3].faces[1]) do near(math.abs(v[2]), g.copingOut + 0.25, 1e-12, tag .. ": cover face") end
				-- the street is the same: the edges do not move with the wall
				-- (but for a cross slope: the portal reads the ground at the
				-- lid's edges, so a narrower lid moves it)
				local thick = script.updateFn(cap, with(p, { rtr_wall = 2 }))
				if g.gy == 0 then
					deepEq(r.edgeLists, thick.edgeLists, tag .. ": edges as with the thick wall")
				end
				n = n + 1
			end
		end
		eq(n, 8 * #VARIANTS, "cases")
	end)

	test("wall: on a stated slope the thin wall's approach walls get parapets too; level ground has none", function()
		local cap = defaultCap()
		local level = script.updateFn(cap, { rtr_wall = 1 })
		eq(#tagged(level, "approach_parapet_"), 0, "level: none")
		local sloped = script.updateFn(cap, { rtr_wall = 1, rtr_ground_along = 6 })
		eq(#tagged(sloped, "approach_parapet_"), #tagged(sloped, "approach_coping_"), "sloped: one per approach coping")
		assert(#tagged(sloped, "approach_parapet_") > 0, "sloped: some")
	end)
end

------------------------------------------------------------------------
-- The near joint. Bug: a road of another type joined at the ramp's near
-- end let pedestrians in but no car (any ramp type, country_new_small
-- too), while the same type passed [measured 2026-11-23 PS, PW, PC]. The
-- flat approach is now handed over (both nodes free), so the joined road
-- meets an ordinary street's node, and the kept descent starts at a free
-- node, as the median's kept ramp does after its handed-over first piece.
------------------------------------------------------------------------
do
	local geometry = require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua"
	-- every node of the result with its flags, keyed by position
	local function flagsAt(r)
		local out = {}
		for i, e in ipairs(r.edgeLists) do
			for n = 0, 1 do
				local pos = e.edges[n + 1][1]
				local key = string.format("%.6f,%.6f,%.6f", pos[1], pos[2], pos[3])
				local f = out[key] or { x = pos[1], y = pos[2], edges = {}, snap = 0, free = 0, kept = 0 }
				f.edges[#f.edges + 1] = i
				for _, k in ipairs(e.snapNodes) do if k == n then f.snap = f.snap + 1 end end
				for _, k in ipairs(e.freeNodes) do if k == n then f.free = f.free + 1 end end
				out[key] = f
			end
		end
		return out
	end
	local function isApproach(e, approach)
		local xa, xb = e.edges[1][1][1], e.edges[2][1][1]
		return math.min(xa, xb) < -1e-9 and math.abs(math.max(xa, xb)) < 1e-9
			and math.abs(math.abs(xa - xb) - approach) < 1e-9
	end
	local CASES = {}
	for st = 1, 8 do
		for count = 1, 3 do
			for _, dir in ipairs({ 1, 2 }) do
				for _, side in ipairs({ 1, 2 }) do
					CASES[#CASES + 1] = { rtr_street = st, rtr_count = count, rtr_direction = dir, rtr_side = side }
				end
			end
		end
	end
	CASES[#CASES + 1] = { rtr_approach = 2, rtr_length = 40, rtr_depth = 25 }
	CASES[#CASES + 1] = { rtr_approach = 50, rtr_ground_along = 8, rtr_ground_across = -5, rtr_count = 2 }
	CASES[#CASES + 1] = {}

	test("joint: every street's flat approach is handed over (both nodes free); only the snapping one snaps, at its start", function()
		local cap = defaultCap()
		for ci, p in ipairs(CASES) do
			local r = script.updateFn(cap, p)
			local g = geometry.layout(geometry.spec(cap, p))
			local tag = "case " .. ci
			local approaches, snaps = 0, 0
			for _, e in ipairs(r.edgeLists) do
				if isApproach(e, g.approach) then
					approaches = approaches + 1
					eq(e.edgeType, nil, tag .. ": approach is a surface edge")
					local f = {}
					for _, k in ipairs(e.freeNodes) do f[k] = true end
					assert(f[0] and f[1] and #e.freeNodes == 2, tag .. ": both approach nodes free, got {" .. table.concat(e.freeNodes, ",") .. "}")
					for _, k in ipairs(e.snapNodes) do
						near(e.edges[k + 1][1][1], -g.approach, 1e-9, tag .. ": the snap node is the approach start")
						near(e.edges[k + 1][1][2], g.ys[g.snapIdx], 1e-9, tag .. ": on the snapping street")
						snaps = snaps + 1
					end
				end
			end
			eq(approaches, g.count, tag .. ": one approach per street")
			eq(snaps, 1, tag .. ": one snap node")
			near(r.snapPoint.transf[13], -g.approach, 1e-9, tag .. ": the snap point stays at the approach start")
		end
	end)

	test("joint: the kept descent starts at a free node at x = 0; no other node of the kept edges is free; the runout end still snaps", function()
		local cap = defaultCap()
		for ci, p in ipairs(CASES) do
			local r = script.updateFn(cap, p)
			local g = geometry.layout(geometry.spec(cap, p))
			local tag = "case " .. ci
			-- the kept edges' free nodes are only the descents' starts
			for i, e in ipairs(r.edgeLists) do
				if not isApproach(e, g.approach) then
					for _, k in ipairs(e.freeNodes) do
						near(e.edges[k + 1][1][1], 0, 1e-9, tag .. " edge " .. i .. ": a kept edge's free node lies at x = 0")
						eq(e.edgeType, nil, tag .. " edge " .. i .. ": the descent's first piece is open (not tunnel)")
					end
				end
			end
			local junctions, runoutEnds = 0, 0
			for _, f in pairs(flagsAt(r)) do
				if math.abs(f.x) < 1e-9 then
					junctions = junctions + 1
					eq(#f.edges, 2, tag .. ": the approach and the descent meet at x = 0")
					eq(f.free, 2, tag .. ": free in both lists at x = 0")
					eq(f.snap, 0, tag .. ": no snap at x = 0")
				elseif f.x > g.L then
					if #f.edges == 1 then
						runoutEnds = runoutEnds + 1
						eq(f.snap, 1, tag .. ": runout end snaps")
						eq(f.free, 0, tag .. ": runout end kept")
					end
				end
			end
			eq(junctions, g.count, tag .. ": one joint per street")
			eq(runoutEnds, g.count, tag .. ": one runout end per street")
		end
	end)

	test("joint: hand-over 0 keeps the approach (the layout before); the two differ in free nodes only", function()
		local cap = defaultCap()
		local function strip(r)
			local q = {}
			for k, v in pairs(r) do q[k] = v end
			q.edgeLists = {}
			for i, e in ipairs(r.edgeLists) do
				local c = {}
				for k, v in pairs(e) do c[k] = v end
				c.freeNodes = nil
				q.edgeLists[i] = c
			end
			return q
		end
		for ci, p in ipairs(CASES) do
			local on, off = script.updateFn(cap, p), script.updateFn(cap, kept(p))
			deepEq(strip(on), strip(off), "case " .. ci)
			local g = geometry.layout(geometry.spec(cap, p))
			-- kept: the snapping approach start not free, the others' starts free, nothing else
			for i, e in ipairs(off.edgeLists) do
				local want = {}
				if isApproach(e, g.approach) and #e.snapNodes == 0 then
					for k = 0, 1 do if e.edges[k + 1][1][1] < 0 then want[#want + 1] = k end end
				end
				eq(table.concat(e.freeNodes, ","), table.concat(want, ","), "case " .. ci .. " kept edge " .. i .. " free nodes")
			end
		end
	end)

	test("joint: rtr_approach_hand_over reads 1 / missing / junk as hand over, 0 and below 0.5 as kept, 1.5 and up as depot style", function()
		local cap = defaultCap()
		for _, v in ipairs({ { nil, true }, { 1, true }, { "1", true }, { "abc", true }, { 0 / 0, true },
				{ 0.5, true }, { 1.4, true }, { 0, false }, { "0", false }, { 0.4, false }, { -5, false } }) do
			local spec = geometry.spec(cap, { rtr_approach_hand_over = v[1] })
			eq(spec.handOver, v[2], "value " .. tostring(v[1]))
			eq(spec.approachDepotStyle, false, "value " .. tostring(v[1]) .. ": not depot style")
		end
		-- a spec made elsewhere without the field hands the approach over
		local spec = geometry.spec(cap, {})
		spec.handOver = nil
		local r = geometry.build(spec)
		eq(#r.edgeLists[1].freeNodes, 2, "nil handOver: approach handed over")
		spec.handOver = false
		eq(#geometry.build(spec).edgeLists[1].freeNodes, 0, "false: approach kept, the snapping start not free")
		-- 2 and the values rounding to it (above 2 clamps to 2)
		for _, v in ipairs({ 2, "2", 1.5, 99 }) do
			local d = geometry.spec(cap, { rtr_approach_hand_over = v })
			eq(d.handOver, false, "value " .. tostring(v) .. ": not handed over")
			eq(d.approachDepotStyle, true, "value " .. tostring(v) .. ": depot style")
		end
		-- depot style is read only with handOver false
		local d = geometry.spec(cap, { rtr_approach_hand_over = 2 })
		d.handOver = nil
		eq(#geometry.build(d).edgeLists[1].freeNodes, 2, "nil handOver builds as 1")
		d.handOver, d.approachDepotStyle = false, nil
		eq(#geometry.build(d).edgeLists[1].freeNodes, 0, "nil approachDepotStyle: kept as 0")
	end)

	local function depot(p)
		local q = {}
		for k, v in pairs(p or {}) do q[k] = v end
		q.rtr_approach_hand_over = 2
		return q
	end

	test("joint: hand-over 2 (depot style) frees each approach's outer end only; the snapping one snaps there; x = 0 and the descent stay kept", function()
		local cap = defaultCap()
		for ci, p in ipairs(CASES) do
			local r = script.updateFn(cap, depot(p))
			local g = geometry.layout(geometry.spec(cap, depot(p)))
			local tag = "case " .. ci
			local approaches, snaps, frees = 0, 0, 0
			for i, e in ipairs(r.edgeLists) do
				if isApproach(e, g.approach) then
					approaches = approaches + 1
					eq(e.edgeType, nil, tag .. ": approach is a surface edge")
					local outer = e.edges[1][1][1] < 0 and 0 or 1
					eq(table.concat(e.freeNodes, ","), tostring(outer), tag .. " edge " .. i .. ": only the outer end free")
					near(e.edges[outer + 1][1][1], -g.approach, 1e-9, tag .. ": the free node is the approach start")
					frees = frees + 1
					if #e.snapNodes > 0 then
						eq(table.concat(e.snapNodes, ","), tostring(outer), tag .. ": snaps at the same end it frees, as the depots' entrance")
						near(e.edges[outer + 1][1][2], g.ys[g.snapIdx], 1e-9, tag .. ": on the snapping street")
						snaps = snaps + 1
					end
				else
					eq(#e.freeNodes, 0, tag .. " edge " .. i .. ": a ramp edge stays in the construction")
				end
			end
			eq(approaches, g.count, tag .. ": one approach per street")
			eq(frees, g.count, tag .. ": every street's outer end free")
			eq(snaps, 1, tag .. ": one snap node")
			near(r.snapPoint.transf[13], -g.approach, 1e-9, tag .. ": the snap point stays at the approach start")
			local junctions, runoutEnds = 0, 0
			for _, f in pairs(flagsAt(r)) do
				if math.abs(f.x) < 1e-9 then
					junctions = junctions + 1
					eq(#f.edges, 2, tag .. ": the approach and the descent meet at x = 0")
					eq(f.free, 0, tag .. ": x = 0 not free")
					eq(f.snap, 0, tag .. ": no snap at x = 0")
				elseif f.x > g.L and #f.edges == 1 then
					runoutEnds = runoutEnds + 1
					eq(f.snap, 1, tag .. ": runout end snaps")
					eq(f.free, 0, tag .. ": runout end kept")
				end
			end
			eq(junctions, g.count, tag .. ": one joint per street")
			eq(runoutEnds, g.count, tag .. ": one runout end per street")
		end
	end)

	test("joint: hand-over 2 differs from 0 only in the snapping approach's free nodes", function()
		local cap = defaultCap()
		for ci, p in ipairs(CASES) do
			local k0, k2 = script.updateFn(cap, kept(p)), script.updateFn(cap, depot(p))
			eq(#k2.edgeLists, #k0.edgeLists, "case " .. ci .. ": edge count")
			local changed = 0
			for i, e in ipairs(k2.edgeLists) do
				local o = k0.edgeLists[i]
				if table.concat(e.freeNodes, ",") ~= table.concat(o.freeNodes, ",") then
					changed = changed + 1
					eq(#e.snapNodes, 1, "case " .. ci .. " edge " .. i .. ": only the snapping approach changes")
				end
				local a, b = {}, {}
				for k, v in pairs(e) do a[k] = v end
				for k, v in pairs(o) do b[k] = v end
				a.freeNodes, b.freeNodes = nil, nil
				deepEq(a, b, "case " .. ci .. " edge " .. i)
			end
			eq(changed, 1, "case " .. ci .. ": one edge changed")
			local a, b = {}, {}
			for k, v in pairs(k2) do a[k] = v end
			for k, v in pairs(k0) do b[k] = v end
			a.edgeLists, b.edgeLists = nil, nil
			deepEq(a, b, "case " .. ci .. ": models, terrain and snap point the same")
		end
	end)

	-- ramp_geometry.lua as it stood with the 0 / 1 switch only
	-- (tests/fixtures/ramp_geometry_before_depotstyle.lua).
	test("joint: adding hand-over 2 leaves 0, 1, missing and junk below 1.5 as they were (1.0.0's 36m cover)", lid36(function()
		local cap = defaultCap()
		local before = assert(loadfile(root .. "/tests/fixtures/ramp_geometry_before_depotstyle.lua"))()
		for ci, p in ipairs(CASES) do
			-- the values that read as 0 or 1 before (above 1.5 now reads as 2)
			for _, v in ipairs({ 0, 1, "nil", 0.5, 0.4, 1.4, "abc", "1", -5, 0 / 0 }) do
				local q = {}
				for k, x in pairs(p) do q[k] = x end
				if v ~= "nil" then q.rtr_approach_hand_over = v end
				local old = before.build(before.spec(cap, q))
				deepEq(asBefore(geometry.build(geometry.spec(cap, q)), old), old,
					"case " .. ci .. " hand-over " .. tostring(v))
			end
		end
	end))
end

------------------------------------------------------------------------
-- The street menu (1.0.0): the only street of this mod a player can pick
-- there is the one-lane side street with its sidewalk on the right
-- (median_side_r); the other side streets and the cars-only ramp streets
-- are laid by the constructions only. The test streets tried in the game
-- on 2026-11-24 (test_*, "(test)" names) were removed before release, with
-- their strings.
------------------------------------------------------------------------
test("street menu: only median_side_r is in the build menu, no test streets are left", function()
	local p = assert(io.popen(string.format("cd %q && find content -name '*.street_template.lua' | sort", root)))
	local inMenu, n = {}, 0
	for path in p:lines() do
		local stem = path:match("([%w_]+)%.street_template%.lua$")
		assert(not stem:match("^test_"), path .. ": a test street is left")
		local t = loadData("/" .. path)
		assert(not tostring(t.description and t.description.name or ""):match("^rtr_test_"), path .. ": a test name key")
		local cats = t.menuCategory and t.menuCategory.categories or {}
		if #cats > 0 then inMenu[#inMenu + 1] = stem end
		n = n + 1
	end
	p:close()
	assert(n >= 7, "found only " .. n .. " templates")
	eq(#inMenu, 1, "templates in the menu: " .. table.concat(inMenu, ", "))
	eq(inMenu[1], "median_side_r", "the menu's street")
	local t = templateOf("road_tunnel_ramp::/road_tunnel_ramp/streets/median_side_r.street_template")
	eq(t.menuCategory.categories[1].category, "roads_small", "with the small streets")
	eq(t.description.name, "rtr_median_side_name", "name key")
end)

------------------------------------------------------------------------
-- The engine's laneConfigs check (2026-11-24 crash: picking "(test) 24m 2+2
-- gap1" in the road tool, stdout 2026-11-23 18:43:16Z "Sidewalk in inner
-- lane" then "Assertion 'Valid(result.laneConfigs)' failed",
-- StreetShapeFactory.cpp:1042 CreateStreetContext) [measured]. Valid, read
-- from the TransportFever3 binary (build 40444; the function at 0x37901b0
-- called just before that assertion) [source]:
--   no lanes                                       -> "Too few lanes", false
--   1 or 2 lanes                                   -> true (nothing checked)
--   every lane but the first and the last: its transportModes bit set
--   must not be empty and must not have bit 0 (PERSON, the first
--   TransportMode in api/tealdef/api/type.d.tl)    -> else "Sidewalk in inner lane", false
-- Not checked by it (so not here): forward order, widths, heights, which
-- side a sidewalk is on. All 81 base templates pass; so do the 1684 on
-- mod.io in this cache (2026-11-24) [measured].
------------------------------------------------------------------------
-- TransportMode names (api/tealdef/api/type.d.tl): a misspelt one would set
-- no bit, so a lane of only that would carry nothing in the game.
local TRANSPORT_MODES = { PERSON = true, CARGO = true, CAR = true, BUS = true, TRUCK = true, TRAM = true,
	ELECTRIC_TRAM = true, TRAIN = true, ELECTRIC_TRAIN = true, AIRCRAFT = true, SHIP = true,
	SMALL_AIRCRAFT = true, SMALL_SHIP = true, HELICOPTER = true, TRAM_TRACK = true, ELECTRIC_TRAM_TRACK = true }
local function laneConfigsValid(lanes)
	if type(lanes) ~= "table" or #lanes == 0 then return false, "Too few lanes" end
	for i, l in ipairs(lanes) do
		for _, m in ipairs(l.transportModes or {}) do
			if not TRANSPORT_MODES[m] then return false, "lane " .. i .. ": unknown transport mode " .. tostring(m) end
		end
	end
	for i = 2, #lanes - 1 do
		local modes = lanes[i].transportModes or {}
		if #modes == 0 then return false, "Sidewalk in inner lane (lane " .. i .. " carries nothing)" end
		for _, m in ipairs(modes) do
			if m == "PERSON" then return false, "Sidewalk in inner lane (lane " .. i .. " has PERSON)" end
		end
	end
	return true
end

test("laneConfigs Valid: the check itself (the crashed gap1 layout fails, the kept ones pass)", function()
	local C = { "CAR", "BUS", "TRUCK" }
	local function L(fwd, modes, w) return { forward = fwd, transportModes = modes, width = w } end
	eq(laneConfigsValid({}), false, "no lanes")
	-- test_gap24_hw as it was: the 1m strip, carrying nothing, is lane 4 of 7
	local gap1 = { L(false, {}, 1), L(false, C, 5.25), L(false, C, 5.25), L(false, {}, 1), L(true, C, 5.25), L(true, C, 5.25), L(true, {}, 1) }
	local ok, why = laneConfigsValid(gap1)
	eq(ok, false, "gap1"); assert(why:find("lane 4", 1, true), why)
	eq((laneConfigsValid({ L(false, { "PERSON" }, 3), L(false, { "PERSON" }, 3), L(true, C, 5), L(true, { "PERSON" }, 3) })), false, "inner sidewalk")
	eq((laneConfigsValid({ L(true, C, 3.5) })), true, "one lane")
	eq((laneConfigsValid({ L(true, { "CRA" }, 3.5) })), false, "misspelt mode")
	eq((laneConfigsValid({ L(true, {}, 1), L(true, { "PERSON" }, 3) })), true, "two lanes: nothing checked")
	eq((laneConfigsValid({ L(false, {}, 1.5), L(false, C, 5.25), L(true, C, 5.25), L(true, {}, 1.5) })), true, "empty shoulders outside")
end)

test("street templates: every laneConfigs of this mod passes the engine's Valid", function()
	local p = assert(io.popen(string.format("cd %q && find content -name '*.street_template.lua' | sort", root)))
	local n, seen = 0, {}
	for path in p:lines() do
		local t = loadData("/" .. path)
		local ok, why = laneConfigsValid(t.laneConfigs)
		assert(ok, path .. ": " .. tostring(why))
		seen[path:match("([%w_]+)%.street_template%.lua$")] = true
		n = n + 1
	end
	p:close()
	-- the find really saw the templates (7 after the test streets went before 1.0.0), the menu one among them
	assert(n >= 7, "found only " .. n .. " templates")
	for _, stem in ipairs({ "ramp_car_only", "ramp_car_only_bare", "ramp_car_only_town_style",
		"median_side_r", "median_side_l", "median_c_side_r", "median_c_side_l" }) do
		assert(seen[stem], stem .. " not found")
	end
end)

test("street templates: every base template in street.zip passes the same check (the check is not stricter than the game)", function()
	local zip = os.getenv("HOME") .. "/.local/share/Steam/steamapps/common/Transport Fever 3/base/content/infrastructure/street.zip"
	local fh = io.open(zip, "rb")
	if not fh then print("     (skipped: street.zip not found)") return end
	fh:close()
	local lp = assert(io.popen(string.format("unzip -Z1 %q 2>/dev/null", zip)))
	local n = 0
	for member in lp:lines() do
		if member:match("%.street_template%.lua$") then
			local p = assert(io.popen(string.format("unzip -p %q %q 2>/dev/null", zip, member)))
			local src = p:read("*a"); p:close()
			local env = setmetatable({ _ = function(x) return x end }, { __index = _G })
			local chunk = assert(loadstring(src, member)); setfenv(chunk, env); chunk()
			local ok, why = laneConfigsValid(env.data().laneConfigs)
			assert(ok, member .. ": " .. tostring(why))
			n = n + 1
		end
	end
	lp:close()
	assert(n >= 80, "found only " .. n .. " base templates")
end)

------------------------------------------------------------------------
-- Part models (2026-11-24): the wall, the portal cover (slab) and the
-- coping and parapet (strip) each get their own .mdl, written by
-- tools/wall_models.py, so each can get a mesh with texture coordinates
-- baked for its own base size (the one box stretched the cover's top
-- about 18 times across). All take the base game's light concrete: a Wall
-- colour setting (dark concrete, brick, stone) was tried and dropped
-- before release (the user: 「白以外は微妙ですね」「白だけ採用」).
------------------------------------------------------------------------
do
	local geometry = require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua"
	local PARTS = geometry.WALL_MODELS
	-- the part a model's tag belongs to
	local function partOf(tag)
		if tag:find("wall_%-?%d+_%d+_%d+$") then return "wall" end
		if tag:find("^portal_top_cover_%d+_%d+$") then return "slab" end
		if tag:find("coping_%-?%d+_%d+$") or tag:find("parapet_%-?%d+_%d+$") then return "strip" end
	end
	local function readMdl(rel)
		local env = setmetatable({}, { __index = _G })
		local chunk = assert(loadfile(root .. "/content" .. rel))
		setfenv(chunk, env)
		chunk()
		return env.data()
	end

	test("parts: three part models, the wall's the tests' default id", function()
		local n = 0
		for _ in pairs(PARTS) do n = n + 1 end
		eq(n, 3, "parts")
		eq(PARTS.wall, DEFAULT_WALL_MODEL, "wall")
		eq(PARTS.slab, "road_tunnel_ramp::/road_tunnel_ramp/walls/slab.mdl", "slab")
		eq(PARTS.strip, "road_tunnel_ramp::/road_tunnel_ramp/walls/strip.mdl", "strip")
		assert(PARTS.wall ~= PARTS.slab and PARTS.slab ~= PARTS.strip and PARTS.wall ~= PARTS.strip, "three files")
	end)

	test("parts: walls place the wall model, the cover the slab, the coping and parapet the strip (ramp and median)", function()
		local cap = defaultCap()
		for _, wall in ipairs({ 1, 2 }) do
			for _, extra in ipairs({ {}, { rtr_ground_along = 8, rtr_ground_across = -5 }, { rtr_count = 3, rtr_ground_along = -20 } }) do
				local p = { rtr_wall = wall }
				for k, v in pairs(extra) do p[k] = v end
				for _, b in ipairs({ { "ramp", script.updateFn(cap, p) }, { "median", median.updateFn(medianCap, p) } }) do
					local seen = {}
					local what = b[1] .. " wall " .. wall
					for _, m in ipairs(b[2].subconstructions[1].models) do
						local part = partOf(m.tag)
						assert(part, what .. ": a model of no part: " .. tostring(m.tag))
						eq(m.id, PARTS[part], what .. " " .. m.tag)
						seen[part] = (seen[part] or 0) + 1
					end
					for _, part in ipairs({ "wall", "slab", "strip" }) do
						assert((seen[part] or 0) > 0, what .. ": no " .. part)
					end
					if wall == 1 then assert(#modelsByTagPrefix(b[2], "parapet_") > 0, what .. ": parapet missing") end
				end
			end
		end
	end)

	test("parts: the colour setting is gone from both menus and from the strings", function()
		for _, con in ipairs({ "/content/road_tunnel_ramp/ramp.con.lua", "/content/road_tunnel_ramp/median.con.lua" }) do
			for _, prm in ipairs(loadData(con).params) do
				assert(prm.key ~= "rtr_wall_color", con .. ": rtr_wall_color still offered")
			end
		end
		local f = assert(io.open(root .. "/strings.json"))
		local body = f:read("*a"); f:close()
		assert(not body:find("rtr_wall_color", 1, true), "strings.json still has rtr_wall_color")
		-- a leftover value in old params changes nothing
		local cap = defaultCap()
		deepEq(script.updateFn(cap, { rtr_wall_color = 3 }), script.updateFn(cap, {}), "rtr_wall_color ignored")
	end)

	test("parts: every model exists, on the box the transforms scale, with its own mesh path and the one base-game material", function()
		local material
		for _, part in ipairs({ "wall", "slab", "strip" }) do
			local rel = PARTS[part]:match("^road_tunnel_ramp::(/.+)$")
			assert(rel, "not this mod's: " .. PARTS[part])
			eq(rel, "/road_tunnel_ramp/walls/" .. part .. ".mdl", "file name")
			local d = readMdl(rel)
			eq(table.concat(d.boundingInfo.bbMin, ","), "0,-0.225,0", part .. " bbMin")
			eq(table.concat(d.boundingInfo.bbMax, ","), "1,0.225,1", part .. " bbMax")
			eq(#d.lods, 1, part .. " lods")
			eq(#d.lods[1].node.children, 1, part .. " children")
			local child = d.lods[1].node.children[1]
			eq(child.name, part, part .. ": node name")
			local fh = io.open(root .. "/content" .. child.mesh, "rb")
			assert(fh, part .. ": mesh missing " .. child.mesh); fh:close()
			fh = io.open(root .. "/content" .. child.mesh .. ".blob", "rb")
			assert(fh, part .. ": mesh blob missing"); fh:close()
			eq(#child.materials, 1, part .. " materials")
			assert(child.materials[1]:match("^::/[%w_/]+%.mtl$"), part .. ": material " .. child.materials[1])
			material = material or child.materials[1]
			eq(child.materials[1], material, part .. ": one material for all parts")
		end
		eq(material, "::/warehouses/wh_goods/mat/warehouse_goods_concrete.mtl", "light concrete")
	end)

	test("parts: the old walls/concrete.mdl stays for old saves, as the wall model, and no build places it", function()
		-- saves from before the mod's own box name it in their model table;
		-- a missing file brings up the game's "models are missing" window
		-- on load (2026-11-25)
		local d = readMdl("/road_tunnel_ramp/walls/concrete.mdl")
		deepEq(d, readMdl(PARTS.wall:match("::(/.+)$")), "same as wall.mdl")
		local child = d.lods[1].node.children[1]
		eq(child.mesh, "/road_tunnel_ramp/walls/aom_wall_box.msh", "the mod's own box")
		eq(#child.materials, 1, "materials")
		eq(child.materials[1], "::/warehouses/wh_goods/mat/warehouse_goods_concrete.mtl", "the base game's light concrete")
		for _, v in pairs(PARTS) do assert(v ~= OLD_WALL_MODEL, "a part is the old name") end
		local cap = defaultCap()
		for _, b in ipairs({ script.updateFn(cap, {}), median.updateFn(medianCap, {}), script.updateFn(cap, { rtr_wall = 2, rtr_count = 3 }) }) do
			for _, m in ipairs(b.subconstructions[1].models) do
				assert(m.id ~= OLD_WALL_MODEL, "placed the old name: " .. tostring(m.tag))
			end
		end
	end)

	test("parts: the material exists in the base game, in the form its models use (skipped without the game)", function()
		local base = os.getenv("HOME") .. "/.local/share/Steam/steamapps/common/Transport Fever 3/base/content"
		local probe = io.open(base .. "/infrastructure/street.zip", "rb")
		if not probe then print("     (skipped: base game not found)") return end
		probe:close()
		for _, part in ipairs({ "wall", "slab", "strip" }) do
			local m = readMdl(PARTS[part]:match("::(/.+)$")).lods[1].node.children[1].materials[1]
			-- ::/<dir>/<zip stem>/<rest> lives in content/<dir>/<zip stem>.zip
			-- as <zip stem>/<rest>, or ::/<zip stem>/<rest> in content/<zip stem>.zip
			local rel = m:sub(4)
			local found = false
			local parts = {}
			for piece in rel:gmatch("[^/]+") do parts[#parts + 1] = piece end
			for cut = 1, #parts - 1 do
				local dir = table.concat(parts, "/", 1, cut - 1)
				local zip = base .. "/" .. (dir ~= "" and dir .. "/" or "") .. parts[cut] .. ".zip"
				local member = table.concat(parts, "/", cut)
				local fh = io.open(zip, "rb")
				if fh then
					fh:close()
					local lp = assert(io.popen(string.format("unzip -Z1 %q %q 2>/dev/null", zip, member)))
					local out = lp:read("*a"); lp:close()
					if out:find(member, 1, true) then
						-- the form the base game's models use (samplers under
						-- fragmentSamplers)
						local mp = assert(io.popen(string.format("unzip -p %q %q 2>/dev/null", zip, member)))
						local body = mp:read("*a"); mp:close()
						assert(body:find("fragmentSamplers", 1, true), part .. ": " .. m .. " is not in the models' material form")
						found = true
						break
					end
				end
			end
			assert(found, part .. ": " .. m .. " not in the base game")
		end
	end)
end

------------------------------------------------------------------------
-- The mod's own wall box (2026-11-24). The borrowed wall mesh and
-- material (Enivia's Railway Tunnel Approach) were replaced with
-- walls/aom_wall_box.msh, made for this mod, because no
-- permission to use them came (the user: 「擁壁部分のモデルの使用許可が来
-- ないので、自力作成するのはどう思いますか？」「自力で作って色を選べるよう
-- に」). Its texture coordinates are baked for a 4m x 6m wall piece, so a
-- wall is stacked in boxes of about 6m and the cover laid in 4m pieces.
------------------------------------------------------------------------
do
	local geometry = require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua"
	local function models(r) return r.subconstructions[1].models end
	-- every stack, keyed by its base tag, its pieces in order
	local function stacks(r)
		local out, order = {}, {}
		for _, m in ipairs(models(r)) do
			local base, k = m.tag:match("^(.*wall_%-?%d+_%d+)_(%d+)$")
			if base then
				if not out[base] then out[base] = {}; order[#order + 1] = base end
				local st = out[base]
				st[#st + 1] = { k = tonumber(k), m = m }
			end
		end
		return out, order
	end
	local CASES = {
		{},
		{ rtr_wall = 2 },
		{ rtr_length = 400, rtr_depth = 25 },
		{ rtr_length = 40, rtr_depth = 25, rtr_curvature = 5, rtr_count = 3 },
		{ rtr_length = 40, rtr_depth = 13, rtr_curvature = 1 },
		{ rtr_ground_along = 8, rtr_ground_across = 5 },
		{ rtr_ground_along = -20, rtr_ground_across = -20, rtr_wall = 2 },
		{ rtr_ground_along = 20, rtr_ground_across = 20, rtr_length = 40, rtr_approach = 50 },
		{ rtr_ground_along = -8, rtr_ground_across = 3, rtr_direction = 2, rtr_side = 2 },
	}
	local function builds(p)
		return { { "ramp", script.updateFn(defaultCap(), p) }, { "median", median.updateFn(medianCap, p) } }
	end

	test("stack: n = max(1, round(H / 6)) at the ends of its range", function()
		eq(geometry.WALL_STACK, 6, "the box's baked height")
		for _, c in ipairs({
			{ 0, 1 }, { -2, 1 }, { 0.5, 1 }, { 2.99, 1 }, { 3, 1 },   -- under 6m: one box
			{ 6, 1 }, { 8.99, 1 },                                  -- exactly 6, up to 9
			{ 9, 2 }, { 12, 2 }, { 14.99, 2 }, { 15, 3 }, { 18, 3 }, { 36, 6 }, { 100, 17 },
		}) do
			eq(geometry.stackCount(c[1]), c[2], "stackCount(" .. c[1] .. ")")
		end
	end)

	test("stack: every wall piece is boxes of one height that add up to it, base to top with no gap or overlap (ramp and median)", function()
		local maxN = 0
		for ci, p in ipairs(CASES) do
			for _, b in ipairs(builds(p)) do
				local tag0 = b[1] .. " case " .. ci
				local merged = {}
				for _, m in ipairs(models(oneBox(b[2]))) do merged[m.tag] = m end
				local all, order = stacks(b[2])
				assert(#order > 0, tag0 .. ": walls")
				for _, base in ipairs(order) do
					local st, tag = all[base], tag0 .. " " .. base
					local n = #st
					local first, one = st[1].m.transf, merged[base].transf
					local H = 0
					for j, piece in ipairs(st) do
						eq(piece.k, j, tag .. ": pieces numbered 1..n bottom up")
						H = H + piece.m.transf[11]
					end
					near(H, one[11], 1e-12, tag .. ": the heights add up to the piece")
					eq(n, geometry.stackCount(H), tag .. ": n from the height")
					maxN = math.max(maxN, n)
					if H >= 4.5 then
						local h = H / n
						assert(h >= 4.5 - 1e-9 and h < 9 + 1e-9, tag .. ": box height " .. h)
					end
					for j, piece in ipairs(st) do
						local t = piece.m.transf
						near(t[11], H / n, 1e-9, tag .. ": box " .. j .. " of one height")
						eq(piece.m.id, st[1].m.id, tag .. ": one model")
						-- the same footprint and shear: each top runs on the next base
						for _, k in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13, 14, 16 }) do
							eq(t[k], first[k], tag .. ": box " .. j .. " transf[" .. k .. "]")
						end
						if j > 1 then
							local below = st[j - 1].m.transf
							near(t[15], below[15] + below[11], 1e-9, tag .. ": box " .. j .. " on the one below")
						end
					end
					near(first[15], one[15], 0, tag .. ": the stack starts at the piece's base")
					local top = st[n].m.transf
					near(top[15] + top[11], one[15] + one[11], 1e-9, tag .. ": and ends at its top")
				end
			end
		end
		assert(maxN >= 3, "some walls are stacked three high (deepest " .. maxN .. ")")
	end)

	test("cover pieces: coverAcross(W) = max(1, round(W / 4)) at the ends of its range", function()
		for _, c in ipairs({
			{ -5, 1 }, { 0, 1 }, { 1, 1 }, { 5.99, 1 },     -- under 6m: one piece (the slab as it was)
			{ 6, 2 }, { 9.99, 2 }, { 10, 3 }, { 19, 5 }, { 20, 5 }, { 59, 15 }, { 200, 50 },
		}) do
			eq(geometry.coverAcross(c[1]), c[2], "coverAcross(" .. c[1] .. ")")
		end
	end)

	test("cover pieces: the cover in 4m pieces along and W / round(W / 4) across, edge to edge, as long, as wide and as high as the one slab (1.0.0's 36m cover)", lid36(function()
		local widths = {}
		for ci, p in ipairs(CASES) do
			for _, b in ipairs(builds(p)) do
				local tag = b[1] .. " case " .. ci
				local r = b[2]
				local _, g = geometry.build(geometry.spec(defaultCap(), p))
				local pieces = modelsByTagPrefix(r, "portal_top_cover_")
				local one = modelsByTagPrefix(oneBox(r), "portal_top_cover")
				eq(#one, 1, tag .. ": one slab")
				one = one[1].transf
				local W = one[6] * 0.45
				local nA = geometry.coverAcross(W)
				widths[#widths + 1] = W
				eq(#pieces, 9 * nA, tag .. ": 36m in 4m pieces, " .. nA .. " across")
				local grid = {}
				for k, m in ipairs(pieces) do
					local i, j = math.floor((k - 1) / nA) + 1, (k - 1) % nA + 1
					eq(m.tag, string.format("portal_top_cover_%d_%d", i, j), tag .. ": numbered along, then across")
					grid[i] = grid[i] or {}
					grid[i][j] = m.transf
				end
				local first = grid[1][1]
				for i = 1, 9 do
					local width = 0
					for j = 1, nA do
						local t, what = grid[i][j], tag .. " piece " .. i .. "_" .. j
						near(t[1], 4, 1e-9, what .. ": 4m along")
						near(t[6] * 0.45, W / nA, 1e-9, what .. ": W / n across")
						width = width + t[6] * 0.45
						-- the same box at the same scale, along x and on one plane
						for _, k in ipairs({ 2, 4, 5, 8, 9, 10, 11, 12, 16 }) do
							eq(t[k], first[k], what .. " transf[" .. k .. "]")
						end
						near(t[3] / t[1], first[3] / first[1], 1e-9, what .. ": rises as the slab")
						near(t[7] / t[6], first[7] / first[6], 1e-12, what .. ": tilts as the slab")
						if j > 1 then
							-- no gap and no overlap across, and the faces meet in height
							local o = grid[i][j - 1]
							near(t[14] - t[6] * 0.225, o[14] + o[6] * 0.225, 1e-9, what .. ": starts where the one beside ends")
							near(t[15] - t[7] * 0.225, o[15] + o[7] * 0.225, 1e-9, what .. ": at its height")
							eq(t[13], o[13], what .. ": same x")
						end
						if i > 1 then
							local o = grid[i - 1][j]
							near(t[13], o[13] + o[1], 1e-9, what .. ": starts where the one before ended")
							near(t[15], o[15] + o[3], 1e-9, what .. ": and at its height")
							eq(t[14], o[14], what .. ": same y")
						end
					end
					near(width, W, 1e-9, tag .. " row " .. i .. ": as wide as the slab")
					-- the row's outer edges are the slab's
					near(grid[i][1][14] - grid[i][1][6] * 0.225, -W / 2, 1e-9, tag .. " row " .. i .. ": from -W/2")
					near(grid[i][nA][14] + grid[i][nA][6] * 0.225, W / 2, 1e-9, tag .. " row " .. i .. ": to W/2")
				end
				local len = 0
				for i = 1, 9 do len = len + grid[i][1][1] end
				near(len, 36, 1e-9, tag .. ": 36m in all")
				near(len, one[1], 1e-12, tag .. ": the length of the one slab")
				near(one[14], 0, 1e-9, tag .. ": the slab centred")
				if b[1] == "ramp" then
					near(W, g.roofHalf * 2, 1e-9, tag .. ": as wide as roofHalf * 2")
					eq(first[13], g.lidA, tag .. ": starts at lidA")
					local last = grid[9][nA]
					eq(last[13] + last[1], g.lidB, tag .. ": ends at lidB")
				end
			end
		end
		-- the cases cover narrow and wide covers
		table.sort(widths)
		assert(widths[1] < 22 and widths[#widths] > 40, "cover widths " .. widths[1] .. ".." .. widths[#widths])
	end))

	test("cover pieces: one piece across is the one slab (y 0, the full width) bit for bit, and the split adds up to it (1.0.0's 36m cover)", lid36(function()
		-- a cover under 6m wide is one piece: the y position 0 and the
		-- width roofHalf * 2 exactly, as the one slab had (the frozen-build
		-- comparisons hold the slab to the earlier builds)
		local s = geometry.spec(defaultCap(), {})
		local r, g = geometry.build(s)
		local W = g.roofHalf * 2
		local pieces = modelsByTagPrefix(r, "portal_top_cover_")
		local nA = geometry.coverAcross(W)
		assert(nA > 1, "the default cover is split across")
		-- the same build with coverAcross giving one piece across
		local coverAcross = geometry.coverAcross
		geometry.coverAcross = function() return 1 end
		local ok, r1 = pcall(geometry.build, s)
		geometry.coverAcross = coverAcross
		assert(ok, tostring(r1))
		local p1 = modelsByTagPrefix(r1, "portal_top_cover_")
		eq(#p1, 9, "one across: nine pieces")
		for i, m in ipairs(p1) do
			eq(m.tag, "portal_top_cover_" .. i .. "_1", "tag")
			eq(m.transf[14], 0, "centred on y 0")
			eq(m.transf[6], W / 0.45, "the full width")
			eq(m.transf[15], g.lidZ(m.transf[13], 0) - 0.3, "on the plane at y 0")
		end
		-- and the split one adds back to it within the last bits
		local merged = modelsByTagPrefix(oneBox(r), "portal_top_cover")[1].transf
		local whole = modelsByTagPrefix(oneBox(r1), "portal_top_cover")[1].transf
		for k = 1, 16 do near(merged[k], whole[k], 1e-9 * math.max(1, math.abs(whole[k])), "transf[" .. k .. "]") end
		eq(#pieces, 9 * nA, "split")
	end))

	test("cover pieces: pieces() splits a run into equal pieces ending on its end", function()
		local function check(x0, x1, len, wantN)
			local xs, n = geometry.pieces(x0, x1, len)
			eq(n, wantN, string.format("pieces(%g, %g, %g)", x0, x1, len))
			eq(xs[0], x0, "first end")
			eq(xs[n], x1, "last end is x1 itself")
			for i = 1, n do near(xs[i] - xs[i - 1], (x1 - x0) / n, 1e-9, "equal") end
			for i = 1, n do assert(xs[i] - xs[i - 1] <= len + 1e-9, "at most len") end
		end
		check(10, 46, 4, 9)        -- 36 exactly: no tenth sliver
		check(0, 10, 4, 3)
		check(0, 3, 4, 1)          -- shorter than one piece
		check(5, 5, 4, 1)          -- empty run: one piece
		check(0.1, 36.1, 4, 9)
		check(0, 4.0000001, 4, 2)
	end)

	test("stack: the number of pieces stays bounded (walls and cover, ramp and median) (1.0.0's 36m cover)", lid36(function()
		-- 2026-11-24 the default ramp went from 65 to 83 models (wall
		-- stacks, the cover in 4m pieces along), then to 128 (the 22.8m
		-- cover also in 6 pieces across: 9 x 6 for 9). The walls and the rest at most
		-- double; the cover is 9 x coverAcross(W) pieces
		local function n(r) return #models(r) end
		eq(n(script.updateFn(defaultCap(), {})), 128, "the default ramp")
		local most = 0
		-- the widest cover (three Large Streets) with the tallest walls:
		-- the most models of any menu setting (577, against 352 before the
		-- split across; counted over every street, count, wall, slope and
		-- depth 2026-11-24)
		local cases = {}
		for _, p in ipairs(CASES) do cases[#cases + 1] = p end
		cases[#cases + 1] = { rtr_street = 7, rtr_count = 3, rtr_wall = 1, rtr_ground_along = -20,
			rtr_ground_across = -20, rtr_depth = 13, rtr_approach = 50 }
		for ci, p in ipairs(cases) do
			for _, b in ipairs(builds(p)) do
				local what = b[1] .. " case " .. ci
				local covers = #modelsByTagPrefix(b[2], "portal_top_cover_")
				local one = modelsByTagPrefix(oneBox(b[2]), "portal_top_cover")[1].transf
				eq(covers, 9 * geometry.coverAcross(one[6] * 0.45), what .. ": cover pieces")
				local merged = n(oneBox(b[2])) - 1
				local rest = n(b[2]) - covers
				assert(rest <= merged * 2, what .. ": " .. rest .. " models for " .. merged .. " boxes before")
				most = math.max(most, n(b[2]))
			end
		end
		eq(n(script.updateFn(defaultCap(), cases[#cases])), 577, "the widest, tallest ramp")
		assert(most <= 600, "at most " .. most .. " models")
		if os.getenv("RTR_PRINT_COUNTS") then
			print("     most models in the cases: " .. most)
			for _, p in ipairs({ { rtr_wall = 1 }, { rtr_wall = 2 }, { rtr_wall = 2, rtr_street = 7, rtr_count = 3, rtr_ground_along = -20 } }) do
				for _, b in ipairs(builds(p)) do
					local covers = #modelsByTagPrefix(b[2], "portal_top_cover_")
					local W = modelsByTagPrefix(oneBox(b[2]), "portal_top_cover")[1].transf[6] * 0.45
					print(string.format("     %s wall %d street %s count %s: W %.2f, %d models (%d before the split across)",
						b[1], p.rtr_wall, tostring(p.rtr_street), tostring(p.rtr_count), W, n(b[2]), n(b[2]) - covers + 9))
				end
			end
		end
	end))

	test("assets: the borrowed wall files are gone; the wall models use the mod's own box", function()
		-- concrete.mdl stays by name on the mod's box (the old-saves test above)
		for _, f in ipairs({ "wall.msh", "wall.msh.blob", "concrete_albedo.dds", "concrete_mga.dds", "concrete.mtl" }) do
			local h = io.open(root .. "/content/road_tunnel_ramp/walls/" .. f, "rb")
			if h then h:close() end
			assert(not h, "walls/" .. f .. " (Enivia's) is still in the mod")
		end
		for part, id in pairs(geometry.WALL_MODELS) do
			local f = assert(io.open(root .. "/content" .. id:match("^road_tunnel_ramp::(/.+)$")))
			local body = f:read("*a"); f:close()
			-- the mod's own meshes (aom_wall_box, or the slab and strip boxes made for it)
			assert(body:find('"/road_tunnel_ramp/walls/aom_[%w_]+%.msh"'), part .. ": the mod's own box")
			assert(not body:find("/road_tunnel_ramp/walls/concrete.mtl", 1, true), part .. ": no borrowed material")
		end
		-- nothing that builds the walls still names the old model
		for _, rel in ipairs({ "ramp_geometry.lua", "median_geometry.lua", "ramp.script.lua", "median.script.lua" }) do
			local f = assert(io.open(root .. "/content/road_tunnel_ramp/" .. rel))
			local body = f:read("*a"); f:close()
			assert(not body:find("walls/concrete.mdl", 1, true), rel .. " names walls/concrete.mdl")
			assert(not body:find("wall.msh", 1, true), rel .. " names wall.msh")
		end
	end)
end

------------------------------------------------------------------------
-- Portal cover length (rtr_cover_length, 2026-11-26): the cover's whole
-- length, LID_MIN-24m in 1m steps, 18 initially, from 6m in front of the portal
-- (lidA) as before; 1.0.0's 36m is not offered. A mod.io comment asked why
-- a road needs that huge slab; the user: 「しかし、現在は確かに長過ぎる気が
-- します」「30とかそもそもいらないので、6-18ぐらいをスライダーにするとかは？」
-- 「全体の長さにしてください」.
------------------------------------------------------------------------
do
	local rampSpec = loadData("/content/road_tunnel_ramp/ramp.con.lua")
	local MIN = rampGeo.LID_MIN
	local LENGTHS = { MIN, MIN + 1, 12, 18, 23, 24 }

	-- 1.1.1: the lower end raised from 6m. At 6m the lid ended on the portal
	-- and the top of the game's tunnel portal piece (tunnel_a_car) showed
	-- past it [in game, picture, 2026-11-26]; the user: 「6mはなんかおかしい
	-- ですよね」「下限を上げて隠す、ということですね」「OKです。その方針で」.
	-- e2e picks 8, 10 or 12 (10 until then); 18m initially and 24m at most
	-- stay.
	test("cover length: the range is 8, 10 or 12 to 24m, 18m initially; the shortest reaches past the portal", function()
		assert(MIN == 8 or MIN == 10 or MIN == 12, "LID_MIN " .. tostring(MIN))
		eq(rampGeo.LID_MAX, 24, "max")
		eq(rampGeo.LID_DEFAULT, 18, "initial")
		assert(MIN > rampGeo.LID_BEHIND, "the shortest lid starts in front of the portal and ends past it")
		local p = defaultParams()
		p.rtr_cover_length = MIN
		local _, g = rampGeo.build(rampGeo.spec(defaultCap(), p))
		near(g.lidB - g.portalX, MIN - 6, 1e-9, "the shortest lid's run past the portal")
		assert(g.lidB - g.portalX >= 2 - 1e-9, "at least 2m past the portal")
	end)

	test("cover length: both menus offer rtr_cover_length LID_MIN-24m in 1m steps after the wall, 18m initially", function()
		for _, spec in ipairs({ rampSpec, medianSpec }) do
			local keys, prm = {}, nil
			for i, q in ipairs(spec.params) do
				keys[#keys + 1] = q.key
				if q.key == "rtr_cover_length" then
					prm = q
					eq(spec.params[i - 1].key, "rtr_wall", "right after the wall")
				end
			end
			assert(prm, "rtr_cover_length in " .. table.concat(keys, " "))
			eq(prm.uiType, "Slider", "a slider, as rtr_length")
			eq(prm.name, "rtr_cover_length_name", "name key")
			eq(prm.tooltip, "rtr_cover_length_tooltip", "tooltip key")
			eq(#prm.numbers, 24 - MIN + 1, "LID_MIN..24")
			eq(#prm.values, #prm.numbers, "a label for each")
			for i, n in ipairs(prm.numbers) do
				eq(n, MIN - 1 + i, "numbers")
				eq(prm.values[i], (MIN - 1 + i) .. "m", "labels")
			end
			eq(prm.numbers[prm.defaultIndex], 18, "18m initially")
			eq(prm.numbers[prm.defaultIndex], rampGeo.LID_DEFAULT, "the same as the script's")
			eq(prm.numbers[1], rampGeo.LID_MIN, "min")
			eq(prm.numbers[#prm.numbers], rampGeo.LID_MAX, "max")
		end
	end)

	-- Below the range: LID_MIN. A ramp placed with 1.1.0's 6-9m keeps that
	-- value in its params and is rebuilt with the shortest length, which is
	-- also what its settings window's slider shows (the nearest of its
	-- numbers: gui script_param_util.tl findNumberIndex1).
	test("cover length: below the range reads as LID_MIN, 1.1.0's 6-9m too, and builds as LID_MIN", function()
		for _, v in ipairs({ 6, 7, 8, 9, 9.99, MIN - 0.01, 5, 5.99, 0, -6, -math.huge, "6" }) do
			if tonumber(v) < MIN then
				local p = { rtr_cover_length = v }
				eq(rampGeo.lidLengthOf(p), MIN, "value " .. tostring(v))
				eq(rampGeo.spec(defaultCap(), p).lidLength, MIN, "spec, value " .. tostring(v))
				eq(medianGeo.spec(medianCap, p).lidLength, MIN, "median spec, value " .. tostring(v))
			end
		end
		local ref = script.updateFn(defaultCap(), defaultParams({ rtr_cover_length = MIN }))
		local mref = median.updateFn(medianCap, { rtr_cover_length = MIN })
		for _, v in ipairs({ 6, MIN - 1, 0 }) do
			deepEq(script.updateFn(defaultCap(), defaultParams({ rtr_cover_length = v })), ref, "ramp " .. v)
			deepEq(median.updateFn(medianCap, { rtr_cover_length = v }), mref, "median " .. v)
		end
		local _, g = rampGeo.build(rampGeo.spec(defaultCap(), defaultParams({ rtr_cover_length = 6 })))
		assert(g.lidB > g.portalX, "1.1.0's 6m rebuilt past the portal")
	end)

	test("cover length: missing, junk and above the range read as 18m; in range to the whole metre", function()
		for _, v in ipairs({ "nil", "abc", 0 / 0, 24.01, 25, 30, 36, 1e9, math.huge, true }) do
			local p = {}
			if v ~= "nil" then p.rtr_cover_length = v end
			eq(rampGeo.lidLengthOf(p), 18, "value " .. tostring(v))
			eq(rampGeo.spec(defaultCap(), p).lidLength, 18, "spec, value " .. tostring(v))
			eq(medianGeo.spec(medianCap, p).lidLength, 18, "median spec, value " .. tostring(v))
		end
		eq(rampGeo.lidLengthOf(nil), 18, "no params")
		for _, c in ipairs({ { MIN, MIN }, { 24, 24 }, { 13, 13 }, { "13", 13 }, { 12.4, 12 }, { 12.5, 13 }, { MIN + 0.2, MIN }, { 23.6, 24 } }) do
			eq(rampGeo.lidLengthOf({ rtr_cover_length = c[1] }), c[2], "value " .. tostring(c[1]))
		end
		-- and the whole build: nil and out of range build the 18m ramp and median
		local ref = script.updateFn(defaultCap(), defaultParams({ rtr_cover_length = 18 }))
		local mref = median.updateFn(medianCap, { rtr_cover_length = 18 })
		for _, v in ipairs({ "nil", 25, 36, "abc" }) do
			local p = defaultParams()
			local q = {}
			if v ~= "nil" then p.rtr_cover_length = v; q.rtr_cover_length = v end
			deepEq(script.updateFn(defaultCap(), p), ref, "ramp " .. tostring(v))
			deepEq(median.updateFn(medianCap, q), mref, "median " .. tostring(v))
		end
		-- layout refuses a lid that would end before the portal
		local sp = rampGeo.spec(defaultCap(), {})
		sp.lidLength = 5.9
		assert(not pcall(rampGeo.layout, sp), "lidLength under 6 refused")
		sp.lidLength = "18"
		assert(not pcall(rampGeo.layout, sp), "a string refused")
		sp.lidLength = nil
		eq(rampGeo.layout(sp).lidLength, 18, "a spec without it: 18")
	end)

	-- The ramp's cases: level, uphill, cross, a downhill the ramp gets under,
	-- one too steep (the lid lifted), short and deep, three wide streets.
	local RAMP_CASES = {
		{}, { rtr_ground_along = 8, rtr_ground_across = 5 }, { rtr_ground_along = -3, rtr_ground_across = -7 },
		{ rtr_ground_along = -10, rtr_ground_across = 10, rtr_depth = 13 }, { rtr_length = 40, rtr_depth = 25 },
		{ rtr_street = 7, rtr_count = 3, rtr_wall = 1 },
	}
	local function lists(r) return r.subconstructions[1].terrainAlignmentLists end
	local function xRange(faces)
		local lo, hi = math.huge, -math.huge
		for _, f in ipairs(faces) do
			for _, v in ipairs(f) do lo, hi = math.min(lo, v[1]), math.max(hi, v[1]) end
		end
		return lo, hi
	end

	test("cover length: the lid, its terrain faces and the banks past it end at lidA + length; the start stays 6m before the portal", function()
		for _, C in ipairs(LENGTHS) do
			for ci, base in ipairs(RAMP_CASES) do
				local p = defaultParams(base)
				p.rtr_cover_length = C
				local tag = string.format("cover %d case %d", C, ci)
				local r, g = rampGeo.build(rampGeo.spec(defaultCap(), p))
				deepEq(script.updateFn(defaultCap(), p), r, tag .. ": the script builds the module's result")
				local px = portalXOf(r)
				eq(g.portalX, px, tag .. ": portal")
				eq(g.lidLength, C, tag .. ": lidLength")
				eq(g.lidA, px - 6, tag .. ": lidA 6m before the portal")
				near(g.lidB - g.lidA, C, 1e-9, tag .. ": lidB = lidA + length")
				eq(g.coverA, px - 6.25, tag .. ": coverA")
				near(g.coverB, g.lidB + 0.25, 1e-9, tag .. ": coverB 0.25m past the lid")
				near(g.lidB - px, C - 6, 1e-9, tag .. ": C - 6 past the portal")
				-- the slab: pieces of at most 4m from lidA to lidB
				local pieces = modelsByTagPrefix(r, "portal_top_cover_")
				local nA = rampGeo.coverAcross(g.roofHalf * 2)
				local nL = math.ceil(C / 4 - 1e-9)
				eq(#pieces, nL * nA, tag .. ": " .. nL .. " pieces along")
				for _, m in ipairs(pieces) do
					assert(m.transf[1] <= 4 + 1e-9, tag .. ": a piece at most 4m")
				end
				local lid = modelsByTagPrefix(oneBox(r), "portal_top_cover")[1].transf
				eq(lid[13], g.lidA, tag .. ": the slab from lidA")
				near(lid[13] + lid[1], g.lidB, 1e-9, tag .. ": the slab to lidB")
				-- terrain: LESS under the cover, GREATER lid support, both to coverB
				local tl = lists(r)
				local lo, hi = xRange(tl[3].faces)
				near(lo, g.coverA, 1e-9, tag .. ": cover face from coverA")
				near(hi, g.coverB, 1e-9, tag .. ": cover face to coverB")
				lo, hi = xRange(tl[4].faces)
				near(lo, g.coverA, 1e-9, tag .. ": lid support from coverA")
				near(hi, g.coverB, 1e-9, tag .. ": lid support to coverB")
				-- the lid support's part past the portal: portalX .. coverB, never inside out
				local past = tl[4].faces[1]
				near(past[1][1], px, 1e-9, tag .. ": support past the portal from the portal")
				assert(past[2][1] > past[1][1], tag .. ": support past the portal runs forward")
				-- the banks: beside the lid to coverB, then the end face past it
				local sh = tl[2].faces
				local endFace = sh[#sh]
				near(math.min(endFace[1][1], endFace[2][1]), g.coverB, 1e-9, tag .. ": end bank from coverB")
				near(math.max(endFace[1][1], endFace[2][1]), g.coverB + (g.shoulderOut - g.lidEdge), 1e-9, tag .. ": end bank's far edge")
				lo, hi = xRange({ sh[#sh - 1] })
				near(hi, g.coverB, 1e-9, tag .. ": the bank beside the lid to coverB")
				-- nothing of the lid's past the stub's end, and the stub unchanged
				assert(g.lidB < g.runoutEnd, tag .. ": lid ends short of the stub's end")
				eq(g.runoutEnd, g.L + 30, tag .. ": the stub 30m")
			end
		end
	end)

	-- The lift is found over the tunnel's first HOLD_AHEAD (30m) past the
	-- portal whatever the lid's length (review 2026-11-26: with only the
	-- lid's run, the stub came out of steep downhill ground), so the walls,
	-- coping and banks that rise to it do not change either.
	test("cover length: the edges, the stub, the floor, the lift, the walls, the coping and the cost do not depend on it", function()
		local lifted = 0
		for ci, base in ipairs(RAMP_CASES) do
			local ref, gRef = rampGeo.build(rampGeo.spec(defaultCap(), defaultParams(with(base, { rtr_cover_length = 18 }))))
			if gRef.lift > 0 then lifted = lifted + 1 end
			for _, C in ipairs(LENGTHS) do
				local tag = string.format("cover %d case %d", C, ci)
				local r, g = rampGeo.build(rampGeo.spec(defaultCap(), defaultParams(with(base, { rtr_cover_length = C }))))
				deepEq(r.edgeLists, ref.edgeLists, tag .. ": edges")
				deepEq(r.snapPoint, ref.snapPoint, tag .. ": snap")
				eq(r.cost, ref.cost, tag .. ": cost")
				eq(g.portalX, gRef.portalX, tag .. ": portal")
				eq(g.lift, gRef.lift, tag .. ": lift")
				deepEq(lists(r)[1], lists(ref)[1], tag .. ": floor")
				for _, prefix in ipairs({ "wall_", "coping_", "parapet_", "approach_" }) do
					deepEq(modelsByTagPrefix(r, prefix), modelsByTagPrefix(ref, prefix), tag .. ": " .. prefix)
				end
			end
		end
		assert(lifted > 0, "a lifted case among them")
	end)

	-- The review's case (2026-11-26): steep downhill puts the portal at the
	-- descent's foot, and past a short lid the plane ran under the tunnel
	-- roof over the stub. The ground the faces hold over the tunnel (the
	-- lid support, the hold face past the lid) is over the roof all the way
	-- from the portal to 30m past it, at every length; the hold face only
	-- when lifted and the lid is short of that.
	test("cover length: on steep downhill the ground over the tunnel's first 30m past the portal stays over the roof at every length", function()
		local checked = 0
		for _, C in ipairs({ 6, 12, 18, 24, 36 }) do
			for _, D in ipairs({ 13, 16, 25 }) do
				for _, L in ipairs({ 40, 100 }) do
					for _, along in ipairs({ -2, -4, -6, -10, -20 }) do
						for _, across in ipairs({ -10, 0, 10 }) do
							local s = rampGeo.spec(defaultCap(), defaultParams({ rtr_depth = D, rtr_length = L,
								rtr_ground_along = along, rtr_ground_across = across }))
							s.lidLength = C
							local r, g = rampGeo.build(s)
							local tag = string.format("cover %d D %d L %d along %d across %d", C, D, L, along, across)
							local tl = lists(r)
							local hold = nil
							for k = 5, #tl do
								if tl[k].type == "GREATER" then hold = tl[k] end
							end
							local want = g.lift > 0 and g.lidB < g.portalX + 30 - 1e-9
							eq(hold ~= nil, want, tag .. ": hold face only when lifted and short")
							-- where the faces hold the ground: under the lid (lid
							-- support) and past it (hold), as a function of x
							local function heldAt(x, y)
								local z = -math.huge
								local faces = { tl[4].faces[1] }
								if hold then faces[#faces + 1] = hold.faces[1] end
								for _, f in ipairs(faces) do
									local x0, x1 = f[1][1], f[2][1]
									if x >= x0 - 1e-9 and x <= x1 + 1e-9 then
										-- planar: under the lid 0.55 below the lid's plane,
										-- past it on the plane
										z = math.max(z, g.lidZ(x, y) - (f == tl[4].faces[1] and 0.55 or 0))
									end
								end
								return z
							end
							for k = 0, 30 do
								local x = g.portalX + k
								local z = heldAt(x, 0)
								local roof = g.roadZ(x) + g.tunnelHeight
								if g.lift > 0 then
									-- (as under the lid before: at 13m deep the held ground
									-- sits up to 0.06m into the roof, the steep downhill test)
									assert(z >= roof - 0.1, tag .. string.format(": x %.1f held %.2f, roof %.2f", x, z, roof))
								else
									-- not lifted: the plane itself is over the roof
									assert(math.min(g.ground(x, -g.lidEdge), g.ground(x, g.lidEdge)) >= roof - 0.1, tag .. ": plane over the roof at " .. x)
								end
							end
							if hold then
								local f = hold.faces[1]
								near(f[1][1], g.coverB, 1e-9, tag .. ": hold from the lid's terrain end")
								near(f[2][1], g.portalX + 30.25, 1e-9, tag .. ": to 30.25m past the portal")
								eq(hold.slopeLow, 0.45, tag .. ": gentle fill banks")
								for _, v in ipairs(f) do near(v[3], g.lidZ(v[1], v[2]), 1e-9, tag .. ": on the lifted plane (no slab)") end
								checked = checked + 1
							end
						end
					end
				end
			end
		end
		assert(checked > 0, "some hold faces")
	end)

	-- (6m given to the module itself: the slider no longer offers it, the
	-- layout still takes any length from LID_BEHIND on)
	test("cover length: the lift is the same at every length (36m too), finite and never below the plane, at 6m as well", function()
		for _, base in ipairs(RAMP_CASES) do
			local prev = -1
			for _, C in ipairs({ 6, MIN, 12, 18, 24 }) do
				local s = rampGeo.spec(defaultCap(), defaultParams(base))
				s.lidLength = C
				local g = rampGeo.layout(s)
				assert(g.lift == g.lift and g.lift < math.huge, "finite lift")
				assert(g.lift >= 0, "never lowered")
				if prev >= 0 then eq(g.lift, prev, "the same lift at " .. C) end
				prev = g.lift
			end
			local s = rampGeo.spec(defaultCap(), defaultParams(base))
			s.lidLength = 36
			eq(rampGeo.layout(s).lift, prev, "36m lifted as 24m")
		end
	end)

	test("cover length: the default ramp has 104 models (1.0.0: 128; the 18m cover in 5 x 6 pieces instead of 9 x 6)", function()
		eq(#script.updateFn(defaultCap(), {}).subconstructions[1].models, 104, "the default ramp")
		local n = {}
		for _, C in ipairs({ MIN, 24 }) do n[C] = #script.updateFn(defaultCap(), { rtr_cover_length = C }).subconstructions[1].models end
		local along = math.ceil(MIN / 4 - 1e-9)
		eq(n[MIN], 128 - 9 * 6 + along * 6, "the shortest: " .. along .. " x 6 pieces")
		eq(n[24], 128 - 9 * 6 + 6 * 6, "24m: 6 x 6 pieces")
	end)

	test("cover length: 36 passed to the module lays 1.0.0's lid (portalX - 6 .. portalX + 30, faces to + 30.25) to the bit", function()
		for ci, base in ipairs(RAMP_CASES) do
			local s = rampGeo.spec(defaultCap(), defaultParams(base))
			s.lidLength = 36
			local g = rampGeo.layout(s)
			eq(g.lidA, g.portalX - 6, "case " .. ci .. ": lidA")
			eq(g.lidB, g.portalX + 30, "case " .. ci .. ": lidB")
			eq(g.coverB, g.portalX + 30.25, "case " .. ci .. ": coverB")
		end
	end)

	test("median: the side streets end with the lid and their ground cuts at its terrain end, for every cover length", function()
		for _, C in ipairs(LENGTHS) do
			for ci, base in ipairs({ {}, { rtr_ground_along = 6, rtr_ground_across = -4 }, { rtr_ground_along = -12, rtr_ground_across = 5, rtr_length = 60 },
				{ rtr_median_entry = 6, rtr_wall = 2 }, { rtr_ground_along = -20, rtr_ground_across = -20 } }) do
				local p = with(base, { rtr_cover_length = C })
				local tag = string.format("cover %d case %d", C, ci)
				local r = median.updateFn(medianCap, p)
				local lay = medianGeo.layout(medianGeo.spec(medianCap, p), p)
				local g = lay.g
				eq(g.lidLength, C, tag .. ": lidLength")
				near(g.lidB, g.portalX - 6 + C, 1e-9, tag .. ": lidB")
				local wx0, wx1 = wallsAndLid(r)
				near(wx1, g.lidB, 1e-9, tag .. ": the lid's end")
				local _, sides, ground = splitSides(r)
				for _, ySign in ipairs({ -1, 1 }) do
					local lo, hi = sideRun(sides, ySign)
					near(lo, 0, 1e-9, tag .. ": from the trench start")
					eq(lo, wx0, tag .. ": with the walls")
					near(hi, g.lidB, 1e-9, tag .. ": to the lid's end, side " .. ySign)
				end
				-- the side streets' ground: up to the lid's end, from the
				-- lid's terrain edge beside the cover, from the coping's
				-- outside it (coverB in the run unless the run ends first)
				local lo, hi = xRange(ground.faces)
				near(lo, 0, 1e-9, tag .. ": ground from the trench start")
				near(hi, g.lidB, 1e-9, tag .. ": ground to the lid's end")
				for _, f in ipairs(ground.faces) do
					local xm = (f[1][1] + f[2][1]) * 0.5
					local inner = math.min(math.abs(f[1][2]), math.abs(f[3][2]))
					local want = (xm > g.coverA and xm < g.coverB) and g.lidEdge or g.copingOut
					near(inner, want, 1e-9, tag .. ": inner edge at x " .. xm)
				end
				-- the body is the full-width ramp's body for the same length
				local s = medianGeo.spec(medianCap, p)
				local body = rampGeo.build(s)
				deepEq(lists(body)[3], lists(r)[3], tag .. ": the cover face is the body's")
			end
		end
	end)
end

------------------------------------------------------------------------
-- The mod setting Initial portal cover length (mod.json params
-- rtr_cover_length_default; the user, 2026-11-26: 「1.1.0にMODの設定を入れて
-- OKです」): the slider's starting value in both constructions, set by
-- mod.script.lua's loadConstruction modifier; placed ramps keep theirs.
------------------------------------------------------------------------
do
	local setting = require "road_tunnel_ramp::/road_tunnel_ramp/cover_setting.lua"
	local rampConData = loadData("/content/road_tunnel_ramp/ramp.con.lua")

	local MIN = rampGeo.LID_MIN
	local N = rampGeo.LID_MAX - MIN + 1   -- the positions

	test("mod setting: the mod param (1-based position in LID_MIN..24m) to a length; missing, junk and out of range are 18m", function()
		for i = 1, N do eq(setting.lengthFromModParam(i), MIN - 1 + i, "position " .. i) end
		eq(setting.lengthFromModParam(1), MIN, "position 1: the shortest")
		eq(setting.lengthFromModParam(N), 24, "the last position: 24m")
		eq(setting.lengthFromModParam("1"), MIN, "a numeric string")
		eq(setting.lengthFromModParam(18 - MIN + 1), 18, "the mod.json default (defaultIndex 18 - LID_MIN) arrives one up")
		for _, v in ipairs({ "nil", 0, -1, N + 1, 19, 20, 100, 1.5, 12.9, 0 / 0, math.huge, "abc", true }) do
			eq(setting.lengthFromModParam(v ~= "nil" and v or nil), 18, "value " .. tostring(v))
		end
	end)

	test("mod setting: lengths to mod.json's 0-based and a .con's 1-based defaultIndex", function()
		for _, c in ipairs({ { MIN, 0, 1 }, { MIN + 1, 1, 2 }, { 18, 18 - MIN, 19 - MIN }, { 23, 23 - MIN, 24 - MIN }, { 24, N - 1, N } }) do
			eq(setting.modDefaultIndex(c[1]), c[2], "mod.json index of " .. c[1])
			eq(setting.conDefaultIndex(c[1]), c[3], ".con index of " .. c[1])
		end
		-- the .con's own: numbers[defaultIndex] is the length (1-based)
		for _, spec in ipairs({ rampConData, medianSpec }) do
			for _, q in ipairs(spec.params) do
				if q.key == "rtr_cover_length" then
					for len = MIN, 24 do eq(q.numbers[setting.conDefaultIndex(len)], len, "numbers at " .. len) end
					eq(q.defaultIndex, setting.conDefaultIndex(18), "the file's own default is 18m")
				end
			end
		end
		-- round trip: mod.json's default index, as the game hands it (+ 1)
		for len = MIN, 24 do eq(setting.lengthFromModParam(setting.modDefaultIndex(len) + 1), len, "round trip " .. len) end
	end)

	test("mod setting: this mod's params from runFn's 2nd or 3rd argument, by modId or folder name", function()
		eq(setting.modParamsFrom(nil, { road_tunnel_ramp = { a = 1 } }).a, 1, "3rd")
		eq(setting.modParamsFrom({ road_tunnel_ramp = { a = 2 } }, nil).a, 2, "2nd")
		eq(setting.modParamsFrom({ road_tunnel_ramp_1 = { a = 3 } }).a, 3, "folder name")
		eq(next(setting.modParamsFrom(nil, nil, "x", 5)), nil, "nothing: empty")
		eq(next(setting.modParamsFrom({ other = { a = 1 } })), nil, "another mod's only")
	end)

	test("mod setting: the file names it applies to", function()
		for _, n in ipairs({ "road_tunnel_ramp/ramp.con", "road_tunnel_ramp/ramp.con.lua",
			"road_tunnel_ramp::/road_tunnel_ramp/ramp.con", "/x/res/construction/road_tunnel_ramp/ramp.con",
			"road_tunnel_ramp::road_tunnel_ramp/median.con",
			-- the form AoM's log shows for the base game's (::/depots/rail/rail_depot.con.lua)
			"road_tunnel_ramp::/road_tunnel_ramp/ramp.con.lua", "road_tunnel_ramp::/road_tunnel_ramp/median.con.lua" }) do
			assert(setting.conOf(n), n)
		end
		eq(setting.conOf("road_tunnel_ramp/median.con.lua"), "median", "median")
		for _, n in ipairs({ "road_tunnel_ramp/ramp.con.bak", "my_road_tunnel_ramp/ramp.con",
			"road_tunnel_ramp/other.con", "road_tunnel_ramp/ramp.script.lua", "ramp.con",
			"station/rail/road_tunnel_ramp_x/ramp.con", "" }) do
			eq(setting.conOf(n), nil, n)
		end
		eq(setting.conOf(nil), nil, "nil")
		eq(setting.conOf(5), nil, "a number")
	end)

	test("mod setting: the modifier moves only the cover slider's defaultIndex in both constructions", function()
		for _, file in ipairs({ "ramp", "median" }) do
			for _, len in ipairs({ MIN, MIN + 1, 18, 24 }) do
				local d = loadData("/content/road_tunnel_ramp/" .. file .. ".con.lua")
				local before = loadData("/content/road_tunnel_ramp/" .. file .. ".con.lua")
				local out = setting.modifier(len)("road_tunnel_ramp/" .. file .. ".con", d)
				local tag = file .. " " .. len
				assert(out == d, tag .. ": the same table back")
				local cover
				for i, q in ipairs(out.params) do
					if q.key == "rtr_cover_length" then
						cover = q
						eq(q.numbers[q.defaultIndex], len, tag .. ": starts on the length")
						eq(q.defaultIndex, setting.conDefaultIndex(len), tag .. ": 1-based")
						before.params[i].defaultIndex = q.defaultIndex
					end
				end
				assert(cover, tag .. ": the slider")
				deepEq(out, before, tag .. ": nothing else changed")
			end
		end
		-- other files: untouched
		local other = { params = { { key = "rtr_cover_length", numbers = { 6, 18 }, defaultIndex = 2 } } }
		eq(setting.modifier(6)("street/other.con", other), other, "other: same table")
		eq(other.params[1].defaultIndex, 2, "other: untouched")
		-- odd data: nothing raises
		for _, d in ipairs({ {}, { params = 5 }, { params = { 5, { key = "rtr_cover_length" } } } }) do
			setting.modifier(6)("road_tunnel_ramp/ramp.con", d)
		end
		eq(setting.modifier(6)("road_tunnel_ramp/ramp.con", nil), nil, "nil data passes through")
		-- a length the slider lacks leaves it
		local d = loadData("/content/road_tunnel_ramp/ramp.con.lua")
		eq(setting.applyToCon(d, 36), false, "36 is not on the slider")
		eq(setting.applyToCon(d, MIN - 1), false, "below the shortest is not on it (1.1.0's 6m)")
	end)

	test("mod setting: mod.script runFn adds one loadConstruction modifier from the mod params; a failing addModifier is logged, not raised", function()
		local saved = { data = data, addModifier = addModifier, print = print }
		local function run(second, third, add)
			data = false
			assert(loadfile(root .. "/content/mod.script.lua"))()
			local fns = data()
			data = saved.data
			addModifier = add
			local ok, err = pcall(fns.runFn, {}, second, third)
			addModifier = saved.addModifier
			return ok, err, fns
		end
		for _, c in ipairs({ { nil, 18 }, { 1, MIN }, { 18 - MIN + 1, 18 }, { N, 24 }, { N + 1, 18 }, { "abc", 18 } }) do
			local got = {}
			local ok, err = run({}, { road_tunnel_ramp = { rtr_cover_length_default = c[1] } },
				function(kind, fn) got[#got + 1] = { kind, fn } end)
			assert(ok, tostring(err))
			eq(#got, 1, "one modifier")
			eq(got[1][1], "loadConstruction", "kind")
			local d = loadData("/content/road_tunnel_ramp/median.con.lua")
			d = got[1][2]("road_tunnel_ramp::/road_tunnel_ramp/median.con", d)
			for _, q in ipairs(d.params) do
				if q.key == "rtr_cover_length" then eq(q.numbers[q.defaultIndex], c[2], "param " .. tostring(c[1])) end
			end
		end
		local lines = {}
		print = function(m) lines[#lines + 1] = m end
		local ok = run(nil, nil, function() error("no such kind") end)
		print = saved.print
		assert(ok, "runFn does not raise")
		eq(#lines, 1, "one line logged")
		assert(lines[1]:find("addModifier failed", 1, true), lines[1])
		-- quiet when it works
		lines = {}
		print = function(m) lines[#lines + 1] = m end
		run(nil, nil, function() end)
		print = saved.print
		eq(#lines, 0, "nothing logged")
	end)

	test("mod setting: a placed ramp keeps its length: the scripts build from their own params and never read the setting", function()
		for _, rel in ipairs({ "ramp_geometry.lua", "median_geometry.lua", "ramp.script.lua", "median.script.lua" }) do
			local f = assert(io.open(root .. "/content/road_tunnel_ramp/" .. rel))
			local body = f:read("*a"); f:close()
			assert(not body:find("rtr_cover_length_default", 1, true), rel .. " reads the mod setting")
			assert(not body:find("cover_setting", 1, true), rel .. " requires cover_setting")
		end
		-- and the modifier leaves the update script's own params (what a
		-- placed ramp is rebuilt with, beside its own params) as they are
		local d = loadData("/content/road_tunnel_ramp/ramp.con.lua")
		local before = loadData("/content/road_tunnel_ramp/ramp.con.lua")
		assert(setting.applyToCon(d, MIN), "the shortest is on the slider")
		deepEq(d.updateScript, before.updateScript, "updateScript untouched")
	end)
end

print(string.format("\n%d passed, %d failed", passes, failures))
os.exit(failures == 0 and 0 or 1)
