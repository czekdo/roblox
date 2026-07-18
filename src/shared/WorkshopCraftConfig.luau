local WorkshopCraftConfig = {
	Recipes = {
		{
			Id = "EssenceBoost",
			DisplayName = "Essence Boost",
			Description = "25% essence gain for 10 minutes.",
			Tier = 1,
			Cost = 150,
			Reward = { Type = "TemporaryBoost", BoostId = "CraftEssenceBoost", Multiplier = 1.25, Duration = 600, Text = "25% Essence Boost (10m)" },
		},
		{
			Id = "DragonSnack",
			DisplayName = "Dragon Snack",
			Description = "Instantly grants 150 Dragon Essence.",
			Tier = 1,
			Cost = 100,
			Reward = { Type = "DragonEssence", Amount = 150, Text = "+150 Dragon Essence" },
		},
		{
			Id = "RareEggFragment",
			DisplayName = "Rare Egg Fragment",
			Description = "Combine fragments into a Rare quest egg.",
			Tier = 2,
			Cost = 650,
			Reward = { Type = "QuestEgg", Amount = 1, Text = "+1 Rare Quest Egg" },
		},
		{
			Id = "HarvestElixir",
			DisplayName = "Harvest Elixir",
			Description = "Dragons harvest 40% faster for 15 minutes.",
			Tier = 2,
			Cost = 500,
			Reward = { Type = "TemporaryBoost", BoostId = "CraftHarvestBoost", Multiplier = 1.4, Duration = 900, Text = "40% Harvest Speed (15m)" },
		},
		{
			Id = "DragonBanner",
			DisplayName = "Dragon Banner",
			Description = "Kingdom banner decoration for your island.",
			Tier = 3,
			Cost = 750,
			Reward = { Type = "Decoration", DecorationId = "DragonBanner", Text = "Dragon Banner decoration" },
		},
		{
			Id = "CrystalCrown",
			DisplayName = "Crystal Crown",
			Description = "A glowing island decoration.",
			Tier = 3,
			Cost = 1000,
			Reward = { Type = "Decoration", DecorationId = "CrystalCrown", Text = "Crystal Crown decoration" },
		},
		{
			Id = "AncientRelic",
			DisplayName = "Ancient Relic",
			Description = "Mystic relic that grants 1000 essence.",
			Tier = 4,
			Cost = 2600,
			Reward = { Type = "DragonEssence", Amount = 1000, Text = "+1000 Dragon Essence" },
		},
		{
			Id = "MasterworkElixir",
			DisplayName = "Masterwork Elixir",
			Description = "Dragons harvest 50% faster for 20 minutes.",
			Tier = 4,
			Cost = 3200,
			Reward = { Type = "TemporaryBoost", BoostId = "CraftHarvestBoost", Multiplier = 1.5, Duration = 1200, Text = "50% Harvest Speed (20m)" },
		},
		{
			Id = "EssenceSurge",
			DisplayName = "Essence Surge",
			Description = "35% essence gain for 15 minutes.",
			Tier = 4,
			Cost = 3000,
			Reward = { Type = "TemporaryBoost", BoostId = "CraftEssenceBoost", Multiplier = 1.35, Duration = 900, Text = "35% Essence Boost (15m)" },
		},
		{
			Id = "GoldenStatueCraft",
			DisplayName = "Golden Statue",
			Description = "Craft a golden kingdom statue at a workshop discount.",
			Tier = 4,
			Cost = 2200,
			Reward = { Type = "Decoration", DecorationId = "GoldenStatue", Text = "Golden Statue decoration" },
		},
		{
			Id = "EpicEggFragment",
			DisplayName = "Epic Egg Fragment",
			Description = "Refined fragment that becomes an Epic quest egg.",
			Tier = 5,
			Cost = 5200,
			Reward = { Type = "QuestEgg", Amount = 1, Text = "+1 Epic Quest Egg" },
		},
		{
			Id = "EssenceVault",
			DisplayName = "Essence Vault",
			Description = "Sealed vault containing 2800 Dragon Essence.",
			Tier = 5,
			Cost = 5800,
			Reward = { Type = "DragonEssence", Amount = 2800, Text = "+2800 Dragon Essence" },
		},
		{
			Id = "StormBanner",
			DisplayName = "Storm Banner",
			Description = "Crackling storm banner for high-tier kingdoms.",
			Tier = 5,
			Cost = 5400,
			Reward = { Type = "Decoration", DecorationId = "StormBanner", Text = "Storm Banner decoration" },
		},
		{
			Id = "GrandElixir",
			DisplayName = "Grand Elixir",
			Description = "Dragons harvest 60% faster for 25 minutes.",
			Tier = 6,
			Cost = 9500,
			Reward = { Type = "TemporaryBoost", BoostId = "CraftHarvestBoost", Multiplier = 1.6, Duration = 1500, Text = "60% Harvest Speed (25m)" },
		},
		{
			Id = "PlatinumCrown",
			DisplayName = "Platinum Crown",
			Description = "Radiant platinum crown decoration.",
			Tier = 6,
			Cost = 8800,
			Reward = { Type = "Decoration", DecorationId = "PlatinumCrown", Text = "Platinum Crown decoration" },
		},
		{
			Id = "RoyalCache",
			DisplayName = "Royal Cache",
			Description = "Royal treasury yielding 6500 Dragon Essence.",
			Tier = 7,
			Cost = 16800,
			Reward = { Type = "DragonEssence", Amount = 6500, Text = "+6500 Dragon Essence" },
		},
		{
			Id = "LegendaryEggCore",
			DisplayName = "Legendary Egg Core",
			Description = "Condensed core that hatches into a Legendary quest egg.",
			Tier = 7,
			Cost = 15500,
			Reward = { Type = "QuestEgg", Amount = 1, Text = "+1 Legendary Quest Egg" },
		},
		{
			Id = "SovereignEssence",
			DisplayName = "Sovereign Essence",
			Description = "50% essence gain for 30 minutes.",
			Tier = 8,
			Cost = 28000,
			Reward = { Type = "TemporaryBoost", BoostId = "CraftEssenceBoost", Multiplier = 1.5, Duration = 1800, Text = "50% Essence Boost (30m)" },
		},
		{
			Id = "ObsidianThrone",
			DisplayName = "Obsidian Throne",
			Description = "Dark obsidian throne fit for a dragon lord.",
			Tier = 8,
			Cost = 26000,
			Reward = { Type = "Decoration", DecorationId = "ObsidianThrone", Text = "Obsidian Throne decoration" },
		},
		{
			Id = "DragonHeartRelic",
			DisplayName = "Dragon Heart Relic",
			Description = "Legendary relic pulsing with 15000 essence.",
			Tier = 9,
			Cost = 48000,
			Reward = { Type = "DragonEssence", Amount = 15000, Text = "+15000 Dragon Essence" },
		},
		{
			Id = "CelestialObelisk",
			DisplayName = "Celestial Obelisk",
			Description = "Max-tier celestial monument for your kingdom.",
			Tier = 9,
			Cost = 52000,
			Reward = { Type = "Decoration", DecorationId = "CelestialObelisk", Text = "Celestial Obelisk decoration" },
		},
	},
}

function WorkshopCraftConfig.GetRecipe(recipeId)
	for _, recipe in WorkshopCraftConfig.Recipes do
		if recipe.Id == recipeId then
			return recipe
		end
	end
	return nil
end

function WorkshopCraftConfig.GetAvailableRecipes(recipeTier)
	local tier = math.max(1, math.floor(tonumber(recipeTier) or 1))
	local available = {}
	for _, recipe in WorkshopCraftConfig.Recipes do
		if (recipe.Tier or 1) <= tier then
			table.insert(available, recipe)
		end
	end
	table.sort(available, function(a, b)
		if a.Tier == b.Tier then
			return a.Cost < b.Cost
		end
		return a.Tier < b.Tier
	end)
	return available
end

return WorkshopCraftConfig
