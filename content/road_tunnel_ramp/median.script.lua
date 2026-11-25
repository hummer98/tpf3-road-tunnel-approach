-- Median tunnel approach: the full-width ramp's body for a two-lane centre,
-- and a one-way side street either side, handed over (median_geometry.lua
-- has the layout). This script only reads the menu and the engine.

local median = require "road_tunnel_ramp::/road_tunnel_ramp/median_geometry.lua"

function data()
	return {
		updateFn = function(cap, p)
			local spec = median.spec(cap, p)
			-- The same tunnel fallback as ramp.script.lua (the alternate
			-- vanilla path), done here so the modules stay engine-free.
			if api and api.res and api.res.tunnelTypeRep then
				local rep = api.res.tunnelTypeRep
				if rep.find(spec.tunnelRef) == -1 then
					local alt = spec.tunnelRef:gsub("/tunnel/tunnel_", "/tunnel/tunnel/tunnel_")
					assert(rep.find(alt) ~= -1, "road_tunnel_ramp: tunnel resource not found: " .. spec.tunnelRef)
					spec.tunnelRef = alt
				end
			end
			return (median.build(spec, p))
		end,
	}
end
