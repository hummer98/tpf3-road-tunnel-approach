-- Start-up script (mod.json runScript): applies the mod setting "initial
-- portal cover length" (rtr_cover_length_default) to the build menu's
-- Portal cover length slider of both constructions, with a loadConstruction
-- modifier, as AoM edits the base game's constructions (its mod.script.lua
-- runFn, core/dispatch.lua installModifiers). Not postRunFn with
-- constructionRep getAsTable / setAsTable: written back that way, a test
-- mod's construction lost its update script (hummer_pier_spike, e2e
-- 2026-11-24, "0 streets read back"). The setting changes only the
-- slider's starting value: placed ramps keep their own length.

local setting = require "road_tunnel_ramp::/road_tunnel_ramp/cover_setting.lua"

local function say(msg)
	local f = log and log.message or print
	f("[road_tunnel_ramp] " .. msg)
end

function data()
	return {
		runFn = function(_captureParams, second, third)
			local p = setting.modParamsFrom(third, second)
			local len = setting.lengthFromModParam(p[setting.KEY])
			-- pcall: an addModifier that raises must not take the load down;
			-- the slider then starts on the .con files' own 18m
			local ok, err = pcall(addModifier, "loadConstruction", setting.modifier(len))
			if not ok then say("addModifier failed, the cover slider starts on 18m: " .. tostring(err)) end
		end,
	}
end
