local InventoryItemConfig = {}

InventoryItemConfig.Items = {
	EssenceBoost = {
		DisplayName = "Essence Boost Potion",
		Description = "Drink for 25% essence gain for 10 minutes.",
		Effect = { Type = "TemporaryBoost", BoostId = "CraftEssenceBoost", Multiplier = 1.25, Duration = 600 },
	},
	HarvestElixir = {
		DisplayName = "Harvest Elixir",
		Description = "Dragons harvest 40% faster for 15 minutes.",
		Effect = { Type = "TemporaryBoost", BoostId = "CraftHarvestBoost", Multiplier = 1.4, Duration = 900 },
	},
	MasterworkElixir = {
		DisplayName = "Masterwork Elixir",
		Description = "Dragons harvest 50% faster for 20 minutes.",
		Effect = { Type = "TemporaryBoost", BoostId = "CraftHarvestBoost", Multiplier = 1.5, Duration = 1200 },
	},
	EssenceSurge = {
		DisplayName = "Essence Surge",
		Description = "Drink for 35% essence gain for 15 minutes.",
		Effect = { Type = "TemporaryBoost", BoostId = "CraftEssenceBoost", Multiplier = 1.35, Duration = 900 },
	},
	GrandElixir = {
		DisplayName = "Grand Elixir",
		Description = "Dragons harvest 60% faster for 25 minutes.",
		Effect = { Type = "TemporaryBoost", BoostId = "CraftHarvestBoost", Multiplier = 1.6, Duration = 1500 },
	},
	SovereignEssence = {
		DisplayName = "Sovereign Essence",
		Description = "Drink for 50% essence gain for 30 minutes.",
		Effect = { Type = "TemporaryBoost", BoostId = "CraftEssenceBoost", Multiplier = 1.5, Duration = 1800 },
	},
}

function InventoryItemConfig.GetItem(itemId)
	return InventoryItemConfig.Items[itemId]
end

return InventoryItemConfig
