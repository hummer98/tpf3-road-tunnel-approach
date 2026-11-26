-- The mod setting "initial portal cover length" (mod.json params,
-- rtr_cover_length_default): the value the two constructions' Portal cover
-- length slider (rtr_cover_length) starts on in the build menu. The user:
-- 「1.1.0にMODの設定を入れてOKです」 (2026-11-26). It changes only the
-- slider's defaultIndex, through mod.script.lua's loadConstruction
-- modifier; a placed ramp keeps the rtr_cover_length it was built with, as
-- its params hold it, and the construction scripts never read this setting.
--
-- No engine access, so the tests run it offline.

local geometry = require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua"

local M = {}

M.MOD_ID = "road_tunnel_ramp"
M.KEY = "rtr_cover_length_default"   -- in mod.json params
M.CON_KEY = "rtr_cover_length"       -- in ramp.con / median.con params
-- the constructions it applies to (content/road_tunnel_ramp/<name>.con.lua)
M.CONS = { ramp = true, median = true }

-- A mod param arrives as its 1-based position in mod.json's "values",
-- not as mod.json's 0-based defaultIndex [measured 2026-11-24 with
-- hummer_pier_spike and remote_probe, ComboBox and Button settings only:
-- an unset Off/On switch with defaultIndex 0 arrived as 1; source: its
-- mod.script.lua enabled(). For a Slider setting, measured 2026-11-26
-- with this mod's 1.1.0 (6..24m): the setting at position 1 made the menu
-- start on 6m, at 19 on 24m; the mod.io mod 6432568 says sliders come the
-- same way (dashboard_export, "sliders included (seen in stdout.txt)")].
-- The values are LID_MIN .. LID_MAX, so position i is LID_MIN - 1 + i
-- metres: a game set up with 1.1.0 gets LID_MIN - 6 metres more for the
-- same position, and a position past the end reads as 18m. Missing, junk,
-- not whole or out of range: the initial 18m (geometry.LID_DEFAULT), as
-- for the slider itself.
function M.lengthFromModParam(raw)
	local i = tonumber(raw)
	local n = geometry.LID_MAX - geometry.LID_MIN + 1
	if not i or i ~= i or i ~= math.floor(i) or i < 1 or i > n then return geometry.LID_DEFAULT end
	return geometry.LID_MIN + i - 1
end

-- mod.json's defaultIndex (0-based) for a length: LID_MIN -> 0
function M.modDefaultIndex(len)
	return len - geometry.LID_MIN
end

-- A .con param's defaultIndex is 1-based [source: the base game's
-- param_util.tl catenary defaultIndex = 2 is "Yes"; gui construction.tl
-- getParamDefaultValue takes numbers[defaultIndex]; this mod's own
-- rtr_length defaultIndex = #lengthNumbers is 100m]: LID_MIN -> 1.
function M.conDefaultIndex(len)
	return len - geometry.LID_MIN + 1
end

-- This mod's params from runFn's arguments: like AoM (core/registry.lua
-- modParamsFrom) and hummer_pier_spike (mod.script.lua enabled), looked
-- for in the 2nd and the 3rd argument, under the modId or the folder name.
function M.modParamsFrom(...)
	for i = 1, select("#", ...) do
		local all = select(i, ...)
		if type(all) == "table" then
			for _, key in ipairs({ M.MOD_ID, M.MOD_ID .. "_1" }) do
				local ok, p = pcall(function() return all[key] end)
				if ok and type(p) == "table" then return p end
			end
		end
	end
	return {}
end

-- Which of this mod's constructions a loadConstruction file name is: "ramp",
-- "median" or nil. For the base game's the modifier gets
-- "::/depots/rail/rail_depot.con.lua" [measured: AoM's log, clean_depot];
-- for a mod's own file "road_tunnel_ramp::/road_tunnel_ramp/ramp.con.lua"
-- is likely [guess; e2e pending], so the path's end is matched, after a
-- "/" or ":" or nothing, with or without ".lua".
function M.conOf(fileName)
	if type(fileName) ~= "string" then return nil end
	for _, tail in ipairs({ ".con", ".con.lua" }) do
		local before, name = fileName:match("^(.-)road_tunnel_ramp/(%a+)" .. tail:gsub("%.", "%%.") .. "$")
		if name and M.CONS[name] and (before == "" or before:find("[/:]$")) then return name end
	end
	return nil
end

-- Sets the cover slider's defaultIndex in a .con's data to len, where its
-- numbers have len. Returns true when it did; anything else in data stays.
function M.applyToCon(data, len)
	if type(data) ~= "table" or type(data.params) ~= "table" then return false end
	for _, p in ipairs(data.params) do
		if type(p) == "table" and p.key == M.CON_KEY and type(p.numbers) == "table" then
			for i, n in ipairs(p.numbers) do
				if n == len then
					p.defaultIndex = i
					return true
				end
			end
		end
	end
	return false
end

-- The loadConstruction modifier for one length.
function M.modifier(len)
	return function(fileName, data)
		if M.conOf(fileName) then M.applyToCon(data, len) end
		return data
	end
end

return M
