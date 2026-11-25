-- Street style of the median ramp's side street median_c_side_l.street_template
-- (11.5m, sidewalk 3.5m on the left of travel): the base game's town_new.street
-- (base/content/infrastructure/street.zip, street/town/town_new.street.lua)
-- with its paths written out, every street asset on the sidewalk's side
-- only, and town_old's post-top lamp (street_light_eu_a) for its light.
-- Why one side: town_new puts street lights both sides (oneSideOnly false,
-- offsetOrth 3.0), and on the 7.5m side street (as it was) their arms met
-- over the lane as an arch (the user, 2026-11-24: 「側道の街灯？が狭すぎて、
-- アーチ状になってしまっているようです。街灯を片側だけにしたりできますか？」).
-- The wall side has no sidewalk.
-- With oneSideOnly true, offsetOrth is read from the street's left edge
-- (build direction) across its width [source: Bus Bay (mod.io 6437728)
-- puts its one-sided curb at 26.75 / 5.25 from the left on its right /
-- left bus bays; measured 2026-11-24 PN6: the fireplugs at 6.15 stood at
-- the outer edge on both side streets, each laid in its travel direction].
-- Why eu_a, not town_new's eu_c: eu_c's pole stands 2.8m behind its origin
-- and its arm reaches 1.1 to 1.3m ahead, the model's +y [source: the lod0 mesh's
-- vertices, street_light_eu_c_lod0.msh.blob; town_new's 3.0 puts the pole
-- at the back of a 3m sidewalk, the head over the lane], and a one-sided
-- asset faces right of the build direction [guess, from PN6: with the
-- sidewalk on the right (median_side_r at 3.5) both side streets showed
-- the pole by the wall and the arm over the lane toward the sidewalk,
-- seen as an arch over the coping on the one nearer the camera]. No
-- offsetOrth puts eu_c's pole on a right-hand sidewalk with its arm over
-- the lane; eu_a is a post with its lamp on top over its origin [source:
-- its mesh], so it stands where offsetOrth says on either side. It stands
-- 0.6m in from the curb (town_old: 2.4 from the outer edge of a 3m
-- sidewalk), spaced as on town_old (offset 6, distance 12: it is the
-- shorter lamp); the fireplug and the bin at the outer edge, as on
-- town_new.
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
		streetLane = {
			name = "::/infrastructure/street/town/mat/town_new_streetlane.mtl",
			size = { 4.0, 4.0 }
		},
		streetStripe = {
			name = "::/infrastructure/street/town/mat/new_town_stripe.mtl",
			size = { 24.0, .37 }		
		},
		streetStripeMedian = {
			name = "::/infrastructure/street/town/mat/new_town_stripe.mtl",
			size = { 24.0, .37 }		
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
			name = "::/infrastructure/street/town/mat/new_medium_sidewalk_prototype.mtl",
			size = { 32.0, 32.0 }
		},
		sidewalkLane = {	

		},
		sidewalkBorderInner = {
			name = "::/infrastructure/street/town/mat/new_town_sw_in.mtl",		
			size = { 24, 1.5 }
		},
		-- sidewalkBorderOuter = {
			-- name = "::/infrastructure/street/town/mat/new_medium_sidewalk_border_outer.mtl",		
			-- size = { 8.0, 0.41602 }
		-- },
		sidewalkCurb = {
			name = "::/infrastructure/street/town/mat/new_town_sw_curb.mtl",
			size = { 24, .35 }
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
	},
	assets = {
		["street_light"] = {
			name = "::/assets/streets/street_light_eu_a.mdl",
			offset = 6.0,
			distance = 12.0,
			prob = 1.0,
			offsetOrth = 2.9,
			randRot = false,
			oneSideOnly = true,
			alignToElevation = false,
			avoidFaceEdges = false,
			placeOnBridge = true,
		}, 
		["fireplug"] = {
			name = "::/assets/streets/fireplug_c.mdl",
			offset = 10.0,
			distance = 40.0,
			prob = 0.5,
			offsetOrth = 0.35,
			randRot = false,
			oneSideOnly = true,
			alignToElevation = false,
			avoidFaceEdges = false,
		}, 
		["trash"] = {
			name = "::/assets/streets/trash_standing_c.mdl",
			offset = 20,
			distance = 50.0,
			prob = 0.5,
			offsetOrth = 0.4,
			randRot = false,
			oneSideOnly = true,
			alignToElevation = false,
			avoidFaceEdges = false,
		}, 
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
			"withSidewalk",
			"town",
			"new",
		}
	},
	priority = 610,

}
end
