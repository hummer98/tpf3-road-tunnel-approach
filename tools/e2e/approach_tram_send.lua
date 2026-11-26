-- e2e (tf3ctl eval --write --gs, test saves only): the approach's lay-again
-- for one placed ramp, by hand, step by step, with the mod's own code
-- (road_tunnel_ramp/approach_tram.lua), to see where the automatic one
-- stops (the game script rtr_approach_tram.script.lua does the same from
-- the build event).
--
--   sed -e 's/__CONSTRUCTION__/23456/' -e 's/__DRY__/1/' \
--     tools/e2e/approach_tram_send.lua > "$SCRATCH/send.lua"
--   python3 .../tf3ctl.py --owner mod-keeper eval --write --gs --file "$SCRATCH/send.lua"
--
-- __DRY__ 1: asks the engine (makeProposalData) and sends nothing; 0:
-- sends it. The answer: how far it went (stage), what it found and the
-- engine's verdict (dry) or "sent". The build's own answer comes in a
-- callback after this returns: it is logged ("[road_tunnel_ramp] tram
-- approach (by hand): ..." in tf3ctl log) and kept in the module, which
-- the next eval --gs reads:
--   eval --gs 'return require("road_tunnel_ramp::/road_tunnel_ramp/approach_tram.lua").lastManual'
local CONSTRUCTION = __CONSTRUCTION__
local DRY = __DRY__

local tram = require "road_tunnel_ramp::/road_tunnel_ramp/approach_tram.lua"
local out = { construction = CONSTRUCTION, dry = DRY == 1, stage = "start" }

local info = tram.constructionInfo(api, CONSTRUCTION)
if not info then out.stage = "construction does not read"; return out end
out.fileName, out.frameRead = info.fileName, info.m ~= nil
out.params = { rtr_tram = info.params.rtr_tram, rtr_side = info.params.rtr_side, rtr_street = info.params.rtr_street,
	rtr_approach_hand_over = info.params.rtr_approach_hand_over, rtr_tram_edge = info.params.rtr_tram_edge }
local choice, why = tram.choice(info.fileName, info.params)
out.choice = choice
if not choice then out.stage = "choice: " .. tostring(why); return out end

local approaches = tram.findApproaches(api, info)
out.approaches = {}
for _, a in ipairs(approaches) do
	local track = {}
	for i, l in ipairs(a.lanes) do
		if l.modes.TRAM or l.modes.ELECTRIC_TRAM then track[#track + 1] = i end
	end
	local strip, whyNot = tram.lanesToStrip(a.lanes, choice.tram, choice.side, a.runsIn)
	out.approaches[#out.approaches + 1] = { edge = a.edge, runsIn = a.runsIn, lanes = #a.lanes, trackLanes = track,
		strip = strip, why = whyNot }
end
if #approaches == 0 then out.stage = "no approach edge found"; return out end

local plan, whyPlan = tram.plan(api, CONSTRUCTION)
if not plan then out.stage = "plan: " .. tostring(whyPlan); return out end
out.plan = tram.describe(plan)

local okP, proposal = pcall(tram.makeProposal, api, plan)
if not okP then out.stage = "proposal not made: " .. tostring(proposal); return out end
out.stage = "proposal made"

if DRY == 1 then
	local okD, data = pcall(api.engine.util.proposal.makeProposalData, proposal, tram.context(api))
	out.verdict = { asked = okD, critical = nil, messages = {} }
	if okD then
		pcall(function()
			out.verdict.critical = data.errorState.critical == true
			for _, x in ipairs(tram.list(data.errorState.messages)) do out.verdict.messages[#out.verdict.messages + 1] = tostring(x) end
		end)
	else
		out.verdict.error = tostring(data)
	end
	out.stage = "dry run asked"
	return out
end

tram.lastManual = { construction = CONSTRUCTION, plan = out.plan, answer = "pending", at = os.time() }
local okS, err = pcall(tram.send, api, proposal, function(success, msg)
	tram.lastManual.answer = success and "built" or "refused"
	tram.lastManual.messages = msg
	print("[road_tunnel_ramp] tram approach (by hand): construction " .. CONSTRUCTION .. " " .. tram.lastManual.answer .. msg)
end)
out.stage = okS and "sent" or ("not sent: " .. tostring(err))
return out
