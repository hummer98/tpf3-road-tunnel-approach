-- Invisible edge decoration that keeps town house plots (parcels) off one
-- side of the median ramp's side streets: the side against the trench
-- wall. Towns put parcels on both sides of every street edge whatever its
-- lanes (measured: the side templates have no sidewalk on that side and
-- still got 18 parcels and houses there), and nothing in a street
-- template stops parcels per side except its defaultEdgeDecorations,
-- which list a decoration per side; the base game's barriers set
-- preventParcels on theirs (barrier_a/b.edge.lua). This one draws
-- nothing, so the trench wall stays the only thing seen there.
function data()
return {
	-- Hidden (no menu entry, as on Better Road Tools' island decorations):
	-- only the side street templates put it on.
	availability = { yearFrom = 0, yearTo = 0, },
	cost = { price = 0, priceScale = 1, },
	maintenance = { runningCosts = 0, },
	desc = {
		icon = "::/infrastructure/edge_addons/barrier_a.tga",
		previewIcon = "::/infrastructure/edge_addons/barrier_a_preview.tga",
		name = _("rtr_median_inner_name"),
		description = _("rtr_median_inner_desc"),
	},
	categoryList = { categories = { "rtr_median_inner" }, },
	repModel = "road_tunnel_ramp::/road_tunnel_ramp/streets/median_inner.mdl",
	length = 10.0,
	offset = 0.0,
	snapMode = "Side",
	skipSameInParallelStrip = false,
	incompatibleTags = { "track", },
	order = 0,
	menuCategory = { categories = { }, },
	modifiers = { noiseModifier = 0, },
	preventParcels = true,
}
end
