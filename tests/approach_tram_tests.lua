-- Offline tests of the flat approach's tram lay-again (content/road_tunnel_ramp/
-- approach_tram.lua, content/rtr_approach_tram.script.lua, tools/e2e/*.lua).
-- Called from tests/run.lua with its helpers. The engine is a stand-in
-- (fakeApi): components are copied out on read and an edge's laneConfigs
-- are copied in on write, as the engine's records are, so a lane changed
-- in place on a read copy does not reach the world.
local test, eq, root, geometry = ...

local tram = require "road_tunnel_ramp::/road_tunnel_ramp/approach_tram.lua"

local MODES = tram.MODES
local TM = {}
for i, name in ipairs(MODES) do TM[name] = i end

local function deep(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = deep(x) end
	return out
end

-- A lane as the engine gives it: transportModes keyed by the enum's value.
local function lane(forward, offset, width, names)
	local tm = {}
	for i = 1, #MODES do tm[i] = false end
	for _, n in ipairs(names) do tm[TM[n]] = true end
	return { forward = forward, offset = offset, width = width, speed = 13.89, height = 0, transportModes = tm }
end

local SW = { "PERSON", "CARGO" }
local CAR = { "CAR", "BUS", "TRUCK" }
local CAR_TRACK = { "CAR", "BUS", "TRUCK", "TRAM", "ELECTRIC_TRAM" }

-- town_new_small with tramTrackType on (both outer car lanes carry it)
local function smallBoth()
	return { lane(false, 0.15, 3, SW), lane(false, -0.5, 5, CAR_TRACK), lane(true, 0.5, 5, CAR_TRACK), lane(true, -0.15, 3, SW) }
end

-- An edge record whose laneConfigs are copied on write.
local function edgeComp(t)
	local store = deep(t)
	return setmetatable({}, {
		__index = function(_, k) return store[k] end,
		__newindex = function(_, k, v)
			if k == "laneConfigs" then
				local c = {}
				for i, l in ipairs(v) do c[i] = deep(l) end
				store[k] = c
			else
				store[k] = v
			end
		end,
	})
end

-- The stand-in engine around a world { constructions, edges, nodes }.
local function fakeApi(world)
	local sent = {}
	local api = { sent = sent }
	api.type = {
		ComponentType = { BASE_EDGE = "BASE_EDGE", BASE_NODE = "BASE_NODE", CONSTRUCTION = "CONSTRUCTION",
			BASE_EDGE_STREET = "BASE_EDGE_STREET", PLAYER_OWNED = "PLAYER_OWNED" },
		enum = { TransportMode = TM },
		SimpleProposal = { new = function() return { streetProposal = {} } end },
		SegmentAndEntity = { new = function() return { comp = edgeComp({ laneConfigs = {} }) } end },
		Context = { new = function() return {} end },
		Vec2f = { new = function(x, y) return { x = x, y = y } end },
		Vec3f = { new = function(x, y, z) return { x = x, y = y, z = z } end },
		Box3 = { new = function(a, b) return { a, b } end },
	}
	api.engine = {
		getComponent = function(e, ct)
			if ct == "BASE_EDGE" then return world.edges[e] and edgeComp(world.edges[e]) or nil end
			if ct == "BASE_NODE" then return world.nodes[e] and { position = deep(world.nodes[e]) } or nil end
			if ct == "CONSTRUCTION" then return world.constructions[e] and deep(world.constructions[e]) or nil end
			if ct == "BASE_EDGE_STREET" then return world.edges[e] and { precedenceNode0 = 0 } or nil end
			if ct == "PLAYER_OWNED" then return world.edges[e] and { player = 7 } or nil end
			return nil
		end,
		system = {
			streetSystem = { getNodeStreetSegments = function(n)
				local out = {}
				for e, be in pairs(world.edges) do if be.node0 == n or be.node1 == n then out[#out + 1] = e end end
				table.sort(out)
				return out
			end },
			octreeSystem = { findIntersectingEntities = function(_box, fn)
				for e in pairs(world.constructions) do fn(e) end
			end },
		},
		util = {
			getPlayer = function() return 7 end,
			octree = { findEntitiesInCircle = function()
				local out = {}
				for e in pairs(world.edges) do out[#out + 1] = e end
				table.sort(out)
				return out
			end },
			proposal = { makeProposalData = function() return { errorState = { critical = false, messages = {} } } end },
		},
	}
	api.cmd = {
		makeWorldBuildProposalCmd = function(p, ctx, ignore, player) return { kind = "build", proposal = p, context = ctx, ignore = ignore, player = player } end,
		makeScriptingSendEventCmd = function(src, id, name, param) return { kind = "event", src = src, id = id, name = name, param = param } end,
		sendCommand = function(cmd, cb) sent[#sent + 1] = { cmd = cmd, cb = cb } end,
	}
	return api
end

-- A ramp turned 90 degrees (local +X = world +Y) at (1000, 2000, 50):
-- approach 10 from local (-20, 0) to (0, 0), the descent's first piece 11
-- (the construction's), and the player's road 12 in front of the approach.
local function world(opts)
	opts = opts or {}
	local function at(x, y, z) return { x = 1000 - y, y = 2000 + x, z = 50 + (z or 0) } end
	local w = {
		nodes = { [1] = at(-20, 0), [2] = at(0, 0), [3] = at(12.5, 0, -0.5), [4] = at(-40, 0) },
		edges = {
			[10] = { node0 = 1, node1 = 2, laneConfigs = opts.lanes or smallBoth(), roadTemplate = "town_new_small" },
			[11] = { node0 = 2, node1 = 3, laneConfigs = smallBoth(), roadTemplate = "ramp_descent_town_small_f_etram" },
			[12] = { node0 = 4, node1 = 1, laneConfigs = smallBoth(), roadTemplate = "town_new_small" },
		},
		constructions = {
			[100] = { fileName = opts.fileName or "road_tunnel_ramp/ramp.con",
				params = opts.params or { rtr_tram = 3, rtr_side = 1 },
				transf = { 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 1000, 2000, 50, 1 }, frozenEdges = { 11 } },
		},
	}
	if opts.reversed then w.edges[10].node0, w.edges[10].node1 = 2, 1 end
	return w
end

local function has(lc, name) return lc.transportModes[TM[name]] == true end
local function same(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do if a[i] ~= b[i] then return false end end
	return true
end
local function listOf(t) return "{" .. table.concat(t, ",") .. "}" end

local function plainLanes(lanes)
	local out = {}
	for i, l in ipairs(lanes) do
		local modes = {}
		for name, v in pairs(TM) do if l.transportModes[v] then modes[name] = true end end
		out[i] = { forward = l.forward, modes = modes }
	end
	return out
end

test("approach tram: keepsInto agrees with the descent's copies (f = the forward lanes of an edge into the tunnel)", function()
	for _, tr in ipairs({ 3, 4 }) do
		for _, side in ipairs({ 1, 2 }) do
			eq(tram.keepsInto(tr, side), geometry.tramLanes(tr, side, false) == "f", "tram " .. tr .. " side " .. side)
		end
	end
end)

test("approach tram: lanesToStrip takes the other direction's track off, by forward, traffic side and the edge's way", function()
	local lanes = plainLanes(smallBoth())
	local cases = {
		{ 3, 1, true, { 2 } }, { 4, 1, true, { 3 } }, { 3, 2, true, { 3 } }, { 4, 2, true, { 2 } },
		{ 3, 1, false, { 3 } }, { 4, 1, false, { 2 } }, { 3, 2, false, { 2 } }, { 4, 2, false, { 3 } },
	}
	for _, c in ipairs(cases) do
		local got, why = tram.lanesToStrip(lanes, c[1], c[2], c[3])
		assert(same(got, c[4]), string.format("tram %d side %d runsIn %s: %s (%s)", c[1], c[2], tostring(c[3]), listOf(got), tostring(why)))
		eq(why, nil, "no why")
	end
	-- town_new_medium's six lanes: the outer car lane of the other direction
	local medium = plainLanes({ lane(false, 0.15, 3, SW), lane(false, -0.5, 5, CAR_TRACK), lane(false, 0, 4, CAR),
		lane(true, 0, 4, CAR), lane(true, 0.5, 5, CAR_TRACK), lane(true, -0.15, 3, SW) })
	assert(same(tram.lanesToStrip(medium, 3, 1, true), { 2 }), "medium right")
	assert(same(tram.lanesToStrip(medium, 4, 1, true), { 5 }), "medium left")
end)

test("approach tram: lanesToStrip leaves one-way, unread, trimmed and trackless-chosen-side edges alone", function()
	local oneWay = plainLanes({ lane(true, -0.5, 5, CAR_TRACK), lane(true, 0.5, 5, CAR_TRACK) })
	local got, why = tram.lanesToStrip(oneWay, 3, 1, true)
	eq(#got, 0, "one-way"); assert(why, "one-way says why")
	got, why = tram.lanesToStrip({}, 3, 1, true)
	eq(#got, 0, "empty"); assert(why, "empty says why")
	got, why = tram.lanesToStrip(nil, 3, 1, true)
	eq(#got, 0, "nil"); assert(why, "nil says why")
	local unread = plainLanes(smallBoth())
	for _, l in ipairs(unread) do l.forward = nil end
	got, why = tram.lanesToStrip(unread, 3, 1, true)
	eq(#got, 0, "directions unread"); assert(why, "unread says why")
	-- already one side (Right, right-hand: lane 3 keeps it): nothing, quietly
	local trimmed = plainLanes({ lane(false, 0.15, 3, SW), lane(false, -0.5, 5, CAR), lane(true, 0.5, 5, CAR_TRACK), lane(true, -0.15, 3, SW) })
	got, why = tram.lanesToStrip(trimmed, 3, 1, true)
	eq(#got, 0, "trimmed"); eq(why, nil, "trimmed is quiet")
	-- the track only on the side not chosen: taking it off would leave none
	got, why = tram.lanesToStrip(trimmed, 4, 1, true)
	eq(#got, 0, "chosen side bare"); assert(why and why:find("chosen side", 1, true), "says the chosen side has none")
	-- no track at all (a street without tramTrackType): nothing, quietly
	local bare = plainLanes({ lane(false, 0.15, 3, SW), lane(false, -0.5, 5, CAR), lane(true, 0.5, 5, CAR), lane(true, -0.15, 3, SW) })
	got, why = tram.lanesToStrip(bare, 3, 1, true)
	eq(#got, 0, "bare"); eq(why, nil, "bare is quiet")
end)

test("approach tram: choice reads Right / Left, the traffic side and the hand-over; anything else is nothing to do", function()
	local c = tram.choice("road_tunnel_ramp/ramp.con", { rtr_tram = 3 })
	eq(c.tram, 3, "right"); eq(c.side, 1, "right-hand initially"); eq(c.kind, "ramp", "ramp")
	c = tram.choice("x/road_tunnel_ramp/median.con", { rtr_tram = 4, rtr_side = 2, rtr_approach_hand_over = 0 })
	eq(c.tram, 4, "left"); eq(c.side, 2, "left-hand"); eq(c.kind, "median", "median, always handed over")
	for _, p in ipairs({ { rtr_tram = 1 }, { rtr_tram = 2 }, { rtr_tram = "x" }, { rtr_x = 1 } }) do
		eq(tram.choice("road_tunnel_ramp/ramp.con", p), nil, "none / both / junk")
	end
	eq(tram.choice("road_tunnel_ramp/ramp.con", {}), nil, "empty params")
	eq(tram.choice("road_tunnel_ramp/ramp.con", nil), nil, "nil params")
	eq(tram.choice("road_tunnel_ramp/ramp.con", { rtr_tram = 3, rtr_approach_hand_over = 0 }), nil, "kept approach")
	eq(tram.choice("road_tunnel_ramp/ramp.con", { rtr_tram = 3, rtr_approach_hand_over = 2 }), nil, "depot style")
	eq(tram.choice("::/station/street/x.con", { rtr_tram = 3 }), nil, "another construction")
	eq(tram.choice(nil, { rtr_tram = 3 }), nil, "no file name")
end)

test("approach tram: approachDirection finds an approach in the construction's frame, turned and moved", function()
	local m = world().constructions[100].transf
	local function at(x, y, z) return { x = 1000 - y, y = 2000 + x, z = 50 + (z or 0) } end
	eq(tram.approachDirection(m, at(-20, 4), at(0, 4)), true, "into the tunnel")
	eq(tram.approachDirection(m, at(0, -4), at(-20, -4)), false, "out of it")
	eq(tram.approachDirection(m, at(0, 0), at(12, 0, -0.5)), nil, "the descent")
	eq(tram.approachDirection(m, at(0, 10), at(40, 10)), nil, "a median side street")
	eq(tram.approachDirection(m, at(-40, 0), at(-20, 0)), nil, "the player's road in front")
	eq(tram.approachDirection(m, at(-20, 0), at(0, 2)), nil, "not along x")
	eq(tram.approachDirection(m, at(-20, 0, 3), at(0, 0, 3)), nil, "another level")
	local l = tram.toLocal(m, at(-7, 3, 1))
	assert(math.abs(l.x + 7) < 1e-9 and math.abs(l.y - 3) < 1e-9 and math.abs(l.z - 1) < 1e-9, "toLocal")
	local p = tram.toWorld(m, -7, 3, 1)
	assert(math.abs(p.x - 997) < 1e-9 and math.abs(p.y - 1993) < 1e-9, "toWorld")
	eq(tram.matrix16(nil), nil, "no matrix")
	local zero = {}
	for i = 0, 15 do zero[i] = i end
	eq(tram.matrix16(zero)[1], 0, "0-based read")
end)

test("approach tram: plan picks the handed-over approach, not the descent or the player's road", function()
	local api = fakeApi(world())
	local plan = assert(tram.plan(api, 100))
	eq(#plan.edges, 1, "one approach"); eq(plan.edges[1].edge, 10, "edge 10")
	eq(plan.edges[1].runsIn, true, "runs in"); assert(same(plan.edges[1].strip, { 2 }), "lane 2")
	api = fakeApi(world({ reversed = true }))
	plan = assert(tram.plan(api, 100))
	eq(plan.edges[1].runsIn, false, "reversed runs out"); assert(same(plan.edges[1].strip, { 3 }), "lane 3")
	api = fakeApi(world({ params = { rtr_tram = 4, rtr_side = 2 } }))
	assert(same(assert(tram.plan(api, 100)).edges[1].strip, { 2 }), "left, left-hand")
	-- nothing to do: quiet; something wrong: worth a line
	local p, why, worth = tram.plan(fakeApi(world({ params = { rtr_tram = 2 } })), 100)
	eq(p, nil, "both"); eq(worth, false, "both is quiet")
	p, why, worth = tram.plan(fakeApi(world({ lanes = { lane(false, 0.15, 3, SW), lane(false, -0.5, 5, CAR), lane(true, 0.5, 5, CAR_TRACK), lane(true, -0.15, 3, SW) } })), 100)
	eq(p, nil, "trimmed"); eq(worth, false, "trimmed is quiet")
	local w = world(); w.edges[10] = nil
	p, why, worth = tram.plan(fakeApi(w), 100)
	eq(p, nil, "no approach"); eq(worth, true, "no approach is logged"); assert(why:find("no approach", 1, true), why)
	p, why, worth = tram.plan(fakeApi(world()), 999)
	eq(p, nil, "no construction"); eq(worth, true, "no construction is logged")
end)

test("approach tram: makeProposal lays the approach again with the other side's track off, the rest as it was", function()
	local w = world()
	local api = fakeApi(w)
	local plan = assert(tram.plan(api, 100))
	local proposal, removed = tram.makeProposal(api, plan)
	assert(same(removed, { 10 }), "removes 10")
	assert(same(proposal.streetProposal.edgesToRemove, { 10 }), "edgesToRemove")
	local adds = proposal.streetProposal.edgesToAdd
	eq(#adds, 1, "one added"); eq(adds[1].entity, -1, "new id"); eq(adds[1].type, 0, "street")
	local c = adds[1].comp
	eq(c.node0, 1, "node0 kept"); eq(c.node1, 2, "node1 kept"); eq(c.roadTemplate, "town_new_small", "template kept")
	local lanes = c.laneConfigs
	eq(#lanes, 4, "four lanes")
	assert(not has(lanes[2], "TRAM") and not has(lanes[2], "ELECTRIC_TRAM"), "lane 2 track off")
	assert(has(lanes[2], "CAR") and has(lanes[2], "BUS") and has(lanes[2], "TRUCK"), "lane 2 keeps the cars")
	eq(lanes[2].forward, false, "lane 2 direction kept"); eq(lanes[2].offset, -0.5, "lane 2 offset kept"); eq(lanes[2].width, 5, "lane 2 width")
	assert(has(lanes[3], "TRAM") and has(lanes[3], "ELECTRIC_TRAM") and has(lanes[3], "CAR"), "lane 3 keeps the track")
	assert(has(lanes[1], "PERSON") and has(lanes[4], "PERSON"), "sidewalks kept")
	eq(adds[1].streetEdge.precedenceNode0, 0, "BASE_EDGE_STREET copied"); eq(adds[1].playerOwned.player, 7, "owner copied")
	-- the world is untouched until the engine builds it
	assert(w.edges[10].laneConfigs[2].transportModes[TM.TRAM], "world lane 2 still has its track")
	-- sent as electrify.tl does: not player initiated, errors not ignored; street graph left alone
	tram.send(api, proposal, nil)
	local cmd = api.sent[1].cmd
	eq(cmd.kind, "build", "a build"); eq(cmd.ignore, false, "errors not ignored"); eq(cmd.player, false, "not player initiated")
	eq(cmd.context.cleanupStreetGraph, false, "street graph left alone"); eq(cmd.context.gatherBuildings, false, "no buildings")
	assert(type(api.sent[1].cb) == "function", "with a callback")
	local answer
	tram.send(api, proposal, function(ok, msg) answer = { ok, msg } end)
	api.sent[2].cb({ resultProposalData = { errorState = { critical = true, messages = { "Collision" } } } }, false)
	eq(answer[1], false, "refused"); assert(answer[2]:find("Collision", 1, true), "messages passed on")
end)

test("approach tram: makeProposal raises on a gone edge and on lanes that do not take the write", function()
	local w = world()
	local api = fakeApi(w)
	local plan = assert(tram.plan(api, 100))
	w.edges[10] = nil
	assert(not pcall(tram.makeProposal, api, plan), "gone edge")
	-- an engine whose lanes ignore the modes written
	w = world()
	api = fakeApi(w)
	plan = assert(tram.plan(api, 100))
	api.type.SegmentAndEntity.new = function()
		local comp = setmetatable({}, { __index = function(_, k)
			if k == "laneConfigs" then return { setmetatable({}, { __index = w.edges[10].laneConfigs[2], __newindex = function() end }) } end
		end, __newindex = function() end })
		return { comp = comp }
	end
	local ok, err = pcall(tram.makeProposal, api, plan)
	assert(not ok and tostring(err):find("not written", 1, true), tostring(err))
end)

-- The game script, with the stand-in engine as the global api.
local function scriptWith(w)
	local fapi = fakeApi(w)
	local oldApi, oldData = api, data
	api = fapi
	data = nil
	assert(loadfile(root .. "/content/rtr_approach_tram.script.lua"))()
	local d = data()
	data = oldData
	local function state()
		return { s = {}, subs = nil, calls = {},
			get = function(self) return self.s end, set = function(self, v) self.s = v end,
			hasEventSubscriptions = function(self) return self.subs ~= nil end,
			subscribeToEvent = function(self, name)
				if self.inHandle then error("subscribeToEvent from handleEvent") end
				self.subs = self.subs or {}; self.subs[#self.subs + 1] = name
			end,
			subscribeToNoEvents = function(self) self.subs = nil end }
	end
	local lines = {}
	local function run(fn, ...)
		local oldPrint = print
		print = function(s) lines[#lines + 1] = tostring(s) end
		local saved = api
		api = fapi
		local ok, err = pcall(fn, ...)
		api, print = saved, oldPrint
		if not ok then error(err, 2) end
	end
	api = oldApi
	return d, fapi, state, run, lines
end

local function buildEvent(params, made)
	return { { toAdd = { { fileName = "road_tunnel_ramp/ramp.con", construction = { params = params },
		transf = { 0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 1000, 2000, 50, 1 } } } },
		{ errorState = { critical = false } }, made or { 100 }, true }
end

test("approach tram script: build event -> update's event -> handleEvent's proposal; subscribed from update only", function()
	local d, fapi, newState, run, lines = scriptWith(world())
	eq(type(d.update), "function", "update"); eq(type(d.handleEvent), "function", "handleEvent")
	local st = newState()
	run(d.update, {}, st, 1)
	assert(st.subs and #st.subs == 2, "subscribed from update")
	st.inHandle = true
	run(d.handleEvent, {}, st, "", "", "onPostBuildProposal", buildEvent({ rtr_tram = 3, rtr_side = 1 }))
	st.inHandle = false
	eq(#fapi.sent, 0, "nothing sent from the build event")
	eq(st.s.approach_tram_found[1].construction, 100, "noted")
	run(d.update, {}, st, 1)
	eq(#fapi.sent, 1, "one event"); eq(fapi.sent[1].cmd.kind, "event", "a script event")
	eq(fapi.sent[1].cb, nil, "without a callback from update")
	eq(fapi.sent[1].cmd.name, tram.EVENT_NAME, "its name"); eq(fapi.sent[1].cmd.src, tram.SCRIPT, "from this script")
	eq(st.s.approach_tram_found, nil, "list emptied")
	run(d.update, {}, st, 1)
	eq(#fapi.sent, 1, "sent once")
	st.inHandle = true
	run(d.handleEvent, {}, st, "", tram.EVENT_ID, tram.EVENT_NAME, fapi.sent[1].cmd.param)
	eq(#fapi.sent, 2, "the proposal"); eq(fapi.sent[2].cmd.kind, "build", "a build")
	assert(same(fapi.sent[2].cmd.proposal.streetProposal.edgesToRemove, { 10 }), "edge 10 laid again")
	eq(#lines, 0, "nothing logged on the way")
	run(fapi.sent[2].cb, {}, true)
	eq(#lines, 0, "nothing logged when built")
	run(fapi.sent[2].cb, { resultProposalData = { errorState = { critical = true, messages = { "Collision" } } } }, false)
	eq(#lines, 1, "a refusal is logged"); assert(lines[1]:find("refused", 1, true) and lines[1]:find("Collision", 1, true), lines[1])
end)

test("approach tram script: Both, a refused build, other mods' builds and a missing approach", function()
	local d, fapi, newState, run, lines = scriptWith(world({ params = { rtr_tram = 2 } }))
	local st = newState()
	run(d.handleEvent, {}, st, "", "", "onPostBuildProposal", buildEvent({ rtr_tram = 2 }))
	eq(st.s.approach_tram_found, nil, "Both: not noted")
	local refused = buildEvent({ rtr_tram = 3 }); refused[4] = false
	run(d.handleEvent, {}, st, "", "", "onPostBuildProposal", refused)
	eq(st.s.approach_tram_found, nil, "refused build: not noted")
	local other = buildEvent({ rtr_tram = 3 }); other[1].toAdd[1].fileName = "::/station/x.con"
	run(d.handleEvent, {}, st, "", "", "onPostBuildProposal", other)
	eq(st.s.approach_tram_found, nil, "another construction: not noted")
	run(d.handleEvent, {}, st, "", "", "onPostBuildProposal", "junk")
	eq(#lines, 0, "all quiet")
	-- made entities that do not read: noted by place, found again there
	local w = world(); w.edges[10] = nil
	d, fapi, newState, run, lines = scriptWith(w)
	st = newState()
	run(d.handleEvent, {}, st, "", "", "onPostBuildProposal", buildEvent({ rtr_tram = 3 }, {}))
	eq(st.s.approach_tram_found[1].x, 1000, "noted by place")
	run(d.handleEvent, {}, st, "", tram.EVENT_ID, tram.EVENT_NAME, st.s.approach_tram_found[1])
	eq(#fapi.sent, 0, "nothing sent without an approach")
	eq(#lines, 1, "the missing approach is logged"); assert(lines[1]:find("no approach", 1, true), lines[1])
end)

-- The e2e scripts, with their placeholders filled, against the stand-in.
local function e2eChunk(name, subs)
	local f = assert(io.open(root .. "/tools/e2e/" .. name, "r"))
	local src = f:read("*a"); f:close()
	for k, v in pairs(subs) do
		local n
		src, n = src:gsub(k, v)
		assert(n > 0, name .. ": no " .. k)
	end
	return assert(loadstring(src, name))
end

test("approach tram e2e scripts: the reader gives the lanes, the sender asks (dry) or sends the same proposal", function()
	local oldApi = api
	api = fakeApi(world())
	local ok, out = pcall(e2eChunk("approach_lanes.lua", { __EDGES__ = "10, 11, 999", __CONSTRUCTION__ = "100" }))
	local okD, dry = pcall(e2eChunk("approach_tram_send.lua", { __CONSTRUCTION__ = "100", __DRY__ = "1" }))
	local sentDry = #api.sent
	local okS, sent = pcall(e2eChunk("approach_tram_send.lua", { __CONSTRUCTION__ = "100", __DRY__ = "0" }))
	local fapi = api
	api = oldApi
	assert(ok, tostring(out)); assert(okD, tostring(dry)); assert(okS, tostring(sent))
	eq(out.frameRead, true, "frame read")
	local e = out.edges[1]
	eq(e.edge, 10, "edge 10"); eq(e.runsIntoTunnel, true, "runs in")
	assert(same(e.trackLanes, { 2, 3 }), "track on both: " .. listOf(e.trackLanes))
	eq(e.lanes[2].forward, false, "forward read"); eq(e.lanes[2].offset, -0.5, "offset read")
	assert(math.abs(e.node0Local.x + 20) < 1e-6, "node0 local x")
	assert(out.edges[3].why, "a missing edge says why")
	eq(dry.stage, "dry run asked", "dry"); eq(dry.verdict.critical, false, "verdict"); eq(sentDry, 0, "dry sends nothing")
	eq(dry.approaches[1].edge, 10, "approach found"); assert(same(dry.approaches[1].strip, { 2 }), "lane 2")
	eq(sent.stage, "sent", "sent"); eq(#fapi.sent, 1, "one build")
	assert(same(fapi.sent[1].cmd.proposal.streetProposal.edgesToRemove, { 10 }), "edge 10")
	local oldPrint = print
	print = function() end
	fapi.sent[1].cb({}, true)
	print = oldPrint
	eq(tram.lastManual.answer, "built", "answer kept for the next eval")
end)
