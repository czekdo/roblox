local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local RebirthState = require(ServerScriptService:WaitForChild("RebirthState"))
local DragonEggConfig = require(ReplicatedStorage:WaitForChild("DragonEggConfig"))
local AdminBridge = require(ServerScriptService:WaitForChild("AdminBridge"))

local AscensionBonusService = {}

local playerBonuses = {}

local ATTRIBUTE_MAP = {
	TrainingSpeedBonus = "AscensionTrainingSpeedBonus",
	HatchLuckBonus = "AscensionHatchLuckBonus",
	ActiveDragonSlots = "AscensionActiveDragonSlots",
	AbilityCooldownReduction = "AscensionAbilityCooldownReduction",
	IslandCostReduction = "AscensionIslandCostReduction",
	HarvestMultiplier = "AscensionHarvestBonus",
	BuildingCostReduction = "AscensionBuildingCostReduction",
	MovementSpeedBonus = "AscensionMovementSpeedBonus",
	PortalSpeedBonus = "AscensionPortalSpeedBonus",
	QuestRewardBonus = "AscensionQuestRewardBonus",
	ExplorationRewardBonus = "AscensionExplorationRewardBonus",
}

local function createEmptyBonuses()
	local bonuses = {}
	for effectType in ATTRIBUTE_MAP do
		bonuses[effectType] = 0
	end
	return bonuses
end

local function computeBonuses(player)
	local bonuses = createEmptyBonuses()
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return bonuses
	end
	if not RebirthState.IsLoaded(player) then
		return bonuses
	end

	for _, node in RebirthConfig.SkillTreeNodes do
		if node.Disabled == true then
			continue
		end
		local rank = RebirthState.GetSkillTreeRank(player, node.Id)
		if rank > 0 and node.EffectType then
			local effectType = node.EffectType
			local perRank = tonumber(node.EffectPerRank) or 0
			bonuses[effectType] = (bonuses[effectType] or 0) + rank * perRank
		end
	end

	return bonuses
end

local function syncAttributes(player, bonuses)
	for effectType, attributeName in ATTRIBUTE_MAP do
		local value = bonuses[effectType] or 0
		if effectType == "ActiveDragonSlots" then
			player:SetAttribute(attributeName, math.floor(value))
		else
			player:SetAttribute(attributeName, value)
		end
	end
end

