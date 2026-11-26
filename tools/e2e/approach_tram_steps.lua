-- e2e (tf3ctl eval --write --gs, test saves only; sends nothing): where the
-- approach's lay-again breaks, step by step. For each way of building it
-- (WAYS below: the edge laid again unchanged, with a template's lanes, with
-- the lanes written mode by mode; each bare, and with BASE_EDGE_STREET and
-- PLAYER_OWNED copied) every assignment and call runs in its own pcall; the
-- answer gives, per way, the steps done and the first that raised, then the
-- engine's verdict: makeProposalData with the mod's context and with none,
-- and makeWorldBuildProposalCmd made but not sent (TC7 raised in it).
-- A way the engine refuses may log "map_util.h:22 ... Assertion" in the
-- Sim Pool (TC7: the game went on).
--
--   sed -e 's/__CONSTRUCTION__/23456/' tools/e2e/approach_tram_steps.lua > "$SCRATCH/steps.lua"
--   python3 .../tf3ctl.py --owner mod-keeper eval --write --gs --file "$SCRATCH/steps.lua"
local CONSTRUCTION = __CONSTRUCTION__

local tram = require "road_tunnel_ramp::/road_tunnel_ramp/approach_tram.lua"
local CT = api.type.ComponentType
local WAYS = {
	{ name = "same-bare", lanes = "same" },
	{ name = "same", lanes = "same", streetEdge = true, playerOwned = true },
	{ name = "template-bare", lanes = "template" },
	{ name = "template", lanes = "template", streetEdge = true, playerOwned = true },
	{ name = "written-bare", lanes = "written" },
	{ name = "written", lanes = "written", streetEdge = true, playerOwned = true },
}

local out = { construction = CONSTRUCTION, ways = {} }
local plan, why = tram.plan(api, CONSTRUCTION)
if not plan then out.stage = "plan: " .. tostring(why); return out end
out.plan = tram.describe(plan)

for _, w in ipairs(WAYS) do
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
	local adds, removes, holders = {}, {}, {}
	for k, item in ipairs(plan.edges) do
		local tag = "edge " .. item.edge .. ": "
		local old = step(tag .. "getComponent BASE_EDGE", function()
			local c = api.engine.getComponent(item.edge, CT.BASE_EDGE)
			assert(c ~= nil, "no BASE_EDGE")
			return c
		end)
		local seg = step(tag .. "SegmentAndEntity.new", function() return api.type.SegmentAndEntity.new() end)
		step(tag .. "seg.entity = -" .. k, function() seg.entity = -k end)
		step(tag .. "seg.type = 0", function() seg.type = 0 end)
		step(tag .. "seg.comp = old", function() seg.comp = old end)
		local lanes = step(tag .. "lanes (" .. w.lanes .. ")", function()
			if w.lanes == "same" then return tram.list(old.laneConfigs) end
			if w.lanes == "template" then
				local tl, name = tram.templateLanes(api, item, old, plan.choice, plan.params or {})
				assert(tl, name)
				r.template = name
				return tl
			end
			local strip = {}
			for _, i in ipairs(item.strip) do strip[i] = true end
			local nl = {}
			for i, lc in ipairs(tram.list(old.laneConfigs)) do nl[i] = strip[i] and tram.stripped(api, lc, holders) or lc end
			return nl
		end)
		step(tag .. "seg.comp.laneConfigs = lanes", function() seg.comp.laneConfigs = lanes end)
		step(tag .. "lanes read back", function()
			local back = tram.list(seg.comp.laneConfigs)
			assert(#back == #lanes, #back .. " lanes back of " .. #lanes)
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
	step("edgesToRemove", function() proposal.streetProposal.edgesToRemove = removes end)
	step("edgesToAdd", function() proposal.streetProposal.edgesToAdd = adds end)
	local function verdict(name, ctx)
		step(name, function()
			local data = api.engine.util.proposal.makeProposalData(proposal, ctx)
			local v = { critical = false, messages = {} }
			pcall(function()
				v.critical = data.errorState.critical == true
				for _, x in ipairs(tram.list(data.errorState.messages)) do v.messages[#v.messages + 1] = tostring(x) end
			end)
			r[name] = v
		end)
	end
	verdict("makeProposalData(context)", tram.context(api))
	-- (with none, as electrify.tl sends it; after a raise above nothing more runs)
	verdict("makeProposalData(nil)", nil)
	step("makeWorldBuildProposalCmd (not sent)", function()
		api.cmd.makeWorldBuildProposalCmd(proposal, tram.context(api), false, false)
	end)
	out.ways[#out.ways + 1] = r
end
return out
