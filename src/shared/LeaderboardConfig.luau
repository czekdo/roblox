local LeaderboardConfig = {}

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
	{
		-- Sum of every owned dragon's DragonPowerScore, mirrored onto this attribute by
		-- DragonInventoryService.BuildInventoryPayload (and refreshed directly after upgrade/sell/
		-- trade actions that don't otherwise rebuild the full inventory payload).
		Key = "DragonPower",
		Name = "Dragon Power",
		IconKey = "Dragon",
		GetValue = function(player)
			return player:GetAttribute("DragonPower") or 0
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
