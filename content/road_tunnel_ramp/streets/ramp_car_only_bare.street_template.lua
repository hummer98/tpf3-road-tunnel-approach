-- e2e only (rtr_car_only_variant 2, not in the menu): kept as the stand-in
-- it was (bare shoulders, the control for the pedestrian shoulders, PW).
-- Since ramp_car_only's shoulders carry nothing too (2026-11-24) the two
-- are the same street, 0.5m shoulders, 8m: the width the body is laid
-- for (ramp.con.lua streets[8]).
function data()
return {
		-- Hidden (no menuCategory): only the full-width ramp builds it.
		availability = { yearFrom = 0, yearTo = 0, },
		-- As on the median's templates (meant to keep it out of road lists;
		-- not checked).
		initiallyLocked = true,
		borderGroundTex = "::/infrastructure/street/shared/town_street_border.gtex",
		cost = 180,
		description = {
			description = _("rtr_ramp_car_only_desc"),
			icon = "::/infrastructure/street/town/town_new_small.tga",
			name = _("rtr_ramp_car_only_name"),
			previewIcon = "::/infrastructure/street/town/town_new_small_preview.tga",
		},
		emissions = { noise = 0, pollution = 0, pollutionRadius = 0, radius = 0, },
		fillGroundTex = "::/infrastructure/street/shared/town_street_fill.gtex",
		laneConfigs = {
			{ forward = false, height = 0, offset = 0, speed = 13.89, transportModes = { }, width = 0.5, },
			{ forward = false, height = 0, offset = 0, speed = 13.89, transportModes = { "CAR", "BUS", "TRUCK", }, width = 3.5, },
			{ forward = true, height = 0, offset = 0, speed = 13.89, transportModes = { "CAR", "BUS", "TRUCK", }, width = 3.5, },
			{ forward = true, height = 0, offset = 0, speed = 13.89, transportModes = { }, width = 0.5, },
		},
		maintenanceCost = 30,
		modifiers = { maxSpeedModifier = 0, noiseModifier = 0, pollutionModifier = 0, },
		priority = 400,
		roadType = "STREET",
		sidewalkFillGroundTex = "::/infrastructure/street/shared/highway_safety_lane.gtex",
		-- Every base town style (town_new, town_old, their large and xsmall)
		-- draws sidewalk paving and curbs on the outer lanes, which would put
		-- back the look of a sidewalk; this one draws none, and paves and
		-- marks the lanes with town_new's materials (its borders and stripes
		-- are the new country road's).
		streetStyle = "::/infrastructure/street/country/country_new_small.street",
		builderAudioRes = "::/gui/construction/sound/buildoze_street.builder_audio",
	}
end
