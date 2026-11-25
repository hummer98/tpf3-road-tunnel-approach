-- Median tunnel approach: a two-lane centre goes down into a tunnel with the
-- full-width ramp's body, and a one-way side street either side stays on the
-- surface, handed over to the player as ordinary streets so the town builds
-- along them (median_geometry.lua). The fork at the near end and the merge
-- at the far end are the player's to lay, with ordinary streets: no script
-- joins them (the user, 2026-11-24: 「中央導入路パターンは、側道接続は離散/
-- 合流共にユーザーにやってもらうことにします。プリセット設置が不可能なら
-- スクリプト接続は無し。」, after the scripted S and 2+2 forks both failed).

-- Evenly stepped slider options: labels "<n>m" and matching numbers.
local function metres(lo, hi, step)
	local values, numbers = {}, {}
	for n = lo, hi, step do
		values[#values + 1] = string.format("%dm", n)
		numbers[#numbers + 1] = n
	end
	return values, numbers
end

-- Ground grade options in whole percent, signed ("-3%", "0%", "+3%"), as
-- on the full-width ramp.
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
local approachValues, approachNumbers = metres(30, 50, 2)
local depthValues, depthNumbers = metres(13, 25, 1)
local gradeValues, gradeNumbers = percents(-20, 20)
return {
	autoRemovable = false,
	availability = { yearFrom = 0, yearTo = 0 },
	buildMode = "SINGLE",
	description = {
		description = _("rtr_median_description"),
		icon = "median.tga",
		name = _("rtr_median_name"),
		previewIcon = "median_preview.tga",
	},
	heightAdjustable = true,
	heightModView = true,
	keepBuildingsAndFields = false,
	menuCategory = {
		categories = {
			{
				category = "street_constructions",
				order = 101,  -- right after the full-width ramp (100)
			},
		},
	},
	params = {
		{
			-- The town street the approach is placed on, by its lanes
			-- (median_geometry.lua ENTRIES): 2 and 4 keep one lane each
			-- way beside the centre, 6 two.
			key = "rtr_median_entry",
			name = _("rtr_median_entry_name"),
			tooltip = _("rtr_median_entry_tooltip"),
			uiType = "Button",
			values = { _("rtr_median_entry_2"), _("rtr_median_entry_4"), _("rtr_median_entry_6") },
			numbers = { 2, 4, 6 },
			defaultIndex = 2,
		},
		{
			-- The centre's street: the full-width ramp's two-lane entries,
			-- by the same numbers and labels (median_geometry.lua CENTRES),
			-- the cars-only one initially.
			key = "rtr_street",
			name = _("rtr_median_street_name"),
			tooltip = _("rtr_median_street_tooltip"),
			uiType = "ComboBox",
			values = {
				_("rtr_street_highway_small"),
				_("rtr_street_country_small"),
				_("rtr_street_town_small"),
				_("rtr_street_car_only"),
			},
			numbers = { 1, 2, 3, 8 },
			defaultIndex = 4,
		},
		{
			-- As on the full-width ramp (ramp_geometry.lua M.WALLS).
			key = "rtr_wall",
			name = _("rtr_wall_name"),
			tooltip = _("rtr_wall_tooltip"),
			uiType = "Button",
			values = { _("rtr_wall_thin"), _("rtr_wall_thick") },
			numbers = { 1, 2 },
			defaultIndex = 1,
		},
		{
			key = "rtr_length",
			name = _("rtr_length_name"),
			tooltip = _("rtr_length_tooltip"),
			uiType = "Slider",
			values = lengthValues,
			numbers = lengthNumbers,
			defaultIndex = #lengthNumbers,  -- 100m, the gentlest
		},
		{
			key = "rtr_approach",
			name = _("rtr_approach_name"),
			tooltip = _("rtr_approach_tooltip"),
			uiType = "Slider",
			values = approachValues,
			numbers = approachNumbers,
			-- From 30m (median_geometry.lua APPROACH_MIN): room in front
			-- of the side streets' near ends (at the trench start) for a
			-- fork the player lays from the snap point.
			defaultIndex = 1,  -- 30m
		},
		{
			-- Same floor as the full-width ramp: tunnelHeight + 2 = 12.55m.
			key = "rtr_depth",
			name = _("rtr_depth_name"),
			tooltip = _("rtr_depth_tooltip"),
			uiType = "Slider",
			values = depthValues,
			numbers = depthNumbers,
			defaultIndex = 4,  -- 16m
		},
		{
			-- Only the one-way centre (the highway) reads it, as on the
			-- full-width ramp; own tooltip, as there are no parallel streets.
			key = "rtr_direction",
			name = _("rtr_direction_name"),
			tooltip = _("rtr_median_direction_tooltip"),
			uiType = "Button",
			values = { _("rtr_direction_down"), _("rtr_direction_up") },
			numbers = { 1, 2 },
			defaultIndex = 1,
		},
		{
			-- Fixes which way each side street runs and so which of the
			-- two side templates puts its sidewalk on the outside.
			key = "rtr_side",
			name = _("rtr_side_name"),
			tooltip = _("rtr_median_side_tooltip"),
			uiType = "Button",
			values = { _("rtr_side_right"), _("rtr_side_left") },
			numbers = { 1, 2 },
			defaultIndex = 1,
		},
		{
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
			-- Own tooltip: here the side streets follow the slope too.
			key = "rtr_ground_along",
			name = _("rtr_ground_along_name"),
			tooltip = _("rtr_median_ground_along_tooltip"),
			uiType = "Slider",
			values = gradeValues,
			numbers = gradeNumbers,
			defaultIndex = 21,  -- 0%: level
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
		fileName = "road_tunnel_ramp::/road_tunnel_ramp/median.script@updateFn",
		params = {
			-- The street types and the layout are in median_geometry.lua,
			-- where the game script can read them too.
			tunnelRef = "::/infrastructure/tunnel/tunnel_a_car.tunnel",
			tunnelHeight = 10.55,
		},
	},
}
end
