-- Street style of the town streets' descents (Medium and Large Street): the base game's
-- town_new_large.street (base/content/infrastructure/street.zip) with its paths written
-- out, its lane markings and borders as they are, but no sidewalk paving,
-- curbs or sidewalk borders, no street assets (lights, fire plugs, bins
-- stood on the sidewalk) and not in the "withSidewalk" category. The
-- descent has 0.5m shoulders where the sidewalks were, and every base town
-- style draws curbs and paving there; the country style it had instead
-- (as ramp_car_only has) gave the descent the country road's yellow centre
-- lines under the town street's white ones in front (the user: 「導入路と
-- 手前の道の種類が合ってないきがしますが」, chose 1: the town lines without
-- curbs; picture tc5_over_town.png, 2026-11-26). The empty sidewalk blocks
-- are written as the base country styles write theirs. Written from
-- street.zip by hand; tests compare it with its source.
function data()
return {
	roadType = "STREET",
	materials = {
		streetPaving = {
			name = "::/infrastructure/street/town/mat/town_new_street_paving.mtl",
			size = { 6.0, 6.0 }
		},		
		streetBorder = {
			name = "::/infrastructure/street/town/mat/new_town_border.mtl",
			size = { 24.0, 3.0 }
		},
		streetBorder2 = {
			name = "::/infrastructure/street/shared/mat/new_shared_border.mtl",
			size = { 24.0, 3.0 }
		},
		streetLane = {
			name = "::/infrastructure/street/town/mat/town_new_streetlane.mtl",
			size = { 4.0, 5.0 }
		},
		streetArrow = {
			name = "::/infrastructure/street/shared/mat/default_arrows.mtl",
			size = { 9.0, 3.0 }
		},
		streetStripe = {
			name = "::/infrastructure/street/town/mat/new_town_stripe.mtl",
			size = { 24.0, 0.37 }		
		},
		streetStripeMedian = {
			name = "::/infrastructure/street/town/mat/new_town_median.mtl",
			size = { 24.0, 0.37 }		
		},
		streetBus = {
			name = "::/infrastructure/street/town/mat/new_medium_bus.mtl",
			size = { 12, 2.7 }
		},
		streetTram = {
			name = "::/infrastructure/street/shared/mat/new_tram_paving.mtl",
			size = { 2.0, 2.0 }
		},
		streetTramTrack = {
			name = "::/infrastructure/street/shared/mat/new_tram_track.mtl",
			size = { 2.0, 2.0 }
		},
		crossingLane = {
			name = "::/infrastructure/street/town/mat/town_new_streetlane.mtl",
			size = { 4.0, 4.0 }
		},
		crossingBus = {
			name = ""		
		},
		crossingTram = {
			name = "::/infrastructure/street/shared/mat/new_tram_paving.mtl",
			size = { 2.0, 2.0 }
		},
		crossingTramTrack = {
			name = "::/infrastructure/street/shared/mat/new_tram_track.mtl",
			size = { 2.0, 2.0 }
		},
		crossingCrosswalk = {
			name = "::/infrastructure/street/shared/mat/new_crosswalk.mtl",
			size = { 3.0, 2.5 }
		},
		sidewalkPaving = {
		},
		sidewalkLane = {
		},
		sidewalkBorderInner = {
		},
		-- sidewalkBorderOuter = {
			-- name = "::/infrastructure/street/town/mat/new_medium_sidewalk_border_outer.mtl",		
			-- size = { 8.0, 0.41602 }
		-- },
		sidewalkCurb = {
		},
		-- sidewalkWall = {
			-- name = "::/infrastructure/street/town/mat/new_medium_sidewalk_wall.mtl",
			-- size = { 8.0, 0.41602 }
		-- },
		catenary = {
			name = "::/infrastructure/street/shared/mat/tram_cable.mtl"
		},
		junctionBorder = {
			name = "::/infrastructure/street/town/mat/new_town_border.mtl",
			size = { 24.0, 3.0 }
		},
		-- junctionBorder2 = {
		-- 	name = "::/infrastructure/street/shared/mat/new_shared_border.mtl",
		-- 	size = { 24.0, 3.0 }
		-- },	
	},
	assets = {
	},
	catenary = {
		pole = {
			name = "::/assets/streets/tram_pole.mdl",
		},
		poleCrossbar = {
			name = "::/assets/streets/tram_pole_crossbar.mdl",
		},
		poleDoubleCrossbar = {
			name = "::/assets/streets/tram_pole_double_crossbar.mdl",
		},
		isolatorStraight = "::/assets/streets/cable_isolator.mdl",
		isolatorCurve = "::/assets/streets/cable_isolator.mdl",
		junction = "::/assets/streets/cable_junction.mdl"
	},
	categoryList = {
		categories = {
			"town",
			"new",
		}
	},
	arrowIndices = {
		LEFT = 0,
		STRAIGHT = 1,
		RIGHT = 2,
		LEFT_STRAIGHT = 3,
		RIGHT_STRAIGHT = 4,
		LEFT_RIGHT = 5,
		LEFT_RIGHT_STRAIGHT = 6
	},
	priority = 620,
}
end
