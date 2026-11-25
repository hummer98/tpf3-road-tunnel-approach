-- Road tunnel approach: a street ramp descending from the surface to an
-- underground car tunnel. The geometry (eased vertical profile, portal
-- position by bisection, retaining walls, coping slabs, portal top cover,
-- terrain alignment) follows the Enivia railway ramp, rescaled for roads.

local function value(p, key, default, lo, hi)
	local n = tonumber(p[key])
	if not n or n ~= n then n = default end
	return math.max(lo, math.min(hi, n))
end

local function newResult()
	-- One subconstruction holds every piece that isn't an edge: walls,
	-- coping slabs, portal cover, and the terrain alignment faces that
	-- carve the open trench. A non-empty models list is what lets the
	-- engine accept this subcon (Phase 1 crashed on "Empty Subconstruction"
	-- here; see commit aa749c6).
	return {
		cost = 0,
		bulldozeCost = 0,
		maintenanceCost = 0,
		edgeLists = {},
		edgeObjects = {},
		subconstructions = {
			{ tag = 1, models = {}, groundFaces = {}, terrainAlignmentLists = {}, colliders = {} },
		},
	}
end

function data()
	return {
		updateFn = function(cap, p)
			local r = newResult()
			local sub = r.subconstructions[1]
			-- rtr_street picks one of the street templates captured by
			-- con.lua; each entry carries both the resource reference and
			-- the measured width so wall / coping / terrain spacing stays
			-- in step with the template without probing the engine.
			local streetIdx = math.floor(value(p, "rtr_street", 3, 1, #cap.streets) + 0.5)
			local street = cap.streets[streetIdx] or cap.streets[3]
			local streetRef = street.ref
			local tunnelRef = cap.tunnelRef
			-- Fall back to the alternate vanilla tunnel path layout
			-- (seen on the rail side as /tunnel/tunnel/tunnel_a.tunnel).
			if api and api.res and api.res.tunnelTypeRep then
				local rep = api.res.tunnelTypeRep
				if rep.find(tunnelRef) == -1 then
					local alt = tunnelRef:gsub("/tunnel/tunnel_", "/tunnel/tunnel/tunnel_")
					assert(rep.find(alt) ~= -1, "road_tunnel_ramp: tunnel resource not found: " .. tunnelRef)
					tunnelRef = alt
				end
			end

			-- The UI stops at 100m, but ramps placed before that kept up to
			-- 400m; clamping them would shorten them on rebuild.
			local L = value(p, "rtr_length", 100, 40, 400)
			local D = value(p, "rtr_depth", 16, 10, 25)
			local curvatureIdx = math.floor(value(p, "rtr_curvature", 3, 1, 5) + 0.5)
			local count = math.floor(value(p, "rtr_count", 1, 1, 3) + 0.5)
			-- 1 = traffic descends into the tunnel, 2 = climbs out of it.
			local direction = math.floor(value(p, "rtr_direction", 1, 1, 2) + 0.5)
			-- 1 = right-hand traffic (game default), 2 = left-hand.
			local side = math.floor(value(p, "rtr_side", 1, 1, 2) + 0.5)
			local approach = value(p, "rtr_approach", 20, 2, 50)
			local runout = 30
			local Z = 0
			local tunnelHeight = cap.tunnelHeight or 10.55
			local halfWidth = street.width * 0.5
			-- Parallel streets: centre-to-centre pitch is the template
			-- width plus a 2m gap; ys holds each street's lateral offset,
			-- centred on y = 0 (so count=1 stays at y=0 like before).
			local gap = 2
			local pitch = street.width + gap
			local ys = {}
			for i = 1, count do ys[i] = (i - (count + 1) * 0.5) * pitch end
			local halfSpread = math.abs(ys[count])  -- 0 when count == 1

			-- The pit must cover the full tunnel clearance plus a thin layer.
			D = math.max(D, tunnelHeight + 2)

			-- Vertical profile f(t) ∈ [0,1], with f(0)=0 and f(1)=1. Five
			-- shapes blend the straight line, cubic smoothstep, and quintic
			-- smootherstep in pairs so idx 3 reproduces the legacy cubic
			-- easing exactly (end slope 0, mid slope 1.5*D/L).
			--   idx 1 Shallow:    0.5 * t + 0.5 * cubic   (end 0.5, mid 1.25)
			--   idx 2 Gentle:     0.25 * t + 0.75 * cubic (end 0.25, mid 1.375)
			--   idx 3 Normal:     cubic                   (end 0, mid 1.5)
			--   idx 4 Steep:      0.5 * cubic + 0.5 * quintic (end 0, mid 1.6875)
			--   idx 5 Very steep: quintic                 (end 0, mid 1.875)
			local blend = { { 0.5, 0.5, 0 }, { 0.25, 0.75, 0 }, { 0, 1, 0 }, { 0, 0.5, 0.5 }, { 0, 0, 1 } }
			local b = blend[curvatureIdx] or blend[3]
			local function profile(t)
				local cubic = 3 * t * t - 2 * t * t * t
				local dcubic = 6 * t - 6 * t * t
				local quintic = t * t * t * (10 + t * (-15 + 6 * t))
				local dquintic = 30 * t * t * (1 + t * (-2 + t))
				local f  = b[1] * t    + b[2] * cubic  + b[3] * quintic
				local df = b[1] * 1    + b[2] * dcubic + b[3] * dquintic
				return -D * f, -D * df / L
			end

			-- Portal t: the first point where the earth cover above the roof
			-- exceeds one tunnel height (same heuristic the rail mod uses).
			local roof = math.max(7, tunnelHeight + 1)
			local cover = math.min(D * 0.85, roof)
			local lo, hi = 0, 1
			for _ = 1, 40 do
				local m = (lo + hi) * 0.5
				local z = profile(m)
				if -z < cover then lo = m else hi = m end
			end
			local portal = (lo + hi) * 0.5
			local portalX = L * portal

			local function node(x, y, z, dx, dy, dz)
				return { { x, y, Z + z }, { dx, dy, dz } }
			end

			-- One-way templates carry traffic in edge direction, so a
			-- reversed street is emitted b→a with negated tangents (and
			-- its snap/free node indices swapped to stay on the same end).
			local reverse = false
			local function edge(a, b, isTunnel, snapA, snapB, freeA, freeB)
				if reverse then
					a, b = { b[1], { -b[2][1], -b[2][2], -b[2][3] } },
					       { a[1], { -a[2][1], -a[2][2], -a[2][3] } }
					snapA, snapB = snapB, snapA
					freeA, freeB = freeB, freeA
				end
				local snaps, frees = {}, {}
				if snapA then snaps[#snaps + 1] = 0 end
				if snapB then snaps[#snaps + 1] = 1 end
				-- Mark a node 'free' when it is not snapped and would
				-- otherwise be a bare dangling endpoint: the engine then
				-- treats it as an explicitly open end of construction
				-- rather than a floating node.
				if freeA then frees[#frees + 1] = 0 end
				if freeB then frees[#frees + 1] = 1 end
				-- Terrain is shaped centrally via terrainAlignmentLists on
				-- the subconstruction, so no per-edge alignment is wanted
				-- either side of the portal.
				local e = {
					type = "STREET",
					params = { type = streetRef },
					edges = { a, b },
					snapNodes = snaps,
					freeNodes = frees,
					alignTerrain = false,
				}
				if isTunnel then
					e.edgeType = "TUNNEL"
					e.edgeTypeName = tunnelRef
				end
				r.edgeLists[#r.edgeLists + 1] = e
			end

			-- Ramp proper: a mix of surface and tunnel segments, split at the
			-- portal so that curvature stays smooth at the transition.
			local segments = math.max(8, math.ceil(L / 40))
			local ts = { 0, portal, 1 }
			-- Skip regular splits that land within 2m of the portal: they
			-- would leave a sliver edge (down to ~0.07m on 40m ramps), which
			-- TF placement handles poorly.
			for i = 1, segments - 1 do
				if math.abs(i / segments - portal) * L >= 2 then ts[#ts + 1] = i / segments end
			end
			table.sort(ts)
			local uniq = {}
			for _, t in ipairs(ts) do
				if #uniq == 0 or t - uniq[#uniq] > 1e-7 then
					uniq[#uniq + 1] = t
				end
			end

			-- Travel direction (+1 = toward +X) of each street. One-way
			-- carriageways are laid out by traffic side: facing +X, the +X
			-- group sits on the driving side (right-hand: -Y = ys[1..],
			-- left-hand: +Y), the -X group opposite, so Double is always a
			-- proper divided road and Triple is 2+1. The direction option
			-- then only picks which carriageway snaps to the external road.
			-- A single one-way street simply follows the direction.
			local want = (direction == 1) and 1 or -1
			local flows, snapIdx = {}, 1
			if street.oneWay and count > 1 then
				local plus = math.ceil(count / 2)
				for k = 1, count do
					-- (not `side == 1 and x or y`: a false x would fall through)
					local onPlus
					if side == 1 then onPlus = k <= plus else onPlus = k > count - plus end
					flows[k] = onPlus and 1 or -1
				end
				for k = 1, count do
					if flows[k] == want then snapIdx = k; break end
				end
			else
				for k = 1, count do flows[k] = street.oneWay and want or 1 end
			end

			-- Build each parallel street. Only ys[snapIdx] exposes a
			-- snap node at its approach start so the external edge-end snap
			-- binds to exactly one lane; the others stay free so the player
			-- can hand-connect them after placement.
			local segN = math.max(1, math.ceil(runout / 40))
			for idx, yOffset in ipairs(ys) do
				reverse = flows[idx] == -1
				local snapApproach = (idx == snapIdx)
				-- Flat approach segment (external connection at x = -approach).
				-- ys[snapIdx] snaps to the external road; the others expose their
				-- approach start as a free node so the engine treats the
				-- dangling endpoint as an open end rather than a floating
				-- node (unsnapped + non-free can trigger placement refusal).
				edge(
					node(-approach, yOffset, 0, approach, 0, 0),
					node(0, yOffset, 0, approach, 0, 0),
					false, snapApproach, false,
					not snapApproach, false
				)
				for i = 1, #uniq - 1 do
					local ta, tb = uniq[i], uniq[i + 1]
					local za, ga = profile(ta)
					local zb, gb = profile(tb)
					local dx = L * (tb - ta)
					local isTunnel = (ta + tb) * 0.5 >= portal
					edge(
						node(L * ta, yOffset, za, dx, 0, ga * dx),
						node(L * tb, yOffset, zb, dx, 0, gb * dx),
						isTunnel, false, false
					)
				end
				-- Underground runout, so the player's own tunnel can snap to the end.
				for i = 0, segN - 1 do
					local a, b = L + runout * i / segN, L + runout * (i + 1) / segN
					edge(
						node(a, yOffset, -D, b - a, 0, 0),
						node(b, yOffset, -D, b - a, 0, 0),
						true, false, i == segN - 1
					)
				end
			end

			-- Wall geometry: outer = wall centreline offset from the group
			-- centre. halfSpread is the offset of the farthest street (0
			-- for a single street); halfWidth+1 keeps the ~0.6m-thick
			-- wall mesh just outside the outermost sidewalk edge.
			local outer = halfSpread + halfWidth + 1.0
			local wallSegLen = 4
			local wallSegments = math.max(1, math.ceil(portalX / wallSegLen))
			local wallModel = "road_tunnel_ramp::/road_tunnel_ramp/walls/concrete.mdl"

			-- Walls along both sides of the surface trench.
			-- transf columns: local x along the segment, local y perpendicular
			-- (scaled 2.667 for ~1.2m wall thickness), local z up (scaled by
			-- height = 0.3 - bottom, so top sits 30cm above z=0).
			for _, wallSide in ipairs({ -1, 1 }) do
				for i = 0, wallSegments - 1 do
					local xa = portalX * i / wallSegments
					local xb = portalX * (i + 1) / wallSegments
					local a = node(xa, wallSide * outer, 0, 1, 0, 0)[1]
					local b = node(xb, wallSide * outer, 0, 1, 0, 0)[1]
					local dx, dy = b[1] - a[1], b[2] - a[2]
					local len = math.sqrt(dx * dx + dy * dy)
					local za = profile(xa / L)
					local zb = profile(xb / L)
					local bottom = math.min(za, zb) - 1.5
					local height = 0.3 - bottom
					sub.models[#sub.models + 1] = {
						id = wallModel,
						transf = {
							dx, dy, 0, 0,
							-2.667 * dy / len, 2.667 * dx / len, 0, 0,
							0, 0, height, 0,
							a[1], a[2], Z + bottom, 1,
						},
						tag = string.format("wall_%d_%d", wallSide, i),
					}
				end
			end

			-- Concrete coping on top of the wall, hiding the seam where the
			-- descending terrain meets the wall face.
			local function slab(a, b, width, bottom, thickness, tag)
				local dx, dy = b[1] - a[1], b[2] - a[2]
				local len = math.sqrt(dx * dx + dy * dy)
				sub.models[#sub.models + 1] = {
					id = wallModel,
					transf = {
						dx, dy, 0, 0,
						-dy / len * width / 0.45, dx / len * width / 0.45, 0, 0,
						0, 0, thickness, 0,
						a[1], a[2], Z + bottom, 1,
					},
					tag = tag,
				}
			end
			for _, sign in ipairs({ -1, 1 }) do
				local inside = outer - 0.65
				local outside = outer + 2.4
				local mid = sign * (inside + outside) * 0.5
				for i = 0, wallSegments - 1 do
					local xa = portalX * i / wallSegments
					local xb = portalX * (i + 1) / wallSegments
					slab(
						node(xa, mid, 0, 1, 0, 0)[1],
						node(xb, mid, 0, 1, 0, 0)[1],
						outside - inside, 0.28, 0.25,
						string.format("coping_%d_%d", sign, i)
					)
				end
			end

			-- Portal top cover: one rigid slab across the portal tangent so
			-- the heightmap below the cover can be driven down (LESS face
			-- below) and the surface seam at the portal is hidden.
			local roofHalf = outer + 4
			slab(
				node(portalX - 6, 0, -D, 1, 0, 0)[1],
				node(portalX + 30, 0, -D, 1, 0, 0)[1],
				roofHalf * 2, -0.3, 0.8, "portal_top_cover"
			)

			-- Terrain alignment: floor (EQUAL) carves the trench bottom
			-- below the ramp; shoulder (EQUAL at z=0) keeps ground level
			-- outside the walls; portal cover (LESS) lowers the heightmap
			-- under the big top slab so dirt doesn't poke through.
			local floorOuter = outer + 0.4
			local floorFaces = {}
			for i = 0, wallSegments - 1 do
				local xa = portalX * i / wallSegments
				local xb = portalX * (i + 1) / wallSegments
				local za = profile(xa / L)
				local zb = profile(xb / L)
				floorFaces[#floorFaces + 1] = {
					{ xa, -floorOuter, Z + za - 0.25 },
					{ xb, -floorOuter, Z + zb - 0.25 },
					{ xb,  floorOuter, Z + zb - 0.25 },
					{ xa,  floorOuter, Z + za - 0.25 },
				}
			end
			local shoulders = {}
			for _, sign in ipairs({ -1, 1 }) do
				local inner = outer + 0.65
				local outside = outer + 3
				for i = 0, wallSegments - 1 do
					local xa = portalX * i / wallSegments
					local xb = portalX * (i + 1) / wallSegments
					local face = {
						{ xa, sign * inner,   Z },
						{ xb, sign * inner,   Z },
						{ xb, sign * outside, Z },
						{ xa, sign * outside, Z },
					}
					if sign == -1 then face = { face[4], face[3], face[2], face[1] } end
					shoulders[#shoulders + 1] = face
				end
			end
			local coverFace = {
				{ portalX - 6.25, -roofHalf - 0.25, Z - 0.55 },
				{ portalX + 30.25, -roofHalf - 0.25, Z - 0.55 },
				{ portalX + 30.25,  roofHalf + 0.25, Z - 0.55 },
				{ portalX - 6.25,  roofHalf + 0.25, Z - 0.55 },
			}
			sub.terrainAlignmentLists = {
				{ type = "EQUAL", faces = floorFaces,   slopeLow = 100, slopeHigh = 100, optional = true },
				{ type = "EQUAL", faces = shoulders,    slopeLow = 1,   slopeHigh = 100, optional = true },
				{ type = "LESS",  faces = { coverFace }, slopeLow = 100, slopeHigh = 100, optional = true },
			}

			r.cost = math.floor((L + approach + runout) * 300 * count + D * 2000)
			r.bulldozeCost = math.floor(r.cost * 0.1)
			r.maintenanceCost = math.floor(r.cost * 0.001)

			-- External connection point at the snapping street's approach
			-- start. With count > 1, only ys[snapIdx] exposes a snap node, so
			-- the snap point is placed on that lane.
			--
			-- TPF3 interprets a snap point's local +Y axis (not +X as the
			-- landmark examples might suggest) as the direction of the edge
			-- it should snap to. Our approach edge runs along world +X, so
			-- we rotate the frame CW 90° about Z to point local +Y along
			-- +X. Writing a unit matrix here places the ramp sideways
			-- (90° right-rotated) against the target road.
			r.snapPoint = {
				transf = {
					0, -1, 0, 0,
					1,  0, 0, 0,
					0,  0, 1, 0,
					-approach, ys[snapIdx], Z, 1,
				},
				transportModes = { "CAR", "BUS", "TRUCK" },
				snapToBaseEdgeTypes = { "STREET" },
				allowSnapToBaseEdgeEnds = true,
				placeAtTerrainHeight = true,
				allowSnapToMesh = false,
			}

			return r
		end,
	}
end
