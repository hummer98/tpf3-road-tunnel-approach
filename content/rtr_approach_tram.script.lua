-- Road Tunnel Approach: the game script that, after a ramp (or the median
-- approach) is built with Tram track Right or Left, lays its handed-over
-- flat approach again with the track only on the chosen side (why and
-- which lanes: road_tunnel_ramp/approach_tram.lua).
--
-- When and where, as the median branch's fork and merge script did it
-- in game [measured 2026-11-23 C3-C6, 4f71da0]:
-- 1. handleEvent, onPostBuildProposal (the engine fires it for every build,
--    from the build menu and tf3ctl build alike [measured C6]): notes each
--    of this mod's constructions the build made, when Right or Left was
--    chosen, in the game-script state. No command may be sent from inside
--    it ("Assertion !m_betweenChanges" [source: Public Roads
--    refund.script.lua; measured 2026-11-23 for subscribeToEvent there]).
-- 2. update: sends this script the event rtr_approach_tram { construction
--    = id } for each noted one, without a callback (a callback from update
--    raised "Callbacks are currently disallowed" [measured C3]), and
--    empties the list. The list lives in the state, not in this file's
--    locals: update and handleEvent run in different Lua states [measured
--    C4].
-- 3. handleEvent, rtr_approach_tram: finds the approach edges, asks the
--    engine (makeProposalData) about the ways of laying them again in turn
--    (approach_tram.lua M.VARIANTS: TC7 and TC8 found which way it takes), and sends
--    the first it takes as one SimpleProposal (edgesToRemove / edgesToAdd), with
--    a callback that logs a refusal [measured C3: a callback from
--    handleEvent goes through].
-- Only failures are logged; nothing to do (no track chosen, Both, already
-- one side) is silent.
--
-- By hand (tf3ctl script-event road_tunnel_ramp rtr_approach_tram
-- '{"construction": ID}'): the same step 3 for a placed one; dry_run = 1
-- asks the engine (makeProposalData) instead and logs its verdict.

local tram = require "road_tunnel_ramp::/road_tunnel_ramp/approach_tram.lua"

local TAG = "[road_tunnel_ramp] "
local BUILD_EVENT = "onPostBuildProposal"
local FOUND_KEY = "approach_tram_found"
local FOUND_MAX = 8 -- a build places one; more is a stuck list

local function log(msg)
	print(TAG .. "tram approach: " .. msg)
end

local function try(fn)
	local ok, v = pcall(fn)
	if ok then return v end
	return nil
end

local list = tram.list

-- Without a state object (not seen in game) the list lives in this Lua
-- state only.
local fallback = {}
local function readState(state)
	if state ~= nil then
		local ok, v = pcall(function() return state:get() end)
		if ok and type(v) == "table" then return v end
		if ok then return {} end
	end
	return fallback
end
local function writeState(state, s)
	if state == nil or s == fallback then return end
	local ok, err = pcall(function() state:set(s) end)
	if not ok then log("the game-script state does not take the list: " .. tostring(err)) end
end

