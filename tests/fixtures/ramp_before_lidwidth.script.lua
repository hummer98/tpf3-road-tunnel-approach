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
			-- Wall geometry: outer = wall centreline offset from the group
			-- centre. halfSpread is the offset of the farthest street (0
			-- for a single street); halfWidth+1 keeps the ~0.6m-thick
			-- wall mesh just outside the outermost sidewalk edge.
			local outer = halfSpread + halfWidth + 1.0

			-- The pit must cover the full tunnel clearance plus a thin layer.
			D = math.max(D, tunnelHeight + 2)

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

			-- Ground plane. The body is placed at the height of the road end
			-- it snaps to (Z), and everything used to be level with it, so on
			-- sloped ground the walls, coping and lid floated on the downhill
			-- side. The player states the slope instead (the build cursor
			-- shows the measured one): along = % rise toward the tunnel,
			-- across = % rise to the right when facing the tunnel (local +X
			-- is the ramp direction, local +Y its left side). The plane
			-- passes through the snap point, the one place where the ground
			-- is known to be at Z. 0/0 reproduces the old level layout.
			local gx = value(p, "rtr_ground_along", 0, -20, 20) / 100
			local gy = -value(p, "rtr_ground_across", 0, -20, 20) / 100
			local ySnap = ys[snapIdx]
			local function ground(x, y)
				return gx * (x + approach) + gy * (y - ySnap)
			end
			local sloped = gx ~= 0 or gy ~= 0

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
			-- The cover is measured from the ground plane on the lower edge
			-- of the portal cover slab (outer + 4.25 out), so a downhill or
			-- cross slope pushes the portal on until the whole slab has it.
			local roof = math.max(7, tunnelHeight + 1)
			local cover = math.min(D * 0.85, roof)
			local lidEdge = (outer + 4) + 0.25  -- = roofHalf + 0.25 below
			local function coverAt(t)
				local z = profile(t)
				local x = L * t
				return math.min(ground(x, -lidEdge), ground(x, lidEdge)) - z
			end
			local lo, hi = 0, 1
			if gx < 0 then
				-- Downhill the cover can peak and shrink again, so bisection
				-- alone could land on a later crossing: bracket the first one.
				-- If it never gets deep enough the portal sits at the foot.
				local steps, found = 200, false
				for k = 1, steps do
					if coverAt(k / steps) >= cover then
						lo, hi, found = (k - 1) / steps, k / steps, true
						break
					end
				end
				if not found then lo, hi = 1, 1 end
			end
			for _ = 1, 40 do
				local m = (lo + hi) * 0.5
				if coverAt(m) < cover then lo = m else hi = m end
			end
			-- Steep uphill ground can give the cover at once; keep 8m of open
			-- trench so the walls and the lid (from portalX - 6) stay on the
			-- ramp side of x = 0.
			local portal = math.max((lo + hi) * 0.5, 8 / L)
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

			local wallSegLen = 4
			local wallSegments = math.max(1, math.ceil(portalX / wallSegLen))
			local wallModel = "road_tunnel_ramp::/road_tunnel_ramp/walls/concrete.mdl"

			-- Height the walls, coping and shoulders follow: the ground plane,
			-- but never below the road. Near the mouth on a downhill slope
			-- the road is still above the ground, and walls cut to the plane
			-- there would sit below the trench floor fill.
			local function roadZ(x)
				return (profile(math.max(0, math.min(1, x / L))))
			end
			-- The portal cover lies on the ground plane, but must never sink
			-- into the tunnel: on downhill ground steeper than the ramp can
			-- get under, the plane runs through it. Then the plane is lifted
			-- as a whole (lift) until the ground under the cover is 0.6m over
			-- the tunnel roof (just under the cover at the portal, so level
			-- ground, where the cover is met exactly, never trips it),
			-- checked where the cover spans the tunnel (from the portal on,
			-- including the faces' 0.25m margin). The walls, coping and banks
			-- ramp up to it from the trench start, an embankment instead of
			-- a lid floating over the walls.
			local roofHalf = outer + 4
			local lidA, lidB = portalX - 6, portalX + 30
			local lidClear = math.min(cover, tunnelHeight + 0.6) - 0.01
			local lift = 0
			for k = 0, 10 do
				local x = portalX + (lidB + 0.25 - portalX) * k / 10
				for _, y in ipairs({ -roofHalf - 0.25, roofHalf + 0.25 }) do
					lift = math.max(lift, roadZ(x) + lidClear - ground(x, y))
				end
			end
			-- Lifted as a whole: the lid and the faces under it stay one flat
			-- slab parallel to the ground.
			local function lidZ(x, y)
				return ground(x, y) + lift
			end
			-- 0 at the trench start (no step to the approach), full from
			-- the front of the cover's margin on.
			local function lifted(x, y)
				return ground(x, y) + lift * math.max(0, math.min(1, x / (portalX - 6.25)))
			end
			local function surface(x, y)
				return math.max(lifted(x, y), roadZ(x))
			end

			-- Walls along both sides of the surface trench.
			-- transf columns: local x along the segment (its z component
			-- shears the segment so the top follows the surface), local y
			-- perpendicular (scaled 2.667 for ~1.2m wall thickness), local z
			-- up (scaled by height, so the top sits 30cm above the surface).
			-- On a stated slope the approach street gets walls too: the
			-- plane meets the road at the snap point but not at x = 0, so
			-- without them the trench walls would start with a bare end face
			-- over a cut (uphill) or a fill (downhill).
			local function walls(x0, x1, segments, prefix)
				for _, wallSide in ipairs({ -1, 1 }) do
					for i = 0, segments - 1 do
						local xa = x0 + (x1 - x0) * i / segments
						local xb = x0 + (x1 - x0) * (i + 1) / segments
						local a = node(xa, wallSide * outer, 0, 1, 0, 0)[1]
						local b = node(xb, wallSide * outer, 0, 1, 0, 0)[1]
						local dx, dy = b[1] - a[1], b[2] - a[2]
						local len = math.sqrt(dx * dx + dy * dy)
						local za = roadZ(xa)
						local zb = roadZ(xb)
						local topA = surface(xa, wallSide * outer) + 0.3
						local rise = surface(xb, wallSide * outer) + 0.3 - topA
						-- The shear also tilts the base; start it lower when the
						-- top rises so both ends stay 1.5m under the road.
						local bottom = math.min(za, zb) - 1.5 - math.max(0, rise)
						local height = topA - bottom
						sub.models[#sub.models + 1] = {
							id = wallModel,
							transf = {
								dx, dy, rise, 0,
								-2.667 * dy / len, 2.667 * dx / len, 0, 0,
								0, 0, height, 0,
								a[1], a[2], Z + bottom, 1,
							},
							tag = string.format("%s%d_%d", prefix, wallSide, i),
						}
					end
				end
			end
			local approachSegments = math.max(1, math.ceil(approach / wallSegLen))
			walls(0, portalX, wallSegments, "wall_")
			if sloped then walls(-approach, 0, approachSegments, "approach_wall_") end

			-- Concrete coping on top of the wall, hiding the seam where the
			-- descending terrain meets the wall face. rise (z over the
			-- segment) and tilt (z per metre toward the segment's left)
			-- shear the slab onto a sloped surface.
			local function slab(a, b, width, bottom, thickness, tag, rise, tilt)
				local dx, dy = b[1] - a[1], b[2] - a[2]
				local len = math.sqrt(dx * dx + dy * dy)
				sub.models[#sub.models + 1] = {
					id = wallModel,
					transf = {
						dx, dy, rise or 0, 0,
						-dy / len * width / 0.45, dx / len * width / 0.45, (tilt or 0) * width / 0.45, 0,
						0, 0, thickness, 0,
						a[1], a[2], Z + bottom, 1,
					},
					tag = tag,
				}
			end
			local function copings(x0, x1, segments, prefix)
				for _, sign in ipairs({ -1, 1 }) do
					local inside = outer - 0.65
					local outside = outer + 2.4
					local mid = sign * (inside + outside) * 0.5
					local width = outside - inside
					for i = 0, segments - 1 do
						local xa = x0 + (x1 - x0) * i / segments
						local xb = x0 + (x1 - x0) * (i + 1) / segments
						local sa = surface(xa, mid)
						local xm = (xa + xb) * 0.5
						slab(
							node(xa, mid, 0, 1, 0, 0)[1],
							node(xb, mid, 0, 1, 0, 0)[1],
							width, sa + 0.28, 0.25,
							string.format("%s%d_%d", prefix, sign, i),
							surface(xb, mid) - sa,
							(surface(xm, mid + width * 0.5) - surface(xm, mid - width * 0.5)) / width
						)
					end
				end
			end
			copings(0, portalX, wallSegments, "coping_")
			if sloped then copings(-approach, 0, approachSegments, "approach_coping_") end

			-- Portal top cover: one rigid slab across the portal tangent so
			-- the heightmap below the cover can be driven down (LESS face
			-- below) and the surface seam at the portal is hidden. It lies
			-- on the (lifted, see lift above) ground plane like the coping.
			slab(
				node(lidA, 0, -D, 1, 0, 0)[1],
				node(lidB, 0, -D, 1, 0, 0)[1],
				roofHalf * 2, lidZ(lidA, 0) - 0.3, 0.8, "portal_top_cover",
				lidZ(lidB, 0) - lidZ(lidA, 0), gy
			)

			-- Terrain alignment: floor (EQUAL) carves the trench bottom
			-- below the ramp; shoulders (EQUAL on the surface) keep the
			-- ground at the coping outside the walls and beside / past the
			-- lid; portal cover (LESS) lowers the heightmap under the big
			-- top slab so dirt doesn't poke through, and lid support
			-- (GREATER, same height) fills it up where the ground is lower
			-- so the slab never floats.
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
			-- Faces are counter-clockwise seen from above. A face on the
			-- surface is level in old saves' 0/0 case and tilted otherwise.
			local function face(height, x0, x1, y0, y1, dz)
				return {
					{ x0, y0, Z + height(x0, y0) + dz },
					{ x1, y0, Z + height(x1, y0) + dz },
					{ x1, y1, Z + height(x1, y1) + dz },
					{ x0, y1, Z + height(x0, y1) + dz },
				}
			end
			-- Beside and past the lid the shoulders rise with it.
			local function lidSurface(x, y)
				return math.max(surface(x, y), lidZ(x, y))
			end
			-- Shoulders run from the coping to well past it (the old 2.35m
			-- strip gave a 1:1 bank right at the wall), along the trench and
			-- on beside and beyond the lid, which used to have nothing
			-- holding the ground up to it.
			local inner = outer + 0.65
			local outside = outer + 7
			-- (written out, not lidA - 0.25: keeps the 0/0 faces bit-identical)
			local coverA, coverB = portalX - 6.25, portalX + 30.25
			local shoulders = {}
			local trenchSegments = math.max(1, math.ceil(coverA / wallSegLen))
			for _, sign in ipairs({ -1, 1 }) do
				local function strip(height, x0, x1, y0, y1)
					if sign == 1 then
						shoulders[#shoulders + 1] = face(height, x0, x1, y0, y1, 0)
					else
						shoulders[#shoulders + 1] = face(height, x0, x1, -y1, -y0, 0)
					end
				end
				-- Along the approach walls (stated slope only), so the
				-- banks run on to the snap point.
				if sloped then
					for i = 0, approachSegments - 1 do
						strip(surface, -approach + approach * i / approachSegments,
							-approach + approach * (i + 1) / approachSegments, inner, outside)
					end
				end
				for i = 0, trenchSegments - 1 do
					strip(surface, coverA * i / trenchSegments, coverA * (i + 1) / trenchSegments, inner, outside)
				end
				strip(lidSurface, coverA, coverB, lidEdge, outside)
			end
			shoulders[#shoulders + 1] = face(lidSurface, coverB, coverB + (outside - lidEdge), -outside, outside, 0)
			local coverFace = face(lidZ, coverA, coverB, -lidEdge, lidEdge, -0.55)
			-- Lid support leaves out the open trench mouth under the lid's
			-- front 6m, which the floor faces cut down.
			local lidSupport = {
				face(lidZ, portalX, coverB, -lidEdge, lidEdge, -0.55),
				face(lidZ, coverA, portalX, inner, lidEdge, -0.55),
				face(lidZ, coverA, portalX, -lidEdge, -inner, -0.55),
			}
			-- Gentle banks: slopeLow is the fill side (embankment from below),
			-- slopeHigh the cut side, as for the street types' embankments.
			sub.terrainAlignmentLists = {
				{ type = "EQUAL",   faces = floorFaces,   slopeLow = 100,  slopeHigh = 100, optional = true },
				{ type = "EQUAL",   faces = shoulders,    slopeLow = 0.45, slopeHigh = 1,   optional = true },
				{ type = "LESS",    faces = { coverFace }, slopeLow = 100, slopeHigh = 100, optional = true },
				{ type = "GREATER", faces = lidSupport,   slopeLow = 100,  slopeHigh = 100, optional = true },
			}
			-- The approach street stays level at Z (it has to meet the road
			-- it snaps to), so on a stated slope its ground between the
			-- approach walls is cut or filled to the trench floor level.
			if sloped then
				table.insert(sub.terrainAlignmentLists, {
					type = "EQUAL",
					faces = { { { -approach, -floorOuter, Z - 0.25 }, { 0, -floorOuter, Z - 0.25 },
					            { 0, floorOuter, Z - 0.25 }, { -approach, floorOuter, Z - 0.25 } } },
					slopeLow = 0.45, slopeHigh = 1, optional = true,
				})
			end

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
