-- Side street of the median ramp from a Large Street (32m, entry 6,
-- median_geometry.lua ENTRIES): two one-way lanes of 4m and a 3.5m
-- sidewalk, 11.5m (6->2+2->6: 「中2+2は一方通行」). Otherwise as
-- median_side_l.street_template.lua: the sidewalk on the left of travel
-- only, the trench side kept free of house plots by the hidden
-- decoration.
function data()
return {
		-- Hidden (no menuCategory): only the median ramp builds it.
		availability = { yearFrom = 0, yearTo = 0, },
		borderGroundTex = "::/infrastructure/street/shared/town_street_border.gtex",
		cost = 90,
		-- No house plots on the wall side (the right of travel here): towns
		-- fill both sides of a street regardless of its lanes, and a
		-- decoration with preventParcels is the only per-side parcel switch (see
		-- median_inner.edge.lua). The flag is the side, true = left as
		-- in SimpleStreetProposal.EdgeObject.left (not documented for
		-- decorations; the e2e parcels --edge check confirms it).
		defaultEdgeDecorations = {
			{ "road_tunnel_ramp::/road_tunnel_ramp/streets/median_inner.edge", false, },
		},
		description = {
			description = _("rtr_median_side_desc"),
			icon = "::/infrastructure/street/town/town_new_one_way_medium.tga",
			name = _("rtr_median_side_name"),
			previewIcon = "::/infrastructure/street/town/town_new_one_way_medium.tga",
		},
		emissions = { noise = 0, pollution = 0, pollutionRadius = 0, radius = 0, },
		fillGroundTex = "::/infrastructure/street/shared/town_street_fill.gtex",
		laneConfigs = {
			{ forward = false, height = 0.15, offset = 0.15, speed = 13.89, transportModes = { "PERSON", "CARGO", }, width = 3.5, },
			{ forward = true, height = 0, offset = 0, speed = 13.89, transportModes = { "CAR", "BUS", "TRUCK", }, width = 4, },
			{ forward = true, height = 0, offset = 0, speed = 13.89, transportModes = { "CAR", "BUS", "TRUCK", }, width = 4, },
		},
		maintenanceCost = 15,
		modifiers = { maxSpeedModifier = 0, noiseModifier = 0, pollutionModifier = 0, },
		priority = 400,
		roadType = "STREET",
		sidewalkFillGroundTex = "::/infrastructure/street/shared/street_sidewalk_fill.gtex",
		-- town_new.street with its street lights, fireplugs and bins on the
		-- sidewalk's side only (the style file says why)
		streetStyle = "road_tunnel_ramp::/road_tunnel_ramp/streets/median_c_side_l.street",
		builderAudioRes = "::/gui/construction/sound/buildoze_street.builder_audio",
	}
end
