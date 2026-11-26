-- Tram track Right / Left on the flat approach (both constructions): after
-- the build, the handed-over approach edges are laid again with the track
-- taken off the lanes of the side not chosen.
--
-- Why: on a street with sidewalks the approach needs the edges'
-- tramTrackType for any track at all (the copy's own TRAM lane went on
-- build), and tramTrackType lays it on both directions' outer lanes
-- [measured 2026-11-26 TC5, TC6: Right gave tramLanes 2 and 5]. An edge's
-- track is per lane, in BaseEdge.laneConfigs[i].transportModes (TRAM,
-- ELECTRIC_TRAM) [source: api/tealdef engine.d.tl BaseEdge, type.d.tl
-- LaneConfig], and the edge list of a construction has no way to name a
-- lane [source: construction_util_serialized.d.tl]. A built street can be
-- laid again with other laneConfigs: the base game's mission electrify.tl
-- reads an edge's BASE_EDGE, changes its laneConfigs and sends
-- streetProposal.edgesToRemove { old } / edgesToAdd { new } with
-- makeWorldBuildProposalCmd [source: mission.zip mission/tasks/
-- auto_builder/electrify.tl:9-35]. The approach is an ordinary street once
-- built (handed over), so it can be laid again; the new edge gets a new id.
-- The descent, the tunnel and the median's side streets stay as built.
--
-- Which lanes: the track stays on the lanes of the chosen side, facing the
-- tunnel, as on the descent (ramp_geometry.lua M.tramLanes: Right with
-- right-hand traffic is the forward lanes of the edge that runs into the
-- tunnel). The side is told by each lane's direction, not its place in the
-- list: with right-hand traffic the lanes that run into the tunnel lie on
-- its right, with left-hand traffic on its left (rtr_side, the player's
-- Traffic side) [guess for left-hand traffic, as the descent's copies
-- assume]. A lane's direction is forward (node0 -> node1) against the way
-- the edge runs (into the tunnel or out of it, from its nodes' places in
-- the construction's frame). Every lane of the other direction that has
-- the track loses TRAM, ELECTRIC_TRAM, TRAM_TRACK and ELECTRIC_TRAM_TRACK:
-- that is its outer lane, the one at the kerb (offset +-0.5 on the base
-- streets [source: Lane tools, mod.io 6527675, roads/lanes.lua]), since
-- tramTrackType lays it there; offset is kept in what is read (the e2e
-- script shows it) but not used, as its sign is not known in game
-- [source: remote_probe remote_lanes.lua notes it as a guess].
--
-- A lane's modes are read as lc.transportModes[enum.TransportMode[name]]
-- and written as a list of 16 booleans in the enum's order on a copy of the
-- lane read out of a fresh segment, and read back, as Lane tools does
-- [source: roads/lanes.lua ownLane, made]; the order is type.d.tl's.
-- That way raised std::exception in the engine in TC7 [measured
-- 2026-11-26], so it is tried after the copy template's laneConfigs (the
-- track on the chosen lane only, as electrify.tl takes a template's):
-- M.VARIANTS, M.firstPassing.
--
-- Nothing is done (the track stays on both sides) when: Tram track is not
-- Right or Left, the approach is kept in the construction (the e2e's
-- rtr_approach_hand_over 0 / 2), no approach edge is found, the street is
-- one-way (its track is one lane set already), the chosen side has no
-- track, or the engine refuses the proposal. Only failures are logged
-- (rtr_approach_tram.script.lua), and a build answered yes that left the
-- track on both sides (stillBoth).
--
-- Engine-free but for the functions that take `api` (the game's, or the
-- tests' stand-in), so the choice and the proposal are tested offline.

local geometry = require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua"

local M = {}

M.EVENT_ID = "road_tunnel_ramp"
M.EVENT_NAME = "rtr_approach_tram"
-- the game script's file name, the source of the events it sends itself
M.SCRIPT = "rtr_approach_tram.script"
M.CONS = { ramp = "road_tunnel_ramp/ramp.con", median = "road_tunnel_ramp/median.con" }

-- TransportMode in the enum's order (type.d.tl)
M.MODES = { "PERSON", "CARGO", "CAR", "BUS", "TRUCK", "TRAM", "ELECTRIC_TRAM", "TRAIN", "ELECTRIC_TRAIN",
	"AIRCRAFT", "SHIP", "SMALL_AIRCRAFT", "SMALL_SHIP", "HELICOPTER", "TRAM_TRACK", "ELECTRIC_TRAM_TRACK" }
M.TRACK = { TRAM = true, ELECTRIC_TRAM = true, TRAM_TRACK = true, ELECTRIC_TRAM_TRACK = true }
local VEHICLE = { CAR = true, BUS = true, TRUCK = true, TRAM = true, ELECTRIC_TRAM = true }

M.END_TOL = 0.5  -- m: how far an approach end may sit from x = 0, and its two ends' y apart
M.Z_TOL = 1.5    -- m: how far up or down from the construction's level (the approach is laid at z = 0)
M.MIN_RUN = 1    -- m: the far end lies at least this far in front of x = 0
M.SEARCH_R = 80  -- m: around local (-25, 0): approaches up to 50 m, three 32 m streets across

local function value(p, key, default, lo, hi)
	local n = tonumber(p and p[key])
	if not n or n ~= n then n = default end
	return math.floor(math.max(lo, math.min(hi, n)) + 0.5)
end

local function try(fn)
	local ok, v = pcall(fn)
	if ok then return v end
	return nil
end

-- Plain list from an engine vector or a Lua table.
local function list(v)
	local out = {}
	if v == nil then return out end
	pcall(function() for i = 1, #v do out[#out + 1] = v[i] end end)
	if #out == 0 then
		pcall(function() for _, x in pairs(v) do out[#out + 1] = x end end)
	end
	return out
end
M.list = list

-- "ramp" / "median" for this mod's constructions, nil for any other.
function M.kindOf(fileName)
	if type(fileName) ~= "string" then return nil end
	for kind, con in pairs(M.CONS) do
		if fileName:find(con, 1, true) then return kind end
	end
	return nil
end

-- What the build asked for: { kind, tram (3 right, 4 left), side (1
-- right-hand, 2 left-hand) }, or nil and why (nothing to do there).
-- The median's centre is always handed over (median_geometry.spec).
function M.choice(fileName, params)
	local kind = M.kindOf(fileName)
	if not kind then return nil, "not this mod's construction" end
	if type(params) ~= "table" or next(params) == nil then return nil, "no params" end
	local tram = value(params, "rtr_tram", 1, 1, 4)
	if tram ~= 3 and tram ~= 4 then return nil, "Tram track is not Right or Left" end
	if kind == "ramp" and value(params, "rtr_approach_hand_over", 1, 0, 2) ~= 1 then
		return nil, "the approach is kept in the construction"
	end
	return { kind = kind, tram = tram, side = value(params, "rtr_side", 1, 1, 2) }
end

-- Whether the track stays on the lanes that run into the tunnel: Right
-- with right-hand traffic, Left with left-hand traffic.
function M.keepsInto(tram, side)
	return (tram == 3) == (side == 1)
end

local function hasAny(lane, set)
	for name in pairs(set) do
		if lane.modes and lane.modes[name] then return true end
	end
	return false
end

-- The lanes to take the track off. lanes: { forward, modes = { NAME =
-- true } } per laneConfig, left to right; runsIn: the edge's node0 ->
-- node1 runs into the tunnel. Returns the lane numbers (1-based), or an
-- empty list and why: a one-way street (one direction only: Right / Left
-- is its lane set, not a direction) or a chosen side without track (taking
-- the other off would leave none) is left as it is. Nothing to take off
-- is an empty list without a why.
function M.lanesToStrip(lanes, tram, side, runsIn)
	local keepInto = M.keepsInto(tram, side)
	local dirs, keptTrack = {}, false
	for _, l in ipairs(lanes or {}) do
		if type(l.forward) == "boolean" and hasAny(l, VEHICLE) then
			local into = l.forward == runsIn
			dirs[into] = true
			if into == keepInto and hasAny(l, M.TRACK) then keptTrack = true end
		end
	end
	-- (one direction only: a one-way street, whose track is one lane set
	-- already, as tramTrackType is not given there: nothing to do, quietly)
	if dirs[true] ~= dirs[false] then return {} end
	if not dirs[true] then return {}, "the lanes' directions do not read" end
	local out = {}
	for i, l in ipairs(lanes) do
		if type(l.forward) == "boolean" and (l.forward == runsIn) ~= keepInto and hasAny(l, M.TRACK) then
			out[#out + 1] = i
		end
	end
	if #out > 0 and not keptTrack then return {}, "the chosen side has no track" end
	return out
end

-- A Mat4f as 16 numbers, column-major (m[13..15] the origin), from a Lua
-- list or an engine matrix (0- or 1-based); nil when it does not read.
function M.matrix16(t)
	if t == nil then return nil end
	if type(t) == "table" and getmetatable(t) == nil and type(t[16]) == "number" and t[0] == nil then
		local m = {}
		for i = 1, 16 do m[i] = t[i] end
		return m
	end
	for _, base in ipairs({ 0, 1 }) do
		local m = {}
		local ok = pcall(function()
			for i = 0, 15 do
				local x = t[i + base]
				if type(x) ~= "number" then error("not " .. base .. "-based") end
				m[i + 1] = x
			end
		end)
		if ok then return m end
	end
	return nil
end

-- A world point in the construction's frame (its axes need not be unit).
function M.toLocal(m, p)
	local d = { p.x - m[13], p.y - m[14], p.z - m[15] }
	local out = {}
	for k, base in ipairs({ 0, 4, 8 }) do
		local ax, ay, az = m[base + 1], m[base + 2], m[base + 3]
		local n = ax * ax + ay * ay + az * az
		out[k] = n > 0 and (d[1] * ax + d[2] * ay + d[3] * az) / n or 0
	end
	return { x = out[1], y = out[2], z = out[3] }
end

-- A local point back in the world.
function M.toWorld(m, x, y, z)
	return { x = m[13] + m[1] * x + m[5] * y + m[9] * z, y = m[14] + m[2] * x + m[6] * y + m[10] * z,
		z = m[15] + m[3] * x + m[7] * y + m[11] * z }
end

-- Whether an edge between world points p0 (node0) and p1 (node1) is a flat
-- approach of the construction at m: one end at x = 0 (the descent's
-- start), the other in front of it (x < 0), both at the same y and at
-- the construction's level. true: it runs into the tunnel (node0 in
-- front), false: out of it, nil: not an approach. (The median's side
-- streets start at x = 0 too, but run on to x > 0.)
function M.approachDirection(m, p0, p1)
	local a, b = M.toLocal(m, p0), M.toLocal(m, p1)
	if math.abs(a.z) > M.Z_TOL or math.abs(b.z) > M.Z_TOL then return nil end
	if math.abs(a.y - b.y) > M.END_TOL then return nil end
	if math.abs(b.x) <= M.END_TOL and a.x < -M.MIN_RUN then return true end
	if math.abs(a.x) <= M.END_TOL and b.x < -M.MIN_RUN then return false end
	return nil
end

-- Engine side -----------------------------------------------------------------

local function CT(api) return api.type.ComponentType end

local function comp(api, entity, kind)
	return try(function()
		local ct = CT(api)[kind]
		if ct == nil then return nil end
		return api.engine.getComponent(entity, ct)
	end)
end

function M.allows(api, lc, name)
	local yes = false
	pcall(function() yes = lc.transportModes[api.type.enum.TransportMode[name]] == true end)
	return yes
end

-- An edge's laneConfigs as plain values: { forward, offset, width, modes }.
function M.plainLanes(api, laneConfigs)
	local out = {}
	for i, lc in ipairs(list(laneConfigs)) do
		local modes = {}
		for _, name in ipairs(M.MODES) do
			if M.allows(api, lc, name) then modes[name] = true end
		end
		local fwd = try(function() return lc.forward end)
		out[i] = { offset = tonumber(try(function() return lc.offset end)),
			width = tonumber(try(function() return lc.width end)), modes = modes }
		-- (false kept: an and/or would drop it)
		if type(fwd) == "boolean" then out[i].forward = fwd end
	end
	return out
end

-- Plain copy of construction params (numbers, strings and booleans), from
-- an engine table or a native one.
function M.plainParams(t)
	local out = {}
	if t == nil then return out end
	local src = t
	if type(t) == "userdata" then
		local ok, tb = pcall(function() return t:asTable() end)
		if ok and type(tb) == "table" then src = tb end
	end
	pcall(function()
		for k, v in pairs(src) do
			local tv = type(v)
			if type(k) == "string" and (tv == "number" or tv == "string" or tv == "boolean") then out[k] = v end
		end
	end)
	return out
end

-- { entity, fileName, params, m, frozenEdges } of a construction, or nil.
function M.constructionInfo(api, entity)
	entity = tonumber(entity)
	if not entity then return nil end
	local c = comp(api, entity, "CONSTRUCTION")
	if not c then return nil end
	local params = M.plainParams(try(function() return c.params_native end))
	if next(params) == nil then params = M.plainParams(try(function() return c.params end)) end
	local frozen = {}
	for _, e in ipairs(list(try(function() return c.frozenEdges end))) do
		if tonumber(e) then frozen[tonumber(e)] = true end
	end
	return { entity = entity, fileName = tostring(try(function() return c.fileName end) or ""), params = params,
		m = M.matrix16(try(function() return c.transf end)), frozenEdges = frozen }
end

local function box(api, x, y, z, r, h)
	local B = api.type.Box3 or api.type.Box3f
	return B.new(api.type.Vec3f.new(x - r, y - r, z - h), api.type.Vec3f.new(x + r, y + r, z + h))
end

-- This mod's construction nearest a point, within 3 m (for a build whose
-- made entities did not read).
function M.constructionNear(api, x, y, z)
	local best, bestD = nil, 9
	pcall(function()
		api.engine.system.octreeSystem.findIntersectingEntities(box(api, x, y, z or 0, 3, 100), function(e)
			local info = M.constructionInfo(api, e)
			if info and info.m and M.kindOf(info.fileName) then
				local d = (info.m[13] - x) ^ 2 + (info.m[14] - y) ^ 2
				if d <= bestD then best, bestD = info, d end
			end
		end)
	end)
	return best
end

local function nodePos(api, n)
	local bn = comp(api, n, "BASE_NODE")
	local p = bn and try(function() return bn.position end)
	if not p then return nil end
	return { x = p.x, y = p.y, z = p.z }
end

-- The street edges around the approach: at the nodes of the construction's
-- own edges (the descent's start is one), and those the octree meets around
-- local (-25, 0) (the way the median branch's fork script found its ends: findEntitiesInCircle,
-- else findIntersectingEntities).
local function candidateEdges(api, info)
	local seen, out = {}, {}
	local function add(e)
		e = tonumber(e)
		if e and not seen[e] then seen[e] = true; out[#out + 1] = e end
	end
	for e in pairs(info.frozenEdges) do
		local be = comp(api, e, "BASE_EDGE")
		for _, k in ipairs({ "node0", "node1" }) do
			local n = be and tonumber(try(function() return be[k] end))
			if n then
				for _, s in ipairs(list(try(function() return api.engine.system.streetSystem.getNodeStreetSegments(n) end))) do add(s) end
			end
		end
	end
	local c = M.toWorld(info.m, -25, 0, 0)
	local found = list(try(function()
		return api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(c.x, c.y), M.SEARCH_R, CT(api).BASE_EDGE)
	end))
	if #found == 0 then
		pcall(function()
			api.engine.system.octreeSystem.findIntersectingEntities(box(api, c.x, c.y, c.z, M.SEARCH_R, 30), function(e)
				if comp(api, e, "BASE_EDGE") then found[#found + 1] = e end
			end)
		end)
	end
	for _, e in ipairs(found) do add(e) end
	return out
end

-- The construction's handed-over approach edges: { edge, runsIn, lanes }.
function M.findApproaches(api, info)
	local out = {}
	if not (info and info.m) then return out end
	for _, e in ipairs(candidateEdges(api, info)) do
		local be = not info.frozenEdges[e] and comp(api, e, "BASE_EDGE")
		local street = be and (CT(api).BASE_EDGE_STREET == nil or comp(api, e, "BASE_EDGE_STREET") ~= nil)
		if street then
			local p0 = nodePos(api, tonumber(try(function() return be.node0 end)))
			local p1 = nodePos(api, tonumber(try(function() return be.node1 end)))
			local runsIn = p0 and p1 and M.approachDirection(info.m, p0, p1)
			if runsIn ~= nil then
				out[#out + 1] = { edge = e, runsIn = runsIn, lanes = M.plainLanes(api, try(function() return be.laneConfigs end)),
					nodes = { tonumber(be.node0), tonumber(be.node1) } }
			end
		end
	end
	table.sort(out, function(a, b) return a.edge < b.edge end)
	return out
end

-- What to lay again for a construction: { construction, choice, edges =
-- { { edge, runsIn, lanes, strip } } }, or nil, why and whether that is
-- worth a log line (true: something went wrong; false: nothing to do).
function M.plan(api, con)
	local info = M.constructionInfo(api, con)
	if not info or not info.m then return nil, "construction " .. tostring(con) .. " does not read", true end
	local choice, why = M.choice(info.fileName, info.params)
	if not choice then return nil, why, false end
	local approaches = M.findApproaches(api, info)
	if #approaches == 0 then return nil, "no approach edge found", true end
	local edges, notes = {}, {}
	for _, a in ipairs(approaches) do
		local strip, whyNot = M.lanesToStrip(a.lanes, choice.tram, choice.side, a.runsIn)
		if #strip > 0 then
			a.strip = strip
			edges[#edges + 1] = a
		elseif whyNot then
			notes[#notes + 1] = "edge " .. a.edge .. ": " .. whyNot
		end
	end
	if #edges == 0 then
		if #notes > 0 then return nil, table.concat(notes, "; "), true end
		return nil, "nothing to take off", false
	end
	return { construction = info.entity, choice = choice, params = info.params, edges = edges, notes = notes }
end

-- A copy of lane lc with the track modes off (the others as they were),
-- read back. holders keeps the fresh segments the copies were read from.
function M.stripped(api, lc, holders)
	local holder = api.type.SegmentAndEntity.new()
	holder.comp.laneConfigs = { lc }
	holders[#holders + 1] = holder
	local own = holder.comp.laneConfigs[1]
	local want = {}
	for i, name in ipairs(M.MODES) do
		want[i] = (not M.TRACK[name]) and M.allows(api, lc, name)
	end
	own.transportModes = want
	for i, name in ipairs(M.MODES) do
		if M.allows(api, own, name) ~= want[i] then error("lane modes not written as asked (" .. name .. ")") end
	end
	return own
end

-- The street template whose laneConfigs the approach is laid again with
-- (opts.lanes "template"): the approach's own type when it is one of this
-- mod's tram copies (it is laid as one: ramp_geometry M.build streetRef),
-- else the copy of it for the choice (ramp_geometry M.tramRef). The copy
-- has the track on the chosen lane only, as the descent's copies that kept
-- it in game [measured TC5, TC7]; the base game's electrify.tl lays an
-- edge again with a template's laneConfigs the same way [source].
function M.templateName(roadTemplate, choice, params)
	local name = tostring(roadTemplate or "")
	if name:find("/streets/tram_", 1, true) then return name end
	local lanes = geometry.tramLanes(choice.tram, choice.side, false)
	local power = geometry.TRAM_POWER[value(params, "rtr_tram_wire", 1, 1, 2)]
	local ok, ref = pcall(geometry.tramRef, name, lanes, power)
	return ok and ref or nil
end

-- The template's laneConfigs for an item, or nil and why: only when they
-- match the built edge lane for lane (as many, the same directions, the
-- edge laid in the template's direction) and carry the track exactly on
-- the lanes the edge keeps it on.
function M.templateLanes(api, item, old, choice, params)
	if not item.runsIn then return nil, "the edge runs out of the tunnel (not the template's direction)" end
	local name = M.templateName(try(function() return old.roadTemplate end), choice, params)
	if not name then return nil, "no template name" end
	local rep = api.res and api.res.streetTemplateRep
	local idx = rep and tonumber(try(function() return rep.find(name) end))
	if not idx or idx < 0 then return nil, "template " .. name .. " not found" end
	local t = try(function() return rep.get(idx) end)
	local style = t and try(function() return t.streetStyle end)
	local lanes = t and list(try(function() return t.laneConfigs end)) or {}
	local built = item.lanes
	if #lanes ~= #built then return nil, string.format("template %s has %d lanes, the edge %d", name, #lanes, #built) end
	local strip = {}
	for _, i in ipairs(item.strip) do strip[i] = true end
	for i, lc in ipairs(lanes) do
		local fwd = try(function() return lc.forward end)
		if fwd ~= built[i].forward then return nil, "template " .. name .. ": lane " .. i .. " runs the other way" end
		local track = false
		for nm in pairs(M.TRACK) do if M.allows(api, lc, nm) then track = true end end
		local want = false
		for nm in pairs(M.TRACK) do if built[i].modes[nm] then want = true end end
		if track ~= (want and not strip[i]) then return nil, "template " .. name .. ": lane " .. i .. " has the track where the edge keeps none or the other way" end
	end
	return lanes, name, style
end

-- The ways to lay an approach again, tried in this order (M.firstPassing)
-- until the engine's makeProposalData takes one. TC7 [measured
-- 2026-11-26]: the lanes written mode by mode ("written") with
-- BASE_EDGE_STREET and PLAYER_OWNED copied raised std::exception in
-- makeWorldBuildProposalCmd and makeProposalData, with "map_util.h:22 Get:
-- Assertion it != map.end()" in the Sim Pool, while electrify.tl's way
-- (the edge's own BASE_EDGE, a template's laneConfigs, nothing else) is
-- the base game's [source]. Which part the engine refused is not known
-- yet [guess]; tools/e2e/approach_tram_steps.lua asks each part apart.
M.VARIANTS = {
	{ name = "template", lanes = "template", streetEdge = true, playerOwned = true },
	{ name = "template-bare", lanes = "template" },
	{ name = "written-bare", lanes = "written" },
	{ name = "written", lanes = "written", streetEdge = true, playerOwned = true },
}

-- The proposal that lays each planned edge again with the track only on
-- the chosen side: the edge's own BASE_EDGE (nodes, curve, template,
-- style) with laneConfigs as opts.lanes says: "template"
-- (M.templateLanes), "written" (its own, the strip lanes' track modes
-- written off, as Lane tools writes a lane) or "same" (unchanged, only for
-- the e2e's checks); with opts.streetEdge / opts.playerOwned its
-- BASE_EDGE_STREET / PLAYER_OWNED copied, as Lane tools does. opts nil is
-- the first of M.VARIANTS. Returns the proposal and the old edges, or
-- raises.
function M.makeProposal(api, plan, opts)
	opts = opts or M.VARIANTS[1]
	local proposal = api.type.SimpleProposal.new()
	local adds, removes, holders = {}, {}, {}
	for k, item in ipairs(plan.edges) do
		local old = comp(api, item.edge, "BASE_EDGE")
		if old == nil then error("edge " .. tostring(item.edge) .. " is gone") end
		local strip = {}
		for _, i in ipairs(item.strip) do strip[i] = true end
		local lanes = list(old.laneConfigs)
		local newLanes, template
		if opts.lanes == "template" then
			local tl, why, style = M.templateLanes(api, item, old, plan.choice, plan.params or {})
			if not tl then error("edge " .. item.edge .. ": " .. tostring(why)) end
			newLanes = tl
			-- (a copy other than the edge's own type: its name and style go
			-- with its lanes, as electrify.tl writes both)
			if why ~= tostring(try(function() return old.roadTemplate end)) then
				template = { name = why, style = style }
			end
		elseif opts.lanes == "same" then
			newLanes = lanes
		else
			newLanes = {}
			for i, lc in ipairs(lanes) do
				newLanes[i] = strip[i] and M.stripped(api, lc, holders) or lc
			end
		end
		local seg = api.type.SegmentAndEntity.new()
		seg.entity = -k
		seg.type = 0
		seg.comp = old
		seg.comp.laneConfigs = newLanes
		if template then
			seg.comp.roadTemplate = template.name
			if template.style ~= nil then seg.comp.roadStyle = template.style end
		end
		local back = list(seg.comp.laneConfigs)
		if #back ~= #lanes then error("edge " .. item.edge .. ": the lanes were not written as asked") end
		if opts.lanes ~= "same" then
			for i, lc in ipairs(back) do
				local had = false
				for name in pairs(M.TRACK) do if M.allows(api, lanes[i], name) then had = true end end
				local has = false
				for name in pairs(M.TRACK) do if M.allows(api, lc, name) then has = true end end
				if has ~= (had and not strip[i]) then
					error(string.format("edge %d lane %d: the track not written as asked", item.edge, i))
				end
			end
		end
		if opts.streetEdge then
			local streetEdge = comp(api, item.edge, "BASE_EDGE_STREET")
			if streetEdge ~= nil then seg.streetEdge = streetEdge end
		end
		if opts.playerOwned then
			local owned = comp(api, item.edge, "PLAYER_OWNED")
			if owned ~= nil then seg.playerOwned = owned end
		end
		adds[k] = seg
		removes[k] = item.edge
	end
	proposal.streetProposal.edgesToRemove = removes
	proposal.streetProposal.edgesToAdd = adds
	return proposal, removes
end

-- The engine's verdict on a proposal: nil when it takes it (no critical
-- error), else why (a raise, or the critical messages).
function M.verdict(api, proposal, context)
	local ok, data = pcall(api.engine.util.proposal.makeProposalData, proposal, context)
	if not ok then return "makeProposalData raised: " .. tostring(data) end
	local critical, msg = false, ""
	pcall(function()
		critical = data.errorState.critical == true
		for _, x in ipairs(list(data.errorState.messages)) do msg = msg .. " " .. tostring(x) end
	end)
	if critical then return "critical:" .. msg end
	return nil
end

-- The first of M.VARIANTS (from number `from`, 1 when nil) the engine
-- takes: proposal, its name, the others' failures on the way, and its
-- number; or nil and every failure.
function M.firstPassing(api, plan, context, from)
	local fails = {}
	for k = from or 1, #M.VARIANTS do
		local v = M.VARIANTS[k]
		local ok, proposal = pcall(M.makeProposal, api, plan, v)
		local why
		if not ok then
			why = "not made: " .. tostring(proposal)
		else
			why = M.verdict(api, proposal, context)
		end
		if not why then return proposal, v.name, fails, k end
		fails[#fails + 1] = v.name .. ": " .. why
	end
	return nil, nil, fails
end

-- As tf3ctl road's and the median branch's fork script's: nothing knocked down, the street
-- graph left as it is.
function M.context(api)
	local context = api.type.Context.new()
	pcall(function() context.player = api.engine.util.getPlayer() end)
	context.cleanupStreetGraph = false
	context.gatherBuildings = false
	context.gatherFields = false
	return context
end

-- The engine's messages in a build answer, as one string.
function M.answerText(res)
	local msg = ""
	pcall(function()
		local es = res.resultProposalData.errorState
		if es.critical then msg = msg .. " critical" end
		for _, x in ipairs(list(es.messages)) do msg = msg .. " " .. tostring(x) end
	end)
	return msg
end

-- Sends the proposal (with a callback: from handleEvent only, see the
-- game script); done(success, message) gets the answer. Not player
-- initiated, as electrify.tl.
function M.send(api, proposal, done)
	api.cmd.sendCommand(api.cmd.makeWorldBuildProposalCmd(proposal, M.context(api), false, false), function(res, success)
		if done then done(success == true, M.answerText(res)) end
	end)
end

-- After a build the engine answered yes to: the new edges between the
-- planned edges' nodes, read again; the ones that still have the track on
-- the side not chosen (the engine may lay lanes anew, as it did the
-- copies' TRAM lanes on the construction's build [measured TC5]: then the
-- answer was yes but nothing changed). Returns a list of edge ids.
function M.stillBoth(api, plan)
	local out = {}
	for _, item in ipairs(plan.edges) do
		local old = item.nodes
		for _, e in ipairs(old and list(try(function() return api.engine.system.streetSystem.getNodeStreetSegments(old[1]) end)) or {}) do
			local be = comp(api, e, "BASE_EDGE")
			local n0 = be and tonumber(try(function() return be.node0 end))
			local n1 = be and tonumber(try(function() return be.node1 end))
			if be and ((n0 == old[1] and n1 == old[2]) or (n0 == old[2] and n1 == old[1])) then
				local runsIn = item.runsIn
				if n0 ~= old[1] then runsIn = not runsIn end
				local strip = M.lanesToStrip(M.plainLanes(api, try(function() return be.laneConfigs end)), plan.choice.tram,
					plan.choice.side, runsIn)
				if #strip > 0 then out[#out + 1] = tonumber(e) end
			end
		end
	end
	return out
end

-- Short words for a plan, for the log and the e2e script.
function M.describe(plan)
	local parts = {}
	for _, e in ipairs(plan.edges) do
		parts[#parts + 1] = string.format("edge %d (%s) lanes %s", e.edge, e.runsIn and "into the tunnel" or "out of it",
			table.concat(e.strip, ","))
	end
	return table.concat(parts, "; ")
end

return M
