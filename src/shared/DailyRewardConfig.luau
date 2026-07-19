local DailyRewardConfig = {}

-- One entry per streak day. Streak counts up indefinitely; the reward shown/granted for a given
-- streak day is Track[((streak - 1) % #Track) + 1], so the track loops after day 7.
DailyRewardConfig.Track = {
	{ Day = 1, Reward = { Type = "DragonEssence", Amount = 80, Text = "+80 Dragon Essence" } },
	{ Day = 2, Reward = { Type = "DragonEssence", Amount = 120, Text = "+120 Dragon Essence" } },
	{ Day = 3, Reward = { Type = "PremiumCurrency", Amount = 3, Text = "+3 Gems" } },
	{ Day = 4, Reward = { Type = "DragonEssence", Amount = 180, Text = "+180 Dragon Essence" } },
	{ Day = 5, Reward = { Type = "PremiumCurrency", Amount = 5, Text = "+5 Gems" } },
	{ Day = 6, Reward = { Type = "DragonEssence", Amount = 260, Text = "+260 Dragon Essence" } },
	{ Day = 7, Reward = { Type = "PremiumCurrency", Amount = 12, Text = "+12 Gems" } },
}

function DailyRewardConfig.GetEntryForStreak(streak)
	local index = ((streak - 1) % #DailyRewardConfig.Track) + 1
	return DailyRewardConfig.Track[index]
end

return DailyRewardConfig
