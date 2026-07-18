local IslandUnlockConfig = require(script.Parent:WaitForChild("IslandUnlockConfig"))

local RebirthConfig = {}

RebirthConfig.DataStoreName = "RebirthProgressV1"
RebirthConfig.SaveDelay = 4
RebirthConfig.SaveVersion = 1

RebirthConfig.Currency = {
	Id = "AscensionShards",
	DisplayName = "Ascension Shards",
	Symbol = "✦",
	IconKey = "Crystal",
}

RebirthConfig.Ceremony = {
	FadeInTime = 0.6,
	HoldTime = 1.2,
	FadeOutTime = 0.8,
	ShardRevealDelay = 0.4,
}

RebirthConfig.FirstRebirth = {
	MinIslandId = "Storm",
	MinKingdomLevel = 12,
	MinBuildingsAtLevel = 8,
	MinBuildingsCount = 3,
	MinLifetimeHatches = 50,
	MinEvolutionStars = 4,
}

-- Minimum island index required before the NEXT rebirth (rebirthCount + 1).
RebirthConfig.IslandMinimums = {
	{ MaxRebirth = 1, MinIslandIndex = 4 }, -- Storm
	{ MaxRebirth = 3, MinIslandIndex = 5 }, -- Shadow
	{ MaxRebirth = 7, MinIslandIndex = 6 }, -- Crystal
	{ MaxRebirth = math.huge, MinIslandIndex = 7 }, -- Celestial
}

-- Depth gates scale with rebirth tier.
RebirthConfig.GateTiers = {
	{
		MaxRebirth = 1,
		Minimum = { MinIslandIndex = 4, MinKingdomLevel = 12 },
		Recommended = { MinIslandIndex = 7, MinKingdomLevel = 15 },
		RecommendedBonus = 0.30,
	},
	{
		MaxRebirth = 4,
		Minimum = { MinIslandIndex = 5, MinKingdomLevel = 15 },
		Recommended = { MinIslandIndex = 7, MinKingdomLevel = 18, MinBuildingsAtLevel = 15, MinBuildingsCount = 1 },
		RecommendedBonus = 0.25,
	},
	{
		MaxRebirth = 9,
		Minimum = { MinIslandIndex = 6, MinKingdomLevel = 18 },
		Recommended = { MinIslandIndex = 7, MinKingdomLevel = 20, MinAvgBuildingLevel = 18 },
		RecommendedBonus = 0.20,
	},
	{
		MaxRebirth = 19,
		Minimum = { MinIslandIndex = 7, MinKingdomLevel = 20 },
		Recommended = { MinIslandIndex = 7, MinKingdomLevel = 22, MinBuildingsAtLevel = 20, MinBuildingsCount = 2 },
		RecommendedBonus = 0.18,
	},
	{
		MaxRebirth = math.huge,
		Minimum = { MinIslandIndex = 7, MinKingdomLevel = 22 },
		Recommended = { MinIslandIndex = 7, MinKingdomLevel = 24, MinAvgBuildingLevel = 22 },
		RecommendedBonus = 0.15,
	},
}

RebirthConfig.ScoreFormula = {
	FloorShards = 10,
	BaseShards = 25,
	IslandIndexWeight = 45,
	KingdomLevelWeight = 18,
	BuildingDepthWeight = 8,
	BuildingDepthThreshold = 5,
	LifetimeEssenceDivisor = 25000,
	LifetimeEssenceCap = 120,
	CurrentEssenceConversionRate = 0.12,
	CurrentEssenceConversionCap = 40,
	CelestialClearBonus = 35,
	RebirthDiminishingFactor = 0.92,
}

RebirthConfig.SkillTreeBranches = {
	{ Id = "Dragon", Name = "Dragon Path", Emoji = "🐉", IconKey = "Dragon" },
	{ Id = "Kingdom", Name = "Kingdom Path", Emoji = "🏰", IconKey = "Crown" },
	{ Id = "Explorer", Name = "Explorer Path", Emoji = "🧭", IconKey = "House" },
}

