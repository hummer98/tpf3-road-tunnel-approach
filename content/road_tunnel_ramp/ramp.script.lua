-- Road tunnel approach: a street ramp descending from the surface to an
-- underground car tunnel. The geometry (eased vertical profile, portal
-- position by bisection, retaining walls, coping slabs, portal top cover,
-- terrain alignment) follows the Enivia railway ramp, rescaled for roads.
-- It lives in ramp_geometry.lua, so the median approach can build the same
-- body as its centre; this script only reads the menu and the engine.

local geometry = require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua"

function data()
	return {
		updateFn = function(cap, p)
			local spec = geometry.spec(cap, p)
			-- Fall back to the alternate vanilla tunnel path layout
			-- (seen on the rail side as /tunnel/tunnel/tunnel_a.tunnel).
			-- Done here, not in the module, which stays free of engine
			-- calls so it can run offline.
			if api and api.res and api.res.tunnelTypeRep then
				local rep = api.res.tunnelTypeRep
				if rep.find(spec.tunnelRef) == -1 then
					local alt = spec.tunnelRef:gsub("/tunnel/tunnel_", "/tunnel/tunnel/tunnel_")
					assert(rep.find(alt) ~= -1, "road_tunnel_ramp: tunnel resource not found: " .. spec.tunnelRef)
					spec.tunnelRef = alt
				end
			end
			return (geometry.build(spec))
		end,
	}
end
