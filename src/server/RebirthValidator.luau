local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RebirthConfig = require(ReplicatedStorage:WaitForChild("RebirthConfig"))
local RebirthScoreCalculator = require(script.Parent:WaitForChild("RebirthScoreCalculator"))

local RebirthValidator = {}

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

local function validateFirstRebirth(snapshot)
	local first = RebirthConfig.FirstRebirth
	local reasons = {}
	local requirements = {}

	local requiredIslandIndex = RebirthConfig.GetIslandIndex(first.MinIslandId)
	local islandMet = (snapshot.highestIslandIndex or 0) >= requiredIslandIndex
	table.insert(requirements, {
		Id = "FirstRebirth_Island",
		Label = "Unlock Storm Island",
		Met = islandMet,
		Current = snapshot.highestIslandId or "None",
		Target = first.MinIslandId,
	})
	if not islandMet then
		table.insert(reasons, "Unlock Storm Island to begin your first Rebirth.")
	end

	local kingdomMet = (snapshot.kingdomLevel or 1) >= first.MinKingdomLevel
	table.insert(requirements, {
		Id = "FirstRebirth_KingdomLevel",
		Label = string.format("Reach Kingdom Level %d", first.MinKingdomLevel),
		Met = kingdomMet,
		Current = snapshot.kingdomLevel or 1,
		Target = first.MinKingdomLevel,
	})
	if not kingdomMet then
		table.insert(reasons, string.format("Reach Kingdom Level %d.", first.MinKingdomLevel))
	end

	local buildingsMet = getBuildingsAt(snapshot, first.MinBuildingsAtLevel) >= first.MinBuildingsCount
	table.insert(requirements, {
		Id = "FirstRebirth_Buildings",
		Label = string.format("Upgrade %d buildings to Level %d+", first.MinBuildingsCount, first.MinBuildingsAtLevel),
		Met = buildingsMet,
		Current = getBuildingsAt(snapshot, first.MinBuildingsAtLevel),
		Target = first.MinBuildingsCount,
	})
	if not buildingsMet then
		table.insert(reasons, string.format("Upgrade %d buildings to Level %d+.", first.MinBuildingsCount, first.MinBuildingsAtLevel))
	end

	local hatchOk = (snapshot.lifetimeHatches or 0) >= first.MinLifetimeHatches
	local starOk = (snapshot.maxEvolutionStars or 0) >= first.MinEvolutionStars
	local dragonMet = hatchOk or starOk
	table.insert(requirements, {
		Id = "FirstRebirth_Dragons",
		Label = string.format("Hatch %d dragons or reach a %d-star dragon", first.MinLifetimeHatches, first.MinEvolutionStars),
		Met = dragonMet,
		Current = string.format("%d hatches / %d stars", snapshot.lifetimeHatches or 0, snapshot.maxEvolutionStars or 0),
		Target = string.format("%d hatches or %d stars", first.MinLifetimeHatches, first.MinEvolutionStars),
	})
	if not dragonMet then
		table.insert(reasons, string.format("Hatch %d dragons or reach a %d-star dragon.", first.MinLifetimeHatches, first.MinEvolutionStars))
	end

	return reasons, requirements
end