RebirthConfig.SkillTreeNodes = {
	-- Dragon Path
	{ Id = "Dragon_TrainingPace", Branch = "Dragon", DisplayName = "Swift Training", Description = "Dragons train faster each rank.", MaxRank = 5, CostPerRank = { 15, 25, 40, 60, 85 }, Prerequisites = {}, EffectType = "TrainingSpeedBonus", EffectPerRank = 0.08 },
	{ Id = "Dragon_HatchFortune", Branch = "Dragon", DisplayName = "Hatch Fortune", Description = "Improves rare hatch odds.", MaxRank = 4, CostPerRank = { 20, 35, 55, 80 }, Prerequisites = {}, EffectType = "HatchLuckBonus", EffectPerRank = 0.05 },
	{ Id = "Dragon_ActiveSlots", Branch = "Dragon", DisplayName = "Active Brood", Description = "Unlock an additional active harvest dragon.", MaxRank = 2, CostPerRank = { 50, 100 }, Prerequisites = { "Dragon_TrainingPace" }, EffectType = "ActiveDragonSlots", EffectPerRank = 1 },
	{ Id = "Dragon_AbilityMastery", Branch = "Dragon", DisplayName = "Ability Mastery", Description = "Dragon abilities recharge faster.", MaxRank = 3, CostPerRank = { 30, 50, 75 }, Prerequisites = { "Dragon_TrainingPace" }, EffectType = "AbilityCooldownReduction", EffectPerRank = 0.06 },
	-- Kingdom Path
	{ Id = "Kingdom_IslandDiscount", Branch = "Kingdom", DisplayName = "Island Charter", Description = "Reduces island unlock costs.", MaxRank = 5, CostPerRank = { 20, 30, 45, 65, 90 }, Prerequisites = {}, EffectType = "IslandCostReduction", EffectPerRank = 0.05 },
	{ Id = "Kingdom_HarvestFlow", Branch = "Kingdom", DisplayName = "Harvest Flow", Description = "Increases essence per harvest hit.", MaxRank = 5, CostPerRank = { 15, 25, 40, 60, 85 }, Prerequisites = {}, EffectType = "HarvestMultiplier", EffectPerRank = 0.06 },
	{ Id = "Kingdom_BuilderGuild", Branch = "Kingdom", DisplayName = "Builder Guild", Description = "Reduces building upgrade costs.", MaxRank = 4, CostPerRank = { 25, 40, 60, 85 }, Prerequisites = { "Kingdom_IslandDiscount" }, EffectType = "BuildingCostReduction", EffectPerRank = 0.07 },
	{ Id = "Kingdom_StorageLegacy", Branch = "Kingdom", DisplayName = "Storage Legacy", Description = "Buildings reset to a higher floor level.", MaxRank = 3, CostPerRank = { 40, 70, 110 }, Prerequisites = { "Kingdom_BuilderGuild" }, EffectType = "BuildingResetFloor", EffectPerRank = 1 },
	-- Explorer Path
	{ Id = "Explorer_SwiftStride", Branch = "Explorer", DisplayName = "Swift Stride", Description = "Permanent movement speed bonus.", MaxRank = 4, CostPerRank = { 15, 25, 40, 60 }, Prerequisites = {}, EffectType = "MovementSpeedBonus", EffectPerRank = 0.05 },
	{ Id = "Explorer_PortalNetwork", Branch = "Explorer", DisplayName = "Portal Network", Description = "Faster portal travel and shorter cooldowns.", MaxRank = 3, CostPerRank = { 30, 50, 80 }, Prerequisites = { "Explorer_SwiftStride" }, EffectType = "PortalSpeedBonus", EffectPerRank = 0.10 },
	{ Id = "Explorer_QuestInsight", Branch = "Explorer", DisplayName = "Quest Insight", Description = "Daily quest rewards are more generous.", MaxRank = 4, CostPerRank = { 20, 35, 55, 80 }, Prerequisites = {}, EffectType = "QuestRewardBonus", EffectPerRank = 0.08 },
	{ Id = "Explorer_ShrineSense", Branch = "Explorer", DisplayName = "Shrine Sense", Description = "Bonus essence from island shrine interactions.", MaxRank = 3, CostPerRank = { 25, 45, 70 }, Prerequisites = { "Explorer_PortalNetwork" }, EffectType = "ExplorationRewardBonus", EffectPerRank = 0.10, Disabled = true },
}

