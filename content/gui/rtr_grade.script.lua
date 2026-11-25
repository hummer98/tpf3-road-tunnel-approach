-- Adds "Max grade: N%" under the build cursor while placing the tunnel
-- ramp or the median approach (grade.isRamp), so short + deep settings
-- show how steep they are before building,
-- and the slope of the ground under it, in the units of the two ground
-- slope options, so players know what to enter there.
--
-- Same hook as construction_height_tooltip: the cursor text comes from
-- C++, and the only Lua extension point is the action's
-- getProposalStringsFn. Actions are created by the exported
-- construction_react_util.getActionParams, so we wrap it once before the
-- UI starts and chain to whatever other mods put there.
local grade = require "road_tunnel_ramp::/road_tunnel_ramp/grade.lua"

local reported = {}
local function reportOnce(key, msg)
	if not reported[key] then
		reported[key] = true
		debugPrint("[road_tunnel_ramp] " .. msg)
	end
end

-- Builder fields are engine types; read them defensively. Script params
-- arrive as numbers[index] values (script_param_util), same as updateFn.
local function readList(list)
	local out = {}
	if type(list) == "table" then
		for i = 1, #list do out[i] = list[i] end
		return out
	end
	local ok = pcall(function()
		for i = 1, #list do out[i] = list[i] end
	end)
	if not ok then
		pcall(function()
			for i = 0, list:size() - 1 do out[#out + 1] = list:at(i) end
		end)
	end
	return out
end

local function readParam(params, key)
	local ok, v = pcall(function() return params[key] end)
	if ok and v ~= nil then return v end
	ok, v = pcall(function() return params:at(key) end)
	if ok then return v end
	return nil
end

local function text(key, fallback)
	local ok, v = pcall(_, key)
	if ok and type(v) == "string" and v ~= "" and v ~= key then return v end
	return fallback
end

local function label()
	return text("rtr_grade_label", "Max grade")
end

local function gradeLine(builder)
	if not grade.isRamp(readList(builder.constructions)) then return nil end
	local params = builder.params
	local p = {}
	for _, key in ipairs({ "rtr_length", "rtr_depth", "rtr_curvature" }) do
		p[key] = readParam(params, key)
	end
	-- A grade computed from defaults would look right but be wrong, so
	-- show nothing when the engine's params can't be read.
	if p.rtr_length == nil then
		reportOnce("noparams", "grade line: builder params not readable, line skipped")
		return nil
	end
	return grade.formatLine(label(), grade.maxGrade(p))
end

-- Base height leaves out terrain alignments (the preview's own cut, the
-- road it snaps to), which would otherwise feed the entered slope back.
local function heightFn()
	local terrain = api.engine.terrain
	return terrain.getBaseHeightAt or terrain.getHeightAt
end

local function groundLine(builder, proposal)
	if proposal == nil then return nil end
	local params = builder.params
	local p = { rtr_length = readParam(params, "rtr_length"), rtr_approach = readParam(params, "rtr_approach") }
	if p.rtr_length == nil then return nil end  -- gradeLine reports it
	-- Nothing to place yet (cursor off the map): no line, and not a failure.
	local okSize, size = pcall(function() return proposal.toAdd_native:size() end)
	if okSize and type(size) == "number" and size < 1 then return nil end
	local ok, transf = pcall(function() return proposal.toAdd_native:at(1).transf end)
	if not ok or transf == nil then
		reportOnce("notransf", "ground line: proposal transf not readable, line skipped")
		return nil
	end
	-- Mat4f is column-major with 1-based __index (see the altitude
	-- tooltip): 1,2 = local +x, 5,6 = local +y, 13,14 = origin.
	local m = {}
	for _, i in ipairs({ 1, 2, 5, 6, 13, 14 }) do
		m[i] = transf[i]
		if type(m[i]) ~= "number" then
			reportOnce("badtransf", "ground line: transf[" .. i .. "] is not a number, line skipped")
			return nil
		end
	end
	local heightAt = heightFn()
	local pts = grade.groundSamples(p)
	local zs = {}
	for i, pt in ipairs(pts) do
		local x, y = pt[1], pt[2]
		zs[i] = heightAt(api.type.Vec2f.new(m[13] + x * m[1] + y * m[5], m[14] + x * m[2] + y * m[6]))
	end
	local along, across = grade.fitGround(pts, zs)
	if not along then return nil end
	return grade.formatGroundLine(text("rtr_ground_line", "Ground slope: along {along}, across {across}"), along, across)
end

local function wrapAction(action)
	local original = action.getProposalStringsFn
	action.getProposalStringsFn = function(proposal, proposalData)
		local base = original and original(proposal, proposalData) or {}
		-- Read the live builder each time: params may change while the
		-- same action stays active.
		local ok, line = pcall(gradeLine, action.constructionBuilder)
		if not ok then
			reportOnce("err", "grade line failed: " .. tostring(line))
			return base
		end
		if not line then return base end
		local out = {}
		for i = 1, #base do out[i] = base[i] end
		out[#out + 1] = line
		-- Separate pcall: a terrain read failing must not take the max
		-- grade line with it.
		local okGround, ground = pcall(groundLine, action.constructionBuilder, proposal)
		if not okGround then
			reportOnce("grounderr", "ground line failed: " .. tostring(ground))
		elseif ground then
			out[#out + 1] = ground
		end
		return out
	end
end

local function install()
	local cru = ug_require "::/gui/construction/construction_react_util.tl"
	if cru.__rtrGradeInstalled then return end
	local originalGetActionParams = cru.getActionParams
	local wrapped = setmetatable({}, { __mode = "k" })
	cru.getActionParams = function(...)
		local result = originalGetActionParams(...)
		local action = result and result.constructionActionParams
		if action and action.constructionBuilder ~= nil and not wrapped[action] then
			local ok, isRamp = pcall(function() return grade.isRamp(readList(action.constructionBuilder.constructions)) end)
			if ok and isRamp then
				wrapped[action] = true
				wrapAction(action)
			end
		end
		return result
	end
	cru.__rtrGradeInstalled = true
end

function data()
	return {
		prepare = function(_replacementApi)
			local ok, err = pcall(install)
			if not ok then debugPrint("[road_tunnel_ramp] grade tooltip install failed: " .. tostring(err)) end
		end,
	}
end
