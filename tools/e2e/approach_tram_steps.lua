-- e2e (tf3ctl eval --write --gs, test saves only; sends nothing): where the
-- approach's lay-again breaks, step by step. WAYS below: how the new edge
-- is made (base: "replace" the engine's replaceSegment, with its junction
-- set-ups; "fields" a fresh one given approach_tram.lua M.FIELDS one by
-- one; "try" TC8 try.lua's six fields; "whole" the old BASE_EDGE whole,
-- which raised in TC7 and TC8), its lanes (written: the other side's track
-- off; same; template), the look, objects, BASE_EDGE_STREET, PLAYER_OWNED,
-- and how the lists go in (whole, or element by element as try.lua: an
-- element written into an engine list may be lost, AoM 2026-11-16). Every
-- assignment and call runs in its own pcall; per way the answer gives the
-- steps done, the first that raised, how many edges and set-ups the
-- proposal holds when read back (0 for an empty one), then makeProposalData
-- with the mod's context and with none (critical, messages, costs,
-- networks made) and makeWorldBuildProposalCmd made but not sent.
-- A way the engine refuses may log "map_util.h:22 ... Assertion" in the
-- Sim Pool (TC7, TC8: the game went on). Like the game script, it lays the
-- first approach edge only (one per proposal). The mod's own path in one
-- piece: approach_tram_send.lua.
--
-- __WAY__: one way's name in quotes (one eval per way, so a game that stops
-- on an assert loses only that way's answer: "replace" first, the game
-- script's first), or "all".
--
--   sed -e 's/__CONSTRUCTION__/23456/' -e 's/__WAY__/"replace"/' tools/e2e/approach_tram_steps.lua > "$SCRATCH/steps.lua"
--   python3 .../tf3ctl.py --owner mod-keeper eval --write --gs --file "$SCRATCH/steps.lua"
local CONSTRUCTION = __CONSTRUCTION__
local WAY = __WAY__

local tram = require "road_tunnel_ramp::/road_tunnel_ramp/approach_tram.lua"
local CT = api.type.ComponentType
local TRY_FIELDS = { "node0", "node1", "tangent0", "tangent1", "type", "typeIndex" }
local WAYS = {
	{ name = "replace", base = "replace", lanes = "written" },
	{ name = "replace-noconfigs", base = "replace", lanes = "written", noConfigs = true },
	{ name = "replace-same", base = "replace", lanes = "same" },
	{ name = "fields", base = "fields", lanes = "written", streetEdge = true, look = true },
	{ name = "fields-plain", base = "fields", lanes = "written", streetEdge = true },
	{ name = "fields-template", base = "fields", lanes = "template", streetEdge = true, look = true },
	{ name = "fields-objects", base = "fields", lanes = "written", streetEdge = true, look = true, objects = true },
	{ name = "fields-owned", base = "fields", lanes = "written", streetEdge = true, look = true, playerOwned = true },
	-- TC8 try.lua as it was: six fields, the lanes as read, lists by element
	{ name = "try", base = "try", lanes = "vector", streetEdge = true, lists = "element" },
	{ name = "try-whole-lists", base = "try", lanes = "vector", streetEdge = true },
	{ name = "whole-same", base = "whole", lanes = "same" },
	{ name = "whole-element-lists", base = "whole", lanes = "same", lists = "element" },
}

local out = { construction = CONSTRUCTION, ways = {} }
local plan, why = tram.plan(api, CONSTRUCTION)
if not plan then out.stage = "plan: " .. tostring(why); return out end
out.plan = tram.describe(plan)
-- (the first approach edge only, one per proposal as the game script sends them)
plan = { construction = plan.construction, choice = plan.choice, params = plan.params, edges = { plan.edges[1] }, notes = {} }
out.edge = plan.edges[1].edge

local known = false
for _, w in ipairs(WAYS) do if WAY == "all" or w.name == WAY then known = true end end
if not known then out.stage = "no way named " .. tostring(WAY); return out end

