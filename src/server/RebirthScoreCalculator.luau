local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))

local RebirthScoreCalculator = {}

local function getBuildingsAt(snapshot, threshold)
	local key = tostring(threshold)
	if typeof(snapshot.buildingsAtOrAbove) == "table" and snapshot.buildingsAtOrAbove[key] ~= nil then
		return math.max(0, math.floor(tonumber(snapshot.buildingsAtOrAbove[key]) or 0))
	end

	local count = 0
	for _, level in typeof(snapshot.buildingLevels) == "table" and snapshot.buildingLevels or {} do
		if (tonumber(level) or 1) >= threshold then
			count += 1
		end
	end
	return count
end

local function meetsGate(snapshot, gate)
	if typeof(gate) ~= "table" then
		return true
	end

	if gate.MinIslandIndex and (snapshot.highestIslandIndex or 0) < gate.MinIslandIndex then
		return false
	end
	if gate.MinKingdomLevel and (snapshot.kingdomLevel or 1) < gate.MinKingdomLevel then
		return false
	end
	if gate.MinAvgBuildingLevel and (snapshot.avgBuildingLevel or 1) < gate.MinAvgBuildingLevel then
		return false
	end
	if gate.MinBuildingsAtLevel and gate.MinBuildingsCount then
		if getBuildingsAt(snapshot, gate.MinBuildingsAtLevel) < gate.MinBuildingsCount then
			return false
		end
	end
	return true
end

function RebirthScoreCalculator.Calculate(snapshot)
	local formula = RebirthConfig.ScoreFormula
	local rebirthCount = math.max(0, math.floor(tonumber(snapshot and snapshot.rebirthCount) or 0))
	local gateTier = RebirthConfig.GetGateTier(rebirthCount)

	local islandIndex = math.max(0, math.floor(tonumber(snapshot.highestIslandIndex) or 0))
	local kingdomLevel = math.max(1, math.floor(tonumber(snapshot.kingdomLevel) or 1))
	local lifetimeEssence = math.max(0, math.floor(tonumber(snapshot.lifetimeEssence) or 0))
	local currentEssence = math.max(0, math.floor(tonumber(snapshot.currentEssence) or 0))

	local buildingDepth = 0
	for _, level in typeof(snapshot.buildingLevels) == "table" and snapshot.buildingLevels or {} do
		buildingDepth += math.max(0, math.floor(tonumber(level) or 1) - formula.BuildingDepthThreshold)
	end

	local islandScore = islandIndex * formula.IslandIndexWeight
	local kingdomScore = kingdomLevel * formula.KingdomLevelWeight
	local buildingScore = buildingDepth * formula.BuildingDepthWeight
	local essenceScore = math.min(
		formula.LifetimeEssenceCap,
		math.floor(lifetimeEssence / math.max(1, formula.LifetimeEssenceDivisor))
	)

	local walletBonus = math.min(
		formula.CurrentEssenceConversionCap,
		math.floor(currentEssence * formula.CurrentEssenceConversionRate)
	)

	local celestialBonus = snapshot.celestialUnlocked == true and formula.CelestialClearBonus or 0

	local subtotal = formula.BaseShards + islandScore + kingdomScore + buildingScore + essenceScore + walletBonus + celestialBonus

	local diminishing = formula.RebirthDiminishingFactor ^ rebirthCount
	subtotal *= diminishing

	local minimumMet = meetsGate(snapshot, gateTier.Minimum)
	local recommendedMet = meetsGate(snapshot, gateTier.Recommended)
	local recommendedBonus = recommendedMet and gateTier.RecommendedBonus or 0

	local total = math.floor(subtotal * (1 + recommendedBonus))
	total = math.max(formula.FloorShards, total)

	return {
		projectedShards = total,
		breakdown = {
			base = formula.BaseShards,
			island = islandScore,
			kingdom = kingdomScore,
			building = buildingScore,
			lifetimeEssence = essenceScore,
			walletConversion = walletBonus,
			celestial = celestialBonus,
			diminishingMultiplier = diminishing,
			recommendedBonus = recommendedBonus,
		},
		minimumGateMet = minimumMet,
		recommendedGateMet = recommendedMet,
		gateTier = gateTier,
	}
end

return RebirthScoreCalculator
