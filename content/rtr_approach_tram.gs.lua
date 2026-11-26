-- Road Tunnel Approach: registers the game script that takes the tram
-- track off the flat approach's other side after a build with Tram track
-- Right or Left (rtr_approach_tram.script.lua, road_tunnel_ramp/
-- approach_tram.lua). Its resource name "road_tunnel_ramp::/
-- rtr_approach_tram.gs" names the script's saved state (empty but while a
-- placed ramp waits for its approach to be laid again): never rename or
-- move this file [source: the same note in Two-way Highway's
-- twh_uturn.gs.lua and the median branch's fork script, 4f71da0].
function data()
	return {
		updateScript = { fileName = "rtr_approach_tram.script@update" },
		handleEventScript = { fileName = "rtr_approach_tram.script@handleEvent" },
	}
end