local function runWay(w)
	local r = { way = w.name, done = {} }
	local failed = false
	local function step(name, fn)
		if failed then return nil end
		local ok, v = pcall(fn)
		if ok then
			r.done[#r.done + 1] = name
			return v
		end
		failed = true
		r.failedAt, r.error = name, tostring(v)
		return nil
	end
	local adds, removes, holders, cfgAdd, cfgRemove = {}, {}, {}, {}, {}
	for k, item in ipairs(plan.edges) do
		local tag = "edge " .. item.edge .. ": "
		local old = step(tag .. "getComponent BASE_EDGE", function()
			local c = api.engine.getComponent(item.edge, CT.BASE_EDGE)
			assert(c ~= nil, "no BASE_EDGE")
			return c
		end)
		local seg
		if w.base == "replace" then
			seg = step(tag .. "replaceSegment", function()
				local s, add, rem = tram.replacement(api, item.edge)
				if not w.noConfigs then
					for _, c in ipairs(add) do cfgAdd[#cfgAdd + 1] = c end
					for _, n in ipairs(rem) do cfgRemove[#cfgRemove + 1] = n end
				end
				-- (the set-ups' lane connections, and those with a tram: made
				-- for the old lanes, the track on both sides)
				local conns, tramConns = 0, 0
				for _, c in ipairs(add) do
					for _, lc in ipairs(tram.list(c.comp and c.comp.laneConnections)) do
						conns = conns + 1
						if lc.withTram then tramConns = tramConns + 1 end
					end
				end
				r.replaceConfigs = { add = #add, remove = #rem, laneConnections = conns, withTram = tramConns,
					node0 = s.comp.node0, node1 = s.comp.node1, oldNode0 = old.node0, oldNode1 = old.node1 }
				return s
			end)
		else
			seg = step(tag .. "SegmentAndEntity.new", function() return api.type.SegmentAndEntity.new() end)
			step(tag .. "seg.entity = -" .. k, function() seg.entity = -k end)
			step(tag .. "seg.type = 0", function() seg.type = 0 end)
			if w.base == "whole" then
				step(tag .. "seg.comp = old", function() seg.comp = old end)
			else
				for _, f in ipairs(w.base == "try" and TRY_FIELDS or tram.FIELDS) do
					step(tag .. "seg.comp." .. f, function()
						local v = old[f]
						if v ~= nil then seg.comp[f] = v end
					end)
				end
			end
		end
		local lookName, lookStyle
		if w.look then
			step(tag .. "old.roadTemplate / roadStyle", function() lookName, lookStyle = old.roadTemplate, old.roadStyle end)
		end
		local lanes = step(tag .. "lanes (" .. w.lanes .. ")", function()
			if w.lanes == "vector" then return old.laneConfigs end
			if w.lanes == "same" then return tram.list(old.laneConfigs) end
			if w.lanes == "template" then
				local tl, name, style = tram.templateLanes(api, item, old, plan.choice, plan.params or {})
				assert(tl, name)
				r.template = name
				lookName, lookStyle = name, style or lookStyle
				return tl
			end
			local strip = {}
			for _, i in ipairs(item.strip) do strip[i] = true end
			local nl = {}
			for i, lc in ipairs(tram.list(old.laneConfigs)) do nl[i] = strip[i] and tram.stripped(api, lc, holders) or lc end
			return nl
		end)
		step(tag .. "seg.comp.laneConfigs = lanes", function() seg.comp.laneConfigs = lanes end)
		if w.look then
			step(tag .. "seg.comp.roadTemplate / roadStyle", function()
				if lookName ~= nil then seg.comp.roadTemplate = lookName end
				if lookStyle ~= nil then seg.comp.roadStyle = lookStyle end
				r.look = tostring(lookName)
			end)
		end
		if w.objects then
			step(tag .. "seg.comp.objects", function()
				local o = old.objects
				if o ~= nil then seg.comp.objects = o end
			end)
		end
		step(tag .. "lanes read back", function()
			local back = tram.list(seg.comp.laneConfigs)
			r.lanesBack = {}
			for i, lc in ipairs(back) do
				local modes = {}
				for _, nm in ipairs(tram.MODES) do if tram.allows(api, lc, nm) then modes[#modes + 1] = nm end end
				r.lanesBack[i] = { forward = lc.forward, offset = lc.offset, modes = table.concat(modes, " ") }
			end
		end)
		if w.streetEdge then
			step(tag .. "seg.streetEdge = BASE_EDGE_STREET", function()
				local c = api.engine.getComponent(item.edge, CT.BASE_EDGE_STREET)
				if c ~= nil then seg.streetEdge = c end
			end)
		end
		if w.playerOwned then
			step(tag .. "seg.playerOwned = PLAYER_OWNED", function()
				local c = api.engine.getComponent(item.edge, CT.PLAYER_OWNED)
				if c ~= nil then seg.playerOwned = c end
			end)
		end
		adds[k], removes[k] = seg, item.edge
	end
	local proposal = step("SimpleProposal.new", function() return api.type.SimpleProposal.new() end)
	local sp = proposal and proposal.streetProposal
	if w.lists == "element" then
		step("edgesToRemove[k] / edgesToAdd[k]", function()
			for k, e in ipairs(removes) do sp.edgesToRemove[k] = e end
			for k, seg in ipairs(adds) do sp.edgesToAdd[k] = seg end
		end)
	else
		step("edgesToRemove / edgesToAdd (whole lists)", function()
			sp.edgesToRemove = removes
			sp.edgesToAdd = adds
			if #cfgAdd > 0 then sp.nodeConfigsToAdd = cfgAdd end
			if #cfgRemove > 0 then sp.nodeConfigsToRemove = cfgRemove end
		end)
	end
	-- (0 here: the proposal is empty, whatever the engine says of it)
	if sp then
		local ok = pcall(function()
			r.held = { remove = #tram.list(sp.edgesToRemove), add = #tram.list(sp.edgesToAdd),
				configsAdd = #tram.list(sp.nodeConfigsToAdd), configsRemove = #tram.list(sp.nodeConfigsToRemove) }
		end)
		if not ok then r.held = "does not read" end
	end
	-- The asks each run on their own, whatever went before them (whether
	-- the mod's context is the cause is one of the questions), once the
	-- proposal is whole.
	local whole = not failed
	local function verdict(name, ctx)
		if not whole then return end
		local ok, err = pcall(function()
			local data = api.engine.util.proposal.makeProposalData(proposal, ctx)
			local v = { critical = false, messages = {} }
			pcall(function()
				v.critical = data.errorState.critical == true
				for _, x in ipairs(tram.list(data.errorState.messages)) do v.messages[#v.messages + 1] = tostring(x) end
			end)
			local c = tram.dataCounts(data)
			v.costs, v.networks = c.costs, c.networks
			r[name] = v
		end)
		if not ok then r[name] = { raised = tostring(err) } end
	end
	verdict("makeProposalData(context)", tram.context(api))
	-- (with none, as electrify.tl sends it)
	verdict("makeProposalData(nil)", nil)
	if whole then
		local ok, err = pcall(function() api.cmd.makeWorldBuildProposalCmd(proposal, tram.context(api), false, false) end)
		r["makeWorldBuildProposalCmd (not sent)"] = ok and "made" or { raised = tostring(err) }
	end
	return r
end

for _, w in ipairs(WAYS) do
	if WAY == "all" or w.name == WAY then out.ways[#out.ways + 1] = runWay(w) end
end
return out