function AscensionBonusService.RefreshPlayer(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return createEmptyBonuses()
	end

	local bonuses = computeBonuses(player)
	playerBonuses[player] = bonuses
	syncAttributes(player, bonuses)
	return bonuses
end

function AscensionBonusService.ClearPlayer(player)
	playerBonuses[player] = nil
end

function AscensionBonusService.GetBonuses(player)
	if playerBonuses[player] then
		return playerBonuses[player]
	end
	return AscensionBonusService.RefreshPlayer(player)
end

function AscensionBonusService.GetBonus(player, effectType)
	local bonuses = AscensionBonusService.GetBonuses(player)
	return bonuses[effectType] or 0
end

function AscensionBonusService.GetFlatBonus(player, effectType)
	return math.floor(AscensionBonusService.GetBonus(player, effectType))
end

function AscensionBonusService.ApplyCostDiscount(player, baseCost, effectType)
	local numericCost = math.max(0, math.floor(tonumber(baseCost) or 0))
	if numericCost <= 0 then
		return 0
	end
	local reduction = AscensionBonusService.GetBonus(player, effectType or "IslandCostReduction")
	reduction = math.clamp(reduction, 0, 0.9)
	return math.max(1, math.floor(numericCost * (1 - reduction) + 0.5))
end

function AscensionBonusService.ApplyRewardMultiplier(player, baseAmount, effectType)
	local numericAmount = math.max(0, tonumber(baseAmount) or 0)
	local bonus = AscensionBonusService.GetBonus(player, effectType or "QuestRewardBonus")
	return math.max(0, math.floor(numericAmount * (1 + bonus) + 0.5))
end

function AscensionBonusService.GetTrainingSpeedMultiplier(player)
	local bonus = AscensionBonusService.GetBonus(player, "TrainingSpeedBonus")
	return math.max(0.2, 1 - math.min(0.75, bonus))
end

function AscensionBonusService.GetPortalSpeedMultiplier(player)
	local bonus = AscensionBonusService.GetBonus(player, "PortalSpeedBonus")
	return math.max(0.25, 1 - math.min(0.75, bonus))
end

local ABILITY_COOLDOWN_FIELDS = {
	ChainLightning = {
		{ field = "HitsPerChain", mode = "threshold" },
	},
	NaturesBlessing = {
		{ field = "ProcChance", mode = "procChance" },
	},
	MoltenCore = {
		{ field = "MaxHeat", mode = "threshold" },
	},
	OceanBlessing = {
		{ field = "TideRisePerHit", mode = "rate" },
	},
}

function AscensionBonusService.GetAbilityCooldownMultiplier(player)
	local reduction = AscensionBonusService.GetBonus(player, "AbilityCooldownReduction")
	if reduction <= 0 then
		return 1
	end
	return math.max(0.5, 1 - math.min(0.6, reduction))
end

function AscensionBonusService.ApplyAbilityLevelParams(player, handlerId, params)
	if typeof(params) ~= "table" then
		return params
	end

	local rules = ABILITY_COOLDOWN_FIELDS[handlerId]
	if not rules then
		return params
	end

	local adjusted = table.clone(params)
	for _, rule in rules do
		local value = params[rule.field]
		if value ~= nil then
			if rule.mode == "threshold" then
				adjusted[rule.field] = AscensionBonusService.ApplyAbilityThreshold(player, value)
			elseif rule.mode == "rate" then
				adjusted[rule.field] = AscensionBonusService.ApplyAbilityRate(player, value)
			elseif rule.mode == "procChance" then
				adjusted[rule.field] = AscensionBonusService.ApplyAbilityProcChance(player, value)
			end
		end
	end
	return adjusted
end

function AscensionBonusService.ApplyAbilityThreshold(player, baseThreshold)
	local base = math.max(1, math.floor(tonumber(baseThreshold) or 1))
	local multiplier = AscensionBonusService.GetAbilityCooldownMultiplier(player)
	if multiplier >= 1 then
		return base
	end
	return math.max(1, math.floor(base * multiplier + 0.5))
end

function AscensionBonusService.ApplyAbilityRate(player, baseRate)
	local base = math.max(1, math.floor(tonumber(baseRate) or 1))
	local multiplier = AscensionBonusService.GetAbilityCooldownMultiplier(player)
	if multiplier >= 1 then
		return base
	end
	return math.max(1, math.floor(base / multiplier + 0.5))
end

function AscensionBonusService.ApplyAbilityProcChance(player, baseChance)
	local base = math.clamp(tonumber(baseChance) or 0, 0, 1)
	local multiplier = AscensionBonusService.GetAbilityCooldownMultiplier(player)
	if multiplier >= 1 or base <= 0 then
		return base
	end
	return math.clamp(base / multiplier, 0, 1)
end

function AscensionBonusService.RollHatchRarity(player)
	-- Global "Luck Boost" events (admin-triggered, see GlobalEventManager) stack additively with a
	-- player's own Ascension luck bonus - a x1.5 event multiplier becomes +0.5 here, same units as
	-- HatchLuckBonus (0.14 = +14%).
	local ok, globalLuckMultiplier = AdminBridge.call("GlobalEvent", "getMultiplier", "LuckBoost")
	local globalLuckBonus = (ok and tonumber(globalLuckMultiplier) or 1) - 1
	local luckBonus = AscensionBonusService.GetBonus(player, "HatchLuckBonus") + globalLuckBonus
	if luckBonus <= 0 then
		return DragonEggConfig.RollRarity()
	end

	local adjustedWeights = {}
	local totalWeight = 0
	for index, rarity in DragonEggConfig.Rarities do
		local weight = rarity.Weight
		if index > 1 then
			weight *= (1 + luckBonus)
		end
		adjustedWeights[index] = weight
		totalWeight += weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for index, rarity in DragonEggConfig.Rarities do
		cumulative += adjustedWeights[index]
		if roll <= cumulative then
			return rarity.Name
		end
	end

	return DragonEggConfig.Rarities[1].Name
end

function AscensionBonusService.BuildClientPayload(player)
	local bonuses = AscensionBonusService.GetBonuses(player)
	local payload = {}
	for effectType, value in bonuses do
		payload[effectType] = value
	end
	return payload
end

return AscensionBonusService
