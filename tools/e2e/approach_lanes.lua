-- e2e (read only, plain tf3ctl eval): the lanes of street edges, to see
-- which carry the tram track after a build with Tram track Right / Left.
-- Self-contained (not the mod's approach_tram.lua), so it reads the engine
-- the same whether or not the mod's code works.
--
--   sed -e 's/__EDGES__/12345,12346/' -e 's/__CONSTRUCTION__/0/' \
--     tools/e2e/approach_lanes.lua > "$SCRATCH/lanes.lua"
--   python3 .../tf3ctl.py --owner mod-keeper eval --file "$SCRATCH/lanes.lua"
--
-- __EDGES__: edge ids. __CONSTRUCTION__: the ramp's construction id, or 0;
-- with one, each node's place in its frame (x = 0 the descent's start, x <
-- 0 the approach) and whether the edge runs into the tunnel. Per edge:
-- template, nodes, and per lane (1-based, left to right from node0 to
-- node1) forward, offset, width and the transport modes by name.
local EDGES = { __EDGES__ }
local CONSTRUCTION = __CONSTRUCTION__

local MODES = { "PERSON", "CARGO", "CAR", "BUS", "TRUCK", "TRAM", "ELECTRIC_TRAM", "TRAIN", "ELECTRIC_TRAIN",
	"AIRCRAFT", "SHIP", "SMALL_AIRCRAFT", "SMALL_SHIP", "HELICOPTER", "TRAM_TRACK", "ELECTRIC_TRAM_TRACK" }
local CT = api.type.ComponentType
local TM = api.type.enum.TransportMode

local function get(e, ct)
	local ok, v = pcall(function() return api.engine.getComponent(e, ct) end)
	if ok then return v end
	return nil
end

local m
if CONSTRUCTION and CONSTRUCTION > 0 then
	local c = get(CONSTRUCTION, CT.CONSTRUCTION)
	-- (a Mat4f reads 0-based or 1-based: the one where all 16 are numbers)
	for _, base in ipairs(c and { 0, 1 } or {}) do
		local t, all = {}, true
		pcall(function() for i = 1, 16 do t[i] = c.transf[i - 1 + base] end end)
		for i = 1, 16 do if type(t[i]) ~= "number" then all = false end end
		if all then m = t; break end
	end
end
local function toLocal(p)
	if not m then return nil end
	local d = { p.x - m[13], p.y - m[14], p.z - m[15] }
	local out = {}
	for k, base in ipairs({ 0, 4, 8 }) do
		local ax, ay, az = m[base + 1], m[base + 2], m[base + 3]
		local n = ax * ax + ay * ay + az * az
		out[k] = n > 0 and math.floor((d[1] * ax + d[2] * ay + d[3] * az) / n * 100 + 0.5) / 100 or 0
	end
	return { x = out[1], y = out[2], z = out[3] }
end

local out = { construction = CONSTRUCTION, frameRead = m ~= nil, edges = {} }
for _, e in ipairs(EDGES) do
	local r = { edge = e }
	local be = get(e, CT.BASE_EDGE)
	if not be then
		r.why = "no BASE_EDGE (gone, or not an edge)"
	else
		r.template = tostring(be.roadTemplate)
		r.node0, r.node1 = be.node0, be.node1
		for k, n in ipairs({ be.node0, be.node1 }) do
			local bn = get(n, CT.BASE_NODE)
			if bn then
				local p = { x = bn.position.x, y = bn.position.y, z = bn.position.z }
				r["node" .. (k - 1) .. "At"] = p
				r["node" .. (k - 1) .. "Local"] = toLocal(p)
			end
		end
		if r.node0Local and r.node1Local then r.runsIntoTunnel = r.node1Local.x > r.node0Local.x end
		r.streetComponent = get(e, CT.BASE_EDGE_STREET) ~= nil
		r.lanes, r.trackLanes = {}, {}
		local n = 0
		pcall(function() n = #be.laneConfigs end)
		for i = 1, n do
			local lc = be.laneConfigs[i]
			local modes = {}
			for _, name in ipairs(MODES) do
				local yes = false
				pcall(function() yes = lc.transportModes[TM[name]] == true end)
				if yes then modes[#modes + 1] = name end
			end
			local lane = { index = i, forward = lc.forward, offset = lc.offset, width = lc.width, modes = modes }
			r.lanes[i] = lane
			for _, name in ipairs(modes) do
				if name == "TRAM" or name == "ELECTRIC_TRAM" or name == "TRAM_TRACK" or name == "ELECTRIC_TRAM_TRACK" then r.trackLanes[#r.trackLanes + 1] = i; break end
			end
		end
	end
	out.edges[#out.edges + 1] = r
end
return out