-- 1. The build event: notes the constructions to lay the approach of.
local function onBuilt(state, param)
	if type(param) ~= "table" and type(param) ~= "userdata" then return end
	if try(function() return param[4] end) == false then return end
	if try(function() return param[2].errorState.critical end) == true then return end
	local ours = {}
	for _, ce in ipairs(list(try(function() return param[1].toAdd end))) do
		local fileName = tostring(try(function() return ce.fileName end) or "")
		if tram.kindOf(fileName) then ours[#ours + 1] = ce end
	end
	-- (most builds stop here: no construction of this mod)
	if #ours == 0 then return end
	local found, seen = {}, {}
	local made = list(try(function() return param[3] end))
	for _, e in ipairs(made) do
		local id = tonumber(e)
		local info = id and not seen[id] and tram.constructionInfo(api, id)
		if info and tram.choice(info.fileName, info.params) then
			seen[id] = true
			found[#found + 1] = { construction = id }
		end
	end
	if #made == 0 then
		-- the made entities do not read: where the construction stands
		for _, ce in ipairs(ours) do
			local params = tram.plainParams(try(function() return ce.construction.params end))
			local m = tram.matrix16(try(function() return ce.transf end))
			if m and tram.choice(tostring(ce.fileName), params) then
				found[#found + 1] = { x = m[13], y = m[14], z = m[15] }
			end
		end
	end
	if #found == 0 then return end
	local s = readState(state)
	local q = type(s[FOUND_KEY]) == "table" and s[FOUND_KEY] or {}
	for _, f in ipairs(found) do
		if #q >= FOUND_MAX then
			local old = table.remove(q, 1)
			log("too many ramps waiting; " .. tostring(old.construction or "one") .. " dropped")
		end
		q[#q + 1] = f
	end
	s[FOUND_KEY] = q
	writeState(state, s)
end

-- 2. update: the event for each noted construction (no callback).
local function sendFound(state)
	local s = readState(state)
	local q = s[FOUND_KEY]
	if q == nil then return end
	s[FOUND_KEY] = nil
	writeState(state, s)
	if type(q) ~= "table" then return end
	for k = 1, math.min(#q, FOUND_MAX) do
		local param = q[k]
		local ok, err = pcall(function()
			api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd(tram.SCRIPT, tram.EVENT_ID, tram.EVENT_NAME, param))
		end)
		if not ok then
			log("construction " .. tostring(param.construction or "?") .. ": event not sent, the track stays on both sides: " .. tostring(err))
		end
	end
end

-- 3. The event: lays the approach edges again.
local function lay(param)
	local con = tonumber(param.construction)
	if not con and tonumber(param.x) and tonumber(param.y) then
		local info = tram.constructionNear(api, tonumber(param.x), tonumber(param.y), tonumber(param.z))
		con = info and info.entity
		if not con then
			return log(string.format("no ramp found at %.1f, %.1f; the track stays on both sides", tonumber(param.x), tonumber(param.y)))
		end
	end
	if not con then return log("event without a construction; nothing done") end
	local plan, why, worth = tram.plan(api, con)
	if not plan then
		if worth then log("construction " .. con .. ": " .. tostring(why) .. "; the track stays on both sides") end
		return
	end
	for _, note in ipairs(plan.notes) do log("construction " .. con .. ": " .. note .. " (left as it is)") end
	-- (the ways of laying it again, in order, until the engine takes one:
	-- approach_tram.lua M.VARIANTS; whole records raised in the engine, TC7, TC8)
	local what = tram.describe(plan)
	local context = tram.context(api)
	local proposal, way, fails, k = tram.firstPassing(api, plan, context)
	if not proposal then
		return log(string.format("construction %d (%s): no way taken, the track stays on both sides: %s", con, what,
			table.concat(fails, " | ")))
	end
	if tonumber(param.dry_run) == 1 then
		return log(string.format("dry run, construction %d, %s: the engine takes \"%s\"%s", con, what, way,
			#fails > 0 and (" (not: " .. table.concat(fails, " | ") .. ")") or ""))
	end
	local function answer(success, msg)
		if not success then
			log(string.format("construction %d: refused (%s, the \"%s\" way), the track stays on both sides:%s", con, what, way, msg))
			return
		end
		local okV, left = pcall(tram.stillBoth, api, plan)
		if okV and #left > 0 then
			log(string.format("construction %d: built (%s), but edge %s still has the track on both sides", con, what,
				table.concat(left, ",")))
		end
	end
	-- (a way the engine takes in makeProposalData but whose command raises
	-- goes on to the next way, as a raise in makeProposalData does)
	while true do
		local okS, err = pcall(tram.send, api, proposal, answer)
		if okS then break end
		fails[#fails + 1] = way .. ": not sent: " .. tostring(err)
		-- (not `_`: that is the game's translation function)
		local more
		proposal, way, more, k = tram.firstPassing(api, plan, context, k + 1)
		for _, f in ipairs(more or {}) do fails[#fails + 1] = f end
		if not proposal then
			return log(string.format("construction %d (%s): no way sent, the track stays on both sides: %s", con, what,
				table.concat(fails, " | ")))
		end
	end
	-- (a way after the first is worth a line: the next e2e reads which)
	if #fails > 0 then
		log(string.format("construction %d: laid again the \"%s\" way (not: %s)", con, way, table.concat(fails, " | ")))
	end
end

-- Subscribed from update only, asking the engine whether this load has the
-- subscriptions (state:hasEventSubscriptions), as the base game's
-- landmarks.script.tl does from update [source]; never from handleEvent,
-- where subscribeToEvent hit "Assertion '!m_betweenChanges' failed"
-- [measured 2026-11-23, the median branch's 4f71da0]. The Lua flag is the
-- fallback only where the engine cannot say.
local EVENTS = { BUILD_EVENT, tram.EVENT_NAME }
local subscribed, failLogged = false, false
local function engineHasSubscriptions(state)
	local ok, has = pcall(function() return state:hasEventSubscriptions() end)
	if ok then return has and true or false end
	return nil
end
local function subscribe(state)
	if not state then return end
	local has = engineHasSubscriptions(state)
	if has == true or (has == nil and subscribed) then return end
	local ok, err = pcall(function()
		for _, name in ipairs(EVENTS) do state:subscribeToEvent(name) end
	end)
	if ok then
		subscribed, failLogged = true, false
	else
		subscribed = false
		if not failLogged then log("subscribe failed: " .. tostring(err)) end
		failLogged = true
		-- drop a partial set, or hasEventSubscriptions would answer true
		pcall(function() state:subscribeToNoEvents() end)
	end
end

function data()
	return {
		update = function(_userParams, state, _dt)
			subscribe(state)
			local ok, err = pcall(sendFound, state)
			if not ok then log("error: " .. tostring(err)) end
		end,
		handleEvent = function(_userParams, state, _src, id, name, param)
			if name == BUILD_EVENT then
				local ok, err = pcall(onBuilt, state, param)
				if not ok then log("build event error: " .. tostring(err)) end
			elseif id == tram.EVENT_ID and name == tram.EVENT_NAME and type(param) == "table" then
				local ok, err = pcall(lay, param)
				if not ok then log("error: " .. tostring(err)) end
			end
		end,
	}
end
