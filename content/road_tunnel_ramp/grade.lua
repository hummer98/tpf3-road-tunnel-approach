-- Pure helpers for the build-cursor grade line (no engine access, so the
-- tests can check them against the edges ramp.script.lua emits).
local M = {}

-- Peak slope of each curvature profile in units of D / L (the profile
-- blends in ramp_geometry.lua: Shallow .. Very steep).
M.peakSlope = { 1.25, 1.375, 1.5, 1.6875, 1.875 }

-- Same fallbacks and clamps as ramp_geometry.spec, so the line
-- matches what is actually built when a param is missing or odd.
local function value(p, key, default, lo, hi)
	local n = tonumber(p and p[key])
	if not n or n ~= n then n = default end
	return math.max(lo, math.min(hi, n))
end

-- Steepest grade (fraction, 0.24 = 24%) of the ramp built from params p.
function M.maxGrade(p, tunnelHeight)
	local L = value(p, "rtr_length", 100, 40, 400)
	local D = value(p, "rtr_depth", 16, 10, 25)
	D = math.max(D, (tunnelHeight or 10.55) + 2)
	local c = math.floor(value(p, "rtr_curvature", 3, 1, 5) + 0.5)
	return (M.peakSlope[c] or M.peakSlope[3]) * D / L
end

function M.formatLine(label, grade)
	return string.format("%s: %.1f%%", label, grade * 100)
end

-- Points (x along the ramp from its trench start, y to its left; the
-- construction's own frame) where the ground is sampled for the slope
-- line: the approach and the descent, the centre line and 10m each side.
-- The median approach places its centre as the full-width ramp places its
-- street (the same snap point and approach), so both sample alike.
function M.groundSamples(p)
	local L = value(p, "rtr_length", 100, 40, 400)
	local approach = value(p, "rtr_approach", 20, 2, 50)
	local pts = {}
	for i = 0, 8 do
		local x = -approach + (L + approach) * i / 8
		for _, y in ipairs({ -10, 0, 10 }) do pts[#pts + 1] = { x, y } end
	end
	return pts
end

-- Least-squares plane z = c + bx*x + by*y through the samples, returned
-- in the build menu's convention: along = % rise toward the tunnel (+x),
-- across = % rise to the right facing the tunnel (-y). nil when the
-- points don't span a plane.
function M.fitGround(pts, zs)
	local n, sx, sy, sxx, syy, sxy, sz, sxz, syz = 0, 0, 0, 0, 0, 0, 0, 0, 0
	for i, pt in ipairs(pts) do
		local x, y, z = pt[1], pt[2], zs[i]
		if type(z) ~= "number" or z ~= z then return nil end
		n = n + 1
		sx, sy, sz = sx + x, sy + y, sz + z
		sxx, syy, sxy = sxx + x * x, syy + y * y, sxy + x * y
		sxz, syz = sxz + x * z, syz + y * z
	end
	-- Cramer's rule on the normal equations [n sx sy; sx sxx sxy; sy sxy syy].
	local function det(a, b, c, d, e, f, g, h, k)
		return a * (e * k - f * h) - b * (d * k - f * g) + c * (d * h - e * g)
	end
	local d = det(n, sx, sy, sx, sxx, sxy, sy, sxy, syy)
	if math.abs(d) < 1e-9 then return nil end
	local bx = det(n, sz, sy, sx, sxz, sxy, sy, syz, syy) / d
	local by = det(n, sx, sz, sx, sxx, sxz, sy, sxy, syz) / d
	return bx * 100, -by * 100
end

local function signedPercent(v)
	-- No "-0.0%" for a level ground.
	if math.abs(v) < 0.05 then return "0.0%" end
	return string.format("%+.1f%%", v)
end

-- template holds {along} and {across}, e.g. "Ground: along {along}, ...".
function M.formatGroundLine(template, along, across)
	local a = signedPercent(along):gsub("%%", "%%%%")
	local c = signedPercent(across):gsub("%%", "%%%%")
	return (template:gsub("{along}", a):gsub("{across}", c))
end

-- This mod's constructions that take the ground slope options and so get
-- the cursor lines: the full-width ramp and the median approach (same
-- length / depth / curvature / approach params and clamps up to 100m).
local OWN = { "road_tunnel_ramp/ramp.con", "road_tunnel_ramp/median.con" }

-- True when any of the builder's construction files is one of them.
function M.isRamp(constructions)
	for i = 1, #(constructions or {}) do
		local f = constructions[i]
		if type(f) == "string" then
			for _, own in ipairs(OWN) do
				if f:find(own, 1, true) then return true end
			end
		end
	end
	return false
end

return M