local function buildGateRequirements(snapshot, gate, prefix)
	local requirements = {}
	if typeof(gate) ~= "table" then
		return requirements
	end

	if gate.MinIslandIndex then
		local islandId = RebirthConfig.GetIslandIdByIndex(gate.MinIslandIndex) or ("Island " .. tostring(gate.MinIslandIndex))
		table.insert(requirements, {
			Id = prefix .. "_Island",
			Label = string.format("Reach %s", islandId),
			Met = (snapshot.highestIslandIndex or 0) >= gate.MinIslandIndex,
			Current = snapshot.highestIslandId or snapshot.highestIslandIndex or 0,
			Target = islandId,
		})
	end

	if gate.MinKingdomLevel then
		table.insert(requirements, {
			Id = prefix .. "_KingdomLevel",
			Label = string.format("Reach Kingdom Level %d", gate.MinKingdomLevel),
			Met = (snapshot.kingdomLevel or 1) >= gate.MinKingdomLevel,
			Current = snapshot.kingdomLevel or 1,
			Target = gate.MinKingdomLevel,
		})
	end

	if gate.MinAvgBuildingLevel then
		table.insert(requirements, {
			Id = prefix .. "_AvgBuildingLevel",
			Label = string.format("Average building level %d+", gate.MinAvgBuildingLevel),
			Met = (snapshot.avgBuildingLevel or 1) >= gate.MinAvgBuildingLevel,
			Current = math.floor((snapshot.avgBuildingLevel or 1) * 10) / 10,
			Target = gate.MinAvgBuildingLevel,
		})
	end

	if gate.MinBuildingsAtLevel and gate.MinBuildingsCount then
		table.insert(requirements, {
			Id = prefix .. "_Buildings",
			Label = string.format("Upgrade %d buildings to Level %d+", gate.MinBuildingsCount, gate.MinBuildingsAtLevel),
			Met = getBuildingsAt(snapshot, gate.MinBuildingsAtLevel) >= gate.MinBuildingsCount,
			Current = getBuildingsAt(snapshot, gate.MinBuildingsAtLevel),
			Target = gate.MinBuildingsCount,
		})
	end

	return requirements
end

function RebirthValidator.Validate(snapshot, options)
	options = options or {}

	if typeof(snapshot) ~= "table" then
		return {
			eligible = false,
			reason = "Run snapshot unavailable.",
			reasons = { "Run snapshot unavailable." },
			requirements = {},
			minimumGateMet = false,
			recommendedGateMet = false,
			projectedShards = 0,
		}
	end

	if snapshot.hasPendingTransactions == true and options.ignorePendingTransactions ~= true then
		return {
			eligible = false,
			reason = "Finish pending actions before Rebirth.",
			reasons = { "Finish pending actions before Rebirth." },
			requirements = {},
			minimumGateMet = false,
			recommendedGateMet = false,
			projectedShards = 0,
		}
	end

	local rebirthCount = math.max(0, math.floor(tonumber(snapshot.rebirthCount) or 0))
	local gateTier = RebirthConfig.GetGateTier(rebirthCount)
	local score = RebirthScoreCalculator.Calculate(snapshot)
	local reasons = {}
	local requirements = {}

	if rebirthCount == 0 then
		local firstReasons, firstRequirements = validateFirstRebirth(snapshot)
		for _, reason in firstReasons do
			table.insert(reasons, reason)
		end
		for _, requirement in firstRequirements do
			table.insert(requirements, requirement)
		end
	end

	local minimumRequirements = buildGateRequirements(snapshot, gateTier.Minimum, "Minimum")
	for _, requirement in minimumRequirements do
		table.insert(requirements, requirement)
	end

	if not meetsGate(snapshot, gateTier.Minimum) then
		local minimumIslandIndex = gateTier.Minimum.MinIslandIndex or RebirthConfig.GetMinimumIslandIndex(rebirthCount)
		local islandId = RebirthConfig.GetIslandIdByIndex(minimumIslandIndex) or "later islands"
		table.insert(reasons, string.format("Reach %s and Kingdom Level %d to Rebirth.", islandId, gateTier.Minimum.MinKingdomLevel or 1))
	end

	local recommendedRequirements = buildGateRequirements(snapshot, gateTier.Recommended, "Recommended")
	for _, requirement in recommendedRequirements do
		table.insert(requirements, requirement)
	end

	local eligible = #reasons == 0

	return {
		eligible = eligible,
		reason = reasons[1],
		reasons = reasons,
		requirements = requirements,
		minimumGateMet = score.minimumGateMet,
		recommendedGateMet = score.recommendedGateMet,
		projectedShards = score.projectedShards,
		scoreBreakdown = score.breakdown,
		gateTier = gateTier,
		nextRebirthNumber = RebirthConfig.GetNextRebirthNumber(rebirthCount),
	}
end

return RebirthValidator
