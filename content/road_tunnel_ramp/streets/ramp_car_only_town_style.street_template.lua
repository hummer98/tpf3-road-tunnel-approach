-- e2e only (rtr_car_only_variant 3, not in the menu): the bare shoulders
-- of ramp_car_only_bare under the base town style instead of the country
-- one. Tells the other guess apart: that the street style, not the
-- missing pedestrian lanes, keeps cars from crossing a two-edge node from
-- a town street (town_new_small and median_c_narrow, both town_new.street,
-- passed cars there; the 8m centre, highway_small.street, and the bare
-- template, country_new_small.street, did not) [measured 2026-11-23 PS,
-- PW, PB]. It draws town curbs on the shoulders; not for players.
-- Its shoulders are 0.5m as ramp_car_only's (2026-11-24), the width the
-- body is laid for.
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
		streetStyle = "::/infrastructure/street/town/town_new.street",
		builderAudioRes = "::/gui/construction/sound/buildoze_street.builder_audio",
	}
end
