-- Side street of the median ramp: one one-way lane and a sidewalk on the
-- left of travel only (the other side is the trench wall, where nothing
-- can be built). laneConfigs run left to right in the build direction
-- (the game's StreetTemplate type, api/tealdef/api/type.d.tl);
-- median_geometry.lua picks _l or _r so the sidewalk lands outside
-- (entries 2 and 4). The lane is 3.5m (4.5m before 2026-11-24), 6.5m in all,
-- so the median from a four-lane street is its 24m across (median_geometry).
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
			icon = "::/infrastructure/street/town/town_new_one_way_small.tga",
			name = _("rtr_median_side_name"),
			previewIcon = "::/infrastructure/street/town/town_new_one_way_small.tga",
		},
		emissions = { noise = 0, pollution = 0, pollutionRadius = 0, radius = 0, },
		fillGroundTex = "::/infrastructure/street/shared/town_street_fill.gtex",
		laneConfigs = {
			{ forward = false, height = 0.15, offset = 0.15, speed = 13.89, transportModes = { "PERSON", "CARGO", }, width = 3, },
			{ forward = true, height = 0, offset = 0, speed = 13.89, transportModes = { "CAR", "BUS", "TRUCK", }, width = 3.5, },
		},
		maintenanceCost = 15,
		modifiers = { maxSpeedModifier = 0, noiseModifier = 0, pollutionModifier = 0, },
		priority = 400,
		roadType = "STREET",
		sidewalkFillGroundTex = "::/infrastructure/street/shared/street_sidewalk_fill.gtex",
		-- town_new.street with its street lights, fireplugs and bins on the
		-- sidewalk's side only (the style file says why)
		streetStyle = "road_tunnel_ramp::/road_tunnel_ramp/streets/median_side_l.street",
		builderAudioRes = "::/gui/construction/sound/buildoze_street.builder_audio",
	}
end
