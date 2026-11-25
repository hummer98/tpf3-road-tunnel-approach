-- Side street of the median ramp: one one-way lane and a sidewalk on the
-- right of travel only (the other side is the trench wall, where nothing
-- can be built). laneConfigs run left to right in the build direction
-- (the game's StreetTemplate type, api/tealdef/api/type.d.tl);
-- median_geometry.lua picks _l or _r so the sidewalk lands outside
-- (entries 2 and 4). The lane is 3.5m (4.5m before 2026-11-24), 6.5m in all,
-- so the median from a four-lane street is its 24m across (median_geometry).
-- In the build menu too, as the street the player joins the side streets
-- with (the user, 2026-11-24: 「側道用の道路をMODで提供します。片側にしか歩道
-- がない一方通行です。ツールシルエットは流用でOK。」). Only this one: a
-- one-way street laid the way its traffic runs has its sidewalk on the right
-- either side of the trench (「左右二種類いります？一方通行を正しく引いたら
-- いつも右が歩道側になりませんか？」); median_side_l, for left-hand traffic,
-- stays hidden. Built from the menu it keeps the trench side's decoration,
-- so no houses come on its left there either.
function data()
return {
		-- no year limit (yearFrom 0 = from the start, yearTo 0 = never ends)
		availability = { yearFrom = 0, yearTo = 0, },
		borderGroundTex = "::/infrastructure/street/shared/town_street_border.gtex",
		cost = 90,
		-- No house plots on the wall side (the left of travel here): towns
		-- fill both sides of a street regardless of its lanes, and a
		-- decoration with preventParcels is the only per-side parcel switch (see
		-- median_inner.edge.lua). The flag is the side, true = left as
		-- in SimpleStreetProposal.EdgeObject.left (not documented for
		-- decorations; the e2e parcels --edge check confirms it).
		defaultEdgeDecorations = {
			{ "road_tunnel_ramp::/road_tunnel_ramp/streets/median_inner.edge", true, },
		},
		description = {
			description = _("rtr_median_side_desc"),
			icon = "::/infrastructure/street/town/town_new_one_way_small.tga",
			name = _("rtr_median_side_name"),
			previewIcon = "::/infrastructure/street/town/town_new_one_way_small_preview.tga",
		},
		emissions = { noise = 0, pollution = 0, pollutionRadius = 0, radius = 0, },
		fillGroundTex = "::/infrastructure/street/shared/town_street_fill.gtex",
		laneConfigs = {
			{ forward = true, height = 0, offset = 0, speed = 13.89, transportModes = { "CAR", "BUS", "TRUCK", }, width = 3.5, },
			{ forward = true, height = 0.15, offset = -0.15, speed = 13.89, transportModes = { "PERSON", "CARGO", }, width = 3, },
		},
		maintenanceCost = 15,
		-- with the base one-way small town streets (100 to 140), before
		-- the extra-small ones (150)
		menuCategory = {
			categories = {
				{ category = "roads_small", filterCategories = { }, order = 145, },
			},
		},
		modifiers = { maxSpeedModifier = 0, noiseModifier = 0, pollutionModifier = 0, },
		priority = 400,
		roadType = "STREET",
		sidewalkFillGroundTex = "::/infrastructure/street/shared/street_sidewalk_fill.gtex",
		-- town_new.street with its street lights, fireplugs and bins on the
		-- sidewalk's side only (the style file says why)
		streetStyle = "road_tunnel_ramp::/road_tunnel_ramp/streets/median_side_r.street",
		builderAudioRes = "::/gui/construction/sound/buildoze_street.builder_audio",
	}
end
