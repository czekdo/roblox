local LeaderboardConfig = {}

-- Dragon Power is deliberately not included yet: there's no single up-to-date aggregate attribute
-- for "total power across all owned dragons" (DragonPowerScore.Compute is only ever called
-- per-dragon in DragonInventoryService). Add a category here once such an attribute exists.
LeaderboardConfig.Categories = {
	{
		Key = "KingdomLevel",
		Name = "Kingdom Level",
		IconKey = "Crown",
		GetValue = function(player)
			return player:GetAttribute("KingdomLevel") or 1
		end,
	},
	{
		Key = "LifetimeEssence",
		Name = "Dragon Essence",
		IconKey = "Crystal",
		GetValue = function(player)
			return player:GetAttribute("LifetimeEssence") or 0
		end,
	},
}

function LeaderboardConfig.GetCategory(key)
	for _, category in LeaderboardConfig.Categories do
		if category.Key == key then
			return category
		end
	end
	return nil
end

return LeaderboardConfig
