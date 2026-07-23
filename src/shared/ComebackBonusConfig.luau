local ComebackBonusConfig = {}

ComebackBonusConfig.DataStoreName = "DragonIslandLastSeenV1"

-- Ordered ascending by MinDays. GetTierForDays keeps overwriting its result while a tier still
-- qualifies, so a 10-day absence correctly lands on the 7-day tier (the highest one it clears),
-- not the 3-day one.
ComebackBonusConfig.Tiers = {
	{ MinDays = 3, Gems = 50, Essence = 500, Label = "Welcome Back!" },
	{ MinDays = 7, Gems = 150, Essence = 1500, Label = "We Missed You!" },
	{ MinDays = 14, Gems = 300, Essence = 3000, Label = "The Kingdom Awaits!" },
}

function ComebackBonusConfig.GetTierForDays(days)
	local best = nil
	for _, tier in ComebackBonusConfig.Tiers do
		if days >= tier.MinDays then
			best = tier
		end
	end
	return best
end

return ComebackBonusConfig