RebirthConfig.Milestones = {
	{ RebirthCount = 5, RewardType = "Title", RewardId = "AscendantV", DisplayName = "Ascendant V", Description = "Exclusive title for five rebirths." },
	{ RebirthCount = 10, RewardType = "Aura", RewardId = "AscensionFlare", DisplayName = "Ascension Flare", Description = "Dragon aura unlocked at ten rebirths." },
	{ RebirthCount = 15, RewardType = "PortalEffect", RewardId = "StarfallPortal", DisplayName = "Starfall Portal", Description = "Unique portal travel effect." },
	{ RebirthCount = 25, RewardType = "Cosmetic", RewardId = "EternalExpeditionCloak", DisplayName = "Eternal Expedition Cloak", Description = "Exclusive cosmetic reward." },
	{ RebirthCount = 50, RewardType = "Aura", RewardId = "LegendOfIslands", DisplayName = "Legend of Islands", Description = "Legendary visual reward." },
}

local nodeById = {}
local nodesByBranch = {}
local milestoneByCount = {}

for _, node in RebirthConfig.SkillTreeNodes do
	nodeById[node.Id] = node
	nodesByBranch[node.Branch] = nodesByBranch[node.Branch] or {}
	table.insert(nodesByBranch[node.Branch], node)
end

for _, milestone in RebirthConfig.Milestones do
	milestoneByCount[milestone.RebirthCount] = milestone
end

function RebirthConfig.GetNextRebirthNumber(rebirthCount)
	return math.max(1, math.floor(tonumber(rebirthCount) or 0) + 1)
end

function RebirthConfig.GetGateTier(rebirthCount)
	local nextRebirth = RebirthConfig.GetNextRebirthNumber(rebirthCount)
	for _, tier in RebirthConfig.GateTiers do
		if nextRebirth <= tier.MaxRebirth then
			return tier
		end
	end
	return RebirthConfig.GateTiers[#RebirthConfig.GateTiers]
end

function RebirthConfig.GetMinimumIslandIndex(rebirthCount)
	local nextRebirth = RebirthConfig.GetNextRebirthNumber(rebirthCount)
	for _, entry in RebirthConfig.IslandMinimums do
		if nextRebirth <= entry.MaxRebirth then
			return entry.MinIslandIndex
		end
	end
	return 7
end

function RebirthConfig.GetIslandIdByIndex(index)
	local islands = IslandUnlockConfig.Islands
	local island = islands[math.clamp(math.floor(index or 1), 1, #islands)]
	return island and island.Id or nil
end

function RebirthConfig.GetIslandIndex(islandId)
	return IslandUnlockConfig.GetIslandIndex(islandId) or 0
end

function RebirthConfig.GetSkillTreeNode(nodeId)
	return nodeById[nodeId]
end

function RebirthConfig.IsSkillTreeNodeEnabled(nodeId)
	local node = nodeById[nodeId]
	return node ~= nil and node.Disabled ~= true
end

function RebirthConfig.GetSkillTreeNodesForBranch(branchId)
	return nodesByBranch[branchId] or {}
end

function RebirthConfig.GetMilestone(rebirthCount)
	return milestoneByCount[math.floor(tonumber(rebirthCount) or 0)]
end

function RebirthConfig.GetNodeCost(nodeId, currentRank)
	local node = nodeById[nodeId]
	if not node then
		return nil
	end
	local nextRank = math.floor(tonumber(currentRank) or 0) + 1
	if nextRank > (node.MaxRank or 1) then
		return nil
	end
	return node.CostPerRank[nextRank]
end

return RebirthConfig
