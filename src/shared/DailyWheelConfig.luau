local DailyWheelConfig = {}

-- A Gems sink: once the free daily spin is used, players can pay Gems for extra spins, capped per
-- day so it stays a nice-to-have rather than a way to grind the wheel's rewards without limit.
DailyWheelConfig.ExtraSpin = {
	Cost = 15,
	MaxPerDay = 3,
}

-- The 2D wheel graphic (drawn in DailyWheelClient.client.luau) has 8 wedges of unequal width.
-- Since the reward economy only has 6 distinct reward types, Dragon Essence and Quest Egg (the two
-- most common rewards) each occupy two wedges; their weights are split across their two entries so
-- the overall drop-rate economy matches a 6-reward design. Order matches the wheel graphic's visual
-- segments going clockwise from the top pointer; each wedge's exact center angle is defined in
-- DailyWheelClient.client.luau's SEGMENT_CENTER_ANGLES (spacing is not uniform).
DailyWheelConfig.Segments = {
	{
		Id = "Essence",
		DisplayName = "Dragon Essence",
		Weight = 18,
		Reward = { Type = "DragonEssence", Amount = 220, Text = "+220 Dragon Essence" },
	},
	{
		Id = "Egg",
		DisplayName = "Quest Egg",
		Weight = 8,
		Reward = { Type = "Eggs", Amount = 1, Text = "+1 Quest Egg" },
	},
	{
		Id = "Gems",
		DisplayName = "Premium Gems",
		Weight = 8,
		Reward = { Type = "PremiumCurrency", Amount = 8, Text = "+8 Gems" },
	},
	{
		Id = "EssenceGold",
		DisplayName = "Dragon Essence",
		Weight = 17,
		Reward = { Type = "DragonEssence", Amount = 220, Text = "+220 Dragon Essence" },
	},
	{
		Id = "Potion",
		DisplayName = "Essence Boost Potion",
		Weight = 17,
		Reward = { Type = "InventoryItem", ItemId = "EssenceBoost", Amount = 1, Text = "+1 Essence Boost Potion" },
	},
	{
		Id = "EggBlue",
		DisplayName = "Quest Egg",
		Weight = 7,
		Reward = { Type = "Eggs", Amount = 1, Text = "+1 Quest Egg" },
	},
	{
		Id = "HarvestBoost",
		DisplayName = "Harvest Boost",
		Weight = 17,
		Reward = { Type = "TemporaryBoost", BoostId = "DailyWheelHarvestBoost", Multiplier = 1.3, Duration = 900, Text = "30% Harvest Speed (15m)" },
	},
	{
		Id = "Decoration",
		DisplayName = "Stone Lantern",
		Weight = 8,
		Reward = { Type = "Decoration", DecorationId = "StoneLantern", Text = "Stone Lantern decoration" },
	},
}

function DailyWheelConfig.GetTotalWeight()
	local total = 0
	for _, segment in DailyWheelConfig.Segments do
		total += segment.Weight
	end
	return total
end

-- Deterministic weighted pick. Returns the segment table and its index (1-based, matching the
-- wheel's clockwise visual order) so the caller can compute the landing angle.
function DailyWheelConfig.RollSegment()
	local total = DailyWheelConfig.GetTotalWeight()
	local roll = math.random() * total
	local cumulative = 0
	for index, segment in DailyWheelConfig.Segments do
		cumulative += segment.Weight
		if roll <= cumulative then
			return segment, index
		end
	end
	return DailyWheelConfig.Segments[#DailyWheelConfig.Segments], #DailyWheelConfig.Segments
end

return DailyWheelConfig
