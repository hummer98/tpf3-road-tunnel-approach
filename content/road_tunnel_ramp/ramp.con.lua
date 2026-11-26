-- The Portal cover length slider's range and initial value come from
-- ramp_geometry.lua (LID_MIN, LID_MAX, LID_DEFAULT), so the menu and the
-- script that reads the value cannot drift apart [source: a mod.io mod's
-- .con.lua requires its own module the same way, grimes_unterfuehrung
-- unterfuehrung_simple.con.lua].
local geometry = require "road_tunnel_ramp::/road_tunnel_ramp/ramp_geometry.lua"

-- Evenly stepped slider options: labels "<n>m" and matching numbers.
local function metres(lo, hi, step)
	local values, numbers = {}, {}
	for n = lo, hi, step do
		values[#values + 1] = string.format("%dm", n)
		numbers[#numbers + 1] = n
	end
	return values, numbers
end

-- Ground grade options in whole percent, signed ("-3%", "0%", "+3%").
local function percents(lo, hi)
	local values, numbers = {}, {}
	for n = lo, hi do
		values[#values + 1] = n == 0 and "0%" or string.format("%+d%%", n)
		numbers[#numbers + 1] = n
	end
	return values, numbers
end

function data()
local lengthValues, lengthNumbers = metres(40, 100, 2)
local approachValues, approachNumbers = metres(2, 50, 2)
local depthValues, depthNumbers = metres(13, 25, 1)
local gradeValues, gradeNumbers = percents(-20, 20)
local coverValues, coverNumbers = metres(geometry.LID_MIN, geometry.LID_MAX, 1)
return {
	autoRemovable = false,
	availability = { yearFrom = 0, yearTo = 0 },
	buildMode = "SINGLE",
	description = {
		description = _("rtr_description"),
		icon = "ramp.tga",
		name = _("rtr_name"),
		previewIcon = "ramp_preview.tga",
	},
	heightAdjustable = true,
	heightModView = true,
	keepBuildingsAndFields = false,
	menuCategory = {
		categories = {
			{
				category = "street_constructions",
				order = 100,
			},
		},
	},
	params = {
		{
			-- The street templates are listed in width order so the slider
			-- feel reads as "wider = further right". Highway entries are
			-- one-way and labelled as such (see rtr_direction). The car-only
			-- entry (8) comes last, not in width order, so the seven older
			-- numbers, and the ramps built with them, keep their street.
			key = "rtr_street",
			name = _("rtr_street_name"),
			tooltip = _("rtr_street_tooltip"),
			uiType = "ComboBox",
			values = {
				_("rtr_street_highway_small"),
				_("rtr_street_country_small"),
				_("rtr_street_town_small"),
				_("rtr_street_highway_medium"),
				_("rtr_street_country_medium"),
				_("rtr_street_town_medium"),
				_("rtr_street_town_large"),
				_("rtr_street_car_only"),
			},
			numbers = { 1, 2, 3, 4, 5, 6, 7, 8 },
			defaultIndex = 3,
		},
		{
			key = "rtr_length",
			name = _("rtr_length_name"),
			tooltip = _("rtr_length_tooltip"),
			uiType = "Slider",
			-- 2m steps for fine fitting in towns; the length is used as
			-- chosen, so short + deep combos are steep (see tooltip and the
			-- grade line under the build cursor).
			values = lengthValues,
			numbers = lengthNumbers,
			defaultIndex = #lengthNumbers,  -- 100m, the gentlest
		},
		{
			-- Flat street before the descent: lets the walls start some
			-- distance from the junction the ramp snaps to.
			key = "rtr_approach",
			name = _("rtr_approach_name"),
			tooltip = _("rtr_approach_tooltip"),
			uiType = "Slider",
			values = approachValues,
			numbers = approachNumbers,
			defaultIndex = 10,  -- 20m, the length used before this option
		},
		{
			-- The script enforces a minimum of (tunnelHeight + 2) = 12.55m so
			-- there is always clearance above the tunnel ceiling; the UI
			-- starts at 13m so no option is silently raised.
			key = "rtr_depth",
			name = _("rtr_depth_name"),
			tooltip = _("rtr_depth_tooltip"),
			uiType = "Slider",
			values = depthValues,
			numbers = depthNumbers,
			defaultIndex = 4,  -- 16m
		},
		{
			-- Number of parallel streets laid side-by-side. Count > 1
			-- widens the trench, walls and portal cover automatically;
			-- only the first street gets a snap point, so the other
			-- streets stay as free endpoints the player can hand-connect.
			key = "rtr_count",
			name = _("rtr_count_name"),
			tooltip = _("rtr_count_tooltip"),
			uiType = "Button",
			values = { _("rtr_count_1"), _("rtr_count_2"), _("rtr_count_3") },
			numbers = { 1, 2, 3 },
			defaultIndex = 1,
		},
		{
			-- Retaining wall per side, from the street's edge to the outer
			-- edge of its top (ramp_geometry.lua M.WALLS). The user asked
			-- for a choice: 「擁壁幅を選べるようにするのは面倒？」, then agreed
			-- to two buttons, thin (after real open road cuttings; 1.5m since
			-- 2026-11-24, its 0.5m clearance dropped: 「擁壁側の路肩はなくして」)
			-- and thick (3.4m, the earlier body), short labels, thin first.
			key = "rtr_wall",
			name = _("rtr_wall_name"),
			tooltip = _("rtr_wall_tooltip"),
			uiType = "Button",
			values = { _("rtr_wall_thin"), _("rtr_wall_thick") },
			numbers = { 1, 2 },
			defaultIndex = 1,
		},
		{
			-- The portal cover's whole length, LID_MIN-24m in 1m steps, from 6m
			-- in front of the portal (ramp_geometry.lua LID_*). It was 36m
			-- in 1.0.0 (a mod.io comment: why so huge a slab for a road);
			-- some lid stays, as the ground just past the portal is shallow
			-- and town buildings may meet the tunnel there (the user,
			-- 2026-11-26: 「全体の長さにしてください」).
			key = "rtr_cover_length",
			name = _("rtr_cover_length_name"),
			tooltip = _("rtr_cover_length_tooltip"),
			uiType = "Slider",
			values = coverValues,
			numbers = coverNumbers,
			defaultIndex = geometry.LID_DEFAULT - geometry.LID_MIN + 1,  -- 18m (1-based)
		},
		{
			-- Only one-way (highway) templates care: which way traffic
			-- flows on the snapped street. With parallel streets it picks
			-- which carriageway snaps; the layout follows rtr_side.
			key = "rtr_direction",
			name = _("rtr_direction_name"),
			tooltip = _("rtr_direction_tooltip"),
			uiType = "Button",
			values = { _("rtr_direction_down"), _("rtr_direction_up") },
			numbers = { 1, 2 },
			defaultIndex = 1,
		},
		{
			-- Which side traffic drives on; fixes where each direction's
			-- carriageway sits when one-way streets are laid in parallel.
			key = "rtr_side",
			name = _("rtr_side_name"),
			tooltip = _("rtr_side_tooltip"),
			uiType = "Button",
			values = { _("rtr_side_right"), _("rtr_side_left") },
			numbers = { 1, 2 },
			defaultIndex = 1,
		},
		{
			-- Tram track on the flat approach, the descent and the tunnel stub,
			-- on one lane (ramp_geometry.lua M.tramLanes): none (initial), the
			-- outer lane of both directions, or only the right or left one,
			-- facing the way the edges run. Short labels (the user's own list:
			-- 「高架線 あり・なし／トラム 両方・右・左・なし」).
			key = "rtr_tram",
			name = _("rtr_tram_name"),
			tooltip = _("rtr_tram_tooltip"),
			uiType = "Button",
			values = { _("rtr_tram_none"), _("rtr_tram_both"), _("rtr_tram_right"), _("rtr_tram_left") },
			numbers = { 1, 2, 3, 4 },
			defaultIndex = 1,
		},
		{
			-- The track's catenary: with it the base game's electric trams,
			-- without it trams that need none (M.TRAM_POWER). Read only
			-- with a track.
			key = "rtr_tram_wire",
			name = _("rtr_tram_wire_name"),
			tooltip = _("rtr_tram_wire_tooltip"),
			uiType = "Button",
			values = { _("rtr_tram_wire_yes"), _("rtr_tram_wire_no") },
			numbers = { 1, 2 },
			defaultIndex = 1,
		},
		{
			-- The vertical profile mixes a straight line with a smoothstep
			-- (and quintic smootherstep at the steep end). Index 3 is the
			-- plain cubic easing that matches older builds; lower indices
			-- give a flatter overall slope at the cost of a small gradient
			-- step at both ends, higher indices concentrate the descent in
			-- the middle so the entrances stay longer flat.
			key = "rtr_curvature",
			name = _("rtr_curvature_name"),
			tooltip = _("rtr_curvature_tooltip"),
			uiType = "Slider",
			values = {
				_("rtr_curvature_shallow"),
				_("rtr_curvature_gentle"),
				_("rtr_curvature_normal"),
				_("rtr_curvature_steep"),
				_("rtr_curvature_very_steep"),
			},
			numbers = { 1, 2, 3, 4, 5 },
			defaultIndex = 3,
		},
		{
			-- Slope of the ground the ramp is built on, so the walls, coping,
			-- lid and the banks beside them follow it instead of staying level
			-- with the road end (they floated on the downhill side). The
			-- measured slope is shown under the build cursor. 1% steps keep
			-- the plane within 0.5m of a 100m ramp's ends; +-20% covers the
			-- hills a 13-25m deep ramp can still get under.
			key = "rtr_ground_along",
			name = _("rtr_ground_along_name"),
			tooltip = _("rtr_ground_along_tooltip"),
			uiType = "Slider",
			values = gradeValues,
			numbers = gradeNumbers,
			defaultIndex = 21,  -- 0%: level, the layout before this option
		},
		{
			key = "rtr_ground_across",
			name = _("rtr_ground_across_name"),
			tooltip = _("rtr_ground_across_tooltip"),
			uiType = "Slider",
			values = gradeValues,
			numbers = gradeNumbers,
			defaultIndex = 21,  -- 0%
		},
	},
	snapping = { rail = false, road = true, water = false },
	type = "ASSET_DEFAULT",
	updateScript = {
		fileName = "road_tunnel_ramp::/road_tunnel_ramp/ramp.script@updateFn",
		params = {
			-- Ordered to match the rtr_street picker labels; the UI value
			-- is the array index. Widths are the sums of each template's
			-- laneConfigs widths; tests re-check them against street.zip
			-- when the game is installed.
			-- oneWay marks templates whose car lanes are all forward.
			-- descent: the street the descent (x = 0 to the portal and on to
			-- the tunnel's foot) is laid with, the same car lanes with 0.5m
			-- shoulders and no sidewalk (streets/ramp_descent_*); the width
			-- it takes off goes to the walls, whose outer edge stays put
			-- (ramp_geometry.lua M.descentWall). The flat approach and the
			-- 30m stub keep ref. None on the cars-only entry: it has no
			-- sidewalk to take off.
			streets = {
				{ ref = "::/infrastructure/street/highway/highway_new_small.street_template",  width = 9, oneWay = true,
				  descent = { ref = "road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_descent_highway_small.street_template", width = 6 } },
				{ ref = "::/infrastructure/street/country/country_new_small.street_template",  width = 14,
				  descent = { ref = "road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_descent_country_small.street_template", width = 11 } },
				{ ref = "::/infrastructure/street/town/town_new_small.street_template",       width = 16,
				  descent = { ref = "road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_descent_town_small.street_template", width = 11 } },
				{ ref = "::/infrastructure/street/highway/highway_new_medium.street_template", width = 18, oneWay = true,
				  descent = { ref = "road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_descent_highway_medium.street_template", width = 11 } },
				{ ref = "::/infrastructure/street/country/country_new_medium.street_template", width = 22,
				  descent = { ref = "road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_descent_country_medium.street_template", width = 19 } },
				{ ref = "::/infrastructure/street/town/town_new_medium.street_template",      width = 24,
				  descent = { ref = "road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_descent_town_medium.street_template", width = 19 } },
				{ ref = "::/infrastructure/street/town/town_new_large.street_template",       width = 32,
				  descent = { ref = "road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_descent_town_large.street_template", width = 27 } },
				-- Two lanes (one each way), no sidewalk, offered as a cars-only
				-- ramp (user: 「一旦歩道ありはそのまま置いておいて、「歩道無し」版の
				-- パーツを作る感じですかね」, 「車専用でいいです」). Its own template,
				-- not the median's 8m centre: with the near end snapped to
				-- town_new_small, country_new_small, town_new_medium or
				-- highway_new_small, that one let no car through either way, while
				-- the same template on both sides did [measured 2026-11-23, reach
				-- drive]. This one has two 3.5m car lanes and 0.5m shoulders that
				-- carry nothing, 8m in all (see the template: it had
				-- town_new_small's 5m lanes and 2m pedestrian shoulders until the
				-- approach was handed over, 2026-11-24).
				-- variants: the e2e's stand-ins, picked by rtr_car_only_variant
				-- 2, 3 (not in the menu; 1 or none is ref): the same lanes, and
				-- the same under the town style.
				{ ref = "road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_car_only.street_template", width = 8,
				  variants = {
					"road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_car_only_bare.street_template",
					"road_tunnel_ramp::/road_tunnel_ramp/streets/ramp_car_only_town_style.street_template",
				  } },
			},
			tunnelRef = "::/infrastructure/tunnel/tunnel_a_car.tunnel",
			tunnelHeight = 10.55,
		},
	},
}
end
