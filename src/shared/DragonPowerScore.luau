local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DragonInventoryConfig = require(ReplicatedStorage:WaitForChild("DragonInventoryConfig"))
local DragonEggConfig = require(ReplicatedStorage:WaitForChild("DragonEggConfig"))

local DragonPowerScore = {}

local function getRarityTiebreaker(rarity)
	local tiebreakers = DragonInventoryConfig.RarityTiebreaker or {}
	return tiebreakers[rarity] or 0
end

-- Single source of truth for dragon strength. Future systems should only adjust this formula.
function DragonPowerScore.Compute(params)
	params = typeof(params) == "table" and params or {}
	local level = math.max(1, math.floor(tonumber(params.level) or 1))
	local evolutionLevel = DragonEggConfig.SanitizeEvolutionLevel(params.evolutionLevel)
	local abilityLevel = math.max(1, math.floor(tonumber(params.abilityLevel) or 1))
	local stats = params.stats or {}
	local harvestSpeed = tonumber(stats.HarvestSpeed) or 1
	local flightSpeed = tonumber(stats.FlightSpeed) or 0
	local carryCapacity = tonumber(stats.CarryCapacity) or 0
	local criticalChance = tonumber(stats.CriticalHarvestChance) or 0
	local luck = tonumber(stats.Luck) or 1

	local score = level * 120
		+ evolutionLevel * 650
		+ abilityLevel * 220
		+ harvestSpeed * 85
		+ carryCapacity * 4
		+ criticalChance * 400
		+ luck * 35
		+ flightSpeed * 12
		+ getRarityTiebreaker(params.rarity) * 0.01

	return math.floor(score * 1000 + 0.5) / 1000
end

return DragonPowerScore
